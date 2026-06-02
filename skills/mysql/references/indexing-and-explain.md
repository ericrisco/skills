# Indexing and EXPLAIN (InnoDB)

Everything here is MySQL 8.4 / MariaDB 11.8 InnoDB behaviour. If the same advice would hold on
PostgreSQL, it belongs in `sql`, not here.

## The clustered-index model — why PK choice is everything

An InnoDB table *is* its primary-key B-tree. The full row lives in the leaf of the PK index; there
is no separate heap. Two consequences drive almost every indexing decision:

1. **Every secondary index stores the PK value as its row pointer**, not a physical address. So a
   wide PK is paid for once per secondary index, per row. A `CHAR(36)` random UUID PK on a table
   with five secondary indexes carries 36 bytes × 5 copies of the key for every row, on top of the
   clustered copy. A `BIGINT` PK is 8 bytes.
2. **Insert locality follows PK order.** A monotonic PK (`BIGINT AUTO_INCREMENT`, ordered UUIDv7)
   appends to the rightmost leaf — tight, sequential, cache-friendly. A random UUID v4 scatters
   inserts across the whole B-tree, causing page splits and buffer-pool churn.

```sql
-- Bad: random UUID as a human-readable CHAR(36) PK.
CREATE TABLE orders (
  id CHAR(36) PRIMARY KEY,          -- 36 bytes, random → page splits + fat secondary indexes
  user_id BIGINT NOT NULL
) ENGINE=InnoDB;

-- Good: small monotonic surrogate PK; store a public UUID as BINARY(16) if you need one.
CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  public_id BINARY(16) NOT NULL,    -- UUIDv7 packed; ordered, 16 bytes
  user_id BIGINT NOT NULL,
  UNIQUE KEY uq_public (public_id)
) ENGINE=InnoDB;
```

If you must use a UUID PK, use a time-ordered one (UUIDv7) stored as `BINARY(16)`, never a random
v4 as `CHAR(36)`.

## The leftmost-prefix rule, worked through

A composite index `INDEX (a, b, c)` is a single sorted B-tree keyed on the tuple `(a, b, c)`. It can
satisfy a predicate only by reading a *contiguous left prefix* of that tuple:

| Query predicate | Uses the index? | Why |
|---|---|---|
| `WHERE a = 1` | Yes (prefix `a`) | leftmost column present |
| `WHERE a = 1 AND b = 2` | Yes (prefix `a,b`) | contiguous prefix |
| `WHERE a = 1 AND b = 2 AND c = 3` | Yes (full key) | full prefix |
| `WHERE a = 1 ORDER BY b` | Yes — sort comes free | `b` is the next key column after the `a` equality |
| `WHERE b = 2` | No | skips the leftmost column `a` |
| `WHERE a = 1 AND c = 3` | Partial — only `a` | `b` is missing, so `c` can't be a seek key (used as a filter) |
| `WHERE a > 1 AND b = 2` | Range on `a` only | a range on an earlier column stops the next column from being a seek key |

The design rule that falls out: **equality columns first, then the single range or `ORDER BY`
column.** A range predicate "uses up" the index — no column after it can be a seek key, only a
filter.

```sql
-- Query: WHERE user_id = ? AND status = ? AND created_at >= ? ORDER BY created_at DESC
-- Good: two equalities first, then the range/sort column last.
CREATE INDEX idx_u_s_c ON orders (user_id, status, created_at);
```

## Covering, prefix, invisible, and functional indexes

**Covering index** — if every column a query touches (SELECT list + WHERE + ORDER BY) is in one
index, InnoDB answers from the index alone and never walks back to the clustered PK leaf. `EXPLAIN`
shows `Using index`.

```sql
SELECT status, total FROM orders WHERE user_id = ?;
-- Good: index covers the filter AND the selected columns → no PK back-lookup.
CREATE INDEX idx_cover ON orders (user_id, status, total);
```

