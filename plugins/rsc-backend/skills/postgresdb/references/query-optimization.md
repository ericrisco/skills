# PostgreSQL query optimization

Reading plans, fixing slow SQL, concurrency, and the JSONB/FTS/pgvector workloads on PostgreSQL 16.
Running example tables: `orders`, `users`, `jobs`, `order_items`, `docs`.

## Reading EXPLAIN

Always run with timing and I/O. `FORMAT TEXT` is the most readable; `SETTINGS` shows non-default GUCs
that shaped the plan; `WAL` shows write volume for DML.

```sql
EXPLAIN (ANALYZE, BUFFERS, SETTINGS, FORMAT TEXT)
SELECT id, amount, created_at
FROM orders
WHERE user_id = $1 AND created_at >= $2
ORDER BY created_at DESC
LIMIT 20;
```

Annotated output:

```text
Limit  (cost=0.43..8.61 rows=20 width=24) (actual time=0.038..0.072 rows=20 loops=1)
  Buffers: shared hit=23
  ->  Index Scan using ix_orders_user_created on orders
        (cost=0.43..410.2 rows=996 width=24) (actual time=0.035..0.063 rows=20 loops=1)
        Index Cond: ((user_id = $1) AND (created_at >= $2))
        Heap Fetches: 0
        Buffers: shared hit=23
Planning Time: 0.21 ms
Execution Time: 0.10 ms
```

How to read it:

- **Estimated vs actual rows** (`rows=996` planned vs `rows=20` actual). A large divergence means stale
  statistics — run `ANALYZE orders;` (or raise `default_statistics_target` for skewed columns).
- **`Index Cond` vs `Filter`** — predicates under `Index Cond` are satisfied by the index; anything
  under `Filter` is a post-scan check (and `Rows Removed by Filter` counts the waste).
- **`Buffers: shared hit/read`** — `hit` is cache, `read` is disk I/O. High `read` on a hot query →
  warm the cache or shrink the working set.
- **`loops`** — per-node cost multiplies by `loops`; a cheap node run 100k times in a Nested Loop is
  your bottleneck.
- **`Heap Fetches: 0`** confirms an index-only scan; non-zero means `VACUUM` the table.

In production, capture slow plans automatically instead of guessing:

```sql
-- postgresql.conf (or ALTER SYSTEM): log the plan of any statement over 500ms
-- shared_preload_libraries = 'auto_explain'
SET auto_explain.log_min_duration = '500ms';
SET auto_explain.log_analyze = on;
SET auto_explain.log_buffers = on;
```

## Scan & join strategies

A `Seq Scan` is not automatically wrong — for a small table, or a query returning most rows, scanning
sequentially beats random index lookups. Distrust it only when you expected a selective index and the
table is large.

| Scan | Correct when |
| --- | --- |
| Seq Scan | small table, or predicate matches a large fraction of rows |
| Index Scan | selective predicate, few matching rows, need ordering |
| Index-Only Scan | all needed columns in the index + pages all-visible |
| Bitmap Heap Scan | medium selectivity, or combining several indexes (`BitmapAnd`/`BitmapOr`) |

| Join | Good for | Goes bad when |
| --- | --- | --- |
| Nested Loop | tiny outer side with an index on the inner | bad estimate → loops over millions |
| Hash Join | large unordered sets | hash spills to disk (`work_mem` too low) |
| Merge Join | both inputs pre-sorted (indexes or sort) | forces an expensive external sort |

A hash join that spills shows multiple batches on disk:

```text
Hash Join  (actual rows=2100000 loops=1)
  ->  Seq Scan on order_items
  ->  Hash  (Batches: 8  Memory Usage: 4096kB  Disk Usage: 51200kB)
```

`Batches > 1` with `Disk Usage` means the hash did not fit in `work_mem`. Fix by raising it for the
session (not globally — it is per-sort-node, per-connection):

```sql
SET work_mem = '128MB';   -- session-scoped; revert or use SET LOCAL inside a txn
```

## CTEs: materialized vs inlined

Before PG12, a `WITH` clause was always an optimization fence (materialized). PG12+ **inlines** a CTE
that is referenced once and is side-effect-free, letting predicates push down. Control it explicitly:

```sql
-- Inlined (PG12 default): the user_id filter pushes into the CTE scan
WITH recent AS (
    SELECT id, amount, created_at FROM orders
)
SELECT * FROM recent WHERE created_at >= $1;

-- MATERIALIZED: force a fence — compute once, reuse. Good for an expensive CTE used twice,
-- or to stop the planner from choosing a worse inlined plan.
WITH heavy AS MATERIALIZED (
    SELECT user_id, sum(amount) AS total FROM orders GROUP BY user_id
)
SELECT * FROM heavy WHERE total > 1000;

-- NOT MATERIALIZED: force inline even when referenced multiple times.
WITH base AS NOT MATERIALIZED (SELECT * FROM orders WHERE status = 'paid')
SELECT count(*) FROM base;
```

