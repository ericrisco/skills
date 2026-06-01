# PostgreSQL zero-downtime migrations

Safe DDL against tables with real data and live traffic, on PostgreSQL 16, across raw SQL,
golang-migrate, Alembic, and Prisma. Running example: add `avatar_url` to `users`, index it
concurrently, backfill `display_name`.

> Using Drizzle, Kysely, Django, or another migration runner not shown here? The engine-level rules
> below (expand–contract, `CONCURRENTLY` outside a txn, `NOT VALID` then `VALIDATE`, batched backfill)
> are identical regardless of runner — translate the raw-SQL recipes into your tool's directives. For
> the per-tool workflow/wiring of those runners, consult that runner's own documentation; the
> engine-level recipes here are what those directives must ultimately emit.

## Principles

- **Forward-only in prod.** Roll back with a new forward migration, not by editing history.
- **DDL and DML in separate migrations.** A schema change and a data backfill have different lock and
  duration profiles; never mix them.
- **Immutable once applied.** Editing an applied migration drifts environments (and breaks Prisma's
  checksum).
- **Test against prod-sized data.** A migration that is instant on 100 rows can hold ACCESS EXCLUSIVE
  for minutes on 10M.
- **Bound every risky DDL** so a wait can never become an outage:

```sql
SET lock_timeout = '3s';        -- give up acquiring the lock rather than queueing behind it
SET statement_timeout = '0';    -- or a bounded value per backfill step
```

A blocked DDL holding ACCESS EXCLUSIVE queues *every* subsequent query behind it; `lock_timeout` makes
the migration fail fast instead of stalling the whole table.

## Lock-impact reference

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
| `CREATE INDEX CONCURRENTLY` | SHARE UPDATE EXCLUSIVE | no | no | the safe one; 2 scans, no txn |
| `DROP COLUMN` | ACCESS EXCLUSIVE (brief) | no | no | code-first, then drop |
| `VACUUM FULL` | ACCESS EXCLUSIVE (long) | yes | yes | autovacuum / `pg_repack` |

## Expand–contract (zero-downtime)

The only safe way to rename a column, change its type, or split/merge columns. Each arrow is a
deployable step; the schema and the app are always compatible.

```text
1. EXPAND   add the new column/table (nullable or instant-default). Schema-only, no app change.
2. DUAL-WRITE + BACKFILL   deploy app that writes BOTH old and new; backfill old rows in batches.
3. MIGRATE READS   deploy app that reads NEW, still writes both; verify parity.
4. CONTRACT   deploy app that uses only NEW; in a later migration drop the old column.
```

Never collapse these into one migration. The gap between deploys is where reads and writes stay
consistent across rolling app instances running mixed versions.

## Safe recipes (raw SQL)

### Add a NOT NULL column safely

```sql
-- 1. add nullable (instant, metadata-only)
ALTER TABLE users ADD COLUMN display_name text;
-- 2. batched backfill (see "Batched backfill" below)
-- 3. add the NOT NULL invariant as a NOT VALID check, then validate under a light lock
ALTER TABLE users ADD CONSTRAINT ck_users_display_name_nn
    CHECK (display_name IS NOT NULL) NOT VALID;
ALTER TABLE users VALIDATE CONSTRAINT ck_users_display_name_nn;  -- scans, SHARE UPDATE EXCLUSIVE
-- 4. promote to a real NOT NULL: PG12+ reuses the proven CHECK and skips the full re-scan
ALTER TABLE users ALTER COLUMN display_name SET NOT NULL;
ALTER TABLE users DROP CONSTRAINT ck_users_display_name_nn;
```

### Add an index concurrently (and clean a failed one)

```sql
CREATE INDEX CONCURRENTLY ix_users_avatar_url ON users (avatar_url);
-- A failed CONCURRENTLY build leaves an INVALID index that still costs writes:
SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;
DROP INDEX CONCURRENTLY ix_users_avatar_url;   -- drop it, then recreate
```

`CONCURRENTLY` cannot run inside a transaction block (it does two table scans and a wait). It is the
mandatory form on any live table.

### Add a foreign key without a long lock

```sql
ALTER TABLE orders ADD CONSTRAINT fk_orders_user
    FOREIGN KEY (user_id) REFERENCES users (id) NOT VALID;   -- brief lock, checks new rows only
ALTER TABLE orders VALIDATE CONSTRAINT fk_orders_user;        -- scans existing rows, light lock
```

### Change a column type via expand-contract

In-place `ALTER COLUMN ... TYPE` rewrites the whole table under ACCESS EXCLUSIVE. When the conversion
is not assignment-cast-free, expand-contract instead:

```sql
-- 1. expand: new typed column
ALTER TABLE orders ADD COLUMN amount_v2 numeric(19,4);
-- 2. backfill in batches; app dual-writes amount and amount_v2
-- 3. migrate reads to amount_v2; verify parity
-- 4. contract: drop the old column in a later migration
ALTER TABLE orders DROP COLUMN amount;
ALTER TABLE orders RENAME COLUMN amount_v2 TO amount;   -- brief lock, metadata-only
```

### Drop a column

```sql
-- code-first: ship an app release that no longer references the column, THEN:
ALTER TABLE orders DROP COLUMN legacy_status;   -- brief ACCESS EXCLUSIVE, metadata-only
```

### Batched backfill

