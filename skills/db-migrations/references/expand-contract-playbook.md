# Expand-contract playbook

Ordered deploy/migrate checklists for the common changes. Every example DDL sets `lock_timeout` first
and uses the non-blocking path, so it is safe to ship as written. Each phase is a **separate deploy**;
the cooling period between *switch reads* and *contract* is what preserves a no-schema-change rollback.

Notation: `M` = a migration (schema change), `A` = an app deploy. They alternate.

---

## Add a `NOT NULL` column

A single `ADD COLUMN ... NOT NULL DEFAULT <expr>` or `SET NOT NULL` validates/rewrites the whole table
under lock. Split it.

1. **M1 (expand)** — add the column nullable; metadata-only.
   ```sql
   SET lock_timeout = '1s';
   ALTER TABLE users ADD COLUMN status text;
   ```
2. **A1** — app dual-writes `status` on every insert/update (defaults it in code).
3. **Backfill** — fill historical rows in batches (see `backfill-and-batching.md`).
4. **M2** — add the constraint without a blocking scan, then validate, then flip `NOT NULL`.
   ```sql
   SET lock_timeout = '1s';
   ALTER TABLE users ADD CONSTRAINT users_status_nn CHECK (status IS NOT NULL) NOT VALID;
   ALTER TABLE users VALIDATE CONSTRAINT users_status_nn;
   ALTER TABLE users ALTER COLUMN status SET NOT NULL;
   ```
   On PG 12+, a validated `CHECK (col IS NOT NULL)` lets `SET NOT NULL` skip its own full scan.

---

## Rename a column

The running app reads the old name, so you cannot rename in place. Run a dual-name window.

1. **M1 (expand)** — add the new column nullable.
   ```sql
   SET lock_timeout = '1s';
   ALTER TABLE users ADD COLUMN email_address text;
   ```
2. **A1** — write BOTH `email` and `email_address`; keep READING `email`.
3. **Backfill** `email_address` from `email` in batches; verify counts/checksum.
4. **A2** — read `email_address`; still dual-write both. **Cooling period starts.**
5. **M2 (contract)** — days later, after the new app has run clean.
   ```sql
   SET lock_timeout = '1s';
   ALTER TABLE users DROP COLUMN email;
   ```

A view aliasing the new column to the old name can shorten the app-side change, but it does not remove
the need for the cooling period.

---

## Split one column into two

Example: `full_name` → `first_name`, `last_name`.

1. **M1** — add both new columns nullable.
   ```sql
   SET lock_timeout = '1s';
   ALTER TABLE people ADD COLUMN first_name text;
   ALTER TABLE people ADD COLUMN last_name text;
   ```
2. **A1** — on write, populate all three (`full_name` plus the two parts).
3. **Backfill** the split for historical rows; verify a reconstructed `full_name` matches the original.
4. **A2** — read the split columns; keep writing `full_name` through the cooling period.
5. **M2 (contract)** — drop `full_name` after cooling.

Merging two columns into one is the same shape with the directions reversed.

---

## Change a column type

A non-trivial type change rewrites every row and can invalidate the running app's expectations. Treat it
as a rename to a new column.

1. **M1** — add the new column with the target type, nullable.
   ```sql
   SET lock_timeout = '1s';
   ALTER TABLE orders ADD COLUMN amount_cents bigint;
   ```
2. **A1** — dual-write both old and new; read the old.
3. **Backfill** with the conversion expression in batches; verify.
4. **A2** — read the new column; keep dual-writing.
5. **M2 (contract)** — drop the old column after cooling.

This avoids the in-place `ALTER COLUMN ... TYPE`, which takes an exclusive lock and rewrites under it
(and, with a `USING` expression, can fail mid-rewrite on bad data).

---

## Drop a column or table

Dropping is a *contract* step, never the first move — the running app may still reference it.

1. **A1** — ship an app version that no longer reads or writes the target.
2. Wait the cooling period; confirm via logs/metrics that nothing touches it.
3. **M1 (contract)** — drop it.
   ```sql
   SET lock_timeout = '1s';
   ALTER TABLE users DROP COLUMN legacy_flag;
   ```

`DROP COLUMN` is metadata-only and fast in Postgres, but the lock it needs is brief-yet-exclusive, so
keep `lock_timeout` short and retry rather than queue behind a long transaction.

---

## Add a foreign key

`ADD CONSTRAINT ... FOREIGN KEY` validates every existing row under lock. Split validation off.

1. Ensure the referenced column is indexed/unique (add that index `CONCURRENTLY` first if missing).
2. **M1** — add the constraint as `NOT VALID` (instant; only new/changed rows are checked).
   ```sql
   SET lock_timeout = '1s';
   ALTER TABLE orders
     ADD CONSTRAINT orders_user_fk FOREIGN KEY (user_id) REFERENCES users (id) NOT VALID;
   ```
3. **M2** — validate existing rows without blocking writes.
   ```sql
   ALTER TABLE orders VALIDATE CONSTRAINT orders_user_fk;
   ```

If validation reveals orphan rows, that is a data-correctness problem — clean it before validating
(see `../../data-cleaning/SKILL.md`), do not loosen the constraint.

---

## Add an index on a live table

Plain `CREATE INDEX` holds a SHARE lock and blocks writes for the whole build — the classic "our deploy
deadlocks when we add an index" symptom.

```sql
-- This statement must NOT run inside a transaction block.
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders (user_id);
```

A failed `CONCURRENTLY` build leaves an INVALID index. Find it and rebuild:

```sql
DROP INDEX CONCURRENTLY idx_orders_user_id;
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders (user_id);
```

How to make a runner skip its transaction wrapper for this one statement is in `tools-and-runners.md`.
For Postgres lock-level semantics (which lock blocks what), see `../../postgresdb/SKILL.md`.
