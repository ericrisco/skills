# Tile schema — `dashboard.yaml` field reference

The artifact `dashboard.yaml` is a manifest a BI tool, a web app, or a human can render. This is the full field-by-field reference, two filled examples, and exactly what `scripts/verify.sh` enforces.

## Top-level keys

| Key | Required | Type | Notes |
| --- | --- | --- | --- |
| `title` | yes | string | Dashboard name shown to the reader |
| `date_range` | yes | string | Active window, e.g. `"2026-05"` or `"last 90d"` |
| `tiles` | yes | list | 1-9 entries (budget rule; verify.sh fails >9) |
| `layout` | yes | map | Placement + scan pattern (below) |

## Tile fields

| Field | Required | Type | Notes |
| --- | --- | --- | --- |
| `id` | yes | string | Unique slug, referenced by drill-downs |
| `north_star` | one tile only | bool | Exactly one tile sets `true`; verify.sh enforces |
| `metric` | yes | string | Human label of the KPI |
| `chart` | yes | enum | `big_number`, `line`, `sorted_bar`, `bullet`, `stacked_bar`, `treemap`, `scatter`, `histogram`. Banned: `pie` >5 cats, `gauge`, `dial` |
| `value_source` | recommended | string | Where the number comes from (table/query/sheet) — analytics owns this |
| `units` | recommended | enum/string | `percent`, `currency`, `count`, `months`, etc. |
| `comparison` | yes | map | `{ type: target\|prior\|benchmark, value: <n or ref> }` |
| `delta` | recommended | string | What the change is measured against, e.g. `vs_prior_week` |
| `status_logic` | recommended | string | The RYG rule, e.g. `"green ≥ target; yellow ≥ 90%; red < 90%"` |
| `owner` | yes | string | Accountable human/role |
| `refresh` | yes | enum | `realtime`, `hourly`, `daily`, `weekly`, `monthly` — match to decision cadence |
| `decision` | yes | string | The Decision Test answer: what action this number drives. Must be non-empty |

## `layout` block

| Field | Type | Notes |
| --- | --- | --- |
| `north_star` | enum | `top_left` (recommended) — where the entry-point tile sits |
| `scan` | enum | `Z` or `F` reading pattern |
| `groups` | list | Named clusters of related tiles, e.g. `[growth, revenue, health]` |

## Example A — SaaS exec (the body's worked example, extended)

```yaml
title: SaaS Exec Dashboard
date_range: "2026-05"
tiles:
  - id: waa
    north_star: true
    metric: Weekly Active Accounts
    chart: big_number
    units: accounts
    comparison: { type: target, value: 1200 }
    delta: vs_prior_week
    status_logic: "green ≥ target; yellow ≥ 90%; red < 90%"
    owner: VP Product
    refresh: daily
    decision: "Below 90% of target two weeks running escalates activation work."
  - id: nrr
    metric: Net Revenue Retention
    chart: big_number
    units: percent
    comparison: { type: benchmark, value: 110 }
    owner: VP Sales
    refresh: monthly
    decision: "Below 100% triggers a save/expansion review."
  - id: churn
    metric: Monthly Logo Churn
    chart: line
    units: percent
    comparison: { type: target, value: 3.0 }
    owner: Head of CS
    refresh: daily
    decision: "Above target investigates cohort + reason codes."
  - id: runway
    metric: Cash Runway
    chart: bullet
    units: months
    comparison: { type: target, value: 18 }
    owner: CFO
    refresh: monthly
    decision: "Under 12 months opens fundraise / cost review."
  - id: pipeline
    metric: New Pipeline by Source
    chart: sorted_bar
    units: currency
    comparison: { type: prior, value: last_month }
    owner: Head of Marketing
    refresh: weekly
    decision: "Shift spend toward the top-converting source."
layout:
  north_star: top_left
  scan: Z
  groups: [growth, revenue, health]
```

## Example B — E-commerce ops

```yaml
title: E-commerce Ops Dashboard
date_range: "last 28d"
tiles:
  - id: rev
    north_star: true
    metric: Net Revenue
    chart: big_number
    units: currency
    comparison: { type: prior, value: prev_28d }
    delta: vs_prior_period
    status_logic: "green ≥ prior; yellow within -5%; red < -5%"
    owner: Head of Ecom
    refresh: daily
    decision: "A red week triggers a promo / merchandising review."
  - id: cvr
    metric: Conversion Rate by Channel
    chart: sorted_bar
    units: percent
    comparison: { type: benchmark, value: 2.5 }
    owner: Growth Lead
    refresh: daily
    decision: "Reallocate ad spend toward channels above benchmark."
  - id: aov
    metric: Average Order Value
    chart: line
    units: currency
    comparison: { type: prior, value: prev_28d }
    owner: Merchandising
    refresh: daily
    decision: "Falling AOV prompts a bundle / upsell test."
  - id: cac
    metric: CAC vs Target
    chart: bullet
    units: currency
    comparison: { type: target, value: 35 }
    owner: Growth Lead
    refresh: weekly
    decision: "Over target pauses the worst-performing campaign."
  - id: returns
    metric: Return Rate
    chart: line
    units: percent
    comparison: { type: target, value: 8.0 }
    owner: Ops Manager
    refresh: weekly
    decision: "A rising trend opens a sizing/quality investigation."
layout:
  north_star: top_left
  scan: F
  groups: [acquisition, revenue, fulfillment]
```

## What `verify.sh` enforces (and what it does not)

Enforces — **shape and discipline**:

1. File parses as YAML.
2. `tiles:` exists and holds 1-9 entries (fails if >9 — the budget rule).
3. Exactly one tile has `north_star: true`.
4. Every tile has non-empty `metric`, `chart`, `comparison`, `owner`, `refresh`, `decision`.
5. No `chart: pie` with more than 5 categories; no `chart: gauge` or `chart: dial`.

Does **not** judge:

- Whether the chosen metrics are the *right* metrics — that is [kpi-framework](../../kpi-framework/SKILL.md).
- Whether the numbers/values are correct — that is the data layer ([analytics](../../analytics/SKILL.md)).

So a `dashboard.yaml` can pass verify.sh and still display the wrong metrics. verify.sh guards the craft of the dashboard, not the choice of what to measure.