Backfill in bounded, committed batches so no single transaction holds locks or bloats WAL, and
autovacuum can keep up. Drive the loop from the app/migration tool (primary), or use a `DO` block in
`psql` (fallback).

```python
# Primary: psycopg 3, keyset + SKIP LOCKED, commit per batch
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

```sql
-- Fallback in psql: a DO block that commits each batch (PG11+ allows COMMIT inside DO)
DO $$
DECLARE last_id bigint := 0; max_id bigint;
BEGIN
  LOOP
    WITH batch AS (
        SELECT id FROM users WHERE id > last_id AND display_name IS NULL
        ORDER BY id LIMIT 5000 FOR UPDATE SKIP LOCKED
    ), upd AS (
        UPDATE users u SET display_name = u.username
        FROM batch WHERE u.id = batch.id
        RETURNING u.id
    )
    SELECT max(id) INTO max_id FROM upd;
    EXIT WHEN max_id IS NULL;   -- no rows updated this round
    last_id := max_id;
    COMMIT;
  END LOOP;
END $$;
```

## Per-tool concrete examples

### Plain SQL (golang-migrate-style file pair)

```sql
-- 000003_add_avatar.up.sql
ALTER TABLE users ADD COLUMN avatar_url text;
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_users_avatar_url ON users (avatar_url);
-- (backfill of display_name runs as a SEPARATE migration / job, not here)
```

```sql
-- 000003_add_avatar.down.sql
DROP INDEX CONCURRENTLY IF EXISTS ix_users_avatar_url;
ALTER TABLE users DROP COLUMN IF EXISTS avatar_url;
```

### golang-migrate

golang-migrate wraps each migration file in a single transaction by default, and `CONCURRENTLY` cannot
run in a transaction. There is no per-file "disable transaction" flag in the `postgres`/`pgx` driver,
so the honest, canonical approach is: **put the concurrent-index statement in its own migration file
and apply that step out-of-band**, or switch to a tool that supports a no-transaction directive
(`dbmate` `-- migrate:up transaction:false`, `atlas`, or `tern`) for that one step.

```bash
# create the pair
migrate create -ext sql -dir migrations -seq add_avatar_index

# put ONLY the concurrent index in its own file, apply it (it will fail if wrapped in a txn —
# run it with psql directly, or via a tool that does not open a transaction):
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -c "CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_users_avatar_url ON users (avatar_url);"

# if a previous run left the migration marked dirty, clear it:
migrate -path migrations -database "$DATABASE_URL" force 3
```

```sql
-- migrations/000004_add_avatar_col.up.sql  (this file IS safe inside a txn)
ALTER TABLE users ADD COLUMN avatar_url text;
```

### Alembic (SQLAlchemy 2.0, Python 3.12)

```python
from alembic import op
import sqlalchemy as sa

def upgrade() -> None:
    op.add_column("users", sa.Column("avatar_url", sa.Text(), nullable=True))
    with op.get_context().autocommit_block():     # required for CONCURRENTLY (leaves the txn)
        op.create_index(
            "ix_users_avatar_url", "users", ["avatar_url"],
            postgresql_concurrently=True, if_not_exists=True,
        )
    op.execute("UPDATE users SET display_name = username WHERE display_name IS NULL")
    op.create_check_constraint(
        "ck_users_display_name_nn", "users", "display_name IS NOT NULL",
        postgresql_not_valid=True,
    )

def downgrade() -> None:
    op.drop_constraint("ck_users_display_name_nn", "users", type_="check")
    op.drop_index("ix_users_avatar_url", "users", postgresql_concurrently=True, if_exists=True)
    op.drop_column("users", "avatar_url")
```

For a large backfill, replace the single `op.execute(...)` with the batched loop from above (run via a
raw connection inside the migration, committing per batch).

### Prisma

Prisma cannot emit `CONCURRENTLY`; generate an empty migration and hand-edit the SQL.

```bash
# 1. create the migration WITHOUT applying it
npx prisma migrate dev --create-only --name add_avatar_url

# 2. hand-edit prisma/migrations/<ts>_add_avatar_url/migration.sql (see below)

# 3. apply in CI/CD with deploy (never migrate dev on shared envs — it can reset the DB)
npx prisma migrate deploy
```

```sql
-- prisma/migrations/<ts>_add_avatar_url/migration.sql
ALTER TABLE "users" ADD COLUMN "avatar_url" TEXT;
CREATE INDEX CONCURRENTLY IF NOT EXISTS "ix_users_avatar_url" ON "users" ("avatar_url");
```

Prisma checksums every migration file: once applied, editing it triggers `P3006` on every environment
where the original already ran — create a new migration instead. ORM-surface traps
(`updateMany` returning a count, `@updatedAt` skipped on bulk writes, serverless connection
exhaustion) are out of scope for this engine-level skill — see Prisma's own documentation.

## Rollback reality

Down-migrations are best-effort. Data-destructive forward changes are not reversible from a
down-migration:

- `DROP COLUMN` discards the data — only a backup restores it.
- Type narrowing (`numeric(19,4)` → `int`) loses precision irreversibly.
- A completed backfill cannot be un-derived if the source was dropped.

Before the **contract** phase, snapshot the affected table:

```bash
pg_dump -Fc -t orders "$DATABASE_URL" > orders_pre_contract.dump   # restore with pg_restore -t orders
```

Treat the down-migration as a convenience for local dev; in prod, recover from backup or roll forward.
