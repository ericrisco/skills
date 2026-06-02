# CTEs and recursion

## Non-recursive CTEs

`WITH name AS (…)` names an intermediate result so you can reference it (possibly multiple times) and read the query top-down instead of inside-out. Chain them; each may reference the ones above.

```sql
WITH paid AS (
  SELECT customer_id, SUM(amount) AS spent
  FROM orders WHERE status = 'paid'
  GROUP BY customer_id
),
ranked AS (
  SELECT *, RANK() OVER (ORDER BY spent DESC) AS rnk FROM paid
)
SELECT * FROM ranked WHERE rnk <= 10;
```

Use CTEs to: name a step, avoid repeating a subquery, or stage a recursive walk. Do **not** assume a CTE is materialized for free — see the optimization fence below.

## Recursive CTEs

`WITH RECURSIVE` has two arms joined by `UNION [ALL]`: an **anchor** (the seed rows) and a **recursive member** that references the CTE name. It iterates until the recursive arm produces no new rows.

### Hierarchy (org chart) with a depth guard

```sql
WITH RECURSIVE chart AS (
  SELECT id, manager_id, name, 1 AS depth, ARRAY[id] AS path
  FROM employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.id, e.manager_id, e.name, c.depth + 1, c.path || e.id
  FROM employees e
  JOIN chart c ON e.manager_id = c.id
  WHERE c.depth < 50              -- depth guard: bound the walk
    AND e.id <> ALL(c.path)       -- cycle guard: don't revisit a node
)
SELECT * FROM chart ORDER BY path;
```

A real cyclic graph will loop forever (or exhaust memory) without a guard. Use **both**: a depth ceiling *and* a visited-path check. The `path` array technique is Postgres/DuckDB; SQLite/MySQL track depth and a string path instead. SQL Server requires `OPTION (MAXRECURSION n)`.

### Graph walk (reachability)

Same shape: anchor = start node, recursive arm follows edges, cycle guard on the accumulated path. Switch `UNION ALL` to `UNION` to collapse duplicate paths to the same node.

### Generated series

```sql
-- Portable date spine without a numbers table
WITH RECURSIVE days(d) AS (
  SELECT DATE '2026-01-01'
  UNION ALL
  SELECT d + INTERVAL '1 day' FROM days WHERE d < DATE '2026-12-31'
)
SELECT d FROM days;
```

Postgres/DuckDB prefer `generate_series()`; SQLite and BigQuery have their own (`generate_series`, `GENERATE_DATE_ARRAY`). The recursive form above works where those don't.

## The optimization fence portability note

Historically Postgres **always materialized** a CTE — an optimization fence that could block predicate push-down and hurt performance. Since **Postgres 12** a CTE referenced once and free of side effects is inlined by default; force the old behavior with `WITH x AS MATERIALIZED (…)` or prevent it with `AS NOT MATERIALIZED`. Other engines (MySQL 8, SQLite, DuckDB, SQL Server) generally inline CTEs as ordinary subqueries. Do not rely on a CTE as a performance barrier across engines.
