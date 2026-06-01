# PostgreSQL schema & indexing

Deep dive on types, constraints, normalization, and every index access method on PostgreSQL 16.
Running example tables: `orders`, `users`, `jobs` (+ `order_items`, `bookings`, `events`, `docs`,
`order_statuses`, `rooms`).

## Naming conventions

- `snake_case` for everything; plural table names (`orders`, `users`, `jobs`).
- Index/constraint prefixes: `pk_` (primary key), `fk_` (foreign key), `uq_` (unique), `ix_` (plain
  index), `ck_` (check). Use the `ix_<table>_<cols>` form and be consistent — this skill uses `ix_`.
- Avoid reserved words as identifiers (`user`, `order` require quoting forever) — use `users`, `orders`.
- Always name constraints explicitly so error messages and migrations are stable:

```sql
ALTER TABLE orders
    ADD CONSTRAINT ck_orders_amount_nonneg CHECK (amount >= 0);
```

## Types, in depth

### Surrogate keys

Prefer identity over `serial`. `serial` is sugar for an owned sequence; it leaks sequence-ownership
edge cases (you can `GRANT`/`REVOKE` the sequence separately, dumps can desync the `OWNED BY`, and an
explicit insert into the column silently consumes nothing). Identity is SQL-standard and the column
is protected.

```sql
-- GOOD: protected identity. An explicit insert is rejected unless you opt in.
CREATE TABLE users (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email text NOT NULL
);
-- Data-migration escape hatch when you must preserve old ids:
INSERT INTO users (id, email) OVERRIDING SYSTEM VALUE VALUES (42, 'a@b.co');
```

For public/distributed ids use a time-ordered UUID (v7). Native `gen_random_uuid()` returns **v4
(random)**, which scatters inserts across the B-tree, causing page splits and WAL amplification on
high-write tables. PostgreSQL gains a native `uuidv7()` only in **PG18**; on PG16 use the `pg_uuidv7`
extension or generate v7 in the application.

```sql
-- PG16: native gen_random_uuid() is v4 (random). For time-ordered keys:
CREATE EXTENSION IF NOT EXISTS pg_uuidv7;   -- provides uuid_generate_v7()
ALTER TABLE orders ALTER COLUMN public_id SET DEFAULT uuid_generate_v7();
```

### Time

`timestamptz` stores a UTC instant — it does **not** store a zone. On input the session `TimeZone`
converts to UTC; on output it converts back. Naive `timestamp` records wall-clock with no instant, so
the same value means different moments in different sessions. Always use `timestamptz` for events.

```sql
-- Store the instant; convert only for display.
SELECT created_at AT TIME ZONE 'Europe/Madrid' AS local_wall_clock FROM orders;
-- Durations are first-class:
SELECT now() - created_at AS age, interval '15 minutes' AS sla FROM orders;
```

### Numbers / money

```sql
-- Exact decimal for anything that must add up. 19 digits, 4 fractional.
amount   numeric(19,4) NOT NULL CHECK (amount >= 0),
-- Counters: bigint, not int (2.1B is reachable).
view_count bigint NOT NULL DEFAULT 0,
```

`double precision` is fine for scientific magnitudes where relative error is acceptable; never for
money — binary floats cannot represent `0.10` exactly and drift across arithmetic.

### Text

```sql
-- Length as a CHECK on text: no rewrite needed to relax it later.
email text NOT NULL CHECK (length(email) <= 320),
```

`citext` (extension) gives case-insensitive equality/uniqueness without rewriting every query with
`lower()`. Use `varchar(n)` only when an external contract mandates a hard byte limit.

```sql
CREATE EXTENSION IF NOT EXISTS citext;
ALTER TABLE users ALTER COLUMN email TYPE citext;   -- 'A@B.co' = 'a@b.co'
```

### Enum vs lookup table

| Aspect | `enum` type | lookup table + FK |
| --- | --- | --- |
| Add a value | `ALTER TYPE ... ADD VALUE` (cannot be used in same txn before commit) | `INSERT` row |
| Remove a value | not supported (must recreate the type) | `UPDATE active = false` (soft retire) |
| Joins to metadata | none | natural `JOIN` |
| FK integrity | implicit (the type) | explicit `REFERENCES` |
| i18n / labels | none | extra columns |
| Ordering | declaration order | a `sort_order` column |

```sql
-- enum: stable, tiny, closed set
CREATE TYPE order_kind AS ENUM ('standard', 'rush', 'gift');

-- lookup table: evolving set, joinable, soft-retire (recommended for status)
CREATE TABLE order_statuses (
    code       text PRIMARY KEY,
    label      text NOT NULL,
    is_active  boolean NOT NULL DEFAULT true,
    sort_order int  NOT NULL DEFAULT 0
);
ALTER TABLE orders
    ADD CONSTRAINT fk_orders_status
    FOREIGN KEY (status) REFERENCES order_statuses (code);
```

Recommend the lookup table for any set that will grow. `ALTER TYPE ... ADD VALUE` cannot run inside a
transaction block before the new value is committed, and an enum value can never be removed.

