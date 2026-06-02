# TLS & ACME

## The 2026 lifetime schedule

The CA/Browser Forum (ballot SC-081v3, voting closed 2025-04-11) ratcheted the **maximum public-TLS certificate lifetime** down on a fixed timeline. Domain-validation (DCV) reuse shrinks in lockstep.

| Effective | Max cert lifetime | Max DCV reuse |
| --- | --- | --- |
| 2026-03-15 | 200 days | 200 days |
| 2027-03-15 | 100 days | 100 days |
| 2029-03-15 | 47 days | 10 days |

Consequence: a human renewing once a year cannot keep up. Every cert path must auto-renew. Let's Encrypt's own default lifetime is moving 90 → 64 → 45 days across 2025–2026, ahead of the CA/B floor.

## HTTP-01 vs DNS-01

| | HTTP-01 | DNS-01 |
| --- | --- | --- |
| Proof | Serve a token at `http://host/.well-known/acme-challenge/...` | Publish a `_acme-challenge` TXT |
| Needs | Inbound port 80 on the host | API access to the DNS zone |
| Wildcards | No | **Yes — wildcards require DNS-01** |
| Off-box issuance | No (must answer on the host) | Yes (issue anywhere) |

Pick DNS-01 when you need `*.example.com`, when port 80 is closed, or when the cert is issued somewhere other than the serving host.

## certbot (HTTP-01, single host)

```bash
# Test against STAGING first so retries don't burn the production rate limit.
certbot certonly --standalone \
  --staging \
  -d example.com -d www.example.com \
  --agree-tos -m admin@example.com --non-interactive

# Then production once the dry run is clean:
certbot certonly --standalone \
  -d example.com -d www.example.com \
  --agree-tos -m admin@example.com --non-interactive
```

certbot installs a systemd timer (`certbot.timer`) or cron entry that renews automatically. Verify it:

```bash
systemctl list-timers | grep certbot
certbot renew --dry-run        # exercises the full renewal path without issuing
```

## acme.sh (DNS-01, wildcard)

```bash
# DNS-01 via the provider's API (Cloudflare token in env) for a wildcard.
export CF_Token="..."; export CF_Account_ID="..."
acme.sh --issue --dns dns_cf -d example.com -d '*.example.com' --staging
acme.sh --issue --dns dns_cf -d example.com -d '*.example.com'   # production
```

acme.sh registers its own cron renewal on install. Always serve the **fullchain**, not the leaf.

## Serve the full chain

```nginx
ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;  # leaf + intermediates
ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
```

A leaf-only config validates in browsers (they cache intermediates from prior sites) and fails on `curl`, mobile, and fresh clients. Always point at `fullchain.pem`.

## Rate limits & ARI

- Let's Encrypt: **50 certificates per registered domain per rolling 7 days**, counted globally across all your ACME accounts.
- **Renewals recognized via ARI (ACME Renewal Info) are exempt** from the limit, so well-behaved auto-renewal never trips it.
- Testing/CI loops must hit the **staging** endpoint, or one bad loop locks you out for a week.

## Platform-managed certs

Let the host do it when it can — Vercel, Netlify, and Cloudflare provision and renew automatically once the DNS record resolves to them. Do not stack certbot on top.

- **Cloudflare SSL mode** matters: *Flexible* terminates TLS at the edge and talks plaintext to your origin (insecure, can loop-redirect). *Full* encrypts edge↔origin but doesn't validate the origin cert. *Full (strict)* validates it — use Full (strict) in production with a real or Cloudflare Origin cert.
- The apex must flatten (see record-cookbook.md) before any of these can validate.

## Cert error → cause → fix

| Symptom | Cause | Fix |
| --- | --- | --- |
| `ERR_CERT_AUTHORITY_INVALID` on curl/mobile but OK in browser | Leaf-only chain, missing intermediate | Serve `fullchain.pem` |
| `ERR_CERT_COMMON_NAME_INVALID` / name mismatch | Cert doesn't cover the hostname (e.g. apex cert, www request) | Add the SAN; reissue covering both names |
| ACME fails with a CAA error | CAA omits your CA, or wildcard lacks `issuewild` | Add `CAA 0 issue "<ca>"` (+ `issuewild` for `*`) |
| Cert valid but site still warns | Mixed content (HTTP assets on an HTTPS page) | Serve all assets over HTTPS |
| Expired cert in prod | No working auto-renew | Fix the timer/cron; `certbot renew --dry-run` |
| Rate-limit / "too many certificates" | Tested against production repeatedly | Use staging; rely on ARI-aware renewal |
