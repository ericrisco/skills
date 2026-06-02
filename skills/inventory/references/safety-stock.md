# Safety stock

Safety stock is the buffer that covers variability *during* the lead time. Get two things right: the **formula** (matched to what varies) and **Z** (set by service level).

## Pick the formula by what varies

```text
1. Demand varies, lead time stable:
   SS = Z · σ_demand · √LT

2. Demand and lead time both vary, independent:
   SS = Z · √(LT · σ_demand²  +  avg_demand² · σ_LT²)

3. Demand and lead time both vary, correlated (King's method):
   SS = Z · σ_demand · √LT  +  Z · avg_demand · σ_LT
```

- `σ_demand` is the standard deviation of demand per period (same period unit as LT).
- `σ_LT` is the standard deviation of lead time, in the same unit.
- `avg_demand` is mean demand per period; `LT` is mean lead time in periods.

The most common under-buffering mistake is using formula 1 when the supplier's lead time actually swings. If receipts arrive in 5, 6, 12, 5, 9 days, `σ_LT` is large and must be in the buffer — use formula 2 (or 3 if demand spikes when lead time stretches).

## Z by service level

| Service level | Z |
|---|---|
| 90% | 1.28 |
| 95% | 1.65 |
| 97.5% | 1.96 |
| 99% | 2.33 |

Service level here = probability of **not** stocking out during a replenishment cycle. Set it per ABC×XYZ cell (see `abc-xyz.md`), then read Z. Never invent a Z.

## Worked examples

**Demand-only (formula 1).** avg daily demand 40, σ_demand 12, LT 9 days, target 95% (Z=1.65):

```text
SS = 1.65 · 12 · √9 = 1.65 · 12 · 3 = 59.4 ≈ 60 units
```

**Both vary, independent (formula 2).** avg_demand 40/day, σ_demand 12, LT 9 days, σ_LT 3 days, Z=1.65:

```text
SS = 1.65 · √(9·12²  +  40²·3²)
   = 1.65 · √(1,296  +  14,400)
   = 1.65 · √15,696
   = 1.65 · 125.3 ≈ 207 units
```

Note the jump from 60 → 207: the lead-time variance dominates here. Ignoring `σ_LT` would have left you ~150 units short of the buffer you actually need.

## Estimating σ_demand and σ_LT from history

- **σ_demand:** take demand per period (day or week, matching LT units) over ≥12 periods, compute the sample standard deviation. Strip known one-offs (a promo, a B2B bulk order) or model them separately — they inflate σ and over-buffer.
- **σ_LT:** take the actual receipt date minus PO date for the last ~10–20 receipts of that supplier/SKU, compute mean and standard deviation in the same time unit as σ_demand.

If you only have a forecast and its error, use forecast error as σ_demand — but that demand model belongs to `forecasting`; you only consume it.

## Diminishing returns past ~98%

The normal tail is fat: moving 95% → 99% raises Z from 1.65 to 2.33 (+41% buffer) for 4 points of service. Going 99% → 99.9% costs far more again. Reserve the top of the curve for A/critical SKUs where a stockout is genuinely expensive; let C items sit at 90% and free the cash.
