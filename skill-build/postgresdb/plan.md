# IMPLEMENTATION PLAN — skill `postgresdb`

Source of truth: `/Volumes/EXTERN/DEV/skills/skill-build/postgresdb/spec.md`.
Follow this plan verbatim. No further design decisions. PostgreSQL **16** is the target; call out
11/12/14/15 deltas where the spec says so. Running example entities used EVERYWHERE: `orders`,
`users`, `jobs`. Voice: directive, dense, copy-pasteable. Every fenced block tagged with a language.

---

## 0. File list (exact paths)

Create exactly these files under `/Volumes/EXTERN/DEV/skills/skills/postgresdb/`:

```text
/Volumes/EXTERN/DEV/skills/skills/postgresdb/SKILL.md
/Volumes/EXTERN/DEV/skills/skills/postgresdb/references/schema-and-indexing.md
/Volumes/EXTERN/DEV/skills/skills/postgresdb/references/query-optimization.md
/Volumes/EXTERN/DEV/skills/skills/postgresdb/references/migrations.md
/Volumes/EXTERN/DEV/skills/skills/postgresdb/references/operations-and-security.md
/Volumes/EXTERN/DEV/skills/skills/postgresdb/scripts/verify.sh
```

Create the directories first:

```bash
mkdir -p /Volumes/EXTERN/DEV/skills/skills/postgresdb/references
mkdir -p /Volumes/EXTERN/DEV/skills/skills/postgresdb/scripts
```

Line budgets (hard): SKILL.md 250–450 (target ~400). schema-and-indexing.md 420–500.
query-optimization.md 400–480. migrations.md 380–460. operations-and-security.md 420–500.
verify.sh ~150–200.

---

## 1. SKILL.md — write this file exactly in this order

### 1.1 Frontmatter (YAML, first lines, no blank line before `---`)

```yaml
---
name: postgresdb
description: Use when designing or reviewing a PostgreSQL schema (types, constraints, normalization), writing or optimizing SQL, choosing or adding indexes, reading EXPLAIN/ANALYZE, planning a migration (expand-contract, concurrent index, batched backfill), or operating/securing Postgres (roles, RLS, PgBouncer pooling, VACUUM/autovacuum, pg_stat_statements, declarative partitioning, backups/PITR). Triggers - "slow query", "add an index", "EXPLAIN", "design this table", "zero-downtime migration", "row level security", "connection pool", "N+1", "JSONB", "full-text search", "pgvector". PostgreSQL 16; ORM-agnostic (SQLAlchemy/Alembic, Prisma, golang-migrate, raw SQL).
origin: risco
---
```

Note: use a hyphen `-` not a colon inside the description's "Triggers" list (a literal `:` after
"Triggers" is fine, but avoid YAML-confusing colons mid-value; the version above is safe — keep it).

### 1.2 H1 + one-line purpose

```markdown
# PostgreSQL — schema, indexing, queries, ops

Engine-level PostgreSQL 16 guidance: design correct schemas, pick the right index, read EXPLAIN and
fix slow SQL, run zero-downtime migrations, and operate/secure the database. Tooling-agnostic; every
example is runnable.
```

### 1.3 `## When to use / When NOT to use`

Two bullet lists. **When to use** (6 bullets from spec §1): schema/DDL decisions; slow/wrong-cardinality
queries & plan reading; index decisions; migrations on tables with real data/live traffic; concurrency
(isolation/locking/deadlocks/queues); ops (pooling/vacuum/monitoring/partitioning/backups/RLS/roles).

**When NOT to use** (4 bullets): ORM-API ergonomics (Prisma `updateMany` count trap, SQLAlchemy session
lifecycle) → `prisma-patterns` / SQLAlchemy skill; non-Postgres engines (MySQL/SQLite/ClickHouse);
app-layer caching / Redis / Kafka as products (only Postgres-as-queue via `SKIP LOCKED` is in scope);
cloud-vendor console clicks (we give SQL/params, not the RDS/Cloud SQL UI path).

Then a one-line map of the four reference files and what each owns:

```markdown
Deep dives: [schema-and-indexing](references/schema-and-indexing.md) (types, constraints, every index
kind, bloat) · [query-optimization](references/query-optimization.md) (EXPLAIN, joins, concurrency,
JSONB/FTS/pgvector) · [migrations](references/migrations.md) (zero-downtime DDL, per-ORM) ·
[operations-and-security](references/operations-and-security.md) (roles, RLS, pooling, vacuum,
partitioning, backups).
```

### 1.4 `## Non-negotiables`

Bulleted list, exactly these 10 (no code), terse imperative:

1. `timestamptz` always for events; store UTC. Never naive `timestamp`.
2. Money is `numeric(19,4)`, never `float`/`double precision`.
3. Every FK gets a covering index — Postgres does **not** auto-index FK columns.
4. `text` + `CHECK (length(...) <= n)`, not `varchar(n)` as a length hack.
5. Index creation on a live table is **always** `CONCURRENTLY` (so it cannot run inside a txn).
6. Never `ADD COLUMN ... NOT NULL` without a default/backfill plan; never add a volatile default on a
   large table without a batched backfill.
7. Read the plan before adding an index: `EXPLAIN (ANALYZE, BUFFERS)` or it didn't happen.
8. Migrations are forward-only in prod; never edit an applied migration.
9. `SET lock_timeout` + `SET statement_timeout` around DDL on hot tables.
10. RLS is opt-in per table and the **table owner bypasses it** — verify with a non-owner role
    (use `FORCE ROW LEVEL SECURITY` for owner too).

### 1.5 `## Decision rules`

Intro line: "Fast lookups; runnable DDL lives in the references."

#### `### Pick the column type` — markdown table, columns: Use case | Correct type | Avoid | Why

Rows (exactly these):

