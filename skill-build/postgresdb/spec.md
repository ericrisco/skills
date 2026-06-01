# DESIGN SPEC — skill `postgresdb`

Title: PostgreSQL — schema, indexing, queries, ops
Origin: risco. Target Postgres version: **16** (note 17 deltas where they matter).
Audience: an LLM coding agent working in a real repo (FastAPI/Python + SQLAlchemy 2.0, Next.js 15, Go 1.22+, Flutter, Postgres 16). Voice: directive, dense, copy-pasteable.

Calibration floor: ECC `postgres-patterns` (cheat-sheet only — we exceed depth), `database-migrations` (multi-ORM migrations — we match breadth, add expand-contract rigor + lock-mode tables), `prisma-patterns` (trap-density style — we match with PG-engine traps). ECC is the floor; this skill must be denser, version-pinned, and engine-correct.

---

## 1. Purpose & precise trigger

**Purpose (one line):** Engine-level PostgreSQL 16 guidance — design correct schemas, pick the right index, read EXPLAIN and fix slow SQL, run zero-downtime migrations, and operate/secure the database — tooling-agnostic but with concrete, runnable examples.

**`description` frontmatter (trigger-rich, starts with "Use when"):**
> Use when designing or reviewing a PostgreSQL schema (types, constraints, normalization), writing or optimizing SQL, choosing or adding indexes, reading EXPLAIN/ANALYZE, planning a migration (expand-contract, concurrent index, batched backfill), or operating/securing Postgres (roles, RLS, PgBouncer pooling, VACUUM/autovacuum, pg_stat_statements, declarative partitioning, backups/PITR). Triggers: "slow query", "add an index", "EXPLAIN", "design this table", "zero-downtime migration", "row level security", "connection pool", "N+1", "JSONB", "full-text search", "pgvector". PostgreSQL 16; ORM-agnostic (SQLAlchemy/Alembic, Prisma, golang-migrate, raw SQL).

**When to use:**
- Schema/DDL decisions: types, keys, constraints, generated/identity columns, enum-vs-lookup, jsonb-vs-column.
- Any query that is slow, scans too much, or returns wrong cardinality; reading a plan.
- Index decisions (which kind, column order, partial/covering, when NOT to).
- Migrations against tables with real data / live traffic.
- Concurrency questions: isolation, locking, deadlocks, queues.
- Ops: pooling, vacuum, monitoring, partitioning, backups, RLS, least-privilege roles.

**When NOT to use (delegate / out of scope):**
- ORM-API ergonomics (Prisma `updateMany` count trap, SQLAlchemy session lifecycle) → those live in `prisma-patterns` / a SQLAlchemy skill. This skill owns the **SQL the ORM emits and the engine behavior underneath**, not the ORM surface.
- Non-Postgres engines (MySQL/SQLite/ClickHouse) — different MVCC, locking, planner.
- App-layer caching, message queues as products (Redis/Kafka) — only Postgres-as-queue (`SKIP LOCKED`) is in scope.
- Cloud-vendor console clicks (RDS/Cloud SQL setup UI) — we give the SQL/params, not the console path.

---

## 2. SKILL.md outline (every H2/H3, with deliverable + code shown)

Target length: ~360–430 lines. One H1. Progressive disclosure: deep material pushed to `references/`.

### H1 `# PostgreSQL — schema, indexing, queries, ops`
One-line purpose under the title.

### `## When to use / When NOT to use`
Two tight bullet lists (from §1). Names the four reference files and what each owns.

### `## Non-negotiables` (the iron rules, 8–10 bullets)
Dense rules an agent must never violate. Delivers principles, no code:
- `timestamptz` always, never `timestamp` for events; store UTC.
- Money is `numeric`, never `float`/`double`.
- Every FK gets a covering index (Postgres does NOT auto-index FKs).
- `text` + `CHECK`, not `varchar(n)` as a length hack.
- Index creation on a live table is **always** `CONCURRENTLY` (and thus outside a txn).
- Never `ADD COLUMN ... NOT NULL` without a default plan; never volatile default on a huge table without batched backfill.
- Read the plan before adding an index; `EXPLAIN (ANALYZE, BUFFERS)` or it didn't happen.
- Migrations are forward-only in prod; never edit an applied migration.
- `SET lock_timeout` + `statement_timeout` around DDL on hot tables.
- RLS is opt-in per table and the table owner bypasses it — verify with a non-owner role.

