# Online DDL and migrations (the MySQL mechanics)

This file owns the MySQL-only knobs — `ALGORITHM=`, `LOCK=`, pt-online-schema-change, gh-ost — that
make a schema change run without an outage. The vendor-neutral *strategy* (expand-contract, batched
backfill, dual-write) lives in `db-migrations`; this is the InnoDB machinery that strategy rides on.

## ALGORITHM / LOCK matrix per operation

Every `ALTER TABLE` resolves to one of three algorithms. **Always state it explicitly** — if you
omit `ALGORITHM=`, MySQL silently picks the cheapest one that works, and "cheapest that works" can
quietly be `COPY`, which locks and rebuilds a multi-GB table.

| Operation | Best algorithm | Notes |
|---|---|---|
| Add column at the end | `INSTANT` | metadata-only since 8.0.12; near-free |
| Add column in the middle | `INSTANT` (8.0.29+) | older versions fall back to INPLACE/COPY |
| Drop a column | `INSTANT` (8.0.29+) | else INPLACE |
| Rename a column | `INSTANT` | metadata-only |
| Set / drop a column DEFAULT | `INSTANT` | metadata-only |
| Add a secondary index | `INPLACE, LOCK=NONE` | rebuilds the index without blocking writes |
| Drop an index | `INPLACE` (often INSTANT) | metadata change |
| Change column NULL → NOT NULL | `INPLACE` | requires the data to already satisfy it |
| Change column data type / charset | `COPY` | full table rebuild — this is the dangerous one |
| Add / drop a PRIMARY KEY | `COPY` (usually) | rebuilds the clustered index and every secondary |
| Change ROW_FORMAT / KEY_BLOCK_SIZE | `INPLACE` (rebuild) | not blocking but rewrites the table |

```sql
-- Always be explicit. If the operation can't be done with the algorithm you named, the statement
-- FAILS LOUDLY instead of silently degrading to a locking COPY.
ALTER TABLE orders ADD COLUMN note VARCHAR(255) NULL, ALGORITHM=INSTANT, LOCK=NONE;

-- Adding a secondary index on a live table: rebuild without blocking writes.
ALTER TABLE orders ADD INDEX idx_user_created (user_id, created_at),
  ALGORITHM=INPLACE, LOCK=NONE;
```

There is a hard limit on `INSTANT` add-column: each `INSTANT` add increments a row-version counter,
and after a number of them the table needs a rebuild before more `INSTANT` adds are allowed. Check
`information_schema.INNODB_TABLES.INSTANT_COLS` / row-version columns if `INSTANT` starts refusing.

## When INSTANT/INPLACE can't do it non-blockingly → gh-ost or pt-osc

For a `COPY`-only change on a large *hot* table (type change, PK change, charset migration), don't
run it in place at peak. Use an external tool that builds a shadow table, copies rows in chunks,
keeps it in sync, and swaps atomically.

### gh-ost (GitHub) — binlog-based, triggerless

gh-ost reads the binlog to keep the shadow table in sync, so it adds no triggers to your hot table
and throttles cleanly on replica lag.

```bash
# Always --dry-run (omit --execute) first; read the plan, then add --execute.
gh-ost \
  --host=primary.db --database=shop --table=orders \
  --alter="MODIFY COLUMN total DECIMAL(19,4) NOT NULL" \
  --max-load="Threads_running=25" \
  --critical-load="Threads_running=100" \
  --max-lag-millis=1500 \
  --throttle-control-replicas="replica1.db,replica2.db" \
  --chunk-size=1000 \
  --cut-over=default \
  --postpone-cut-over-flag-file=/tmp/ghost.postpone \
  --execute
# Touch/remove the postpone file to control exactly when the atomic cutover happens.
```

gh-ost needs `binlog_format=ROW` and either a connection to a replica or `--allow-on-master` with
binlog access. It can't follow a table that already has triggers.

### pt-online-schema-change (Percona) — trigger-based

Use pt-osc when gh-ost can't read the binlog (no replica, restricted binlog). It installs AFTER
INSERT/UPDATE/DELETE triggers on the original table to mirror writes into the shadow copy.

```bash
pt-online-schema-change \
  --alter "MODIFY COLUMN total DECIMAL(19,4) NOT NULL" \
  --max-lag=1.5 --check-slave-lag replica1.db \
  --chunk-time=0.5 \
  --dry-run \
  D=shop,t=orders
# Replace --dry-run with --execute once the dry run is clean.
```

Caveat: pt-osc's triggers conflict with any pre-existing triggers on the table, and foreign keys
referencing the table need `--alter-foreign-keys-method` chosen deliberately (rebuild_constraints
vs drop_swap) — a wrong choice can briefly break FK integrity at cutover.

### Choosing between them

| Situation | Tool |
|---|---|
| You have a replica and ROW binlog, no existing triggers | gh-ost (lighter, no triggers on hot table) |
| No replica / restricted binlog access | pt-osc (triggers) |
| Table already has triggers | pt-osc with care, or refactor first |
| Foreign keys point at the table | pt-osc with an explicit `--alter-foreign-keys-method` |

## Rollback

- An `INSTANT`/`INPLACE` `ALTER` is a single transaction-like operation: if it fails it leaves the
  table unchanged. There is no half-applied state to clean up.
- gh-ost / pt-osc: before cutover, the original table is untouched — abort freely (gh-ost: remove
  the panic flag or kill it; the `_gho`/`_new` shadow + `_del` old table are left for you to drop).
  *After* cutover, "rollback" means running the reverse `ALTER` as a new migration. Design the
  reverse step before you cut over.

## How this composes with db-migrations expand-contract

The vendor-neutral pattern from `db-migrations` is: **expand** (add the new column/index, both old
and new readable), **migrate** (backfill + dual-write), **contract** (drop the old). Each phase maps
to a specific MySQL mechanic here:

- *Expand* = an `ALGORITHM=INSTANT` add-column / `INPLACE` add-index — cheap, non-blocking.
- *Backfill* = chunked `UPDATE ... WHERE id BETWEEN ? AND ?` in small batches (never one giant
  `UPDATE` that holds gap locks across the whole table); or let gh-ost do it for a type change.
- *Contract* = an `INSTANT` drop-column once nothing reads the old one.

Keep each phase a separate, forward-only migration so the reverse is always a clean step.
`db-migrations` owns *why* and *in what order*; this skill owns *which `ALGORITHM=` / which tool*.