### Arrays vs jsonb vs join table

- `text[]` + GIN: read-mostly tag lists with containment queries; no per-tag FK.
- `jsonb` + GIN: heterogeneous semi-structured attributes; promote hot keys to columns later.
- Join table: when you need FK integrity, per-tag rows, or tag-level metadata.

```sql
-- array of tags + containment index
ALTER TABLE orders ADD COLUMN tags text[] NOT NULL DEFAULT '{}';
CREATE INDEX ix_orders_tags ON orders USING gin (tags);          -- WHERE tags @> ARRAY['vip']

-- jsonb attributes; jsonb_path_ops is smaller when you only use @>
ALTER TABLE orders ADD COLUMN meta jsonb NOT NULL DEFAULT '{}';
CREATE INDEX ix_orders_meta ON orders USING gin (meta jsonb_path_ops);
```

## Constraints

### Primary keys

```sql
-- single-column surrogate PK (preferred)
id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
-- composite natural PK for a join table
CREATE TABLE order_tags (
    order_id bigint NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    tag      text   NOT NULL,
    PRIMARY KEY (order_id, tag)
);
```

### Foreign keys

| `ON DELETE` action | Effect on child | Use when |
| --- | --- | --- |
| `NO ACTION` (default) | error if children exist (checked at stmt/txn end) | default; defer checks |
| `RESTRICT` | error immediately, cannot defer | block deletes hard |
| `CASCADE` | delete children too | owned children (order_items) |
| `SET NULL` | child FK → NULL | optional parent |
| `SET DEFAULT` | child FK → its default | rare; default must exist |

```sql
-- owned child cascades; optional reference nulls out
ALTER TABLE order_items
    ADD CONSTRAINT fk_items_order
    FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE;

-- circular or bulk-load FKs: defer the check to COMMIT
ALTER TABLE orders
    ADD CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users (id)
    DEFERRABLE INITIALLY DEFERRED;
```

Index every FK child column — Postgres does not, and a parent `DELETE`/`UPDATE` must scan the child to
enforce the constraint:

```sql
CREATE INDEX ix_order_items_order_id ON order_items (order_id);
```

### Unique

```sql
-- standard unique
ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);

-- PG15+: treat multiple NULLs as colliding (one active row per (a) where b IS NULL)
CREATE UNIQUE INDEX uq_orders_pubid ON orders (public_id) NULLS NOT DISTINCT;
```

### Check (named)

```sql
ALTER TABLE orders
    ADD CONSTRAINT ck_orders_currency_iso CHECK (length(currency) = 3);
```

### Exclusion constraint (no-overlap booking)

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;   -- lets = and && share one GiST index
CREATE TABLE bookings (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_id   bigint NOT NULL REFERENCES rooms (id),
    during    tstzrange NOT NULL,
    EXCLUDE USING gist (room_id WITH =, during WITH &&)   -- no two overlapping ranges per room
);
```

### NOT VALID then VALIDATE (avoid the long lock)

Adding a `CHECK` or FK normally scans the whole table under a heavy lock. Split it: add `NOT VALID`
(no scan, brief lock), then `VALIDATE` (scans under SHARE UPDATE EXCLUSIVE, allowing reads and writes).

```sql
ALTER TABLE orders ADD CONSTRAINT ck_orders_amount_nonneg
    CHECK (amount >= 0) NOT VALID;       -- new rows checked, existing rows not scanned
ALTER TABLE orders VALIDATE CONSTRAINT ck_orders_amount_nonneg;   -- scans, light lock
```

## Generated & identity columns

```sql
-- STORED generated column: maintained by the engine, indexable.
search tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce(note, ''))) STORED,
CREATE INDEX ix_orders_search ON orders USING gin (search);
```

Notes: PG16 supports only `STORED` generated columns (the value is materialized and re-computed on
write); `VIRTUAL` generated columns arrive in PG18. Identity columns differ from `serial` in that
`GENERATED ALWAYS` rejects explicit values unless you write `OVERRIDING SYSTEM VALUE` — useful exactly
once, during a data migration that must preserve old ids.

## Normalization & deliberate denormalization

Default to 3NF: one fact in one place, referenced by FK. Denormalize only with a maintenance plan:

- Read-heavy aggregates: a counter column kept fresh by a trigger.
- Derived values: a `GENERATED ALWAYS AS (...) STORED` column (always correct, no trigger).
- Expensive reporting rollups: a materialized view refreshed off the hot path.

```sql
-- Trigger-maintained counter on users.order_count
CREATE FUNCTION bump_order_count() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE users SET order_count = order_count + 1 WHERE id = NEW.user_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE users SET order_count = order_count - 1 WHERE id = OLD.user_id;
    END IF;
    RETURN NULL;
END $$;
CREATE TRIGGER trg_orders_count
    AFTER INSERT OR DELETE ON orders
    FOR EACH ROW EXECUTE FUNCTION bump_order_count();
