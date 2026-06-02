# Joins and set operations

## Join types and what they do to row counts

Reason about every join as a row-count operation first, columns second.

| Join | Rows returned | When right has no match | When right has many matches |
|---|---|---|---|
| `INNER JOIN` | only matching pairs | left row dropped | left row **duplicated** (fan-out) |
| `LEFT JOIN` | all left rows | right columns NULL | left row duplicated (fan-out) |
| `RIGHT JOIN` | all right rows | left columns NULL | right row duplicated |
| `FULL JOIN` | all rows from both | NULLs on the missing side | duplication on both sides |
| `CROSS JOIN` | `n × m` | n/a | n/a (intentional Cartesian) |

**Fan-out** is the core hazard: a one-to-many join multiplies the left row once per match. If you then `SUM` or `COUNT(*)`, every aggregate is inflated by the match count — the canonical "wrong total" bug.

```sql
-- Bad: each order row repeats once per item; SUM(o.total) is multiplied by item count
SELECT o.customer_id, SUM(o.total)
FROM orders o JOIN order_items i ON i.order_id = o.id
GROUP BY o.customer_id;

-- Good: pre-aggregate items, then join one row to one row
SELECT o.customer_id, SUM(o.total) AS revenue, SUM(i.qty) AS units
FROM orders o
JOIN (SELECT order_id, SUM(qty) AS qty FROM order_items GROUP BY order_id) i
  ON i.order_id = o.id
GROUP BY o.customer_id;
```

When you only need *existence* (not item columns), never join at all — use a semi-join.

## Semi-join and anti-join

- **Semi-join** = "left rows that have at least one match": `WHERE EXISTS (SELECT 1 FROM r WHERE r.fk = l.id)`. Returns each left row at most once — cannot fan out.
- **Anti-join** = "left rows with no match": `WHERE NOT EXISTS (…)`. NULL-safe, unlike `NOT IN`.

```sql
-- customers who have ordered (semi) vs never ordered (anti)
SELECT * FROM customers c WHERE EXISTS     (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
SELECT * FROM customers c WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
```

`NOT IN (SELECT customer_id FROM orders)` returns **zero rows** if any `customer_id` is NULL, because the three-valued comparison yields `UNKNOWN`, never `TRUE`. Always prefer `NOT EXISTS` for anti-joins.

## LATERAL joins (correlated derived tables)

A `LATERAL` subquery may reference columns from tables to its left — the per-row "for each X, get its top N" pattern as a join. Postgres/DuckDB/SQL Server (`CROSS APPLY`) support it; MySQL 8 has `LATERAL`; SQLite and BigQuery do not.

```sql
-- top 3 orders per customer, set-based, via LATERAL
SELECT c.id, o.*
FROM customers c
CROSS JOIN LATERAL (
  SELECT * FROM orders o WHERE o.customer_id = c.id
  ORDER BY o.amount DESC LIMIT 3
) o;
```

## Set operations

| Operator | Result | Cost |
|---|---|---|
| `UNION` | rows from both, **deduplicated** | sort/hash to dedup |
| `UNION ALL` | rows from both, duplicates kept | cheap, no dedup pass |
| `INTERSECT` | rows in both | dedup |
| `EXCEPT` | rows in first not in second | dedup |

- Columns are matched **by position**, not name; the count and types must align across both arms.
- `EXCEPT` is `MINUS` in Oracle. MySQL gained `INTERSECT`/`EXCEPT` in 8.0.31; older MySQL emulates them with joins.
- Default to `UNION ALL` and only pay for dedup when duplicates are actually possible and unwanted.
