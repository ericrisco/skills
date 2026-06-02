# Pricing models — worked numbers

Depth offloaded from SKILL.md. Read this when the model choice is non-obvious or the product is AI/usage/outcome-shaped.

## Per-seat and why it erodes

Per-seat ties revenue to user count. The failure mode is **seat compression**: as the buyer matures, they cap seats, share logins, and provision fewer accounts than people who actually use the product. Revenue plateaus while value (and your cost) keeps rising.

```text
Year 1: 50 seats x $20 = $1,000/mo
Year 2: same team, buyer trims to 35 "active" seats = $700/mo
        usage is flat-to-up, your cost is up, revenue is DOWN 30%.
```

If the value the customer gets does not actually scale with headcount, seats are the wrong metric. Move the variable dial to usage or outcomes and keep seats (if at all) as a small platform component.

## Usage / consumption — metering pitfalls

Usage pricing aligns price with value, but it introduces two buyer anxieties you must design around:

1. **Estimate anxiety.** The buyer cannot predict the bill, so they hesitate to commit. Fix: offer a committed-use floor (prepaid bundle) plus overage, and a usage calculator.
2. **Overage shock.** A spike produces a surprise invoice and a churn risk. Fix: alerts, soft caps, and the ability to pre-buy more before the overage rate kicks in.

You also need a **meter you can defend** — the customer must be able to reconcile your number with theirs. If they cannot count the units, they will dispute the bill.

## Outcome-based — the Bessemer starter formula

Outcome pricing charges for a delivered result (a resolved ticket, a booked meeting, a closed lead). It only works when the outcome is **attributable** — you can prove the result was yours.

Starter shape for an AI product:

```text
platform fee  ~= 2x your delivery cost   (covers infra + margin baseline)
bundle a fixed number of outcome credits in the platform fee
charge overage per block beyond the bundle

example: $12,000 / year including 100 resolutions,
         then $5,000 per additional 100 resolutions.
```

Sanity-check: the platform fee at ~2× delivery cost gives you a ~50% margin baseline before overage. Overage blocks should price at or above your marginal delivery cost per outcome, never below.

## AI-COGS — why the margin assumption flips

| | Classic SaaS | AI product |
|--|--------------|------------|
| Gross margin | 80-90% | 50-60% |
| Marginal cost per use | ~0 | real compute per query |
| Repricing trigger | rare | when compute cost moves |

The consequence: cost-plus floors are load-bearing again. Run the cost floor (spine step 1) on real per-query compute, and revisit the price card whenever model/compute pricing shifts. Do not carry an 80% margin assumption into an AI plan — it will quietly turn a "profitable" tier into a loss.

## Hybrid — keep it legible

Most AI products land on hybrid: a base platform fee (predictable, covers fixed value) plus a usage or outcome dial (scales with value and cost). The risk is explaining two dials at once. Keep the base price legible and let the variable component be the thing that grows; do not make the buyer model two unknowns to estimate their bill.
