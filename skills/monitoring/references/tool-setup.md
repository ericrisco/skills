# Tool setup

Concrete, copy-pasteable configs. Pricing/versions as of 2026-06.

## Uptime Kuma (self-hosted, free)

`docker-compose.yml` — rootless image, persistent volume, single port.

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:2.1.3-rootless
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - kuma-data:/app/data
    ports:
      - "3001:3001"
volumes:
  kuma-data:
```

```bash
docker compose up -d
# open http://your-vps:3001, create the admin user on first load,
# then put it behind your reverse proxy with TLS (do not expose 3001 raw).
```

Monitors to add (Kuma calls them "Monitor type"):

- **HTTP(s)** on your critical endpoint — set "Accepted status codes" to `200-299`, interval 60s, retries 3, and enable **Globalping** (Kuma 2.1) to probe from multiple regions instead of just the box.
- **HTTP(s) – Keyword** to assert a string in the body (e.g. a logged-in marker), so a 200 that renders an error page still alerts.
- **Push** (heartbeat) for a cron/worker: the job `curl`s a Kuma push URL each run; if the beat is missed, Kuma pages. This catches *silent* batch failures.
- **TLS expiry**: enable "Certificate Expiry Notification" on the HTTP monitor; notify at 14 days.
- **Domain expiry**: Kuma 2.1 has a domain-expiry monitor type; notify at 30 days.

```bash
# Push-heartbeat from a cron job — alert fires if this stops arriving.
*/5 * * * * /usr/bin/curl -fsS "https://kuma.example.com/api/push/AbC123?status=up&msg=ok" >/dev/null
```

## Notification wiring

Kuma has 90+ channels; here are the three you actually use.

```bash
# ntfy — dead-simple push to your phone, self-hostable, free.
# In Kuma: Settings → Notifications → ntfy. Server https://ntfy.sh, topic = a long random string.
curl -d "checkout 5xx > 2%" ntfy.sh/your-long-random-topic   # test it lands
```

```json
// Slack incoming webhook — paste the webhook URL into Kuma's Slack notification.
{ "text": "🔴 [PAGE] checkout error rate 4.1% (>2% for 5m) — runbook: https://wiki/runbooks/checkout-5xx" }
```

```text
# PagerDuty — use Events API v2. In PagerDuty create a service → integration
# "Events API v2" → copy the Integration Key (routing key) into Kuma's PagerDuty
# notification. Critical severity routes to the on-call escalation policy.
Integration Key: R0UT1NGK3Yxxxxxxxxxxxxxxxxxxxxxxx
Severity:        critical   # so it pages, not just logs
```

## Managed alternative — monitor config shape

UptimeRobot / Better Stack store this server-side; the shape you reason about:

```json
{
  "type": "http",
  "url": "https://api.example.com/readyz",
  "method": "GET",
  "expected_status": 200,
  "interval_seconds": 60,
  "regions": ["eu", "us-east", "ap"],
  "assertions": [
    { "type": "status_code", "comparison": "equals", "target": 200 },
    { "type": "response_time", "comparison": "less_than", "target_ms": 800 },
    { "type": "body", "comparison": "contains", "target": "\"status\":\"ready\"" }
  ],
  "ssl_expiry_alert_days": 14,
  "domain_expiry_alert_days": 30,
  "on_failure": { "after_failures": 2, "notify": ["pagerduty-critical"] }
}
```

## Synthetic critical-journey check

Not just `GET /` — exercise the path that earns money. Shape of a multi-step synthetic:

```yaml
# synthetic: login -> add to cart -> checkout. Run every 5 min from 2+ regions.
name: checkout-journey
steps:
  - POST /api/login        { body: { user: "$SYNTH_USER", pass: "$SYNTH_PASS" }, expect: 200 }
  - POST /api/cart         { body: { sku: "TEST-SKU", qty: 1 }, expect: 200, save: cart_id }
  - POST /api/checkout     { body: { cart: "$cart_id", token: "tok_test" }, expect: 200 }
assert:
  - total_duration_ms < 4000
on_fail: page   # this is real user impact
```

## Health-endpoint handlers

### FastAPI (Python)

```python
from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI()

@app.get("/livez")           # liveness: process only. Orchestrator restarts on fail.
def livez():
    return {"status": "alive"}

@app.get("/readyz")          # readiness: deps with short timeouts. LB pulls instance on fail.
async def readyz():
    checks = {
        "db": await ping_db(timeout=0.2),
        "cache": await ping_cache(timeout=0.1),
    }
    ready = all(checks.values())
    return JSONResponse(
        {"status": "ready" if ready else "degraded", "checks": checks},
        status_code=200 if ready else 503,
    )
```

### Go

```go
// Liveness: process only, ~instant. Never touch the DB here.
http.HandleFunc("/livez", func(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    _, _ = w.Write([]byte(`{"status":"alive"}`))
})

// Readiness: deps with a tight deadline so the probe stays cheap (<100ms).
http.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), 200*time.Millisecond)
    defer cancel()
    w.Header().Set("Content-Type", "application/json")
    if err := db.PingContext(ctx); err != nil {
        w.WriteHeader(http.StatusServiceUnavailable) // 503 -> LB pulls this instance
        _, _ = w.Write([]byte(`{"status":"degraded","checks":{"db":false}}`))
        return
    }
    w.WriteHeader(http.StatusOK)
    _, _ = w.Write([]byte(`{"status":"ready","checks":{"db":true}}`))
})
```
