# DuckDB — Python client & dataframe interop

Full surface offloaded from the SKILL body. DuckDB v1.5.2 / LTS 1.4.x.

## Connect, cursor, scope

```python
import duckdb

# Module-level default connection (in-memory). Convenient for scripts/notebooks.
duckdb.sql("SELECT 42").fetchone()        # (42,)

# Explicit connection — required for a persistent file or per-thread isolation.
con = duckdb.connect("analytics.duckdb")  # created if absent
cur = con.cursor()                        # independent cursor; safe to hand to one thread
con.close()                               # or: with duckdb.connect(...) as con: ...
```

A replacement scan resolves a bare identifier in the SQL against Python variables in scope, so a local
`orders` frame is queryable as `FROM orders` with no registration. This only works on the default
connection / the connection that ran `.sql()` from that scope.

## Parameterized queries — never f-string user input

```python
con.execute("SELECT * FROM t WHERE region = ? AND amount > ?", ["EU", 100]).fetchall()

con.execute(
    "SELECT * FROM t WHERE region = $region AND amount > $min",
    {"region": "EU", "min": 100},
).fetchall()
```

Positional `?` and named `$name` both work. Parameterizing is correctness (typing) and safety, not just
style — string-building SQL invites injection and quoting bugs.

## Relational API — lazy, chainable

`duckdb.sql(...)` and the relational operators return a lazy relation. Nothing executes until you
materialize. Chain operators or drop into SQL, whichever is clearer.

```python
rel = con.sql("FROM 'sales/*.parquet'")          # a relation, not yet executed
(rel.filter("amount > 0")
    .aggregate("region, sum(amount) AS rev")     # GROUP BY inferred from non-aggregates
    .order("rev DESC")
    .limit(10)
    .df())                                       # materialize here

rel.project("region, amount")                    # SELECT
rel.join(other, "region")                        # join on a condition / column
```

## Materializers

| Call | Returns | Use when |
| --- | --- | --- |
| `.df()` | pandas DataFrame | downstream pandas / plotting |
| `.pl()` | Polars DataFrame | Polars pipeline |
| `.arrow()` | pyarrow.Table | zero-copy handoff, Arrow Flight, Parquet |
| `.fetchall()` | list[tuple] | small results, plain Python |
| `.fetchone()` | tuple / None | single scalar/row |
| `.fetchnumpy()` | dict[str, np.ndarray] | numeric columns into NumPy |
| `.torch()` | dict of tensors | feeding a model (when torch installed) |

## Registering and unregistering frames

Replacement scan covers most cases, but register explicitly when the frame isn't in the calling scope
(e.g. built inside a function) or you want a stable name across queries.

```python
con.register("v", some_dataframe)        # now queryable as FROM v
con.sql("FROM v SELECT count(*)")
con.unregister("v")                      # release the reference
```

`pyarrow.dataset` objects register the same way and get predicate/projection pushdown into the dataset.

## Round-trips

```python
# pandas / Polars / Arrow all go in and come out without an explicit conversion step:
con.sql("FROM my_pandas_df SELECT *").pl()        # pandas in, Polars out
con.sql("FROM my_polars_df SELECT *").arrow()     # Polars in, Arrow out
con.from_arrow(arrow_table).aggregate("k, count(*)").df()
```

## Transactions

```python
con.execute("BEGIN")
con.execute("INSERT INTO t VALUES (1)")
con.execute("COMMIT")          # or ROLLBACK
```

ACID within the single process. Remember the model: one writer. Don't open two writing connections to the
same file from different processes expecting concurrent writes — the second blocks or errors.

## Threading caveat

- One connection (or one `.cursor()`) **per thread**. Never share a cursor across threads.
- The module-level default connection is convenient but not for concurrent threads — give each thread its
  own `duckdb.connect(...)` (or `con.cursor()`).
- Reads parallelize internally across `PRAGMA threads`; you do not need threads to parallelize a single
  query — DuckDB already vectorizes and multi-threads execution.
