# Query optimization

## How the sparse index prunes

ClickHouse reads data in **granules** (8192 rows by default). It keeps one primary-index mark per granule — the `ORDER BY` column values at the granule boundary. A query whose `WHERE` constrains a **prefix of the `ORDER BY`** lets the engine binary-search the marks and read only matching granules. Everything else is skipped without touching disk.

Consequence: a filter on a column **not** in the `ORDER BY` prefix prunes nothing — the engine scans every granule. That is the usual cause of "the primary key isn't pruning." The fixes below all add a *secondary* way to prune.

Inspect what actually happened:

```sql
EXPLAIN indexes = 1
SELECT count() FROM events WHERE country = 'ES' AND ts >= now() - INTERVAL 7 DAY;
-- shows which indexes were used and granules selected vs total

-- or, run the query with trace logging to see granules/rows read:
SET send_logs_level = 'trace';
```

## PREWHERE

`PREWHERE` reads its columns *first*, evaluates the predicate, and only then reads the remaining columns for surviving rows. ClickHouse auto-moves predicates into `PREWHERE`, but an explicit `PREWHERE` on a **cheap, highly selective** column forces the order you want and cuts I/O on wide tables.

```sql
SELECT event_type, count() FROM events
PREWHERE country = 'ES'                 -- 1 narrow column read first, filters hard
WHERE ts >= now() - INTERVAL 7 DAY
GROUP BY event_type;
```

Use it when one filter column is small and eliminates most rows before the expensive columns are touched.

## Projections

A projection is a second physical copy of the table data with a different `ORDER BY` and/or pre-aggregation, stored alongside the table. The optimizer picks it transparently when it serves the query better.

```sql
ALTER TABLE events ADD PROJECTION by_country
( SELECT * ORDER BY (country, ts) );
ALTER TABLE events MATERIALIZE PROJECTION by_country;   -- builds it for existing data
```

Cost: extra storage and insert work (every insert maintains the projection). Worth it when **one** secondary access pattern is frequent and latency-critical.

## Data-skipping indexes

Cheaper and coarser than projections — they store summaries per block of granules and skip blocks that can't match.

| Index | Built for | Example |
|---|---|---|
| `minmax` | Columns correlated with the sort order (ranges) | `INDEX idx_amt revenue TYPE minmax GRANULARITY 4` |
| `set(N)` | Low distinct count per block | `INDEX idx_et event_type TYPE set(100) GRANULARITY 4` |
| `bloom_filter` | High-cardinality equality / `IN` | `INDEX idx_uid user_id TYPE bloom_filter GRANULARITY 4` |

```sql
ALTER TABLE events ADD INDEX idx_uid user_id TYPE bloom_filter GRANULARITY 4;
ALTER TABLE events MATERIALIZE INDEX idx_uid;   -- backfill for existing parts
```

## Which accelerator, when

- Query filters a column the PK prefix doesn't cover, **point/`IN` lookups**, high cardinality → `bloom_filter` skip index.
- Query filters a **range** on a side column loosely correlated with the sort → `minmax` skip index.
- You repeatedly query in a **whole different sort order** (and storage is acceptable) → projection.
- You repeatedly compute the **same aggregate** at read time → pre-aggregate with an `AggregatingMergeTree` MV instead (see `ingestion-and-mvs.md`).
- A cheap, selective filter column on a wide table → explicit `PREWHERE`.

## Common slow-query fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Full scan despite a `WHERE` | Filter not on `ORDER BY` prefix | Skip index / projection, or revisit the key |
| Slow `SELECT *` dashboards | Reading every column | Select only needed columns |
| `ReplacingMergeTree` query slow | `FINAL` merging at query time | Drop `FINAL` off hot path; dedup in the MV layer |
| Query fast cold, slow under load | Too many parts | Fix insert batching/partitioning (see schema ref) |
| Memory blows up on GROUP BY | Huge cardinality grouping | Pre-aggregate via MV; or `max_bytes_before_external_group_by` |
