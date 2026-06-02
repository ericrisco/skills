# Collector config — fuller recipes

Branch-specific Collector depth offloaded from `SKILL.md`. Shapes target Collector **v0.153.0**. An exporter or processor is inert until it is named in a `service.pipelines` entry.

## Gateway vs agent topology

Two deployment shapes; most production setups run both as a tiered pipeline.

- **Agent** — one Collector per host/pod (sidecar or DaemonSet), close to the app. Cheap network hop, does fast local work: `memory_limiter`, `batch`, `resourcedetection`. Forwards via OTLP to the gateway.
- **Gateway** — a horizontally-scaled standalone tier. Does the expensive, stateful work that needs a *whole-trace* view: `tail_sampling`, cross-service `redaction`, per-tenant routing, backend fan-out. Scale it independently of your apps.

Rule: do per-span/per-host work in the agent, do whole-trace and policy work in the gateway. Tail sampling in an agent is wrong — an agent never sees a full trace.

```yaml
# agent (DaemonSet) → forwards everything to the gateway
exporters:
  otlp/gateway: { endpoint: otel-gateway:4317, tls: { insecure: false } }
service:
  pipelines:
    traces:  { receivers: [otlp], processors: [memory_limiter, resourcedetection, batch], exporters: [otlp/gateway] }
    metrics: { receivers: [otlp], processors: [memory_limiter, batch],                     exporters: [otlp/gateway] }
    logs:    { receivers: [otlp], processors: [memory_limiter, batch],                     exporters: [otlp/gateway] }
```

## Tail sampling (gateway only)

Head sampling decides at span start, before you know if the request was interesting. **Tail sampling** buffers the whole trace and decides at the end — so you keep every error and every slow trace, and sample the boring fast ones. It must run on the gateway, after a `groupbytrace`-style stage so all spans of a trace land on the same Collector.

```yaml
processors:
  tail_sampling:
    decision_wait: 10s            # how long to buffer a trace before deciding
    num_traces: 100000
    policies:
      - name: keep-errors
        type: status_code
        status_code: { status_codes: [ERROR] }     # never drop a failed trace
      - name: keep-slow
        type: latency
        latency: { threshold_ms: 1000 }             # never drop a slow trace
      - name: sample-the-rest
        type: probabilistic
        probabilistic: { sampling_percentage: 5 }   # 5% of the boring ones
```

## Redaction / attributes for PII

Strip sensitive data before it leaves your network. `redaction` masks values by regex; `attributes` deletes or hashes specific keys.

```yaml
processors:
  redaction:
    allow_all_keys: true
    blocked_values:
      - "\\b[0-9]{13,16}\\b"                # card PANs
      - "\\b[\\w.+-]+@[\\w-]+\\.[\\w.-]+\\b" # emails
    summary: debug                          # report what it masked, at debug
  attributes/pii:
    actions:
      - { key: user.email, action: delete }
      - { key: user.id,    action: hash }   # keep joinable, not readable
```

Wire both into the pipeline's `processors` list before the exporter, or they do nothing.

## Multi-backend fan-out (LGTM + a vendor in parallel)

A pipeline's `exporters` list is a fan-out — list two and every item goes to both. Useful for migrating off a vendor, or keeping a cheap self-hosted copy beside a managed one.

```yaml
exporters:
  otlphttp/tempo:    { endpoint: http://tempo:4318 }
  otlphttp/honeycomb:
    endpoint: https://api.honeycomb.io
    headers: { "x-honeycomb-team": "${env:HONEYCOMB_API_KEY}" }
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp/tempo, otlphttp/honeycomb]   # both, in parallel
```

LGTM split for reference: **Loki** logs, **Tempo** traces, **Mimir/Prometheus** metrics, **Grafana** to view.

## resourcedetection + env-var overrides

`resourcedetection` auto-fills `host.*`, `cloud.*`, `k8s.*`, `container.*` resource attributes so you don't hand-set them per deploy. Combine with env-var interpolation (`${env:VAR}`) so the same config file works across environments — never bake secrets or per-env endpoints into the file.

```yaml
processors:
  resourcedetection:
    detectors: [env, system, gcp, eks]    # order = precedence
    timeout: 2s
exporters:
  otlphttp/metrics:
    endpoint: "${env:METRICS_ENDPOINT}"   # differs per environment, injected at runtime
```
