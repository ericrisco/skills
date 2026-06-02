# Ingestion and materialized views

Target version: 26.3 LTS. The 26.x line changed several insert defaults — note them per item below.

## Batch sizing

ClickHouse turns every `INSERT` into at least one part on disk. A part is a sorted, compressed unit that the background merge scheduler later combines. Too many small parts = the scheduler falls behind = "too many parts" errors and slow queries.

- Aim for **10k–100k+ rows per `INSERT`** when you batch client-side.
- Or rely on **async inserts** (default-on since 26.3) to batch server-side.
- Never one row per statement in a loop.

## Async inserts (default-on since 26.3 LTS)

The server holds incoming small inserts in an in-memory buffer and flushes them as one part when the first threshold is reached:

| Setting | Default | Meaning |
|---|---|---|
| `async_insert` | `1` (since 26.3) | Buffer inserts server-side |
| `async_insert_max_query_number` | `450` | Flush after this many buffered queries |
| `async_insert_busy_timeout_min_ms` | `50` | Lower bound of the adaptive flush timer |
| `async_insert_busy_timeout_max_ms` | data-rate driven | Upper bound; adaptive since 24.2 |
| `wait_for_async_insert` | `1` | Client waits for the flush to confirm durability |

The busy timeout is **adaptive**: at high data rates it shortens toward the min, at low rates it lengthens toward the max, balancing latency vs part count automatically.

Keep inserts **synchronous** (`async_insert=0`) when you need read-your-write consistency immediately, or when you already send large well-sized blocks and want zero buffering latency.

## Deduplication (default-on for all inserts since 26.2)

- Before 26.2, insert dedup was sync-only. **As of 26.2 it applies uniformly to sync and async inserts.**
- Since 26.1 dedup works **end-to-end across async inserts and dependent materialized views**.
- Net effect: an identical re-sent block is dropped, so **retrying a failed insert is safe** — no double counting.
- Control identity explicitly with `insert_deduplication_token`: same token = same logical insert, so you can dedup across differing row content or split a logical batch.

```sql
INSERT INTO events SETTINGS insert_deduplication_token = 'batch-2026-06-02-0007'
SELECT * FROM s3('https://bucket/events/2026-06-02/*.parquet', 'Parquet');
```

## Loading from external sources

```sql
-- S3 (Parquet / JSONEachRow / CSV auto-detected by extension or explicit format)
INSERT INTO events
SELECT * FROM s3('https://bucket.s3.amazonaws.com/events/2026/*.parquet', 'Parquet');

-- Local/served files via file() or the clickhouse-client --query with FORMAT
INSERT INTO events FROM INFILE 'events.csv.gz' FORMAT CSV;
```

```sql
-- Kafka: a Kafka engine table + an MV that drains it into the MergeTree table.
CREATE TABLE events_queue (raw String)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'kafka:9092',
         kafka_topic_list  = 'events',
         kafka_group_name  = 'ch-ingest',
         kafka_format      = 'JSONEachRow';

CREATE MATERIALIZED VIEW events_queue_mv TO events AS
SELECT * FROM events_queue;          -- the Kafka engine itself never stores rows
```

## AggregatingMergeTree materialized view — end to end

Goal: a rolling **uniq users and revenue per tenant per hour** that stays current as events stream in.

```sql
-- 1. Target table storing partial aggregate STATES.
CREATE TABLE events_hourly
(
    tenant_id  UInt32,
    hour       DateTime,
    users      AggregateFunction(uniq, UInt64),
    revenue    AggregateFunction(sum, Float64)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(hour)
ORDER BY (tenant_id, hour);

-- 2. MV that writes states on every new insert into events.
--    GROUP BY MUST equal the target ORDER BY. No POPULATE.
CREATE MATERIALIZED VIEW events_hourly_mv TO events_hourly AS
SELECT tenant_id,
       toStartOfHour(ts)  AS hour,
       uniqState(user_id) AS users,
       sumState(revenue)  AS revenue
FROM events
GROUP BY tenant_id, hour;

-- 3. Backfill history WITHOUT POPULATE: bounded windows so it never OOMs.
INSERT INTO events_hourly
SELECT tenant_id, toStartOfHour(ts), uniqState(user_id), sumState(revenue)
FROM events
WHERE ts >= '2026-01-01' AND ts < '2026-02-01'   -- one month at a time
GROUP BY tenant_id, hour;
-- repeat per month; dedup keeps reruns safe.

-- 4. Read with -Merge to collapse states into final values.
SELECT tenant_id, hour,
       uniqMerge(users)  AS uniq_users,
       sumMerge(revenue) AS rev
FROM events_hourly
GROUP BY tenant_id, hour
ORDER BY tenant_id, hour;
```

Why no `POPULATE`: it scans the entire base table in one shot, blocks the MV from capturing concurrent inserts during that scan, and can exhaust memory on a billion-row table. Creating the MV empty captures new rows from the moment of creation; the bounded backfill fills the past safely.