## Window functions & LATERAL

```sql
-- Running total per user, ordered by time
SELECT id, amount,
       sum(amount) OVER (PARTITION BY user_id ORDER BY created_at
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM orders;

-- Deduplicate: keep the newest row per user
SELECT * FROM (
    SELECT *, row_number() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
    FROM orders
) t
WHERE rn = 1;

-- Top-N-per-group: JOIN LATERAL is the fast pattern (uses ix_orders_user_created)
SELECT u.id, recent.id AS order_id, recent.amount
FROM users u
JOIN LATERAL (
    SELECT id, amount FROM orders
    WHERE user_id = u.id ORDER BY created_at DESC LIMIT 3
) recent ON true;
```

## Pagination

Keyset (cursor) pagination is O(1) per page; `OFFSET` is O(n) because the engine still computes and
discards every skipped row. The keyset must use the exact composite sort with a row-value comparator
and a unique tiebreaker.

```sql
-- GOOD: keyset; pass the last row's (created_at, id) as $2, $3
SELECT id, amount, created_at
FROM orders
WHERE user_id = $1
  AND (created_at, id) < ($2, $3)
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- pair with a covering index for an index-only scan
CREATE INDEX ix_orders_user_keyset ON orders (user_id, created_at DESC, id DESC)
    INCLUDE (amount);

-- BAD: OFFSET re-scans 100000 rows for page 5001
SELECT * FROM orders WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20 OFFSET 100000;
```

## Set-based thinking / killing N+1

```sql
-- Loop → single query
SELECT o.id, json_agg(i.* ORDER BY i.id) AS items
FROM orders o
JOIN order_items i ON i.order_id = o.id
WHERE o.user_id = $1
GROUP BY o.id;

-- Bulk upsert from parallel arrays (one round trip for thousands of rows)
INSERT INTO orders (public_id, user_id, amount)
SELECT * FROM unnest($1::uuid[], $2::bigint[], $3::numeric[])
ON CONFLICT (public_id) DO UPDATE SET amount = EXCLUDED.amount;

-- Insert derived rows in one statement
INSERT INTO order_items (order_id, sku, qty)
SELECT o.id, 'BACKFILL', 0 FROM orders o WHERE o.status = 'legacy';
```

## Transactions & concurrency

### Isolation & retry

| Level | Prevents | Use when |
| --- | --- | --- |
| Read Committed (default) | dirty reads | most OLTP; each statement re-snapshots |
| Repeatable Read | + non-repeatable/phantom (snapshot) | multi-statement consistent read |
| Serializable (SSI) | + write skew | cross-row invariants |

Repeatable Read and Serializable can abort with SQLSTATE `40001`; any level can deadlock with `40P01`.
Both are **retryable** — wrap the whole transaction and retry with backoff.

```python
# Python 3.12 + psycopg 3
import psycopg, time

def run_serializable(conn, fn, tries=5):
    for attempt in range(tries):
        try:
            with conn.transaction():
                conn.execute("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
                return fn(conn)
        except psycopg.errors.SerializationFailure:
            if attempt == tries - 1:
                raise
            time.sleep(0.05 * (2 ** attempt))
```

```go
// Go 1.22+ with pgx v5
func runSerializable(ctx context.Context, pool *pgxpool.Pool, fn func(pgx.Tx) error) error {
    for attempt := 0; attempt < 5; attempt++ {
        tx, err := pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
        if err != nil {
            return err
        }
        if err = fn(tx); err == nil {
            if err = tx.Commit(ctx); err == nil {
                return nil
            }
        }
        _ = tx.Rollback(ctx)
        var pgErr *pgconn.PgError
        if errors.As(err, &pgErr) && (pgErr.Code == "40001" || pgErr.Code == "40P01") {
            time.Sleep(time.Duration(50<<attempt) * time.Millisecond)
            continue
        }
        return err
    }
    return errors.New("serialization retries exhausted")
}
```

### MVCC mental model

Every row is a tuple version stamped with `xmin` (creating txn) and `xmax` (deleting/superseding txn).
A reader sees the version visible to its snapshot; writers never block readers. A long-running
transaction pins the oldest snapshot, which prevents vacuum from removing dead tuples newer than it —
this is how an idle-in-transaction connection causes table bloat. Keep transactions short and set
`idle_in_transaction_session_timeout`.

### Row locks & ordering

```sql
SELECT * FROM orders WHERE id = $1 FOR UPDATE;            -- exclusive; blocks other writers
SELECT * FROM orders WHERE id = $1 FOR NO KEY UPDATE;     -- weaker; allows FK refs concurrently
SELECT * FROM orders WHERE id = $1 FOR SHARE;             -- read lock; blocks writers, allows readers
SELECT * FROM jobs WHERE status='pending' FOR UPDATE SKIP LOCKED LIMIT 1;  -- queue claim
SELECT * FROM orders WHERE id = $1 FOR UPDATE NOWAIT;     -- error instead of waiting
```

