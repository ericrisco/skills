# Burn-rate alerting and on-call

The full math behind the SLO table in SKILL.md, plus copy-paste alert rules, escalation, and a runbook template.

## What "burn rate" means

Pick an SLO, e.g. **99.9% availability over 30 days**. The **error budget** is the allowed bad fraction: `1 - 0.999 = 0.1%` of requests over the month.

**Burn rate = how many times faster than "even" you are spending that budget.**

- Burn rate `1` = you'd exactly exhaust the 30-day budget in 30 days. Fine.
- Burn rate `14.4` = you'd exhaust the *entire month's* budget in `30d / 14.4 ≈ 2h`. Page now.

Why 14.4: it is the rate that burns **2% of the monthly budget in 1 hour** — the Google SRE workbook's recommended fast-burn page threshold. The other rows: **6×** burns ~5% in 6h (ticket), **1×** burns ~10% in 3d (slow review).

## Why two windows

A single window either pages on a momentary spike (short window alone) or reacts too slowly (long window alone). **Require a long AND a short window to both exceed the burn threshold:**

- The **long window** confirms the burn is sustained ("this is real").
- The **short window** confirms it's still happening right now ("don't page me for an outage that already ended"). It also gives fast reset once you recover.

This combination is what kills false positives.

## Prometheus-style alert rule

Symptom-based, two windows, with a `runbook_url` annotation. Adjust `job`/`code` to your metric names.

```yaml
groups:
  - name: slo-burn-rate
    rules:
      # CRITICAL — page. Fast burn: 14.4x over 1h, confirmed by a 5m short window.
      - alert: CheckoutErrorBudgetFastBurn
        expr: |
          (
            sum(rate(http_requests_total{job="checkout",code=~"5.."}[1h]))
            / sum(rate(http_requests_total{job="checkout"}[1h]))
          ) > (14.4 * 0.001)
          and
          (
            sum(rate(http_requests_total{job="checkout",code=~"5.."}[5m]))
            / sum(rate(http_requests_total{job="checkout"}[5m]))
          ) > (14.4 * 0.001)
        labels:
          severity: critical        # routes to page
        annotations:
          summary: "Checkout burning error budget 14.4x (1h+5m)"
          runbook_url: "https://wiki.example.com/runbooks/checkout-5xx"

      # WARNING — ticket. Slower burn: 6x over 6h, confirmed by a 30m short window.
      - alert: CheckoutErrorBudgetSlowBurn
        expr: |
          (
            sum(rate(http_requests_total{job="checkout",code=~"5.."}[6h]))
            / sum(rate(http_requests_total{job="checkout"}[6h]))
          ) > (6 * 0.001)
          and
          (
            sum(rate(http_requests_total{job="checkout",code=~"5.."}[30m]))
            / sum(rate(http_requests_total{job="checkout"}[30m]))
          ) > (6 * 0.001)
        labels:
          severity: warning          # routes to ticket
        annotations:
          summary: "Checkout slow error-budget burn (6h+30m)"
          runbook_url: "https://wiki.example.com/runbooks/checkout-5xx"
```

Note: every alert carries `runbook_url`, and the rule is a *ratio* (symptom), never a bare `cpu`/`memory` threshold.

## Severity → routing

| Label | Where it goes | Who acts | When |
|---|---|---|---|
| `critical` | PagerDuty/Better Stack page → escalation policy | on-call, now | immediately, any hour |
| `warning` | ticket queue / Slack channel | team | next business hours |
| `info` | dashboard / weekly review | nobody paged | retro |

## Escalation policy (sample)

```yaml
# Vendor-agnostic shape — maps to PagerDuty / incident.io / Better Stack.
escalation_policy:
  name: checkout-oncall
  on_call:
    primary:   "@oncall-primary"     # weekly rotation
    secondary: "@oncall-secondary"   # weekly rotation, offset
  steps:
    - notify: primary
      ack_timeout_minutes: 10        # no ack -> escalate
    - notify: secondary
      ack_timeout_minutes: 10
    - notify: "@eng-manager"
  repeat_until_acked: true
  resolve_notifies: true             # send the all-clear too
# Do NOT build this on Opsgenie (EOL 2027-04-05) or Grafana OnCall OSS (deprecated).
```

## Runbook template

Every alert's `runbook_url` points to one of these. Fill it in before the alert ships, not at 3am.

```markdown
# Runbook: <alert name>

## Symptom
What the alert literally measures (e.g. "checkout 5xx ratio > 14.4x SLO burn, 1h+5m").

## Impact
What the user experiences (e.g. "checkout failing → lost revenue, ~X orders/min").

## First 3 checks
1. Dashboard link: <url> — is it errors or latency?
2. Recent deploys: <link> — did we ship in the last 30 min? Consider rollback (see ../deployment/SKILL.md).
3. Dependency status: DB / cache / payment provider status pages.

## Mitigation
- Fastest safe action (rollback / feature-flag off / scale out — see ../scaling/SKILL.md).
- Holding action if root cause unknown (drain region, enable degraded mode).

## Escalation
- If not mitigated in 15 min, page secondary and open an incident.
- Post to the public status page; notify #incidents.

## Dashboards
- <links to the relevant observability dashboards — see ../observability/SKILL.md>
```
