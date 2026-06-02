# ROAS model

The money math that gates every campaign decision. Do this before structure.

*Dated 2026-06-02. Sources: triplewhale.com break-even ROAS guide;
bennettfinancials.com contribution-margin guide; kleene.ai ROAS guide.*

## Break-even ROAS

```text
break-even ROAS = 1 ÷ gross-margin %
```

Gross margin here is **contribution margin** — price minus COGS, payment fees,
shipping, and any per-order variable cost. Use the real number, not the headline
markup.

| Gross margin | Break-even ROAS |
|---|---|
| 30% | 3.33x |
| 40% | 2.50x |
| 50% | 2.00x |
| 60% | 1.67x |
| 70% | 1.43x |

A campaign whose target ROAS sits **below** the break-even row is losing money on
every conversion. There is no targeting fix for that — change the offer, the margin,
or the target.

## Target ROAS by stage

| Mode | Meta target | Google Search target | Judge on |
|---|---|---|---|
| Profit | 3.5x–5x | 5x–8x | Campaign ROAS, validated incremental |
| Scaling | 2x–3x | 2x–3x | Blended MER (you trade margin for growth on purpose) |

Always set **target ≥ break-even**. Scaling-mode targets near break-even are a
deliberate growth bet, not an accident — name it as such.

## Why the platform number lies

| Number | What it measures | Trust for |
|---|---|---|
| **Platform ROAS** | Last-click, per-platform; double-counts across surfaces | Nothing on its own — over-reports 30–100% |
| **Blended MER** | Total revenue ÷ total ad spend, all channels | The scaling decision |
| **Incremental ROAS** | Revenue that would NOT have happened without the ad | The truth — usually 30–60% of the platform number |

Platform-reported ROAS credits the ad for sales that would have closed anyway
(brand searches, returning customers, organic-assisted). Incrementality strips that
out.

## Geo-holdout test design

The 2026 gold standard for validating real lift:

1. Split comparable regions into **test** (ads on) and **control** (ads off / held
   out). Match on baseline revenue and seasonality.
2. Run for a clean window (≥2–4 weeks, longer than the purchase cycle).
3. Incremental revenue = test-region revenue − control-region revenue (scaled to
   equal population/baseline).
4. **Incremental ROAS = incremental revenue ÷ test-region ad spend.**
5. Compare that incremental ROAS to break-even — not the platform number.

Ghost-ad / PSA-holdout tests are the on-platform equivalent when geo-splits aren't
feasible. For the statistical design (power, significance, sample size) hand off to
the `ab-testing` skill — this is the media-side framing, not the experiment math.

## Scale / hold / kill rule

| Incremental ROAS vs break-even | Decision |
|---|---|
| Comfortably above break-even AND stable ≥2 weeks | **Scale** — ≤20%/week, don't reset learning |
| Near break-even or noisy | **Hold** — keep structure ≥4 weeks, gather data, fix creative/signal first |
| Below break-even after the learning phase | **Kill** — or fix margin/offer; no bid tweak rescues negative unit economics |

Never scale on the platform dashboard. Scale on incremental ROAS or blended MER, and
only after the learning phase has stabilized.