### `## Decision rules` (decision tables — the heart of the entrypoint)
Several compact tables. Delivers fast lookups; code lives in references.

#### `### Pick the column type`
Table: use-case → correct type → avoid → why. Rows: surrogate key (`bigint GENERATED ALWAYS AS IDENTITY` vs `uuid v7`), natural text id, money (`numeric(19,4)`), timestamps (`timestamptz`), enum vs lookup table, small set of flags (`boolean`), tags (`text[]` vs join table), semi-structured (`jsonb`), IP (`inet`), ranges (`tstzrange`).

#### `### Pick the index`
Table extending ECC's cheat-sheet but correct and fuller: access pattern → index type → DDL snippet → notes. Rows: equality/range (btree), `LIKE 'prefix%'` (btree + `text_pattern_ops`), case-insensitive (expression index on `lower(col)` or `citext`), containment `@>`/jsonb/array (GIN), FTS (`GIN (to_tsvector(...))`), geo/exclusion overlap (GiST), huge append-only time-series (BRIN), embeddings (`hnsw`/pgvector), dedup-only (unique btree). Explicit "hash almost never".

#### `### When NOT to add an index`
Short bullet list: low-selectivity boolean, tiny tables, write-heavy + rarely-read columns, columns already covered as a left-prefix of an existing composite, redundant with a unique constraint.

### `## Copy-paste patterns` (Good/Bad, runnable SQL — the dense core)
Each is a labeled block with a one-line "why". Examples shown:

#### `### Canonical table (types + constraints + identity)`
Full `CREATE TABLE` for an `orders` table: `id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`, `public_id uuid DEFAULT gen_random_uuid()` (uuidv7 note), FK with `ON DELETE`, `amount numeric(19,4) CHECK (amount >= 0)`, `status` via lookup FK, `created_at timestamptz DEFAULT now()`, generated column `search tsvector GENERATED ALWAYS AS (...) STORED`, `updated_at` trigger note. Good vs Bad (Bad = `varchar(255)`, `timestamp`, `float`, serial).

#### `### Composite index column order`
Equality-then-range rule with EXPLAIN-backed example; show the wrong order failing to be used.

#### `### Partial + covering (INCLUDE) index`
`CREATE INDEX ... WHERE deleted_at IS NULL` and `INCLUDE (cols)` for index-only scan; one line on how to confirm index-only scan in the plan (`Heap Fetches: 0`).

#### `### Keyset (cursor) pagination — not OFFSET`
Composite-key keyset on `(created_at, id)` with the row-value comparator `(created_at, id) < ($1, $2)`; Bad = `OFFSET 100000`. Note matching index requirement.

#### `### UPSERT done right`
`INSERT ... ON CONFLICT (...) DO UPDATE SET ... = EXCLUDED.*` with `WHERE` guard; note `DO NOTHING` returns nothing (use CTE to get the row).

#### `### Queue with SKIP LOCKED`
`SELECT ... FOR UPDATE SKIP LOCKED` inside an `UPDATE ... RETURNING` CTE — correct, contention-free job claim.

#### `### Kill the N+1`
Bad = per-row lookup loop; Good = single set-based query / `JOIN LATERAL` for top-N-per-group; one line: "the ORM emitting N queries is the same bug — fix at the SQL boundary."

#### `### EXPLAIN, the right way`
The command `EXPLAIN (ANALYZE, BUFFERS, SETTINGS, FORMAT TEXT)`; the 4 things to read first (estimated-vs-actual rows, the most expensive node, Seq Scan on a big table, Rows Removed by Filter). Pointer to `query-optimization.md`.

### `## Anti-patterns / rationalizations → STOP`
Table (excuse → reality), prisma-patterns style, PG-specific. Rows:
- "I'll add the index later, query works now" → unindexed FK = lock + seq-scan cascade on delete.
- "`UUID` PK is fine everywhere" → random uuidv4 fragments the btree; use identity or uuidv7.
- "`SELECT count(*)` to check existence" → use `EXISTS`.
- "CTEs are just readability" → pre-12 they were optimization fences; in 16 they inline unless `MATERIALIZED` — know which you want.
- "`NOT IN (subquery)`" → NULL-unsafe + slow; use `NOT EXISTS`.
- "Store money as float, round later" → silent drift; `numeric`.
- "`ADD COLUMN NOT NULL DEFAULT now()`" → volatile default rewrites the table; non-volatile is instant (PG 11+).
- "One big `jsonb` blob instead of columns" → no constraints, no stats, GIN bloat; promote hot keys to columns.
- "RLS policy with a function call per row" → wrap `auth.uid()` in a scalar subquery so it's evaluated once.
- "`CREATE INDEX` in the migration is fine" → blocks writes; `CONCURRENTLY`.