| Use case | Correct type | Avoid | Why |
| --- | --- | --- | --- |
| Surrogate PK (internal) | `bigint GENERATED ALWAYS AS IDENTITY` | `serial`, `int` | identity is SQL-standard, no sequence-ownership gotchas; `bigint` avoids 2.1B overflow |
| Surrogate PK (public/distributed) | `uuid` v7 | `uuid` v4 | v7 is time-ordered → less B-tree fragmentation than random v4 |
| Natural text id (slug, sku) | `text` + `UNIQUE` + `CHECK` | `varchar(n)` | length via CHECK; no rewrite to widen later |
| Money / exact decimal | `numeric(19,4)` | `float8`, `money` | binary floats drift; `money` has locale issues |
| Timestamp (event) | `timestamptz` | `timestamp` | stores a UTC instant; naive timestamp loses zone |
| Duration | `interval` | int seconds | self-documenting, arithmetic-safe |
| Small closed set, stable | `enum` | `text` w/o CHECK | type safety; but see lookup-table note |
| Evolving set, joinable | lookup table + FK | `enum` | `ALTER TYPE ... ADD VALUE` is awkward; FK gives joins + soft-retire |
| Flag | `boolean` | `int`, `varchar` | three-valued NULL still possible — add `NOT NULL DEFAULT` |
| Tags (read-mostly) | `text[]` + GIN | comma string | array ops + GIN containment |
| Tags (relational) | join table | `text[]` | when you need FK integrity / per-tag rows |
| Semi-structured | `jsonb` | `json`, `text` | binary, indexable, dedup keys; promote hot keys to columns |
| IP / CIDR | `inet` / `cidr` | `text` | validation + operators |
| Time range (booking) | `tstzrange` + GiST | two columns | `&&` overlap + exclusion constraint |

#### `### Pick the index` — table, columns: Access pattern | Index | DDL | Notes

Rows (exactly):

| Access pattern | Index | DDL | Notes |
| --- | --- | --- | --- |
| `=` / `<` `>` / range / `ORDER BY` | btree (default) | `CREATE INDEX ix_orders_status ON orders (status)` | also enforces uniqueness |
| `LIKE 'prefix%'` | btree + `text_pattern_ops` | `CREATE INDEX ix_users_email_pat ON users (email text_pattern_ops)` | only for C-locale/prefix; not `%suffix` |
| Case-insensitive eq | expr index or `citext` | `CREATE INDEX ix_users_lemail ON users (lower(email))` | query must use `lower(email)` too |
| `@>` jsonb / array containment | GIN | `CREATE INDEX ix_orders_meta ON orders USING gin (meta)` | `jsonb_path_ops` if only `@>` |
| Full-text `@@` | GIN on tsvector | `CREATE INDEX ix_orders_search ON orders USING gin (search)` | index a generated `tsvector` column |
| Range overlap / exclusion / geo | GiST | `CREATE INDEX ix_book_during ON bookings USING gist (during)` | also PostGIS geometry |
| Huge append-only time-series | BRIN | `CREATE INDEX ix_events_ts ON events USING brin (created_at)` | needs physical correlation |
| Vector similarity | hnsw (pgvector) | `CREATE INDEX ix_docs_embed ON docs USING hnsw (embedding vector_cosine_ops)` | see query-optimization |
| Dedup only | unique btree | `CREATE UNIQUE INDEX uq_users_email ON users (email)` | constraint = index |

Add one line under the table: "Hash indexes: almost never — equality-only, no multicolumn, rarely
beats btree even though WAL-logged since PG10."

#### `### When NOT to add an index`

Bullets: low-selectivity boolean/`status` with few distinct values; tiny tables (seq scan wins);
write-heavy columns rarely filtered (index = write tax); a column already the **left prefix** of an
existing composite; redundant with a `UNIQUE` constraint (already an index).

### 1.6 `## Copy-paste patterns`

Each sub-section: H3 + one-line "why" + Good/Bad fenced `sql` block(s). Write these exactly:

#### `### Canonical table (types + constraints + identity)`

One `sql` GOOD block — full `orders` table:

```sql
-- GOOD: identity PK, public uuid, FK with action, numeric money, timestamptz,
-- status via lookup FK, generated tsvector, CHECK constraints.
CREATE TABLE orders (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    public_id    uuid NOT NULL DEFAULT gen_random_uuid(),  -- v4; see schema ref for v7
    user_id      bigint NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    status       text NOT NULL REFERENCES order_statuses (code) ON UPDATE CASCADE,
    amount       numeric(19,4) NOT NULL CHECK (amount >= 0),
    currency     text NOT NULL CHECK (length(currency) = 3),
    note         text,
    search       tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce(note, ''))) STORED,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (public_id)
);
CREATE INDEX ix_orders_user_id ON orders (user_id);     -- FKs are NOT auto-indexed
CREATE INDEX ix_orders_status  ON orders (status);
```

Then a `sql` BAD block:

```sql
-- BAD: every column is a future migration or a bug.
CREATE TABLE orders (
    id          serial PRIMARY KEY,            -- sequence-ownership gotchas; use IDENTITY
    user_id     int REFERENCES users(id),      -- int overflows at 2.1B; no FK index
    status      varchar(20),                   -- length hack; no constraint on values
    amount      float,                         -- money drift
    created_at  timestamp DEFAULT now()        -- naive: loses the zone
);
```

One line: "`updated_at` is not auto-maintained — add a `BEFORE UPDATE` trigger (see schema ref) or set
it in the app; Postgres has no `ON UPDATE` clause."

#### `### Composite index column order`

Rule line: "Equality columns first, then the range/sort column." GOOD + BAD `sql`:

```sql
-- Query: WHERE user_id = $1 AND created_at >= $2 ORDER BY created_at DESC
-- GOOD: equality (user_id) then range (created_at)
CREATE INDEX ix_orders_user_created ON orders (user_id, created_at DESC);

-- BAD: range-first index cannot satisfy the equality efficiently for this query
CREATE INDEX ix_orders_created_user ON orders (created_at, user_id);
```

One line: "Confirm with `EXPLAIN` that the plan shows `Index Cond: (user_id = ... AND created_at >= ...)`,
not a `Filter:`."

#### `### Partial + covering (INCLUDE) index`

```sql
-- Partial: index only the rows you query (smaller, hotter)
CREATE INDEX ix_orders_active ON orders (user_id, created_at DESC)
WHERE status <> 'cancelled';

-- Covering: INCLUDE non-key columns to enable an index-only scan
CREATE INDEX ix_orders_user_cover ON orders (user_id) INCLUDE (amount, created_at);
```

One line: "Index-only scan requires a recently-`VACUUM`ed table; confirm `Heap Fetches: 0` in
`EXPLAIN (ANALYZE)`."

#### `### Keyset (cursor) pagination — not OFFSET`

```sql
-- GOOD: keyset on a stable composite sort; uses ix_orders_user_created
SELECT id, amount, created_at
FROM orders
WHERE user_id = $1
  AND (created_at, id) < ($2, $3)   -- row-value comparator = last row of prev page
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- BAD: OFFSET scans and discards 100000 rows every page (O(n))
SELECT * FROM orders WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20 OFFSET 100000;
```

