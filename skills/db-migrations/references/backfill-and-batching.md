# Backfill and batching

Filling historical rows is where a "zero-downtime" plan most often turns into an outage: one giant
`UPDATE` locks rows, balloons WAL/undo, and pins replicas behind minutes of lag. The fix is always the
same shape — **bounded chunks, commit per chunk, throttle on lag, verify before you contract.**

## The loop, in words

1. Pick a chunk key. A monotonic PK is best; range over `id BETWEEN :lo AND :hi`, not `OFFSET`
   (OFFSET re-scans and gets slower every batch).
2. Update one chunk, touching only rows that still need it (`WHERE new_col IS NULL`), then **commit**.
3. Read replica lag and the app error rate. If either climbs past your threshold, sleep / back off.
4. Advance the window and repeat until the table is covered.
5. Verify counts and a checksum of old-vs-new. Only then schedule the contract step.

A few thousand rows per batch is a sane start; tune by watching lag. Smaller batches = lower lag, more
total wall-clock time.

## Postgres — server-side batched backfill

```sql
-- Run once per batch from your runner/script, advancing :lo/:hi between calls.
-- Touch only unfilled rows so re-runs are cheap and the loop is idempotent.
UPDATE users
SET    email_address = email
WHERE  id BETWEEN :lo AND :hi
  AND  email_address IS NULL;
```

```sql
-- A self-contained PL/pgSQL loop that commits each batch (PG 11+ supports COMMIT in a procedure).
-- Run as a PROCEDURE via CALL, not inside an outer transaction.
CREATE OR REPLACE PROCEDURE backfill_email_address(batch_size int DEFAULT 5000)
LANGUAGE plpgsql AS $$
DECLARE
  lo bigint := 0;
  hi bigint;
  max_id bigint;
BEGIN
  SELECT max(id) INTO max_id FROM users;
  WHILE lo <= max_id LOOP
    hi := lo + batch_size;
    UPDATE users
    SET    email_address = email
    WHERE  id >= lo AND id < hi
      AND  email_address IS NULL;
    COMMIT;                       -- release locks + flush WAL each batch
    PERFORM pg_sleep(0.1);        -- throttle; raise if replica lag climbs
    lo := hi;
  END LOOP;
END;
$$;
```

Throttle by replica lag instead of a fixed sleep when you can — query
`SELECT max(replay_lag) FROM pg_stat_replication;` between batches and back off while it is high.
(For the meaning of those replication views, see `../../postgresdb/SKILL.md`.)

## MySQL — batched backfill

MySQL has no in-loop `COMMIT` inside a single statement, so drive the loop from your script and run one
bounded `UPDATE` per iteration with `autocommit` on:

```sql
-- One batch; the script advances @lo/@hi and sleeps between iterations.
UPDATE users
SET    email_address = email
WHERE  id >= @lo AND id < @hi
  AND  email_address IS NULL
LIMIT  5000;
```

Watch `SHOW REPLICA STATUS` → `Seconds_Behind_Source` between batches; pause while it grows. For a
single very large `ALTER` (not a data backfill), use an online-schema-change tool instead — see
`tools-and-runners.md` for gh-ost vs pt-osc.

## Verify before you contract

Counts and a checksum must agree before any column is dropped or marked `NOT NULL`.

```sql
-- 1. No rows left unfilled.
SELECT count(*) AS remaining FROM users WHERE email_address IS NULL;  -- expect 0

-- 2. Old and new agree, row for row.
SELECT count(*) AS mismatches
FROM   users
WHERE  email_address IS DISTINCT FROM email;                          -- expect 0
```

A non-zero mismatch is a data-correctness bug, not a migration step — investigate the dual-write path
before contracting. If the divergence is in the *source* data (bad/duplicate rows), that is
`../../data-cleaning/SKILL.md` territory.

## Very large tables — snapshot + CDC

When an online loop would run for days, do it out of band:

1. Snapshot the table into the new shape (a copy job or a logical dump).
2. Stream changes that happened during the snapshot via change-data-capture (logical replication / binlog
   readers) so the copy catches up to live.
3. Cut over reads once the copy is caught up and verified.

This is the same idea gh-ost and pt-osc automate for a single MySQL `ALTER`; for a multi-table or
cross-engine move you build it explicitly. Either way the verify-before-contract rule does not change.