### `## Quick reference` (consolidated cheat tables)
- Isolation levels: RC / RR / Serializable → what each prevents, when to use, retry-on-40001 note.
- Lock modes triggered by common DDL (ACCESS EXCLUSIVE vs SHARE UPDATE EXCLUSIVE) — pointer to ops file for full table.
- Diagnostic one-liners (correct, copy-paste): unindexed FKs, top slow queries from `pg_stat_statements`, bloat/dead tuples, blocking-locks query, cache hit ratio, unused indexes.

### `## Verify`
One paragraph: run `scripts/verify.sh` from the project root; what it checks (sqlfluff lint, SQL parse of migrations, pg_stat_statements guidance); that it skips missing tools rather than failing.

### `## See Also`
Links: `references/schema-and-indexing.md`, `references/query-optimization.md`, `references/migrations.md`, `references/operations-and-security.md`; sibling skills `prisma-patterns`, `database-migrations`, `risco-project-harness` (the `01-TOOLS/POSTGRES` operational tool).

---

## 3. references/ files — outline + key code

### `references/schema-and-indexing.md` (~420–480 lines)
Owns: types, constraints, normalization decisions, every index kind, bloat.

- **`## Naming conventions`** — snake_case, plural tables, `pk_/fk_/uq_/ix_/ck_` index prefixes, `<table>_<cols>_idx` pattern; no reserved words.
- **`## Types, in depth`** — subsections:
  - Surrogate keys: `bigint GENERATED ALWAYS AS IDENTITY` (why over `serial`); uuid v7 (`gen_random_uuid()` is v4; show an SQL/extension path for v7 and the index-fragmentation argument).
  - Time: `timestamptz` semantics (stored as UTC instant, not a zone), `interval`, never naive `timestamp`.
  - Numbers/money: `numeric(19,4)`, `bigint` for counters, when `double precision` is acceptable (science, not money).
  - Text: `text` + `CHECK (length(...))`, `citext` for case-insensitive, `varchar(n)` only when an external contract demands it.
  - Enum vs lookup table: trade-offs table (ALTER TYPE ADD VALUE can't run in a txn pre-considerations; lookup tables give FK + joins + soft retire). Recommend lookup table for evolving sets.
  - Arrays vs jsonb vs join table: decision rules + GIN indexing each.
- **`## Constraints`** — PK, FK with all `ON DELETE`/`ON UPDATE` actions and `DEFERRABLE INITIALLY DEFERRED`, `UNIQUE` (incl. `NULLS NOT DISTINCT` in PG15+), `CHECK`, `EXCLUDE USING gist (... WITH &&)` for no-overlap booking example with `tstzrange` + `btree_gist`. `NOT VALID` + `VALIDATE CONSTRAINT` two-step for adding constraints without long locks.
- **`## Generated & identity columns`** — `GENERATED ALWAYS AS (expr) STORED`; identity vs serial; `OVERRIDING SYSTEM VALUE`.
- **`## Normalization & deliberate denormalization`** — 3NF default; when to denormalize (read-heavy aggregates, counters via trigger or `GENERATED`), materialized views (`REFRESH ... CONCURRENTLY` needs a unique index).
- **`## Indexing deep dive`** — per access method with runnable DDL + when:
  - btree (default; multicolumn order; `text_pattern_ops` for `LIKE 'x%'`; `DESC`/`NULLS LAST` ordered indexes for matching ORDER BY).
  - GIN (jsonb `jsonb_path_ops` vs default opclass; arrays; FTS; `fastupdate`/`gin_pending_list_limit` note).
  - GiST (ranges, exclusion, geometry/PostGIS pointer).
  - BRIN (append-only time-series; `pages_per_range`; correlation requirement).
  - Hash (rarely; equality-only, now WAL-logged since PG10 — still seldom worth it).
  - Partial, expression, covering (`INCLUDE`), unique-partial as a conditional uniqueness trick.
  - Index-only scans: visibility map, `VACUUM` dependency, `Heap Fetches`.
- **`## Bloat & maintenance`** — `pg_stat_user_indexes` unused-index query, `REINDEX INDEX CONCURRENTLY`, `pgstattuple`, when bloat matters; never `VACUUM FULL` on a live hot table (ACCESS EXCLUSIVE).

### `references/query-optimization.md` (~400–460 lines)
Owns: reading plans, fixing SQL, concurrency, JSONB/FTS/pgvector.

- **`## Reading EXPLAIN`** — annotated real `EXPLAIN (ANALYZE, BUFFERS)` output; how to read estimated-vs-actual divergence (stale stats → `ANALYZE`), `Rows Removed by Filter`, `Buffers: shared hit/read`, `Heap Fetches`, loops × per-loop cost. `auto_explain` for prod.
- **`## Scan & join strategies`** — seq vs index vs index-only vs bitmap heap scan (when each is correct, not always-bad); nested loop vs hash vs merge join and what forces a bad one (missing index, bad estimate, `work_mem` too low → disk sort/spill).
- **`## CTEs: materialized vs inlined`** — PG12+ inlines by default; `MATERIALIZED` to force a fence (and when that helps: expensive CTE referenced once, or to defeat a bad plan); `NOT MATERIALIZED`.
- **`## Window functions & LATERAL`** — running totals, dedup with `row_number()`, top-N-per-group via `JOIN LATERAL (... LIMIT n)` — the canonical fast pattern with supporting index.
- **`## Pagination`** — keyset full pattern (multi-column, stable sort), why OFFSET is O(n), how to paginate with a covering index for index-only scan.
- **`## Set-based thinking / killing N+1`** — rewrite loop→single query; bulk upsert from `unnest($1,$2)` arrays; `INSERT ... SELECT`.
- **`## Transactions & concurrency`** —
  - Isolation table (RC default, RR snapshot, Serializable/SSI) + the `40001`/`40P01` retry loop (show a Python/psycopg retry wrapper and a Go `pgx` retry).
  - MVCC one-paragraph mental model (tuple versions, xmin/xmax, why long txns block vacuum).
  - Locking: row locks (`FOR UPDATE`/`FOR NO KEY UPDATE`/`FOR SHARE`), `SKIP LOCKED`, `NOWAIT`; lock ordering to avoid deadlocks; `lock_timeout`.
  - Advisory locks (`pg_advisory_xact_lock`) for app-level mutual exclusion (singleton cron, leader election) — and their footguns with PgBouncer transaction pooling.
- **`## JSONB`** — operators (`->`, `->>`, `@>`, `?`, `#>>`, `jsonb_path_query`), GIN indexing choice, expression index on a hot extracted key, when to promote to a column.
- **`## Full-text search`** — `tsvector`/`tsquery`, `websearch_to_tsquery`, generated `tsvector` column + GIN, ranking (`ts_rank_cd`), `unaccent`; when to reach for pgvector/trigram (`pg_trgm` for fuzzy/`ILIKE`).
- **`## pgvector`** — `vector(1536)` column, `hnsw` vs `ivfflat` index (build/recall/latency trade-off), `<=>`/`<->`/`<#>` operators, `SET hnsw.ef_search`, hybrid search (FTS + vector) pattern, filtering caveat (pre/post-filter).

### `references/migrations.md` (~380–440 lines)
Owns: zero-downtime DDL across tools. Match ECC `database-migrations` breadth, exceed on safety rigor.

- **`## Principles`** — forward-only in prod; DDL and DML in separate migrations; immutable once applied; test against prod-sized data; wrap risky DDL in `SET lock_timeout='3s'; SET statement_timeout='...';`.
- **`## Lock-impact reference`** — table: operation → lock acquired → blocks reads? writes? → safe variant. (ADD COLUMN nullable = metadata-only; ADD COLUMN with volatile default = rewrite; ALTER TYPE = rewrite; ADD CHECK = full scan vs `NOT VALID`; CREATE INDEX vs CONCURRENTLY; SET NOT NULL vs CHECK-then-promote.)
- **`## Expand–contract (zero-downtime)`** — full lifecycle for rename column, change type, split/merge column; phase diagram (expand → dual-write/backfill → migrate-reads → contract) with the app-deploy interleaving.
- **`## Safe recipes (raw SQL)`** —
  - Add column: nullable, then backfill batched, then `SET NOT NULL` via `ADD CONSTRAINT ... CHECK (col IS NOT NULL) NOT VALID` → `VALIDATE` → `SET NOT NULL` (cheap in PG12+ once a validated CHECK exists).
  - Add index: `CREATE INDEX CONCURRENTLY` (+ how to detect/`DROP` an `INVALID` leftover index).
  - Add FK without long lock: `... NOT VALID` then `VALIDATE CONSTRAINT`.
  - Change type without rewrite where possible; otherwise expand-contract.
  - Drop column: code-first, then drop.
  - Batched backfill: the `DO $$ ... LIMIT ... ; COMMIT` loop (correct, with `FOR UPDATE SKIP LOCKED` or a keyset cursor, autovacuum-friendly).
- **`## Per-tool concrete examples`** — same change ("add `avatar_url` + concurrent index + backfill `display_name`") expressed in:
  - **plain SQL** (`*.up.sql`/`*.down.sql`).
  - **golang-migrate** — file pair; the `CONCURRENTLY` caveat (no txn): use `-- +migrate NoTransaction` style / split file; `force` to clear dirty state.
  - **Alembic (SQLAlchemy 2.0, Python 3.12)** — `op.add_column`, `op.create_index(..., postgresql_concurrently=True)` + `with op.get_context().autocommit_block():`, `op.execute()` for batched backfill, `op.create_check_constraint` NOT VALID.
  - **Prisma** — `migrate dev --create-only` then hand-edit SQL for `CONCURRENTLY`; `migrate deploy` in CI; checksum-immutability warning; pointer to `prisma-patterns`.
- **`## Rollback reality`** — down-migrations are best-effort; data-destructive forward changes aren't reversible; backup/snapshot before contract phase.

### `references/operations-and-security.md` (~420–480 lines)
Owns: roles, RLS, pooling, vacuum, monitoring, partitioning, backups, HA.

- **`## Roles & least privilege`** — role vs login role; `REVOKE ALL ON SCHEMA public FROM PUBLIC`; per-app role with only needed grants; `DEFAULT PRIVILEGES`; read-only reporting role; never app-as-superuser; `GRANT pg_read_all_data` (PG14+) for read replicas/analytics.
- **`## Row-Level Security`** — `ENABLE ROW LEVEL SECURITY` + `FORCE` (owner bypass!); `CREATE POLICY` for tenant isolation; the `(SELECT current_setting('app.tenant_id'))` per-statement-eval optimization; `USING` vs `WITH CHECK`; testing as a non-owner role; multi-tenant SaaS template + Supabase `auth.uid()` note.
- **`## Connection pooling`** — why PG connections are expensive (process-per-conn); PgBouncer **transaction mode** and its hard caveats (no session-level `SET`, prepared statements need care — PG14 protocol-level + PgBouncer 1.21+ `max_prepared_statements`; advisory session locks unusable; `SET search_path` per session breaks); sizing formula (`pool_size ≈ cores × 2..4`, app pool ≤ server `max_connections`); Prisma/serverless `connection_limit=1` cross-link.
- **`## VACUUM & autovacuum`** — what VACUUM does (dead tuples, freeze, visibility map); autovacuum tuning per-table (`autovacuum_vacuum_scale_factor`, `..._cost_limit`) for hot tables; transaction-ID wraparound danger + `age(datfrozenxid)` monitor; `VACUUM (ANALYZE)` vs `VACUUM FULL` (never on live).
- **`## Monitoring`** — `pg_stat_statements` setup (`shared_preload_libraries`, `track`), the top-queries query, `pg_stat_user_tables`/`_indexes`, blocking-lock query joining `pg_locks`+`pg_stat_activity`, cache hit ratio, replication lag; `statement_timeout`/`idle_in_transaction_session_timeout` as guardrails.
- **`## Declarative partitioning`** — `PARTITION BY RANGE (created_at)` monthly time-series example; attach/detach; `CREATE INDEX` per partition; `pg_partman` pointer; when partitioning helps (huge time-series, drop-old-fast) and when it hurts (small tables, cross-partition queries, too many partitions).
- **`## Backups & PITR`** — logical `pg_dump`/`pg_restore` (custom format, parallel `-j`) vs physical `pg_basebackup` + WAL archiving for PITR (`archive_command`, `recovery_target_time`); test restores; `pgBackRest` pointer.
- **`## HA basics`** — streaming replication (sync vs async), read replicas + replica lag implications for read-after-write, failover tools (Patroni) pointer; not a deep HA guide — link out.

---

## 4. verify.sh contract

Path: `skills/postgresdb/scripts/verify.sh`. `chmod +x`. NOT executed in this repo (wrong stack).

- Header: `#!/usr/bin/env bash` then `set -euo pipefail`. Top usage comment: run from the project root; what it does; that it is read-only and never connects to a DB unless `DATABASE_URL` is set.
- Color helpers: `warn()` prints yellow `[skip]`, `ok()` green, `err()` red. Track an `EXIT=0`; set `EXIT=1` only on real failures.
- **Tool/Check order:**
  1. **sqlfluff lint** — if `command -v sqlfluff` AND a `.sqlfluff` config exists in the repo: run `sqlfluff lint` over discovered SQL/migration dirs (`migrations/`, `db/migrations/`, `prisma/migrations/`, `alembic/versions/`, `**/*.sql`). Lint errors → `EXIT=1`. If `sqlfluff` missing OR no `.sqlfluff` → `warn` and skip (no failure).
  2. **Basic SQL parse check of migration files** — for every discovered `*.sql`, do a dependency-light syntax sanity check. Prefer `pg_format` (pgFormatter) if present as a parse proxy; else if `psql` present, dry-parse via `psql -X --set ON_ERROR_STOP=1 -c "..."` is unsafe (executes) → instead do a lightweight check: balanced parens/quotes and that each statement ends with `;`, and flag obvious foot-guns (a bare `CREATE INDEX` without `CONCURRENTLY` in a file whose name suggests a migration, a `ADD COLUMN ... NOT NULL` with no `DEFAULT`, `VACUUM FULL`). Report as warnings (advisory), only fail on unbalanced quotes/parens (real parse breakage). If no SQL files found → `warn` skip.
  3. **pg_stat_statements guidance** — never connects unless `DATABASE_URL` set AND `psql` present. If both: run `SELECT 1 FROM pg_extension WHERE extname='pg_stat_statements'`; if absent, print guidance (how to enable). If `DATABASE_URL` unset or `psql` missing → print the guidance text and `warn` skip. Connection failure → `warn`, not `err` (the verify gate must not fail because a dev DB is down).
- **Exit:** `exit "$EXIT"` — non-zero only on (a) sqlfluff lint errors, or (b) unbalanced quotes/parens in a SQL file. Everything else is advisory/skip. Idempotent; no writes.

---

## 5. Quality differentiators (why this beats the ECC equivalents)

1. **Version-pinned to Postgres 16** with explicit 11/12/14/15 behavior deltas (instant non-volatile defaults, CTE inlining, `NULLS NOT DISTINCT`, `pg_read_all_data`, protocol-level prepared statements) — ECC `postgres-patterns` is version-agnostic and partly Supabase-flavored.
2. **Engine-correctness over cheat-sheet shallowness:** corrects common myths ECC leaves implicit — seq scans aren't always bad, hash indexes are usually wrong, CTEs are no longer optimization fences, `NOT IN` vs `NOT EXISTS`, volatile-vs-stable default rewrite rule.
3. **A real lock-impact table** mapping each DDL to the lock it takes and the safe variant (`NOT VALID`→`VALIDATE`, `CHECK`→`SET NOT NULL`) — ECC's migration skill lists patterns but never the lock modes that make them necessary.
4. **EXPLAIN literacy as a first-class section** with annotated `(ANALYZE, BUFFERS)` output and a "read these four things first" method — absent from all three ECC skills.
5. **Clean ORM boundary:** explicitly defers ORM-surface traps to `prisma-patterns`/SQLAlchemy and owns only the emitted SQL + engine behavior — no overlap, no contradiction, with cross-links both ways.
6. **PgBouncer transaction-mode caveats stated precisely** (prepared statements with PgBouncer 1.21+/PG14 protocol, session `SET` and advisory-lock incompatibility, sizing formula) — the single biggest prod footgun, hand-waved by ECC.
7. **pgvector + hybrid (FTS+vector) search** with hnsw/ivfflat trade-offs and filtering caveats — current and directly relevant to the user's AI stack; not in any ECC skill.
8. **Runnable verify.sh that never connects without consent and never hard-fails on a missing tool or down DB** — a real gate, not theater.

---

## Notes for the build step
- Keep SKILL.md skimmable: tables + Good/Bad blocks, no prose paragraphs > 3 lines.
- Every fenced block tagged (`sql`, `python`, `go`, `bash`, `prisma`, `text`).
- No "etc.", no TODO, no placeholder identifiers — use the `orders`/`users`/`jobs` running example consistently across files.
- Cross-link references with relative paths; cross-link sibling skills by name.
