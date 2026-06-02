# Window functions — full catalog

A window function computes across a set of rows *related to the current row* without collapsing them. Shape: `func(args) OVER (PARTITION BY … ORDER BY … <frame>)`. `PARTITION BY` resets the calculation per group; `ORDER BY` defines order *within* the partition; the frame defines which rows feed the current calculation.

## Function families

| Family | Functions | Needs ORDER BY? | Frame applies? |
|---|---|---|---|
| Ranking | `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE(n)`, `PERCENT_RANK`, `CUME_DIST` | yes | no (ignore frame) |
| Offset | `LAG(col, n, default)`, `LEAD(col, n, default)`, `FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE` | yes | `FIRST_VALUE`/`LAST_VALUE`/`NTH_VALUE` honor it |
| Aggregate-over | `SUM`, `AVG`, `COUNT`, `MIN`, `MAX`, `ANY_VALUE` `OVER (…)` | optional | yes |

- `ROW_NUMBER` is always unique (1,2,3,4); `RANK` leaves gaps after ties (1,1,3); `DENSE_RANK` does not (1,1,2). Pick by intent.
- `LAG`/`LEAD` take an optional default so the first/last row is not NULL: `LAG(amount, 1, 0)`.
- `FIRST_VALUE`/`LAST_VALUE` are frame-sensitive. `LAST_VALUE` under the default frame returns the *current* row, not the partition's last — extend the frame to `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.

## Frame units, worked

Given a partition ordered by `day` with values for `amount`:

```sql
-- ROWS: N physical rows regardless of value ties. Trailing 7-row average:
AVG(amount) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)

-- RANGE: a value window. With numeric offset, "all rows whose day is within 7 of current":
SUM(amount) OVER (ORDER BY day RANGE BETWEEN INTERVAL '7' DAY PRECEDING AND CURRENT ROW)

-- GROUPS: N distinct peer-groups (Postgres 11+, SQLite 3.28+; NOT MySQL 8):
SUM(amount) OVER (ORDER BY day GROUPS BETWEEN 2 PRECEDING AND CURRENT ROW)
```

Frame bounds: `UNBOUNDED PRECEDING`, `n PRECEDING`, `CURRENT ROW`, `n FOLLOWING`, `UNBOUNDED FOLLOWING`.

## The implicit-frame trap

A window with `ORDER BY` but **no explicit frame** defaults to:

```sql
RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
```

`RANGE` groups *peer* rows (rows tied on the `ORDER BY` value) into the same frame end — so on tied keys, a "running total" assigns every tied row the *same* cumulative value rather than incrementing row by row. For a true row-by-row cumulative, write `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. This default is identical across every engine; it is the single most common window bug.

## EXCLUDE clause (Postgres 11+, SQLite 3.28+; not MySQL 8)

Refines the frame after the bounds: `EXCLUDE CURRENT ROW`, `EXCLUDE GROUP` (current row + its peers), `EXCLUDE TIES` (peers but keep current), `EXCLUDE NO OTHERS` (default). Useful for "average of the others" calculations.

## Named windows

Define once with `WINDOW`, reuse by name — fewer repeated clauses, no drift:

```sql
SELECT id,
       SUM(amount) OVER w  AS running,
       AVG(amount) OVER w  AS avg_to_date
FROM t
WINDOW w AS (PARTITION BY cust ORDER BY day ROWS UNBOUNDED PRECEDING);
```

Supported in Postgres, MySQL 8, SQLite 3.28+, DuckDB. Window functions themselves were standardized in SQL:2003.

## Per-engine support matrix

| Feature | Postgres 11+ | MySQL 8 | SQLite 3.28+ | DuckDB | SQL Server | BigQuery |
|---|---|---|---|---|---|---|
| `ROWS` / `RANGE` frames | yes | yes | yes | yes | yes | yes |
| `GROUPS` frame | yes | **no** | yes | yes | no | no |
| `EXCLUDE` | yes | **no** | yes | yes | no | no |
| numeric `RANGE` offset | yes | yes | yes | yes | yes | yes |
| `FILTER (WHERE …)` on agg | yes | **no** | yes | yes | no | no |
| `QUALIFY` | **no** | no | no | yes | no | yes |
| named `WINDOW` | yes | yes | yes | yes | no | yes |
