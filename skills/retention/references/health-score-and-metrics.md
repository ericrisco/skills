# Health score & retention metrics

The long lookup material most operators consult once when standing the program up.

## Dimension catalog

Pick **4+** dimensions. A composite of 4+ weighted signals predicts churn ~34%
more accurately than a single-dimension gauge (Totango 2025). Weight activity
heaviest — absence precedes every other failure.

| Dimension | Default weight | Candidate signals | Notes |
|---|---|---|---|
| Product usage / activity | ~40% | login recency, sessions/week, DAU/WAU, depth of feature adoption, % of seats active | the dominant predictor; under-weight it and the score lags reality |
| Engagement | ~25–30% | email open/reply, QBR attendance, NPS response, champion still employed, community presence | the relationship layer |
| Milestones / business fit | ~20% | onboarding goals hit, first value realized, ROI demonstrated, plan matches stated need | "are they getting what they bought?" |
| Recency | ~10% | days since last meaningful action | a fast decay signal that sharpens the others |

Add product-specific dimensions (e.g. integration depth, API call volume) by
splitting a category's weight — keep the total at 100.

## Normalize to 0–100

For each dimension, map the raw signal onto 0–100 before weighting:

```text
1. Define the healthy range per signal (e.g. logins/week: 0 = none, 5+ = full).
2. Linear-scale the raw value into 0–100 within that range, clamp at the ends.
3. If a dimension has several signals, average their 0–100 scores first.
4. Multiply each dimension's 0–100 by its weight, sum → the account score.
```

## Cutoff tuning

Starting cutoffs: **green ≥70, yellow 40–69, red <40.**

Tune them against history: pull the last ~2 quarters of cancellations, score each
account at "30 days before they churned," and move the red line until most real
churners were already red or yellow at that point. If everything was green until
the day they left, your dimensions or weights are wrong — usually activity is
under-weighted.

## Worked scored account

```text
Account: Acme Co, mid-market, renewal in 45 days

Usage      30/100  × 0.40 = 12.0   (logins halved, two features abandoned)
Engagement 60/100  × 0.28 = 16.8   (champion still replies, missed last QBR)
Fit        80/100  × 0.20 = 16.0   (hit onboarding goals, ROI shown)
Recency    20/100  × 0.10 =  2.0   (last meaningful action 18 days ago)
                              -----
Score = 46.8  →  YELLOW

Read: usage is collapsing while the relationship is intact — classic "not using
it" pattern. Play: pause + re-onboard touch, not a discount. Flag now: 45 days
of lead time is exactly the window the score is meant to buy.
```

## Metrics reference

### Formulas

```text
GRR = (start MRR − contraction − churn) / start MRR        (never > 100%)
NRR = (start MRR − contraction − churn + expansion) / start MRR   (can be > 100%)
Logo churn    = customers lost in period / customers at start
Revenue churn = MRR lost in period / MRR at start
Save rate     = cancel attempts saved / total cancel attempts
```

### Worked numbers

```text
Start MRR 100k; expansion +15k; contraction −5k; churned −12k.
GRR = (100 − 5 − 12) / 100 = 83%
NRR = (100 − 5 − 12 + 15) / 100 = 98%

Read: NRR 98% looks fine, but GRR 83% is barely above the 80% alarm line —
expansion is papering over real base loss. Optimize the base, not upsell.
```

### Segment benchmark table (2025 B2B SaaS)

| Segment | NRR | Monthly logo churn | Annual churn |
|---|---|---|---|
| SMB | ~97% | 3–7% | ≈31–58% |
| Mid-market | ~108% | 1.5–3% | — |
| Enterprise | ~118% | <1.5% | — |
| "Good" benchmark | NRR median ~106%, GRR median ~90% | <1%/mo | <5%/yr |

The alarm restated: **GRR < 80% means a few expanding accounts are masking a
fundamental retention failure.** And **43% of SMB losses happen in the first 90
days** — that early window is an activation problem (`../client-onboarding/SKILL.md`),
not a renewal-program problem.

Sources: Totango 2025, customerscore.io, SaaS Capital, Fiscallion, ChurnZero,
Vena, Vitally, Optifai, Churnkey 2025 — accessed 2026-06-02.