```

```sql
-- Materialized view; REFRESH CONCURRENTLY requires a UNIQUE index on the MV.
CREATE MATERIALIZED VIEW order_daily AS
    SELECT user_id, date_trunc('day', created_at) AS day, sum(amount) AS total
    FROM orders GROUP BY 1, 2;
CREATE UNIQUE INDEX uq_order_daily ON order_daily (user_id, day);
REFRESH MATERIALIZED VIEW CONCURRENTLY order_daily;   -- no read lock; needs the unique index
```

The `updated_at` column has no native `ON UPDATE`; maintain it with a trigger:

```sql
CREATE FUNCTION set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;
CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

## Indexing deep dive

### btree (default)

Handles `=`, `<`, `>`, `BETWEEN`, `IN`, prefix `LIKE`, `ORDER BY`, and uniqueness. Multicolumn order:
**equality columns first, then the range/sort column** — the index is only usable left-to-right.

```sql
-- equality then range; matches WHERE user_id = $1 AND created_at >= $2 ORDER BY created_at DESC
CREATE INDEX ix_orders_user_created ON orders (user_id, created_at DESC);

-- prefix LIKE in a non-C locale needs text_pattern_ops
CREATE INDEX ix_users_email_pat ON users (email text_pattern_ops);   -- WHERE email LIKE 'foo%'

-- match an ORDER BY with NULLS LAST so the scan needs no sort node
CREATE INDEX ix_orders_created ON orders (created_at DESC NULLS LAST);
```

### GIN

For containment and full-text. Default `jsonb_ops` indexes every key/value and supports `@>`, `?`,
`?|`, `?&`; `jsonb_path_ops` is smaller and faster but supports only `@>`.

```sql
CREATE INDEX ix_orders_meta_full ON orders USING gin (meta);                 -- all operators
CREATE INDEX ix_orders_meta_path ON orders USING gin (meta jsonb_path_ops);  -- @> only, smaller
```

GIN buffers inserts in a pending list (`fastupdate = on`); a huge `gin_pending_list_limit` speeds
bulk loads but slows reads until merged. Lower it for read-latency-sensitive tables, or
`fastupdate = off`.

### GiST

Ranges, exclusion constraints, nearest-neighbor, and PostGIS geometry.

```sql
CREATE INDEX ix_bookings_during ON bookings USING gist (during);   -- && overlap, @> contains
-- geo: CREATE INDEX ... USING gist (geom);  (see PostGIS docs)
```

### BRIN

Tiny block-range index for huge append-only tables where physical order correlates with the column
(insert order ≈ `created_at`). Costs almost nothing to maintain; gives big gains on range scans.

```sql
CREATE INDEX ix_events_ts ON events USING brin (created_at) WITH (pages_per_range = 64);
```

If rows are not physically correlated (random insert order, heavy updates), BRIN degrades to scanning
everything — use btree instead.

### Hash

Equality-only, no multicolumn, no ordering, no uniqueness. WAL-logged since PG10 but still rarely beats
btree; reach for it only for very wide keys where btree size matters, after measuring.

```sql
CREATE INDEX ix_jobs_dedup_hash ON jobs USING hash (dedup_key);   -- = only
```

### Partial, expression, covering

```sql
-- partial: index only the hot subset
CREATE INDEX ix_jobs_pending ON jobs (created_at) WHERE status = 'pending';

-- expression: must match the query expression exactly
CREATE INDEX ix_users_lower_email ON users (lower(email));   -- WHERE lower(email) = $1

-- covering: INCLUDE payload columns for index-only scans
CREATE INDEX ix_orders_user_cover ON orders (user_id) INCLUDE (amount, created_at);

-- conditional uniqueness: one active row per email, ignoring soft-deleted rows
CREATE UNIQUE INDEX uq_users_email_active ON users (email) WHERE deleted_at IS NULL;
```

### Index-only scans

The planner can answer entirely from the index when all selected columns are in the index (key or
`INCLUDE`) **and** the visibility map marks the pages all-visible. Stale visibility forces heap
fetches. Confirm with `EXPLAIN (ANALYZE)` → `Heap Fetches: 0`; if non-zero, `VACUUM` the table to
refresh the visibility map.

## Bloat & maintenance

Updates and deletes leave dead tuples; autovacuum reclaims them but indexes can still bloat.

```sql
-- Unused indexes (drop after confirming across a full traffic cycle)
SELECT relname, indexrelname, idx_scan
FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY relname;

-- Measure real bloat for a suspect index/table
CREATE EXTENSION IF NOT EXISTS pgstattuple;
SELECT * FROM pgstattuple('ix_orders_user_created');

-- Rebuild an index without blocking writes
REINDEX INDEX CONCURRENTLY ix_orders_user_created;
```

Never run `VACUUM FULL` on a live hot table — it takes ACCESS EXCLUSIVE and rewrites the whole table,
blocking all reads and writes. For online table compaction use `pg_repack` (extension + CLI), which
rebuilds the table in the background and swaps it in with only a brief lock.