One line: "The index must match the `ORDER BY` direction exactly; include the tiebreaker (`id`)."

#### `### UPSERT done right`

```sql
-- GOOD: insert-or-update; EXCLUDED is the row that failed to insert
INSERT INTO inventory (sku, qty)
VALUES ($1, $2)
ON CONFLICT (sku)
DO UPDATE SET qty = inventory.qty + EXCLUDED.qty
WHERE inventory.qty + EXCLUDED.qty >= 0   -- guard
RETURNING id, qty;

-- DO NOTHING returns no row on conflict; wrap to always get the row:
WITH ins AS (
    INSERT INTO tags (name) VALUES ($1)
    ON CONFLICT (name) DO NOTHING
    RETURNING id
)
SELECT id FROM ins
UNION ALL
SELECT id FROM tags WHERE name = $1 LIMIT 1;
```

#### `### Queue with SKIP LOCKED`

```sql
-- GOOD: contention-free job claim; concurrent workers never block each other
UPDATE jobs
SET status = 'processing', locked_at = now()
WHERE id = (
    SELECT id FROM jobs
    WHERE status = 'pending'
    ORDER BY created_at
    FOR UPDATE SKIP LOCKED
    LIMIT 1
)
RETURNING id, payload;
```

One line: "`SKIP LOCKED` skips rows another txn holds; `FOR UPDATE` alone would serialize all workers."

#### `### Kill the N+1`

```sql
-- BAD: application loops, one query per order (N+1)
--   for o in orders: SELECT * FROM order_items WHERE order_id = o.id
-- GOOD: one set-based query
SELECT o.id, json_agg(i.*) AS items
FROM orders o
JOIN order_items i ON i.order_id = o.id
WHERE o.user_id = $1
GROUP BY o.id;

-- Top-N-per-group: JOIN LATERAL, not a window-filter scan
SELECT u.id, recent.*
FROM users u
JOIN LATERAL (
    SELECT id, amount, created_at FROM orders
    WHERE user_id = u.id ORDER BY created_at DESC LIMIT 3
) recent ON true;
```

One line: "An ORM emitting N queries is the same bug — fix it at the SQL boundary, not with a cache."

#### `### EXPLAIN, the right way`

```sql
EXPLAIN (ANALYZE, BUFFERS, SETTINGS, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = $1 AND created_at >= $2;
```

Then a numbered "read these four first": (1) estimated vs actual rows (large gap → stale stats, run
`ANALYZE`); (2) the most expensive node (highest `actual time` × `loops`); (3) `Seq Scan` on a big
table where you expected an index; (4) `Rows Removed by Filter` (predicate not pushed to an index).
Pointer: "Full method in [query-optimization](references/query-optimization.md)."

### 1.7 `## Anti-patterns / rationalizations → STOP`

Markdown table, columns: Rationalization | Reality / STOP. Exactly these rows:

| Rationalization | Reality → STOP |
| --- | --- |
| "I'll add the FK index later, the query works now" | Unindexed FK = seq scan + heavy lock cascade on parent `DELETE`/`UPDATE`. Index it now. |
| "UUID PK is fine everywhere" | Random v4 fragments the B-tree and bloats WAL. Use `IDENTITY` internally or uuid **v7**. |
| "`SELECT count(*)` to check existence" | Counts the whole match. Use `EXISTS (SELECT 1 ...)`. |
| "CTEs are just for readability" | Pre-12 they were optimization fences; PG12+ inlines unless `MATERIALIZED`. Know which you want. |
| "`NOT IN (subquery)`" | NULL-unsafe (one NULL → empty result) and slow. Use `NOT EXISTS`. |
| "Store money as float, round on display" | Silent drift across arithmetic. `numeric(19,4)`. |
| "`ADD COLUMN ... NOT NULL DEFAULT now()`" | Volatile default rewrites the table under ACCESS EXCLUSIVE. Non-volatile constant is instant (PG11+). |
| "One big `jsonb` blob beats columns" | No constraints, no per-key stats, GIN bloat. Promote hot keys to typed columns. |
| "RLS policy calling `auth.uid()` per row" | Re-evaluated per row. Wrap: `(SELECT auth.uid())` so it runs once. |
| "`CREATE INDEX` in the migration is fine" | Blocks writes for the whole build. `CREATE INDEX CONCURRENTLY` (outside a txn). |
| "`VACUUM FULL` will fix bloat" | Takes ACCESS EXCLUSIVE, rewrites the table. Use autovacuum tuning / `REINDEX CONCURRENTLY`. |

### 1.8 `## Quick reference`

Three compact pieces.

**Isolation levels** — table: Level | Prevents | Use when | Note.

| Level | Prevents | Use when | Note |
| --- | --- | --- | --- |
| Read Committed (default) | dirty reads | most OLTP | each statement sees a fresh snapshot |
| Repeatable Read | + non-repeatable / phantom (snapshot) | multi-statement consistent read | may raise `40001`; retry |
| Serializable (SSI) | + write skew | invariants across rows | retry `40001` with backoff |

One line: "Retry the txn on SQLSTATE `40001` (serialization_failure) and `40P01` (deadlock_detected)."

