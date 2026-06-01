# PostgreSQL operations & security

Running, securing, and monitoring PostgreSQL 16: least-privilege roles, row-level security,
connection pooling, vacuum, observability, partitioning, backups, and HA basics. Running example
tables: `orders`, `users`, `jobs`, `events`.

## Roles & least privilege

A role is a login role when it has `LOGIN`; group roles aggregate grants. The app connects as a role
that can do exactly its work and nothing more — never as a superuser, never as the schema owner in
normal traffic.

By default every user can create objects in `public` and execute functions there; lock it down first:

```sql
-- 1. close the open default on the public schema
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- 2. an application read/write role with only DML, no DDL, no superuser
CREATE ROLE app_rw LOGIN PASSWORD :'app_pw';
GRANT USAGE ON SCHEMA public TO app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_rw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_rw;

-- 3. make the grants apply to tables created LATER, too
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO app_rw;

-- 4. a read-only reporting / replica role (PG14+ predefined role reads every table)
CREATE ROLE reporter LOGIN PASSWORD :'rep_pw';
GRANT pg_read_all_data TO reporter;   -- PG14+: SELECT on all current and future tables
```

`ALTER DEFAULT PRIVILEGES` is keyed to the role that **creates** the object — run it as whichever role
owns the migrations, or the grants will silently not apply to new tables. The `:'app_pw'` form is a
`psql` variable; pass it with `psql -v app_pw=...` so the secret never lands in shell history.

## Row-Level Security

RLS filters rows per the connecting role. Two facts that bite everyone: it is **opt-in per table**
(disabled by default), and the **table owner bypasses every policy** unless you also `FORCE` it.

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders FORCE ROW LEVEL SECURITY;   -- owner is subject to policies too

CREATE POLICY tenant_isolation ON orders
    USING       (tenant_id = (SELECT current_setting('app.tenant_id', true)::bigint))
    WITH CHECK  (tenant_id = (SELECT current_setting('app.tenant_id', true)::bigint));

-- per request: scope the tenant for the duration of the transaction
SET LOCAL app.tenant_id = '42';   -- inside a txn; cleared at COMMIT
```

- `USING` filters which existing rows are **visible** (SELECT/UPDATE/DELETE); `WITH CHECK` constrains
  what **new/changed** rows may contain (INSERT/UPDATE). Set both or an insert can write a row the role
  cannot then read.
- Wrap the setting in `(SELECT current_setting(...))` so it is evaluated **once per statement**, not
  once per row — the single biggest RLS performance trap.
- `current_setting('app.tenant_id', true)` — the `true` means "missing → NULL" instead of erroring,
  so an unscoped connection sees zero rows (fail-closed).

Test as a non-owner role, or the owner bypass will make a broken policy look like it works:

```sql
SET ROLE app_rw;
SET app.tenant_id = '42';
SELECT count(*) FROM orders;   -- must equal only tenant 42's rows
RESET ROLE;
```

On Supabase the same pattern uses `auth.uid()`; still wrap it: `USING (user_id = (SELECT auth.uid()))`.

## Connection pooling

A PostgreSQL backend is a forked OS process (~5-10 MB RSS) with its own snapshot and caches, so
connections are expensive and `max_connections` should stay modest (a few hundred). Funnel the app
through a pooler.

**PgBouncer transaction mode** assigns a server connection only for the duration of a transaction —
the highest reuse, but with hard caveats:

- No session state across statements: `SET`/`SET search_path`, session-level `SET TIME ZONE`, and
  `LISTEN`/`NOTIFY` do not survive. Use `SET LOCAL` inside a transaction instead.
- **Session** advisory locks (`pg_advisory_lock`) leak across clients — use `pg_advisory_xact_lock`.
- Prepared statements need a driver using **protocol-level** prepared statements (libpq `PQprepare`,
  JDBC `PreparedStatement`, etc. — not text `PREPARE`) **and** PgBouncer ≥ 1.21 with
  `max_prepared_statements > 0`; older combinations error with "prepared statement already exists".
  (Protocol-level `DEALLOCATE`/close requires PG17+; before that PgBouncer cannot deallocate them.)

```ini
; pgbouncer.ini
[databases]
appdb = host=10.0.0.5 port=5432 dbname=appdb

[pgbouncer]
pool_mode = transaction
max_client_conn = 5000
default_pool_size = 20            ; server conns per (user,db); pool_size ~= cores * 2..4
max_prepared_statements = 200     ; >=1.21, enables protocol prepared statements in txn mode
server_idle_timeout = 600
```

Sizing: `default_pool_size ≈ cores × 2..4`; the **sum** of all app-side pool maxima must stay below the
server's `max_connections`. Serverless functions should set `connection_limit=1` per instance and rely
on the external pooler — set the `connection_limit=1` and `pgbouncer=true` `DATABASE_URL` parameters
per your client's documentation (e.g. Prisma's `?connection_limit=1&pgbouncer=true`).

## VACUUM & autovacuum

`VACUUM` reclaims dead tuples (left by every UPDATE/DELETE under MVCC), updates the visibility map
(enabling index-only scans), and freezes old transaction IDs to prevent wraparound. Autovacuum does
this automatically; tune it harder for hot tables instead of disabling it.

```sql
-- A high-churn table: vacuum sooner and let it work harder
ALTER TABLE jobs SET (
    autovacuum_vacuum_scale_factor = 0.02,   -- vacuum at 2% dead tuples, not the 20% default
    autovacuum_vacuum_cost_limit   = 2000    -- more I/O budget per round
);

