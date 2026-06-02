# Cloud spend caps — recipes (accessed 2026-06-02)

App-level metering is the real-time guard. Everything here is the **slow backstop** — useful for catching what the app meter missed, never the thing standing between you and a runaway loop. The recurring caveat: cloud billing data lags, so by the time the cloud notices, the money is already spent.

## AWS

### Cost Anomaly Detection (ML-based)
- ML model, runs roughly **3x/day**, with **up to 24h data delay**.
- Emits to **SNS** → fan out to a **Lambda** that posts into your alert pipe (or revokes a key / disables a feature flag).
- Source: aws.amazon.com/aws-cost-management/aws-cost-anomaly-detection; docs.aws.amazon.com/cost-management/.../manage-ad.html. Accessed 2026-06-02.

### Budgets (threshold)
- Set 50/80/100% threshold alerts on a monthly budget → SNS → same Lambda.
- Pairs with CAD: Budgets catch the *expected* threshold; CAD catches the *unexpected* spike.

```text
AWS Budgets / Cost Anomaly Detection
        │ (SNS, up to ~24h delay)
        ▼
     Lambda  ──►  shared alert pipe (Slack/PagerDuty/webhook)
              └─► optional: disable feature flag / rotate-revoke API key
```

## GCP

- Budgets are **threshold-only** for alerting, but the budget can publish to **Pub/Sub**.
- Pub/Sub → **Cloud Function** is the one path that can actually **pause or throttle a workload** programmatically (e.g. scale a service to zero, disable a billing account binding).
- Source: costimizer.ai gcp guide. Accessed 2026-06-02.

```text
GCP Budget ──► Pub/Sub ──► Cloud Function
                            ├─► shared alert pipe
                            └─► throttle / pause workload (real control)
```

## Azure

- Threshold-only budgets with action groups. Same shape as GCP minus the clean Pub/Sub→pause path; wire the action group into the shared alert pipe.

## Alert-routing pattern (all providers)

Route **every** cloud alert into the **same pipe** as your in-app budget alerts, so there is one place to look and one severity ladder. Tag each alert with its source (`aws-cad`, `gcp-budget`, `app-meter`) so reconciliation can tell which guard fired.

## The delay caveat, stated plainly

| Guard | Latency | Can it stop spend? |
|---|---|---|
| App-level cap (this skill) | real-time | yes — refuse the request now |
| AWS CAD / Budgets | up to ~24h | no — alert only (Lambda can revoke after the fact) |
| GCP budget → Pub/Sub → Function | minutes-to-hours | partial — can pause a workload, but on lagged data |

Design accordingly: the cloud cap is insurance against what your app meter failed to count; it is not the meter.
