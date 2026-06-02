# Model structure — the column/row contract verify.sh enforces

This is the shape `scripts/verify.sh` checks. It validates that the model **computes and ties out**, never whether the forecast is correct.

## Two-part layout

Keep assumptions and projection separate — one fact lives in one cell, and outputs reference assumptions, never the reverse.

**Assumptions sheet** (inputs only, no formulas pointing at outputs): `growth_rate`, `arpa`, funnel rates, `gross_churn_rate`, `expansion_rate`, `cac`, `gross_margin_target`, the per-hire schedule (`role, loaded_cost, start_month`), `starting_cash`, `round_amount`, `round_close_month`.

**Projection grid** (`model.csv`) — one row per month, these columns required:

| Column | Meaning | Tie-out check |
| --- | --- | --- |
| `month` | 1..N index (or date) | monotonic, no gaps |
| `revenue` | recognised revenue that month | from the MRR waterfall |
| `cogs` | cost of goods sold | — |
| `gross_margin` | (revenue − cogs) / revenue | **recomputes** to the stated cell |
| `opex` | total operating expense | sum of function lines |
| `headcount` | active FTEs | ≥ 0 |
| `gross_burn` | total cash outflow | — |
| `net_burn` | gross_burn − revenue | **ties out** |
| `starting_cash` | cash at month start | == prior `ending_cash` |
| `ending_cash` | starting_cash − net_burn | **continuity** |
| `runway_months` | starting_cash / net_burn | ties to cash ÷ net_burn |
| `scenario` | base / downside / upside | ≥1 present; ≥3 if scenarios claimed |

## The cash-continuity rule

The single most important invariant — the line that makes it a model and not a snapshot:

```text
ending_cash[m]      = starting_cash[m] − net_burn[m]
starting_cash[m+1]  = ending_cash[m]
```

If month 7's start cash is not month 6's end cash, the grid has a broken link and the runway number is meaningless. `verify.sh` asserts this row-to-row.

## Recompute checks (no hardcoded outputs)

These exist to catch typed-in numbers that stopped tracking their inputs:

```text
gross_margin[m]  ≈ (revenue[m] − cogs[m]) / revenue[m]      (within tolerance)
net_burn[m]      ≈ gross_burn[m] − revenue[m]
runway_months[m] ≈ starting_cash[m] / net_burn[m]            (when net_burn > 0)
```

A cell that fails to recompute is a hardcoded output — the cardinal modeling sin.

## Defect lint

Hard fails on values that cannot be real, warnings on unfinished placeholders:

- **impossible**: `gross_margin` > 100% or < −100%; negative `headcount`; negative `starting_cash` with positive runway claimed.
- **placeholder**: `TBD`, `XX`, `#REF`, `[assumption]`, `???` anywhere in the grid.

## Filled mini-example (`model.csv`)

```csv
month,scenario,revenue,cogs,gross_margin,opex,headcount,gross_burn,net_burn,starting_cash,ending_cash,runway_months
1,base,25000,5000,0.80,90000,6,95000,70000,400000,330000,5.7
2,base,29625,5925,0.80,92000,6,97925,68300,330000,261700,4.8
3,base,34930,6986,0.80,95000,7,101986,67056,261700,194644,3.9
```

Note `ending_cash` of month 1 (330000) equals `starting_cash` of month 2 — continuity holds. `gross_margin` 0.80 == (25000−5000)/25000 — recompute holds. `net_burn` 70000 == 95000−25000 — ties out. A real model spans 18–36 rows per scenario and adds the function-level OpEx columns; these are the minimum verify.sh requires.