Deadlocks come from inconsistent lock ordering. Always lock rows in a deterministic order (e.g. ascending
`id`) across all code paths, and bound the wait with `SET lock_timeout = '3s'`.

### Advisory locks

Application-level mutexes for singleton crons or leader election, keyed by an arbitrary `bigint`.

```sql
-- Transaction-scoped: auto-released at COMMIT/ROLLBACK. Safe under PgBouncer transaction pooling.
SELECT pg_advisory_xact_lock(hashtext('nightly-rollup'));
-- ... do the singleton work ...
-- (no explicit unlock needed)
```

Footgun: **session** advisory locks (`pg_advisory_lock`) are unusable under PgBouncer transaction
pooling — the lock outlives the pooled "session" and leaks across clients. Always use the `_xact_`
variant behind a transaction pooler.

## JSONB

| Operator | Meaning |
| --- | --- |
| `->` | get field as `jsonb` |
| `->>` | get field as `text` |
| `#>` / `#>>` | get at path as `jsonb` / `text` |
| `@>` | left contains right (GIN-indexable) |
| `?` / `?|` / `?&` | key exists / any / all |
| `jsonb_path_query` | JSONPath query |

```sql
-- containment with GIN
SELECT * FROM orders WHERE meta @> '{"channel": "mobile"}';
CREATE INDEX ix_orders_meta ON orders USING gin (meta jsonb_path_ops);

-- hot extracted key: expression index, then query must match the expression
CREATE INDEX ix_orders_channel ON orders ((meta->>'channel'));
SELECT * FROM orders WHERE meta->>'channel' = 'mobile';
```

Promote a key to a typed column once it is filtered/sorted frequently, needs a constraint, or needs
its own statistics — a column gets planner stats and a slim btree; a buried jsonb key does not.

## Full-text search

```sql
-- generated tsvector column + GIN index
ALTER TABLE orders ADD COLUMN search tsvector
    GENERATED ALWAYS AS (to_tsvector('english', coalesce(note, ''))) STORED;
CREATE INDEX ix_orders_search ON orders USING gin (search);

-- query with user-friendly parser; rank results
SELECT id, ts_rank_cd(search, q) AS rank
FROM orders, websearch_to_tsquery('english', $1) q
WHERE search @@ q
ORDER BY rank DESC
LIMIT 20;
```

`unaccent` normalizes diacritics (wrap it in your `to_tsvector` config). For fuzzy substring / typo
matching use `pg_trgm`:

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX ix_users_email_trgm ON users USING gin (email gin_trgm_ops);
SELECT * FROM users WHERE email ILIKE '%smith%';   -- now index-assisted
```

## pgvector

```sql
CREATE EXTENSION IF NOT EXISTS vector;
ALTER TABLE docs ADD COLUMN embedding vector(1536);
```

| Index | Build time | Recall | Query latency | Needs training |
| --- | --- | --- | --- | --- |
| hnsw | slower | high, tunable | low | no |
| ivfflat | fast | depends on `lists`/`probes` | low at scale | yes (needs data to build `lists`) |

Default to **hnsw** unless build time on a huge static set forces ivfflat.

```sql
CREATE INDEX ix_docs_embed ON docs USING hnsw (embedding vector_cosine_ops);
SET hnsw.ef_search = 100;   -- higher = better recall, slower

-- distance operators: <=> cosine, <-> L2, <#> negative inner product
SELECT id, embedding <=> $1 AS distance
FROM docs ORDER BY embedding <=> $1 LIMIT 10;
```

Filtering caveat: an ANN index returns the top-K by distance, then `WHERE` filters them — so a strict
filter can under-return (fewer than K rows). Over-fetch then filter, or enable pgvector 0.8 iterative
scan:

```sql
SET hnsw.iterative_scan = relaxed_order;   -- pgvector 0.8+: keep scanning until LIMIT is satisfied
SELECT id FROM docs
WHERE tenant_id = $2
ORDER BY embedding <=> $1
LIMIT 10;
```

Hybrid search fuses lexical (FTS) and semantic (vector) rankings with Reciprocal Rank Fusion:

```sql
-- RRF: combine FTS rank and vector rank; k=60 damps the long tail
WITH fts AS (
    SELECT id, row_number() OVER (ORDER BY ts_rank_cd(search, q) DESC) AS r
    FROM docs, websearch_to_tsquery('english', $1) q
    WHERE search @@ q LIMIT 50
),
vec AS (
    SELECT id, row_number() OVER (ORDER BY embedding <=> $2) AS r
    FROM docs ORDER BY embedding <=> $2 LIMIT 50
)
SELECT coalesce(fts.id, vec.id) AS id,
       coalesce(1.0 / (60 + fts.r), 0) + coalesce(1.0 / (60 + vec.r), 0) AS score
FROM fts FULL OUTER JOIN vec USING (id)
ORDER BY score DESC
LIMIT 10;
```
