# Revenue build — bottom-up funnel + MRR waterfall + top-down cross-check

The revenue line is built **bottom-up** for the operating plan and **cross-checked top-down** for the raise. Build both; present both.

## Bottom-up: funnel math

The plan grows from the levers you actually pull. Model the funnel month by month:

```text
leads      → MQL        → SQL        → opportunity → win
   × mql_rate  × sql_rate   × opp_rate    × win_rate
```

Then revenue from wins:

```text
new_customers[m] = leads[m] * mql_rate * sql_rate * opp_rate * win_rate
new_bookings[m]  = new_customers[m] * deal_size
```

Cap it by **capacity** so the plan stays honest — you cannot close more than your reps can carry:

```text
capacity[m] = active_reps[m] * quota_per_rep
new_bookings[m] = MIN(funnel_bookings[m], capacity[m])
```

Every rate, deal_size and quota lives in the assumptions sheet. A plan that grows leads 40%/mo with flat conversion and no extra reps is a hockey stick in disguise — the capacity cap exposes it.

## MRR waterfall (subscription revenue)

For recurring revenue, never grow MRR by a single "+X%/mo". Model the waterfall so each component is a visible, toggleable driver:

```text
starting_MRR[m]
  + new_MRR[m]          = new_customers[m] * arpa
  + expansion_MRR[m]    = active_customers[m] * expansion_rate * arpa
  − contraction_MRR[m]  = active_customers[m] * contraction_rate * arpa
  − churned_MRR[m]      = active_customers[m] * gross_churn_rate * arpa
  = ending_MRR[m]       → starting_MRR[m+1]
revenue[m] = ending_MRR[m]   (or average of start/end for an accrued view)
```

This split is what lets a downside scenario move *churn* without touching *new* — the whole point of a driver-based model. It also surfaces **NRR** directly: `NRR = (starting + expansion − contraction − churn) / starting`. NRR ≥100% means the install base grows itself; <100% means you are refilling a leaky bucket and every new sale is partly replacement.

## Top-down: TAM cross-check

Top-down does not build the plan — it sanity-checks the ceiling:

```text
TAM        = total addressable accounts * annual_contract_value
SAM        = TAM * serviceable_fraction
year3_rev  = SAM * target_penetration
```

The test: does your bottom-up Year-3 revenue imply a **plausible penetration** of SAM? If bottom-up says $40M ARR but that is 35% of SAM in three years, the bottom-up is fantasy. If bottom-up is 0.1% of SAM, either the market is far bigger than the plan needs (fine) or your funnel is too timid. Show the implied penetration number explicitly — investors compute it anyway.

## Worked monthly build (mini, 3 months shown)

Assumptions: arpa $500/mo, leads 200/mo growing 15%/mo, funnel product 5% (lead→win), expansion 1.5%, churn 3%, starting MRR $25,000 (50 customers).

| m | leads | new cust | new MRR | churn MRR | exp MRR | end MRR | end cust |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 200 | 10 | 5,000 | 750 | 375 | 29,625 | 59 |
| 2 | 230 | 11 | 5,750 | 889 | 444 | 34,930 | 68 |
| 3 | 264 | 13 | 6,600 | 1,048 | 524 | 41,006 | 78 |

Every number above is a formula off the assumptions row — change `churn` to 5% and the whole table re-flows. That is the contract. Feed `arpa`, the funnel rates, churn and CAC from `unit-economics` rather than inventing them here.