-- Transaction-ID wraparound watch: if age() approaches ~2^31, the DB will force a shutdown to protect data
SELECT datname, age(datfrozenxid) AS xid_age
FROM pg_database ORDER BY xid_age DESC;
```

`VACUUM (ANALYZE) orders;` is the safe manual form — reclaims space and refreshes planner stats while
allowing reads and writes. `VACUUM FULL` rewrites the entire table under ACCESS EXCLUSIVE — never on a
live hot table; use `pg_repack` for online compaction.

## Monitoring

Enable `pg_stat_statements` (the single most useful extension) — it requires a preload and a restart:

```sql
-- postgresql.conf: shared_preload_libraries = 'pg_stat_statements'
--                  pg_stat_statements.track = top
-- then, once, after restart:
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

```sql
-- Worst total-time queries (where the time actually goes)
SELECT calls,
       round(mean_exec_time::numeric, 2)  AS mean_ms,
       round(total_exec_time::numeric, 2) AS total_ms,
       query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- Table/index activity: seq scans on big tables, dead tuples, unused indexes
SELECT relname, seq_scan, idx_scan, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables ORDER BY seq_scan DESC LIMIT 20;

SELECT relname, indexrelname, idx_scan
FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY relname;

-- Buffer cache hit ratio (aim > 0.99; sustained lower → undersized shared_buffers or cold working set)
SELECT sum(heap_blks_hit) / nullif(sum(heap_blks_hit + heap_blks_read), 0) AS cache_hit_ratio
FROM pg_statio_user_tables;

-- Who is blocking whom
SELECT blocked.pid AS blocked_pid, blocking.pid AS blocking_pid,
       blocked.query AS blocked_query, blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid AND NOT bl.granted
JOIN pg_locks gl ON gl.locktype = bl.locktype
  AND gl.database IS NOT DISTINCT FROM bl.database
  AND gl.relation IS NOT DISTINCT FROM bl.relation AND gl.granted
JOIN pg_stat_activity blocking ON blocking.pid = gl.pid;

-- Replication lag on the primary (seconds behind per standby)
SELECT client_addr, state, replay_lag FROM pg_stat_replication;
```

Set guardrails globally so a single runaway query or leaked transaction cannot take the cluster down:

```sql
ALTER SYSTEM SET statement_timeout = '30s';
ALTER SYSTEM SET idle_in_transaction_session_timeout = '60s';   -- kill txns that pin snapshots
SELECT pg_reload_conf();
```

## Declarative partitioning

Split one logical table into physical partitions by a key — almost always `RANGE` on a timestamp for
time-series. The win is fast bulk drop of old data (`DETACH` + `DROP`, no row-by-row delete) and
partition pruning that skips irrelevant partitions at plan time.

```sql
CREATE TABLE events (
    id         bigint GENERATED ALWAYS AS IDENTITY,
    created_at timestamptz NOT NULL,
    payload    jsonb NOT NULL
) PARTITION BY RANGE (created_at);

-- one partition per month
CREATE TABLE events_2026_06 PARTITION OF events
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE events_2026_07 PARTITION OF events
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

-- index on the parent propagates to all partitions (PG11+)
CREATE INDEX ix_events_created ON events (created_at);

-- drop a month of data instantly
ALTER TABLE events DETACH PARTITION events_2026_06;
DROP TABLE events_2026_06;
```

Note: the partition key must be part of the primary key / unique constraints. Automate partition
creation with `pg_partman` rather than hand-managing months. It **helps** for huge time-series with a
rolling retention window; it **hurts** small tables (pure overhead), queries that cannot prune (no
partition-key predicate), and schemas with thousands of partitions (planning slows). Do not partition
a table under ~10s of millions of rows.

## Backups & PITR

Two independent strategies — run both:

```bash
# Logical: portable, per-object, restorable to a different major version. Custom format + parallel.
pg_dump -Fc -j4 -f appdb.dump "$DATABASE_URL"
pg_restore -j4 -d "$TARGET_URL" appdb.dump          # parallel restore; -t orders for one table

# Physical base backup for point-in-time recovery
pg_basebackup -D /backups/base -Ft -z -P -h "$PGHOST" -U replicator
```

```ini
# postgresql.conf — continuous WAL archiving enables PITR
wal_level = replica
archive_mode = on
# ILLUSTRATIVE ONLY — do NOT ship this archive_command to production. Plain `cp` is not crash-safe:
# it does not fsync the archived file or its directory, so a crash mid-archive can silently corrupt or
# lose a WAL segment and break recovery. Use a tool that fsyncs and verifies — pgBackRest or wal-g
# (referenced below) — as the real archive_command.
archive_command = 'test ! -f /archive/%f && cp %p /archive/%f'
```

```ini
# recovery target on the restored cluster (postgresql.conf + standby.signal)
restore_command = 'cp /archive/%f %p'
recovery_target_time = '2026-06-01 09:30:00+00'
```

Test restores on a schedule — a backup you have never restored is a hypothesis, not a backup. For
production at scale use a purpose-built tool such as `pgBackRest` or `wal-g` (parallel, incremental,
encrypted, crash-safe archiving with retention and verify) instead of a hand-rolled `cp`-based
`archive_command`.

## HA basics

Streaming replication ships WAL from a primary to one or more standbys:

- **Async** (default): low write latency, but a standby may lag and a failover can lose the last few
  committed transactions.
- **Sync** (`synchronous_standby_names`): no data loss on failover, at the cost of write latency that
  depends on the slowest synchronous standby.

Read replicas offload SELECTs but lag behind the primary, so reads that must see a just-committed write
(read-after-write) must go to the primary; route only lag-tolerant reads to replicas. This is not a
deep HA guide — use **Patroni** (or a managed equivalent) for automated failover, leader election, and
fencing; configure it per its docs.
