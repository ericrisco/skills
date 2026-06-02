# The numbers that matter on the deck

This file is about **which numbers belong ON the deck and what "good" looks like** — not how to compute them
at scale. Build the projection/cohort/burn model in `financial-model`; run the standalone CAC/LTV/payback
health check in `unit-economics`. Here you pick the decision-grade few and put them where they persuade.

At seed, the decision rides on a small set. Do **not** dump the P&L on a slide — choose the metrics that tell
*your* story (traction, business model, the ask) and show each with a unit and a trend.

## The metric glossary (formula + current band)

| Metric | Formula | Healthy band (2025/26) | Where on the deck |
| --- | --- | --- | --- |
| MRR | sum of monthly recurring revenue | — | Traction |
| ARR | MRR × 12 | — | Traction |
| MoM growth | (this month − last month) / last month | ~15–20% (<$1M ARR); ~8–15% ($1M–$10M ARR) | Traction (the curve) |
| CAC | sales+marketing spend / new customers acquired | varies; judged via LTV:CAC + payback | Business model |
| LTV | (ARPA × gross margin) / churn rate | — | Business model |
| LTV : CAC | LTV / CAC | **≥ 3:1** | Business model / Traction |
| CAC payback | CAC / (ARPA × gross margin), in months | **< ~18 months** (2024 median; lower = above avg) | Business model |
| Gross margin | (revenue − COGS) / revenue | software typically **70%+** | Business model |
| Net revenue retention | (start + expansion − churn − contraction) / start | **> 110%** | Traction |
| Burn rate | net cash out per month | context for runway | Ask (use-of-funds) |
| Runway | cash on hand / monthly burn | names the ask milestone | Ask |

A quick read of the bands: **LTV:CAC ≥ 3:1, NRR > 110%, CAC payback under ~18 months** is the "above-average
efficiency" signal. You do not need all of them — pick the ones that are strong and honest for your stage.

## Growth shape beats absolute size

This is the load-bearing idea of the traction slide. **A consistent curve outperforms a bigger flat number.**

```text
Company A:  $50K MRR, +25% MoM, 6 months straight   ->  reads STRONGER
Company B:  $200K MRR, flat or erratic              ->  reads weaker
```

Why: investors back the *derivative*, not the level. $50K growing 25% MoM compounds past $200K fast and proves
the acquisition engine works; $200K flat proves it stalled. Show the curve, label the trend, and let the slope
do the persuading. Early-stage targets: ~15–20% MoM under $1M ARR, ~8–15% MoM from $1M–$10M ARR.

## Bad → Good traction slides

```text
Bad   "10,000 users. Huge interest. Going viral."
       (no unit, no trend, no money — a vanity wall)

Good   "$50K MRR, +22% MoM for 5 straight months (curve shown).
        NRR 118%. 40 paying logos incl. [Customer A, Customer B].
        LTV:CAC 4:1, CAC payback 11 months."
       (each number has a UNIT and a TREND; the SHAPE is visible; money is real)
```

```text
Bad   "We grew 300% last year!"
       (300% from what to what? one big % hides a tiny base or a one-off spike)

Good   "$8K -> $50K MRR over 6 months, +22% MoM average (no single month below +15%)."
       (the base, the path, the consistency — the claim is falsifiable and the trend is the point)
```

The vanity tell: **a count with no rate behind it.** Registered users without an activation or paying rate, app
installs without retention, "interest" without revenue. A sharp investor reads the missing rate as the number
you are hiding — so show it, even when it is small but honest.

## What NOT to put on the deck

- The full P&L or a 5-year monthly model — that is a data-room artifact; the deck shows the shape, the room
  holds the detail. Build it in `financial-model`.
- A CAC/LTV teardown by channel and cohort — that is the `unit-economics` health check; the deck shows the
  headline band (LTV:CAC 4:1), the analysis lives elsewhere.
- Every metric you track. Three strong, honest numbers beat twelve mediocre ones. Curate.

## Sourcing rule

Every number on a slide traces to a source: the model, your analytics, or a citation. Mark any gap
`[[NEEDS PROOF]]` rather than inventing a figure to fill a chart — a single fabricated number, once caught,
poisons the whole deck. A hockey-stick projection must name its driver; a curve with no mechanism is fiction.
