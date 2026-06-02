# Cash-flow forecast — 13-week rolling, direct method

The full template behind the forecast section of `SKILL.md`. Use the direct method: every cell traces to a named invoice or bill.

## Full column template

A practical forecast splits inflows and outflows into named lines so you can see *which* lever to pull. The minimal shape `verify.sh` checks is the six-column rollup (`week_start, starting_cash, inflows, outflows, net, ending_cash`); keep the detail columns alongside and sum them into `inflows`/`outflows`.

```csv
week_start,starting_cash,AR_collections,other_inflows,inflows,payroll,AP,rent,tax,loan,other_outflows,outflows,net,ending_cash
2026-06-01,42000,16000,2500,18500,12000,7100,3000,0,1000,0,23100,-4600,37400
2026-06-08,37400,8200,1000,9200,0,9800,0,0,1000,5000,15800,-6600,30800
2026-06-15,30800,14500,0,14500,12000,6300,0,4200,1000,0,23500,-9000,21800
```

Invariants per row:
- `inflows = AR_collections + other_inflows`
- `outflows = payroll + AP + rent + tax + loan + other_outflows`
- `net = inflows - outflows`
- `ending_cash = starting_cash + net`
- `ending_cash[n] == starting_cash[n+1]` (rolling continuity — the spine of the forecast)

## AR-aging → week mapping recipe

Inflows are 60–85% of the forecast and the easiest place to lie to yourself. Map them, don't guess.

1. Pull the AR aging report (open invoices by customer, with invoice date and terms) from `invoicing`.
2. For each open invoice, compute an **expected-clear week** = invoice date + that customer's *observed* days-to-pay, not the contractual terms.
   - Customer pays net-30 on paper but historically clears at day 44 → use day 44.
   - A chronically-late customer → push to the conservative end or split across two weeks.
3. Place the amount in the `AR_collections` cell for that week.
4. Anything past 90 days with no payment pattern: do **not** book it as an inflow. If you want partial credit, haircut it (e.g. 50%) and footnote the assumption.

Conservative inflow timing is the discipline that makes the runway answer trustworthy. When in doubt, book it a week later.

## Worked deficit walkthrough

From the CSV above, week of 2026-06-15 ends at $21,800 — still positive, but watch the slope: three straight negative-net weeks (-4,600, -6,600, -9,000). Project the next rows and you cross zero around week 6–7.

The direct method tells you the lever immediately because every line is named:
- The $4,200 **tax** payment in week 3 is the spike. If it's an estimated payment with a later deadline, moving it one week buys headroom.
- The $9,800 **AP** in week 2 — check which vendors. Two of them are net-45 and could clear in week 4 instead, smoothing -6,600 across two weeks.
- On the inflow side, the $16k week-1 AR includes one $9k invoice from a customer who has paid early before — a polite nudge from `invoicing` could pull it forward.

Pick the smallest-friction lever that keeps every `ending_cash` positive. Document which lever you pulled in the forecast notes.

## Burn and runway — worked numbers

Use actual cash, not accounting profit.

- Sum the last 3 months of `net` from real cleared transactions. Say it's -$5,400, -$6,100, -$5,800 → average net = **-$5,767/month**, so **burn ≈ $5,767/month**.
- Current cash balance = $42,000.
- **Runway = 42,000 ÷ 5,767 ≈ 7.3 months.**

7.3 < 12 → flag it. Report: "Runway ~7 months at current burn. First negative-ending week is ~week 7. Levers: delay the week-3 tax payment, smooth the week-2 AP, or pull the early-paying $9k invoice forward." Never report runway as a bare number without a lever.

If profit and cash disagree (common with depreciation or a big unpaid invoice), trust cash for runway and route the profit question to `bookkeeping`.
