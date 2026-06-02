# Unit-economics formulas — full derivations

The SKILL.md body carries the spine. This file carries every derivation you need to defend a number, with worked examples on consistent units.

All examples reuse one base case unless stated:

```text
period S&M spend = $120,000   new customers = 80
monthly ARPA = $400           gross margin = 75% (0.75)
monthly churn = 3% (0.03)
```

## 1. CAC — fully loaded

```text
CAC = (all sales + marketing cost in period) / (new customers acquired in same period)
    = 120000 / 80
    = $1,500
```

Numerator includes salaries, benefits, commissions, ad spend, content, events, agencies, tooling, and imputed founder selling time. It excludes customer-success/retention spend (that protects existing LTV) and R&D. Ad-spend-only CAC commonly understates true CAC by ~3.5×. Denominator counts new logos only — exclude returning/reactivated customers.

Keep two CACs:
- **Paid CAC** = paid-channel spend ÷ customers from paid channels (the part you scale with money).
- **Blended CAC** = all S&M ÷ all new customers (includes free/organic).

## 2. Contribution margin per customer

```text
contribution_margin = ARPA - variable_cost_to_serve
                    = ARPA - (COGS + variable support + payment/processing fees)
                    = 400 * 0.75            # when GM% already nets out variable cost
                    = $300 / month
```

Distinct from **gross margin %**, which is the company-wide ratio. Contribution margin is the per-customer dollar figure that actually pays back CAC and funds opex. LTV is the (discounted) stream of this contribution margin over the customer's life.

## 3. LTV — gross-margin, not revenue

Consistent monthly units throughout:

```text
gross-margin LTV = (monthly ARPA * GM%) / monthly churn
                 = (400 * 0.75) / 0.03
                 = 300 / 0.03
                 = $10,000

revenue LTV (WRONG) = 400 / 0.03 = $13,333   # overstates by 33%
```

Annual units must pair together:

```text
annual ARPA = 4800, annual churn = 30.4%  (1 - (1-0.03)^12)
annual LTV = (4800 * 0.75) / 0.304 ≈ $11,842
```

Note the annual figure differs from the naive monthly×12 because compounding churn over 12 months exceeds 36%. When precision matters, derive annual churn from monthly via `1 - (1 - m)^12`, not `m * 12`.

## 4. CAC payback period

```text
payback_months = CAC / (monthly ARPA * GM%)
               = 1500 / (400 * 0.75)
               = 1500 / 300
               = 5 months
```

The denominator is monthly contribution margin. Leaving GM% out (`1500 / 400 = 3.75`) understates payback and is a common error.

## 5. LTV:CAC

```text
LTV:CAC = LTV / CAC = 10000 / 1500 = 6.67 : 1
```

Interpretation against 2025-2026 norms: 3:1-5:1 healthy; < 3:1 overspending on acquisition; **> 5:1 under-investing in growth** (6.67:1 here → spend more). Median B2B SaaS ≈ 3.2:1. The ratio is a conversation, not a grade — pair it with payback and NRR.

## 6. Lifetime cap & conservatism

Implied lifetime from churn:

```text
implied_lifetime_months = 1 / monthly_churn = 1 / 0.03 ≈ 33.3 months   # within the 48-mo cap
```

At 1% monthly churn, `1/0.01 = 100 months` (8+ years) — fantasy for an early-stage company. Apply one of:

- **Hard cap** at 36-48 months: `capped_LTV = min(formula_LTV, contribution_margin * cap_months)`.
- **Conservatism multiplier**: `conservative_LTV = formula_LTV * 0.7`.

```text
base case capped LTV = min(10000, 300 * 48) = min(10000, 14400) = 10000   # cap not binding
×0.7 conservative    = 10000 * 0.7 = $7,000
```

## 7. Skok discounted LTV (advanced)

A dollar of contribution margin years out is worth less today. Discount the stream:

```text
LTV = sum over t of [ contribution_margin_t * retention_t / (1 + d)^t ]
```

with discount rate `d` ≈ 20-25% pre-scale, ≈ 10% at scale. Use this once you can model the retention curve `retention_t`; before that, the capped formula LTV is the honest placeholder.

## 8. NRR / GRR worked example

```text
Start MRR = 100,000
+ expansion = 12,000
- contraction = 3,000
- churn = 5,000

NRR = (100000 + 12000 - 3000 - 5000) / 100000 * 100 = 104%
GRR = (100000 - 3000 - 5000) / 100000 * 100        = 92%   # no expansion
```

Healthy NRR 105-115%, top quartile 115-125%. GRR is the true floor. Here NRR 104% looks fine but GRR 92% means **8% gross monthly leakage masked by expansion** — fix gross retention (route to `retention`) before celebrating NRR. When NRR > 100%, the simple churn-only LTV understates the cohort's true value; note it.

## 9. Segment roll-up

Never average segment CACs naively — weight by customers.

```text
blended CAC = total S&M / total new customers
            = (self_serve_spend + inside_spend + field_spend)
              / (self_serve_n + inside_n + field_n)
```

Example: self-serve $80 (500 customers), field $40,000 (10 customers).

```text
blended = (80*500 + 40000*10) / (500 + 10)
        = (40000 + 400000) / 510
        = 440000 / 510
        ≈ $863
```

The $863 blended number is real but useless for action — the levers (scale self-serve, fix field ACV/cycle) live in the segments, not the blend. Always segment before you optimize.

## Sources

Beancount.io "2026 SaaS Metrics Stack" (2026-05-10); ChartMogul LTV guide; metrickit LTV guide; andrewchen "How To (Actually) Calculate CAC"; First Page Sage SaaS CAC Payback Benchmarks 2025; Drivetrain CAC payback glossary; Optifai B2B SaaS LTV benchmark (939 companies); lucid.now LTV vs CAC errors; TZS Digital CAC deep dive; cast.app NRR; WallStreetPrep LTV/CAC; forEntrepreneurs SaaS Metrics 2.0. All accessed 2026-06-02.
