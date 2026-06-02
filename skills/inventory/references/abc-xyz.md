# ABC × XYZ classification

Classification is how you decide where to spend control. Do this before sizing buffers.

## ABC: split by consumption value (Pareto)

1. For each SKU compute **annual consumption value** = `annual_demand × unit_cost`.
2. Sort SKUs descending by that value.
3. Cumulate and take the running share of total value.
4. Cut into bands — A ≈ top ~80% of cumulative value, B the next ~15%, C the bottom ~5%. (Bands are tunable; the point is value, not count.)

Worked sort (illustrative):

```text
sku    annual_demand  unit_cost  value     cum_value  cum_%   class
S-101  1,200          90.00      108,000   108,000    46.0%   A
S-204    900          60.00       54,000   162,000    69.0%   A
S-307  2,000          15.00       30,000   192,000    81.7%   A
S-410    400          20.00        8,000   200,000    85.1%   B
S-512  1,500           4.00        6,000   206,000    87.7%   B
...     (long tail)                                             C
```

A is usually ~20% of SKUs holding ~80% of value — those get the tight control.

## XYZ: split by demand variability

Compute the **coefficient of variation** of period demand: `CV = σ_demand / mean_demand`. Use enough history (≥12 periods) so a single spike doesn't dominate.

| Class | CV range (typical) | Demand shape |
|---|---|---|
| X | CV < 0.5 | stable, predictable |
| Y | 0.5 ≤ CV ≤ 1.0 | fluctuating / seasonal |
| Z | CV > 1.0 | erratic, intermittent |

Cut points are conventions — adjust to your data, but keep them fixed across the catalog so classes are comparable.

## The 9-cell matrix → policy

| Cell | Value × variability | Review mode | Service level | Buffer posture |
|---|---|---|---|---|
| AX | high value, stable | continuous (min-max) | 98–99% | tight, automated, lean |
| AY | high value, fluctuating | continuous | 97–98% | moderate, watch closely |
| AZ | high value, erratic | ddmrp | 95–98% | buffer zones, candidate for DDMRP |
| BX | mid value, stable | continuous or periodic | 95% | standard |
| BY | mid value, fluctuating | periodic | 93–95% | moderate |
| BZ | mid value, erratic | periodic / ddmrp | 90–95% | cautious, review often |
| CX | low value, stable | periodic | 90–95% | generous buffer is cheap |
| CY | low value, fluctuating | periodic | 90% | low buffer |
| CZ | low value, erratic | periodic / make-to-order | 85–90% | near-zero buffer or MTO |

Read it as a control budget: spend tight automated control and high service on the top-left (AX), spend almost nothing on the bottom-right (CZ). The high-value erratic corner (AZ) is where a static reorder point fails and DDMRP earns its keep — see `ddmrp.md`.
