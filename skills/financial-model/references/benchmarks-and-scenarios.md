# Benchmarks & scenarios — the reasonableness gate and the toggle recipe

Two jobs here: gate the model's drivers against 2025/26 reality, and build the base/downside/upside scenarios off a small toggle set.

## The benchmark sanity-table (2025/26 SaaS)

Run every model through this. A driver far outside its band is a red flag you **surface**, not hide — "our churn assumption is 1%/mo, well below the 3%+ benchmark; here is why" is credible; silently shipping it is not.

| Metric | Formula | Reasonable band | Notes |
| --- | --- | --- | --- |
| **Burn multiple** | net burn ÷ net new ARR | <1.0 elite · 1.0–1.5 healthy · 1.5–2.0 ok early · >2 scrutiny | the headline capital-efficiency gauge; SaaS Capital's 2025 survey: 56% of seed / 83% of Series C+ investors call it critical |
| **Rule of 40** | growth % + FCF (or profit) margin % | ≥ 40 | most companies miss it — McKinsey: 200+ firms cleared it only ~16% of the time (2011–2021); Meritech public-SaaS median ~12% early 2025; the one-number whole-model test |
| **Subscription gross margin** | (sub revenue − sub COGS) / sub revenue | 75–80%+ | total incl. services ~71–77% |
| **LTV:CAC** | LTV ÷ CAC | ≥ 3:1 · top quartile 4–6:1 · median ~3.2:1 | imported from `unit-economics` |
| **CAC payback** | CAC ÷ (ARPA × gross margin) | under ~12mo SMB · 2025 median worsened to ~20mo | months until a customer repays its acquisition cost |
| **NRR** | (start + exp − contr − churn) ÷ start | ≥100% floor · 104–106% typical · 120%+ best | <100% = leaky bucket |
| **ARR growth (median)** | YoY ARR growth | ~19–21% median in 2025 | a plan far above median needs the funnel to justify it |
| **Revenue / employee** | revenue ÷ FTE | ~$130K median private SaaS | reasonableness anchor for the headcount plan |
| **ARR multiple (valuation)** | enterprise value ÷ ARR | ~4.8x median bootstrapped · 3–5x slow · 8–12x high-growth | sanity-checks implied valuation behind the raise |

### Rule of 40, worked

A plan claiming 200% growth AND positive margin is fantasy; 10% growth at −50% margin fails the test:

```text
growth 60% + FCF margin −15%  = 45   → passes (healthy growth-funded burn)
growth 200% + margin +10%     = 210  → implausible, re-examine the assumptions
growth 10% + margin −50%      = −40  → fails; burning hard with little growth to show
```

## Scenario recipe — base / downside / upside off toggles

Scenarios are not three hand-typed columns. They are the **same model** with a small driver set toggled, so the whole grid re-flows per scenario.

| Toggle | Base | Downside | Upside |
| --- | --- | --- | --- |
| New-revenue growth | plan | −30% | +20% |
| CAC | plan | +25% | −10% |
| Monthly churn | plan | +50% rel. | −20% rel. |
| Key hire timing | plan | +1 quarter slip (slower, cheaper) | as plan |
| **Round close date** | plan month | +3 months (slips) | on/early |

The **round-close toggle** is the one founders forget and the one that bites: model the gap between today and the close, and show runway if the close slips a quarter. Report **runway under each scenario** — that table is the headline of the summary screen.

## Worked runway-under-scenarios

Start: $400K cash. Base net burn $70K/mo. Toggle effects on net burn and the resulting runway, *before* the raise:

| Scenario | net burn/mo | runway from $400K | reads as |
| --- | --- | --- | --- |
| Base | $70K | ~5.7 mo | already past the raise-now line |
| Downside (−30% rev, +25% CAC, +50% churn) | $92K | ~4.3 mo | tight; cut or bridge |
| Upside (+20% rev) | $61K | ~6.6 mo | still raising, just calmer |

Sizing the raise off the **base** to a 24-month target at projected post-raise burn (~$110K/mo as the team grows) → raise ≈ $2.6M, then show that the *downside* still buys ≥18 months so the round survives a miss. A raise that only works in the base case is under-sized.
