# Authoring semantic models

Offloaded depth from SKILL.md §"Author the model." Worked patterns for real models that span multiple tables and metric shapes. MetricFlow-style YAML throughout; the same concepts map to Cube and warehouse-native objects.

## Multiple entities and join paths

Let the layer own joins. Declare the keys on each semantic model and the layer resolves the path; you never write `JOIN`.

```yaml
semantic_models:
  - name: orders
    model: ref('fct_orders')
    entities:
      - { name: order, type: primary, expr: order_id }
      - { name: customer, type: foreign, expr: customer_id }
      - { name: product, type: foreign, expr: product_id }
    dimensions:
      - { name: order_date, type: time, type_params: { time_granularity: day } }
    measures:
      - { name: order_amount, agg: sum, expr: amount }
      - { name: cost_amount, agg: sum, expr: unit_cost }

  - name: customers
    model: ref('dim_customers')
    entities:
      - { name: customer, type: primary, expr: customer_id }
    dimensions:
      - { name: region, type: categorical }        # reachable from orders via customer
      - { name: signup_date, type: time, type_params: { time_granularity: day } }

  - name: products
    model: ref('dim_products')
    entities:
      - { name: product, type: primary, expr: product_id }
    dimensions:
      - { name: product_category, type: categorical }
```

With this, `gross_revenue` grouped by `product_category` and filtered on `region` works even though those dimensions live on two other tables — the shared `customer` and `product` entities tell the layer how to join.

## Metric types

| Type | Shape | Example |
|---|---|---|
| **Simple** | one measure, additive across all dimensions | `gross_revenue = sum(amount)` |
| **Ratio** | numerator / denominator (two measures) | `gross_margin_pct = gross_profit / gross_revenue` |
| **Derived** | expression over other metrics | `net_revenue = gross_revenue - refunds` |
| **Cumulative** | running/windowed accumulation over time | `running_total_revenue` |

```yaml
metrics:
  - name: gross_revenue
    type: simple
    type_params: { measure: order_amount }

  - name: gross_profit
    type: derived
    type_params:
      expr: revenue - cost
      metrics:
        - { name: gross_revenue, alias: revenue }
        - { name: total_cost, alias: cost }

  - name: gross_margin_pct
    type: ratio
    type_params:
      numerator: gross_profit
      denominator: gross_revenue

  - name: running_total_revenue
    type: cumulative
    type_params:
      measure: order_amount
      window: null   # null = accumulate from the beginning of time
```

## Additive vs non-additive vs semi-additive

- **Additive** — safe to `sum` across every dimension including time. Revenue, order count. The default.
- **Non-additive** — cannot be summed; must be recomputed at each grain. Ratios, percentages, distinct counts. `count(distinct customer_id)` per month does **not** sum to the quarterly distinct count — declare it as a measure with `agg: count_distinct` and let the layer recompute per grain. Never pre-aggregate it.
- **Semi-additive** — additive across some dimensions but not time. Account balances, inventory snapshots, headcount: you sum across regions on a given day, but across days you take the *last* (or first) value, not the sum.

```yaml
measures:
  - name: account_balance
    agg: sum
    expr: balance
    agg_time_dimension: snapshot_date
    non_additive_dimension:           # semi-additive: collapse time to the last value
      name: snapshot_date
      window_choice: max
```

Getting this wrong silently triples your inventory or headcount when someone groups by month. If a measure is a balance/snapshot, it is semi-additive — flag it.

## Time spines and grains

A time spine is a dense date dimension table the layer uses to fill gaps (no orders on a day still shows a zero row) and to roll day → week → month → quarter consistently. Declare the smallest grain you store; the layer aggregates upward. Never let consumers guess the grain — an undeclared grain is the most common source of "the monthly number doesn't match the daily sum."

```yaml
models:
  - name: metricflow_time_spine
    time_spine:
      standard_granularity_column: date_day
    columns:
      - { name: date_day, granularity: day }
```

## The fan-out double-count trap — through the layer

Joining a one-to-many relationship before aggregating multiplies the "one" side. If `orders` has many `order_lines`, summing `order_amount` after joining lines counts each order's amount once per line.

The layer protects you **only if measures live on the right semantic model**: put `order_amount` on `orders` (one row per order) and `line_quantity` on `order_lines` (one row per line). Then the layer aggregates each measure on its own grain before joining, and the fan-out never happens. The trap reappears the moment someone hand-writes the join in SQL — which is the whole reason to query through the layer.

## Testing metric definitions

- Pin a known answer: a date range where you've hand-verified the total once, assert the metric returns it in CI.
- Cross-check grains: monthly summed to a quarter must equal the quarterly query for additive metrics; assert it.
- Assert distinct/ratio metrics do **not** match a naive sum (that's the signal they're correctly non-additive).
- Run `scripts/verify.sh` on the model directory to catch missing `agg`, missing grain, and duplicate metric names before review.
