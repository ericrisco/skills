# Scorecard, TCO, and supplier-relationship templates

Copy these, fill the numbers, keep the structure. `scripts/verify.sh` checks the
scorecard and TCO tables for shape and arithmetic.

## Weighted supplier scorecard

Weights set **before** bids arrive and **sum to 100**. Score each supplier on
each criterion (1–5). Weighted total = Σ(weight × score). Disclose weights to
bidders.

```text
Criterion              Weight  Supplier A  Supplier B  Supplier C
Capability / fit         40        4           3           5
Price / commercial (TCO) 30        3           5           2
Viability / risk         30        4           3           4
-----------------------------------------------------------------
Weighted total          100       370         360         380
```

Weighted total math (Supplier C): 40×5 + 30×2 + 30×4 = 200 + 60 + 120 = **380**.
Highest weighted total wins — *not* lowest price. If two are within ~5%, break
the tie on supply risk, not on a rounding-error price gap.

CSV form (what verify.sh reads most cleanly):

```text
criterion,weight,supplier_a,supplier_b,supplier_c
capability,40,4,3,5
price_commercial,30,3,5,2
viability_risk,30,4,3,4
weighted_total,100,370,360,380
```

## Worked TCO comparison (full lines)

Compare like-for-like over the same horizon. Include every line both suppliers
will actually cost you — not just the quoted unit.

```text
Line item                     Supplier A      Supplier B
Unit price × quantity         $9.00 × 5,000   $11.00 × 5,000
  = acquisition               45,000          55,000
Freight / delivery            6,000           500
Installation / integration    0               0
Annual operating (× years)    0               0
Annual maintenance/support    5,000           0  (included)
Training                      500             0
Downtime / defect loss        4,000 (8% rate) 0
License true-ups              0               0
Residual / resale value       (−500)          (−1,000)
-------------------------------------------------------------
TCO (year 1)                  60,000          54,500
```

The "cheaper" unit (A) loses by **$5,500** once freight, support, and defect
downtime land. Always award on the TCO line, never the unit line.

Required-lines reminder — a TCO that lists only unit price is not a TCO. Include
at least delivery, maintenance/support, training, downtime, or exit.

## Supplier performance scorecard (ongoing)

Score live suppliers each review period on four dimensions; trend matters more
than any single period.

```text
Dimension          Metric                          Target    Weight
Quality            defect / return rate            < 1%       30
Delivery (OTIF)    on-time-in-full %               > 95%      30
Price stability    drift vs awarded price          < escalator 20
Responsiveness     issue resolution time           < 2 days   20
-------------------------------------------------------------------
Score (1–5 each, weighted to 100)                             100
```

## SRM cadence by Kraljic quadrant

| Quadrant | Relationship | Review cadence |
|---|---|---|
| Routine (low impact / low risk) | transactional, automate | annual |
| Leverage (high impact / low risk) | competitive, churn for price | annual / per tender |
| Bottleneck (low impact / high risk) | secure supply, backups | semiannual |
| Strategic (high impact / high risk) | partnership, joint planning | quarterly |

Re-score the quadrant assignment itself at least annually — categories drift.

## Re-source trigger thresholds

Re-open the comparison when any of these fire:

- OTIF below your delivery target for **two consecutive periods**.
- Price drift **above the contracted escalator** without a justified pass-through.
- A single/sole-source supplier **loses its only backup** (qualification lapses,
  alt supplier exits).
- The category **re-segments** into a higher-risk Kraljic quadrant.
- Quality (defect/return) breaches target for **two consecutive periods**.

A re-source doesn't mean switch — it means run the weighted comparison again with
current data, then decide.
