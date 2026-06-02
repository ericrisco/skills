# Portability matrix

Standard reference: **SQL:2023 (ISO/IEC 9075:2023)**, the current ninth edition (published June 2023). It added a native `JSON` type, the `ANY_VALUE` aggregate, and the `GREATEST`/`LEAST` scalar functions; window functions date back to SQL:2003. No engine implements the full standard — this table is what you actually rely on across six common targets.

## Feature matrix

| Construct | Postgres 11+ | MySQL 8 | SQLite 3.28+ | DuckDB | SQL Server | BigQuery |
|---|---|---|---|---|---|---|
| `ROWS` / `RANGE` frames | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GROUPS` frame | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| `EXCLUDE` frame clause | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| `FILTER (WHERE …)` aggregate | ✅ | ❌ (use `CASE`) | ✅ | ✅ | ❌ (use `CASE`) | ❌ (use `CASE`) |
| `QUALIFY` | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ |
| `GROUPING SETS` / `ROLLUP` / `CUBE` | ✅ | `ROLLUP` only | ❌ | ✅ | ✅ | ✅ |
| `INTERSECT` / `EXCEPT` | ✅ | ✅ (8.0.31+) | ✅ | ✅ | ✅ | ✅ |
| `LATERAL` / `CROSS APPLY` | ✅ | ✅ | ❌ | ✅ | ✅ (`APPLY`) | n/a |
| `WITH RECURSIVE` | ✅ | ✅ | ✅ | ✅ | ✅ (no `RECURSIVE` kw) | ✅ |
| native `JSON` type | ✅ (`jsonb`) | ✅ | text + funcs | ✅ | ✅ | ✅ |
| boolean type | ✅ | tinyint(1) | int 0/1 | ✅ | bit | ✅ |

## Common dialect swaps

| Need | Postgres | MySQL 8 | SQLite | DuckDB | SQL Server | BigQuery |
|---|---|---|---|---|---|---|
| limit rows | `LIMIT n OFFSET m` | `LIMIT m, n` | `LIMIT n OFFSET m` | `LIMIT n` | `OFFSET m ROWS FETCH NEXT n ROWS ONLY` / `TOP n` | `LIMIT n` |
| set difference | `EXCEPT` | `EXCEPT` | `EXCEPT` | `EXCEPT` | `EXCEPT` | `EXCEPT DISTINCT` |
| string concat | `\|\|` | `CONCAT()` | `\|\|` | `\|\|` | `+` / `CONCAT` | `CONCAT` / `\|\|` |
| current timestamp | `now()` | `NOW()` | `datetime('now')` | `now()` | `SYSUTCDATETIME()` | `CURRENT_TIMESTAMP()` |
| date + interval | `d + INTERVAL '1 day'` | `DATE_ADD(d, INTERVAL 1 DAY)` | `date(d,'+1 day')` | `d + INTERVAL 1 DAY` | `DATEADD(day,1,d)` | `DATE_ADD(d, INTERVAL 1 DAY)` |
| null coalesce | `COALESCE` | `COALESCE`/`IFNULL` | `COALESCE`/`IFNULL` | `COALESCE` | `COALESCE`/`ISNULL` | `COALESCE`/`IFNULL` |
| cast | `x::int` or `CAST` | `CAST` | `CAST` | `x::int` or `CAST` | `CAST`/`CONVERT` | `CAST`/`SAFE_CAST` |

## Rules of thumb for portable SQL

- Prefer the standard spelling: `CAST(x AS int)`, `COALESCE`, `FETCH FIRST` is the most portable limiter but `LIMIT/OFFSET` covers the open-source four.
- Avoid `QUALIFY` and `FILTER` in code that must run everywhere — use the subquery wrapper and `CASE` instead, and leave a comment naming the cleaner dialect form.
- Set-op arms match by position and type; name your columns explicitly in each arm.
- When you do use a non-portable construct deliberately, flag it inline so a reviewer targeting another engine sees it immediately.