**Lock modes (DDL)** — one line + pointer: "`CREATE INDEX CONCURRENTLY` takes SHARE UPDATE EXCLUSIVE
(allows writes); plain `CREATE INDEX`, `ALTER TABLE ... TYPE`, `ADD COLUMN` with volatile default, and
`VACUUM FULL` take ACCESS EXCLUSIVE (blocks everything). Full table in
[migrations](references/migrations.md#lock-impact-reference)."

**Diagnostic one-liners** — single `sql` block, each correct & copy-paste:

```sql
-- Unindexed foreign keys
SELECT c.conrelid::regclass AS tbl, a.attname AS col
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
WHERE c.contype = 'f'
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid AND (i.indkey::int2[])[0] = a.attnum
  );

-- Top slow queries (needs pg_stat_statements)
SELECT calls, round(mean_exec_time::numeric, 2) AS mean_ms, round(total_exec_time::numeric, 2) AS total_ms, query
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;

-- Dead tuples / bloat candidates
SELECT relname, n_dead_tup, n_live_tup, last_autovacuum
FROM pg_stat_user_tables WHERE n_dead_tup > 1000 ORDER BY n_dead_tup DESC;

-- Blocking locks
SELECT blocked.pid AS blocked_pid, blocking.pid AS blocking_pid, blocked.query AS blocked_query
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid AND NOT bl.granted
JOIN pg_locks gl ON gl.locktype = bl.locktype AND gl.database IS NOT DISTINCT FROM bl.database
  AND gl.relation IS NOT DISTINCT FROM bl.relation AND gl.granted
JOIN pg_stat_activity blocking ON blocking.pid = gl.pid;

-- Cache hit ratio (aim > 0.99)
SELECT sum(heap_blks_hit) / nullif(sum(heap_blks_hit + heap_blks_read), 0) AS ratio
FROM pg_statio_user_tables;

-- Unused indexes
SELECT relname, indexrelname, idx_scan
FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY relname;
```

### 1.9 `## Verify`

One paragraph: "Run `scripts/verify.sh` from your project root. It lints discovered SQL with `sqlfluff`
(if configured), syntax-sanity-checks migration files and flags foot-guns (`CREATE INDEX` without
`CONCURRENTLY` in a migration, `ADD COLUMN ... NOT NULL` without `DEFAULT`, `VACUUM FULL`), and — only
if `DATABASE_URL` and `psql` are present — checks that `pg_stat_statements` is enabled. Missing tools
are skipped with a yellow `[skip]`, never a failure; it never writes and never connects without
`DATABASE_URL`."

### 1.10 `## See Also`

Bullets with relative links:

- [references/schema-and-indexing.md](references/schema-and-indexing.md) — types, constraints, all index kinds, bloat.
- [references/query-optimization.md](references/query-optimization.md) — EXPLAIN, joins, concurrency, JSONB/FTS/pgvector.
- [references/migrations.md](references/migrations.md) — zero-downtime DDL, lock-impact table, per-ORM.
- [references/operations-and-security.md](references/operations-and-security.md) — roles, RLS, pooling, vacuum, partitioning, backups.
- Sibling skills: `prisma-patterns` (Prisma ORM surface traps), `database-migrations` (multi-ORM migration workflow), `risco-project-harness` (scaffolds the `01-TOOLS/POSTGRES` operational tool).

---

## 2. references/schema-and-indexing.md

H1: `# PostgreSQL schema & indexing`. One-line intro. Sections in order:

### `## Naming conventions`
Bullets: `snake_case`; plural table names (`orders`); index prefixes `pk_ / fk_ / uq_ / ix_ / ck_`;
pattern `<table>_<cols>_idx` OR the `ix_<table>_<cols>` form (pick `ix_` and be consistent — match
SKILL.md); avoid reserved words (`user`, `order` need quoting → don't). One tiny `sql` example showing
a named constraint: `CONSTRAINT ck_orders_amount_nonneg CHECK (amount >= 0)`.

### `## Types, in depth`
Sub-bullets, each with `sql`:
- **Surrogate keys**: `bigint GENERATED ALWAYS AS IDENTITY` vs `serial` (sequence ownership, `GRANT`
  on sequence, `OVERRIDING SYSTEM VALUE`). uuid v7: `gen_random_uuid()` returns **v4**; show a v7 path:
  note pgcrypto/`uuidv7()` is native in **PG18**; for PG16 use the `pg_uuidv7` extension or generate v7
  in the app. Include the fragmentation argument (random v4 → page splits, WAL amplification).
  ```sql
  -- PG16: native gen_random_uuid() is v4 (random). For time-ordered keys:
  CREATE EXTENSION IF NOT EXISTS pg_uuidv7;   -- provides uuid_generate_v7()
  ALTER TABLE orders ALTER COLUMN public_id SET DEFAULT uuid_generate_v7();
  ```
- **Time**: `timestamptz` stores a UTC instant (not a zone); `now()`/`current_timestamp`; `interval`;
  never naive `timestamp` for events. `sql` showing `AT TIME ZONE` for display only.
- **Numbers/money**: `numeric(19,4)`; `bigint` counters; `double precision` acceptable for science not
  money; `CHECK (amount >= 0)`.
- **Text**: `text` + `CHECK (length(x) <= 320)`; `citext` (extension) for case-insensitive uniqueness;
  `varchar(n)` only when an external contract demands a hard limit.
- **Enum vs lookup table**: trade-off table (Aspect | enum | lookup table) covering add value, remove
  value, joins, FK integrity, i18n labels, ordering. `sql` for both. Recommend lookup table for
  evolving sets. Note `ALTER TYPE ... ADD VALUE` cannot run inside a transaction block before the value
  is committed and cannot be removed.
- **Arrays vs jsonb vs join table**: decision bullets + GIN index for each (`USING gin (tags)`,
  `USING gin (meta jsonb_path_ops)`).

### `## Constraints`
Each with `sql`:
- PK / composite PK.
- FK: all actions table (`NO ACTION`, `RESTRICT`, `CASCADE`, `SET NULL`, `SET DEFAULT`) + when each;
  `DEFERRABLE INITIALLY DEFERRED` for circular/bulk loads.
- `UNIQUE`, including `UNIQUE NULLS NOT DISTINCT` (PG15+) so multiple NULLs collide.
- `CHECK` (named).
- `EXCLUDE USING gist`: no-overlap booking example with `tstzrange` + `btree_gist`:
  ```sql
  CREATE EXTENSION IF NOT EXISTS btree_gist;
  CREATE TABLE bookings (
      id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      room_id   bigint NOT NULL REFERENCES rooms (id),
      during    tstzrange NOT NULL,
      EXCLUDE USING gist (room_id WITH =, during WITH &&)
  );
  ```
- `NOT VALID` + `VALIDATE CONSTRAINT` two-step (CHECK and FK) to avoid a long lock on a big table.

### `## Generated & identity columns`
`GENERATED ALWAYS AS (expr) STORED` (the `search` tsvector example); identity vs serial; `OVERRIDING
SYSTEM VALUE` for explicit inserts during data migration. Note: no `VIRTUAL` generated columns in PG16
(only STORED); PG18 adds virtual.

### `## Normalization & deliberate denormalization`
3NF default. When to denormalize: read-heavy aggregates, counters maintained by trigger or kept fresh
via `GENERATED`. Materialized views: `CREATE MATERIALIZED VIEW`, `REFRESH MATERIALIZED VIEW
CONCURRENTLY` (requires a UNIQUE index on the MV). `sql` for a counter trigger.

### `## Indexing deep dive`
Per access method, `sql` DDL + "when":
- **btree**: default; multicolumn order (equality→range→sort); `text_pattern_ops` for `LIKE 'x%'`;
  `DESC NULLS LAST` ordered indexes to match `ORDER BY`.
- **GIN**: jsonb default opclass vs `jsonb_path_ops` (smaller, only `@>`); arrays; FTS; `fastupdate`
  and `gin_pending_list_limit` note.
- **GiST**: ranges, exclusion, geometry (PostGIS pointer).
- **BRIN**: append-only time-series; `pages_per_range`; requires physical correlation (insert order ≈
  column order); tiny index, large gains on huge tables.
- **Hash**: equality-only, no multicolumn, WAL-logged since PG10, still rarely worth it.
- **Partial / expression / covering**: `WHERE`, `lower(col)`, `INCLUDE`; unique-partial as conditional
  uniqueness (`CREATE UNIQUE INDEX ... WHERE deleted_at IS NULL`).
- **Index-only scans**: visibility map, `VACUUM` dependency, `Heap Fetches: 0`.

### `## Bloat & maintenance`
`pg_stat_user_indexes` unused-index query (cross-ref SKILL.md); `REINDEX INDEX CONCURRENTLY`;
`pgstattuple` extension to measure; when bloat actually matters; never `VACUUM FULL` on a live hot
table (ACCESS EXCLUSIVE) — prefer `pg_repack` (pointer).

---

## 3. references/query-optimization.md

H1: `# PostgreSQL query optimization`. Sections in order:

### `## Reading EXPLAIN`
Show one annotated real plan in a `text` block (Index Scan with `Buffers: shared hit/read`, `actual
rows`, `loops`, `Rows Removed by Filter`, `Heap Fetches`). Explain estimated-vs-actual divergence →
stale stats → `ANALYZE`; `Buffers` = I/O; `loops` multiplies per-loop cost. Mention `auto_explain`
(`auto_explain.log_min_duration`) for prod and `EXPLAIN (ANALYZE, BUFFERS, SETTINGS, WAL)`.

### `## Scan & join strategies`
Seq vs Index vs Index-Only vs Bitmap Heap scan — when each is *correct* (seq scan on a small/most-rows
query is right). Nested Loop vs Hash Join vs Merge Join; what forces a bad one (missing index, bad
estimate, `work_mem` too low → external merge Disk sort). `text` snippet of a Hash Join with
`Batches: 4 ... Disk` indicating spill; fix = raise `work_mem` for the session.

### `## CTEs: materialized vs inlined`
PG12+ inlines by default. `MATERIALIZED` forces a fence — use when an expensive CTE is referenced once
or to defeat a bad plan. `NOT MATERIALIZED` to force inline. `sql` both.

### `## Window functions & LATERAL`
Running totals (`sum(...) OVER (PARTITION BY ... ORDER BY ...)`); dedup with `row_number()` in a
subquery then filter `= 1`; top-N-per-group via `JOIN LATERAL (... LIMIT n)` with the supporting
composite index. `sql` each.

### `## Pagination`
Full keyset pattern (multi-column stable sort, row-value comparator), why OFFSET is O(n), pairing with
a covering index for index-only scan. `sql`.

### `## Set-based thinking / killing N+1`
Loop→single query; bulk upsert from `unnest($1::bigint[], $2::numeric[])`; `INSERT ... SELECT`. `sql`.

### `## Transactions & concurrency`
- Isolation table (RC/RR/Serializable) + retry loop on `40001`/`40P01`. Two retry wrappers:
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
          if err != nil { return err }
          if err = fn(tx); err == nil {
              if err = tx.Commit(ctx); err == nil { return nil }
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
- MVCC one-paragraph mental model (tuple versions, `xmin`/`xmax`, long txns pin the oldest snapshot and
  block vacuum).
- Row locks: `FOR UPDATE` / `FOR NO KEY UPDATE` / `FOR SHARE`; `SKIP LOCKED`; `NOWAIT`; lock ordering to
  avoid deadlocks; `SET lock_timeout`.
- Advisory locks: `pg_advisory_xact_lock(key)` for singleton cron / leader election; footgun: session
  advisory locks are unusable under PgBouncer transaction pooling (use the `_xact_` variant).

### `## JSONB`
Operators table (`->`, `->>`, `#>`, `#>>`, `@>`, `?`, `?|`, `?&`, `jsonb_path_query`). GIN opclass
choice; expression index on a hot extracted key (`CREATE INDEX ON orders ((meta->>'channel'))`); when
to promote a key to a typed column. `sql`.

### `## Full-text search`
`tsvector`/`tsquery`; `websearch_to_tsquery('english', $1)`; generated `tsvector` column + GIN; ranking
`ts_rank_cd`; `unaccent`; `pg_trgm` (`gin_trgm_ops`) for fuzzy/`ILIKE '%x%'`. `sql`.

### `## pgvector`
`CREATE EXTENSION vector`; `embedding vector(1536)`; hnsw vs ivfflat trade-off table (build time,
recall, latency, needs-training); operators `<=>` cosine / `<->` L2 / `<#>` inner product; `SET
hnsw.ef_search`; hybrid search (FTS + vector with `RRF`/weighted union) pattern; pre- vs post-filter
caveat (filtered ANN can under-return — over-fetch then filter, or use `iterative scan` in pgvector
0.8). `sql`.

---

## 4. references/migrations.md

H1: `# PostgreSQL zero-downtime migrations`. Sections in order:

### `## Principles`
Forward-only in prod; DDL and DML in separate migrations; immutable once applied; test against
prod-sized data; wrap risky DDL:
```sql
SET lock_timeout = '3s';
SET statement_timeout = '0';   -- or a bounded value for the backfill step
```

### `## Lock-impact reference`
The differentiator table. Columns: Operation | Lock | Blocks reads? | Blocks writes? | Safe variant.
Rows (exactly):

| Operation | Lock | Reads | Writes | Safe variant |
| --- | --- | --- | --- | --- |
| `ADD COLUMN` (nullable, no default) | ACCESS EXCLUSIVE (brief) | no | no | metadata-only, instant |
| `ADD COLUMN ... DEFAULT <const>` (PG11+) | ACCESS EXCLUSIVE (brief) | no | no | instant; default stored in catalog |
| `ADD COLUMN ... DEFAULT <volatile>` | ACCESS EXCLUSIVE (long) | yes | yes | add nullable → batched backfill |
| `ALTER COLUMN ... TYPE` (rewrite) | ACCESS EXCLUSIVE (long) | yes | yes | expand-contract new column |
| `ADD CHECK` | ACCESS EXCLUSIVE + full scan | yes | yes | `... NOT VALID` then `VALIDATE` |
| `ADD FOREIGN KEY` | SHARE ROW EXCLUSIVE + scan | no | yes | `... NOT VALID` then `VALIDATE` |
| `SET NOT NULL` | ACCESS EXCLUSIVE + full scan | yes | yes | add validated CHECK first (PG12+ skips re-scan) |
| `CREATE INDEX` | SHARE (blocks writes) | no | yes | `CREATE INDEX CONCURRENTLY` |
| `CREATE INDEX CONCURRENTLY` | SHARE UPDATE EXCLUSIVE | no | no | (the safe one; 2 scans, no txn) |
| `DROP COLUMN` | ACCESS EXCLUSIVE (brief) | no | no | code-first, then drop |
| `VACUUM FULL` | ACCESS EXCLUSIVE (long) | yes | yes | autovacuum / `pg_repack` |

### `## Expand–contract (zero-downtime)`
`text` phase diagram (expand → dual-write/backfill → migrate-reads → contract) interleaved with app
deploys. Apply to: rename column, change type, split/merge column.

### `## Safe recipes (raw SQL)`
Each a `sql` block:
- **Add NOT NULL column safely** (the cheap-promote chain):
  ```sql
  -- 1. add nullable
  ALTER TABLE users ADD COLUMN display_name text;
  -- 2. batched backfill (see below)
  -- 3. add validated CHECK without long lock
  ALTER TABLE users ADD CONSTRAINT ck_users_display_name_nn
      CHECK (display_name IS NOT NULL) NOT VALID;
  ALTER TABLE users VALIDATE CONSTRAINT ck_users_display_name_nn;  -- scans, SHARE UPDATE EXCL
  -- 4. promote to column NOT NULL (PG12+ uses the proven CHECK, skips full re-scan)
  ALTER TABLE users ALTER COLUMN display_name SET NOT NULL;
  ALTER TABLE users DROP CONSTRAINT ck_users_display_name_nn;
  ```
- **Add index concurrently + clean a failed one**:
  ```sql
  CREATE INDEX CONCURRENTLY ix_users_email ON users (email);
  -- if it failed it leaves an INVALID index:
  SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;
  DROP INDEX CONCURRENTLY ix_users_email;   -- then recreate
  ```
- **Add FK without long lock**: `... NOT VALID` then `VALIDATE CONSTRAINT`.
- **Change type via expand-contract** (when in-place rewrite is unavoidable).
- **Drop column**: code-first note + `ALTER TABLE ... DROP COLUMN`.
- **Batched backfill loop** (correct, keyset/SKIP LOCKED, commits per batch):
  ```sql
  DO $$
  DECLARE last_id bigint := 0; n int;
  BEGIN
    LOOP
      WITH batch AS (
        SELECT id FROM users WHERE id > last_id AND display_name IS NULL
        ORDER BY id LIMIT 5000 FOR UPDATE SKIP LOCKED
      )
      UPDATE users u SET display_name = u.username
      FROM batch WHERE u.id = batch.id
      RETURNING u.id INTO last_id;   -- track progress
      GET DIAGNOSTICS n = ROW_COUNT;
      EXIT WHEN n = 0;
      COMMIT;   -- DO block in PG11+ supports COMMIT
    END LOOP;
  END $$;
  ```
  Note: pure `DO` blocks cannot easily capture the max id with `RETURNING ... INTO` across a set; the
  implementer must instead write the loop with `SELECT max(id) ... INTO last_id` from the batch CTE, or
  run the loop from the app/migration tool. Use this app-side variant (psycopg) as the primary example
  and keep the `DO` block as the in-`psql` fallback:
  ```python
  last_id = 0
  while True:
      rows = conn.execute(
          "WITH b AS (SELECT id FROM users WHERE id > %s AND display_name IS NULL "
          "ORDER BY id LIMIT 5000 FOR UPDATE SKIP LOCKED) "
          "UPDATE users u SET display_name = u.username FROM b WHERE u.id = b.id "
          "RETURNING u.id", (last_id,)).fetchall()
      conn.commit()
      if not rows:
          break
      last_id = max(r[0] for r in rows)
  ```

### `## Per-tool concrete examples`
Same change for all: "add `avatar_url` + concurrent index + backfill `display_name`".
- **plain SQL**: `NNNN_add_avatar.up.sql` / `.down.sql` pair (`sql`).
- **golang-migrate**: file pair; `CONCURRENTLY` cannot run in a txn → use a migration **without** the
  default transaction wrapper. golang-migrate runs each file in a txn by default; document the
  `x-migrations-table` is irrelevant — the correct fix is to put the `CONCURRENTLY` statement in its
  own migration file and disable the txn via the `pgx`/`postgres` driver note, OR (simplest) keep the
  concurrent index in a separate migration and rely on golang-migrate NOT wrapping a single statement
  it cannot — be precise: golang-migrate **does** wrap; the accepted approach is to add a leading
  comment is not honored, so the implementer must state: "Split the concurrent index into its own
  migration and run it with a tool/driver that does not open a transaction, or use
  `golang-migrate` with the `multiStatements`/`x-no-tx` driver param" — write: the `postgres` driver
  honors no per-file txn-disable flag, so the canonical recommendation is to execute concurrent-index
  migrations out-of-band or switch to `dbmate`/`atlas`/`tern` for that one step. Keep this honest and
  concrete; `force VERSION` to clear a dirty state. (`bash` + `sql`.)
- **Alembic (SQLAlchemy 2.0, Python 3.12)**:
  ```python
  from alembic import op
  import sqlalchemy as sa

  def upgrade() -> None:
      op.add_column("users", sa.Column("avatar_url", sa.Text(), nullable=True))
      with op.get_context().autocommit_block():     # required for CONCURRENTLY
          op.create_index(
              "ix_users_avatar_url", "users", ["avatar_url"],
              postgresql_concurrently=True, if_not_exists=True,
          )
      op.execute("UPDATE users SET display_name = username WHERE display_name IS NULL")
      op.create_check_constraint(
          "ck_users_display_name_nn", "users", "display_name IS NOT NULL",
          postgresql_not_valid=True,
      )
  ```
- **Prisma**: `prisma migrate dev --create-only`, hand-edit SQL to add `CONCURRENTLY`, `migrate deploy`
  in CI; checksum-immutability warning; pointer to `prisma-patterns`. (`bash` + `sql`.)

### `## Rollback reality`
Down-migrations are best-effort; data-destructive forward changes (`DROP COLUMN`, type narrowing) are
not reversible without a backup; snapshot/`pg_dump` the affected table before the contract phase.

---

## 5. references/operations-and-security.md

H1: `# PostgreSQL operations & security`. Sections in order:

### `## Roles & least privilege`
login role vs group role; `REVOKE ALL ON SCHEMA public FROM PUBLIC`; per-app role with only needed
grants; `ALTER DEFAULT PRIVILEGES`; read-only reporting role; never run the app as superuser;
`GRANT pg_read_all_data TO reporter` (PG14+). `sql`:
```sql
REVOKE ALL ON SCHEMA public FROM PUBLIC;
CREATE ROLE app_rw LOGIN PASSWORD :'app_pw';
GRANT USAGE ON SCHEMA public TO app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;
CREATE ROLE reporter LOGIN PASSWORD :'rep_pw';
GRANT pg_read_all_data TO reporter;   -- PG14+
```

### `## Row-Level Security`
`ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` (owner bypass!); `CREATE POLICY` for tenant
isolation; the `(SELECT current_setting('app.tenant_id', true))` per-statement-eval optimization;
`USING` (read/visible) vs `WITH CHECK` (write); test as a non-owner role; multi-tenant template +
Supabase `auth.uid()` note. `sql`:
```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON orders
    USING (tenant_id = (SELECT current_setting('app.tenant_id', true)::bigint))
    WITH CHECK (tenant_id = (SELECT current_setting('app.tenant_id', true)::bigint));
-- per-request: SET app.tenant_id = '42';  (or SET LOCAL inside a txn)
```

### `## Connection pooling`
Why PG connections are expensive (process-per-connection, ~10MB each). PgBouncer **transaction mode**
caveats: no session-level `SET`/`SET search_path`, session advisory locks unusable, prepared statements
need PG14 protocol-level + PgBouncer ≥1.21 `max_prepared_statements`. Sizing: `pool_size ≈ cores × 2..4`;
app pool total ≤ server `max_connections`. Serverless: `connection_limit=1` per instance + external
pooler (cross-link `prisma-patterns`). `text`/`ini` pgbouncer.ini snippet.

### `## VACUUM & autovacuum`
What VACUUM does (reclaim dead tuples, freeze xids, update visibility map). Per-table autovacuum tuning
for hot tables (`autovacuum_vacuum_scale_factor`, `autovacuum_vacuum_cost_limit`). Transaction-ID
wraparound danger + monitor `age(datfrozenxid)`. `VACUUM (ANALYZE)` vs `VACUUM FULL` (never live). `sql`:
```sql
ALTER TABLE jobs SET (
    autovacuum_vacuum_scale_factor = 0.02,
    autovacuum_vacuum_cost_limit = 2000
);
SELECT datname, age(datfrozenxid) FROM pg_database ORDER BY 2 DESC;
```

### `## Monitoring`
`pg_stat_statements` setup (`shared_preload_libraries = 'pg_stat_statements'`, `pg_stat_statements.track
= top`, `CREATE EXTENSION`). Top-queries query; `pg_stat_user_tables`/`_indexes`; blocking-lock query
(reuse SKILL.md); cache hit ratio; replication lag (`pg_stat_replication`, `replay_lag`);
`statement_timeout` and `idle_in_transaction_session_timeout` as guardrails. `sql`.

### `## Declarative partitioning`
`PARTITION BY RANGE (created_at)` monthly time-series example; create partitions; attach/detach;
index per partition (PG11+ propagates from parent); `pg_partman` pointer. When it helps (huge
time-series, fast drop-old via `DETACH`+`DROP`) and when it hurts (small tables, cross-partition
queries, too many partitions → planning overhead). `sql`:
```sql
CREATE TABLE events (id bigint GENERATED ALWAYS AS IDENTITY, created_at timestamptz NOT NULL,
    payload jsonb NOT NULL) PARTITION BY RANGE (created_at);
CREATE TABLE events_2026_06 PARTITION OF events
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
```

### `## Backups & PITR`
Logical `pg_dump -Fc -j4` / `pg_restore -j4` (per-table, version-portable) vs physical
`pg_basebackup` + WAL archiving for PITR (`archive_command`, `restore_command`,
`recovery_target_time`). Test restores regularly. `pgBackRest` pointer. `bash`.

### `## HA basics`
Streaming replication (sync vs async); read replicas + replica lag → read-after-write inconsistency
(route reads needing freshness to primary); failover (Patroni) pointer. Explicitly "not a deep HA
guide — link out."

---

## 6. scripts/verify.sh — write exactly this

Write the file, then `chmod +x`. Do NOT execute it in this repo.

```bash
#!/usr/bin/env bash
set -euo pipefail

# verify.sh — postgresdb skill gate. Run from your PROJECT root.
#
# What it does (read-only, idempotent, never writes):
#   1. Lints discovered SQL with sqlfluff IF sqlfluff + a .sqlfluff config exist.
#   2. Syntax-sanity-checks migration *.sql files: balanced quotes/parens, ';' terminators,
#      and flags foot-guns (CREATE INDEX without CONCURRENTLY in a migration, ADD COLUMN ...
#      NOT NULL without DEFAULT, VACUUM FULL).
#   3. IF DATABASE_URL is set AND psql is present: checks pg_stat_statements is enabled.
#      It NEVER connects unless DATABASE_URL is set, and a down/unreachable DB is a skip, not a fail.
#
# Exit code: non-zero ONLY on (a) sqlfluff lint errors, or (b) unbalanced quotes/parens.
# Everything else is advisory (yellow [skip] / [warn]). Missing tools never fail the gate.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
warn() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# Discover SQL/migration files (exclude vendor dirs).
mapfile -t SQL_FILES < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' \) -prune -o \
    -type f -name '*.sql' -print 2>/dev/null
)

# ---- 1. sqlfluff ----
if command -v sqlfluff >/dev/null 2>&1; then
  if [ -f "$ROOT/.sqlfluff" ]; then
    if [ "${#SQL_FILES[@]}" -gt 0 ]; then
      if sqlfluff lint --dialect postgres "${SQL_FILES[@]}"; then
        ok "sqlfluff lint clean"
      else
        err "sqlfluff lint reported errors"
      fi
    else
      warn "sqlfluff: no .sql files found"
    fi
  else
    warn "sqlfluff present but no .sqlfluff config — skipping lint"
  fi
else
  warn "sqlfluff not installed — skipping SQL lint"
fi

# ---- 2. SQL syntax sanity + foot-gun scan ----
if [ "${#SQL_FILES[@]}" -eq 0 ]; then
  warn "no .sql files to syntax-check"
else
  for f in "${SQL_FILES[@]}"; do
    # Strip line + block comments before counting, to avoid false positives.
    body="$(sed -E 's/--.*$//' "$f")"
    sq=$(printf '%s' "$body" | tr -cd "'" | wc -c | tr -d ' ')
    op=$(printf '%s' "$body" | tr -cd '(' | wc -c | tr -d ' ')
    cp=$(printf '%s' "$body" | tr -cd ')' | wc -c | tr -d ' ')
    if [ $((sq % 2)) -ne 0 ]; then err "$f: unbalanced single quotes"; fi
    if [ "$op" -ne "$cp" ]; then err "$f: unbalanced parentheses ($op '(' vs $cp ')')"; fi

    # Foot-guns (advisory only) — only flag for files that look like migrations.
    case "$f" in
      *migration*|*migrations*|*alembic/versions*|*prisma/migrations*)
        if grep -Eiq 'create[[:space:]]+(unique[[:space:]]+)?index' "$f" \
           && ! grep -Eiq 'create[[:space:]]+(unique[[:space:]]+)?index[[:space:]]+concurrently' "$f"; then
          note "$f: CREATE INDEX without CONCURRENTLY in a migration"
        fi
        if grep -Eiq 'add[[:space:]]+column[^;]*not[[:space:]]+null' "$f" \
           && ! grep -Eiq 'add[[:space:]]+column[^;]*default' "$f"; then
          note "$f: ADD COLUMN ... NOT NULL without DEFAULT (table rewrite / lock risk)"
        fi
        if grep -Eiq 'vacuum[[:space:]]+full' "$f"; then
          note "$f: VACUUM FULL takes ACCESS EXCLUSIVE — avoid on live tables"
        fi
        ;;
    esac
  done
  [ "$EXIT" -eq 0 ] && ok "SQL syntax sanity passed (${#SQL_FILES[@]} files)"
fi

# ---- 3. pg_stat_statements guidance ----
GUIDE='Enable pg_stat_statements: add "pg_stat_statements" to shared_preload_libraries, restart, then run CREATE EXTENSION pg_stat_statements;'
if [ -n "${DATABASE_URL:-}" ] && command -v psql >/dev/null 2>&1; then
  if res="$(psql "$DATABASE_URL" -At -c \
        "SELECT 1 FROM pg_extension WHERE extname='pg_stat_statements'" 2>/dev/null)"; then
    if [ "$res" = "1" ]; then
      ok "pg_stat_statements is enabled"
    else
      note "pg_stat_statements not enabled. $GUIDE"
    fi
  else
    warn "could not connect to DATABASE_URL (DB down or unreachable) — skipping pg_stat_statements check"
  fi
else
  warn "DATABASE_URL unset or psql missing — skipping DB checks. $GUIDE"
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found failures"; fi
exit "$EXIT"
```

After writing: `chmod +x /Volumes/EXTERN/DEV/skills/skills/postgresdb/scripts/verify.sh`.

---

## 7. Acceptance checks (implementer self-verifies before finishing)

Run/confirm ALL of these. Do not finish until every box is true.

1. All 6 files exist at the exact paths in §0; directories created.
2. `SKILL.md` is 250–450 lines, exactly one H1, frontmatter has `name: postgresdb`, a `description`
   starting with "Use when ", and `origin: risco`.
3. Each `references/*.md` is within its budget (schema 420–500, query 400–480, migrations 380–460,
   ops 420–500), exactly one H1 each.
4. Every fenced code block has a language tag (`sql`, `python`, `go`, `bash`, `prisma`, `ini`, `text`,
   `yaml`, `markdown`). No untagged fences. Run:
   `grep -rn '^```$' /Volumes/EXTERN/DEV/skills/skills/postgresdb` → must return nothing.
5. No placeholders/TODOs/`etc.`: `grep -rni 'TODO\|FIXME\|placeholder\|<your-\| etc\.' <skill dir>`
   returns nothing meaningful (the word "etc" must not appear as hand-waving).
6. Running example is consistent: only `orders`, `users`, `jobs` (+ `order_items`, `bookings`, `events`,
   `docs`, `inventory`, `tags`, `rooms`, `order_statuses` as supporting tables). No stray entity names.
7. SQL is engine-correct: `timestamptz` everywhere for events; `numeric(19,4)` for money;
   `GENERATED ALWAYS AS IDENTITY` not `serial`; FKs have explicit indexes; `CONCURRENTLY` used for
   live-table index DDL; `NOT EXISTS` not `NOT IN`; RLS uses `(SELECT current_setting(...))`.
8. Version deltas are explicit where claimed: PG11 (instant non-volatile default), PG12 (CTE inlining,
   cheap SET NOT NULL after validated CHECK), PG14 (`pg_read_all_data`, protocol prepared statements,
   PgBouncer), PG15 (`NULLS NOT DISTINCT`), and uuid v7 native only in PG18 (use extension on 16).
9. `scripts/verify.sh` starts with `#!/usr/bin/env bash` + `set -euo pipefail`, is executable
   (`test -x` true), skips missing tools with yellow `[skip]`, exits non-zero only on lint errors or
   unbalanced quotes/parens. Confirm executable:
   `test -x /Volumes/EXTERN/DEV/skills/skills/postgresdb/scripts/verify.sh && echo OK`.
   Do NOT run the script itself (wrong stack for this repo).
10. `bash -n /Volumes/EXTERN/DEV/skills/skills/postgresdb/scripts/verify.sh` parses clean (syntax only).
11. SKILL.md `## See Also` links to all 4 reference files (relative paths that resolve) and names
    sibling skills `prisma-patterns`, `database-migrations`, `risco-project-harness`.
12. Headings consistent: every reference uses `##`/`###` only (no second H1); tables render (header +
    separator rows present); Good/Bad blocks labeled in comments.
13. Cross-links between references use relative paths and resolve (e.g.
    `[migrations](references/migrations.md)` from SKILL.md; `../SKILL.md` if linked back).
14. Density bar: SKILL.md has no prose paragraph longer than 3 lines; content is tables + Good/Bad
    blocks + terse bullets. References are code-dense (every sub-section has at least one runnable block).
```