**Prefix index** — index the first N characters of a long `VARCHAR`/`TEXT`. Required for `TEXT`
(which can't be indexed whole) and useful to shrink a fat key. It can never be a covering index, and
N must be long enough for selectivity.

```sql
CREATE INDEX idx_email_prefix ON users (email(20));   -- first 20 chars
-- Pick N from selectivity: SELECT COUNT(DISTINCT LEFT(email,20))/COUNT(*) FROM users;
```

**Invisible index** (`INVISIBLE`) — the optimizer ignores it but maintains it. Use it to stage a new
index on a hot table, or to test "would dropping this index hurt?" without actually dropping it.

```sql
ALTER TABLE orders ALTER INDEX idx_cover INVISIBLE;   -- test impact; ALTER ... VISIBLE to restore
```

**Functional / multi-valued index** (8.0.13+) — index an expression so a non-sargable predicate
becomes sargable without a generated column.

```sql
CREATE INDEX idx_lower_email ON users ((LOWER(email)));   -- query must use LOWER(email) too
CREATE INDEX idx_tags ON docs ((CAST(meta->'$.tags' AS UNSIGNED ARRAY)));  -- multi-valued, for JSON arrays
```

## Reading EXPLAIN field by field

Three forms:
- `EXPLAIN <q>` — the chosen plan, no execution.
- `EXPLAIN ANALYZE <q>` — actually runs the query, reports *actual* rows and timing per node.
- `EXPLAIN FORMAT=JSON <q>` — full cost model, `used_key_parts`, `filtered`, attached conditions.

The **access `type`** is the first thing to read — worst to best:

| `type` | Meaning | Verdict |
|---|---|---|
| `ALL` | Full table scan | Bad on a large table |
| `index` | Full index scan (whole index read) | Usually still too much |
| `range` | Index range scan (`>`, `BETWEEN`, `IN`) | Good |
| `ref` | Non-unique index lookup by equality | Good |
| `eq_ref` | Unique/PK lookup, one row per join row | Great (joins) |
| `const` / `system` | At most one row, resolved as a constant | Best |

Then read:
- **`rows`** — *estimated* rows examined at this node. An estimate from stats, not truth — confirm
  with `EXPLAIN ANALYZE`.
- **`filtered`** — estimated % of `rows` surviving the `WHERE`. Low `filtered` × high `rows` = the
  index gets you to the neighbourhood but the predicate isn't selective in the index.
- **`key`** / **`key_len`** — the chosen index and how many bytes of it were used. A short `key_len`
  on a composite index means only a prefix was usable.
- **`Extra`** flags: `Using index` (covering — good), `Using filesort` (a separate sort pass — the
  index didn't satisfy `ORDER BY`), `Using temporary` (a materialised temp table, common with
  `GROUP BY`/`DISTINCT` that can't use an index), `Using where` (post-filter after the index).

## Every common "why no index" cause, with the fix

```sql
-- 1. Function on the indexed column → index unusable.
-- Bad:
SELECT * FROM orders WHERE DATE(created_at) = '2026-06-01';
-- Good (sargable range):
SELECT * FROM orders WHERE created_at >= '2026-06-01' AND created_at < '2026-06-02';

-- 2. Implicit type cast: VARCHAR column compared to a number → per-row cast, no index.
-- Bad (phone is VARCHAR):
SELECT * FROM users WHERE phone = 6041234567;
-- Good:
SELECT * FROM users WHERE phone = '6041234567';

-- 3. Charset/collation mismatch on a JOIN key → per-row conversion, no index on the joined side.
-- Bad: a.code is utf8mb4, b.code is latin1.
-- Good: make both columns the same charset+collation (ALTER one side), then the join uses the index.

-- 4. Leading wildcard LIKE → no prefix to seek.
-- Bad:
SELECT * FROM products WHERE name LIKE '%phone%';
-- Good (prefix only):
SELECT * FROM products WHERE name LIKE 'phone%';   -- or a FULLTEXT index for substring search

-- 5. OR across different columns → often defeats a single index.
-- Bad:
SELECT * FROM t WHERE a = 1 OR b = 2;
-- Good: UNION two index-friendly halves, or an index_merge the optimizer can use.
SELECT * FROM t WHERE a = 1 UNION SELECT * FROM t WHERE b = 2;
```

After every fix, re-run `EXPLAIN ANALYZE` and confirm the `type` improved and `rows` dropped — the
plan is the proof, not the rewrite.
