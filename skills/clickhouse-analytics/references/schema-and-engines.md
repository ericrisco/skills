# Schema and engines (deep dive)

## Engine matrix

| Engine | Keeps | Merge action | Query pattern | When |
|---|---|---|---|---|
| `MergeTree` | Every inserted row | Just sorts/merges parts | Direct `SELECT ... GROUP BY` | Append-only events, logs, metrics — the default |
| `ReplacingMergeTree([ver][, is_deleted])` | Latest row per `ORDER BY` key | Drops older versions on merge | `SELECT ... FINAL` or app-side latest | Upserts, CDC sink, "current state per id" |
| `AggregatingMergeTree` | Partial aggregate states per key | Combines `-State` partials | `SELECT ...Merge(col)` behind an MV | Pre-aggregated uniq/quantile/argMax rollups |
| `SummingMergeTree([cols])` | Summed numerics per key | Adds numeric columns on merge | Direct `SELECT sum-already-done` | Simple additive counters only |
| `CollapsingMergeTree(sign)` | Rows with +1/-1 sign | Cancels +1/-1 pairs | Sum the sign column | Mutable rows with a known prior state |
| `Replicated<X>` | Same as `<X>` | Same + cross-replica sync via Keeper | Same | Any of the above, in production HA |

Rule of thumb: start at `MergeTree`. Add `AggregatingMergeTree` only behind a materialized view. Reach for `ReplacingMergeTree` only when you genuinely have upserts and can tolerate eventual dedup. Use the `Replicated` prefix in any clustered deployment.

## ORDER BY — the reasoning

The `ORDER BY` defines the **sparse primary index**: ClickHouse stores one index mark per granule (8192 rows by default), so the index is tiny and lives in memory. A query whose `WHERE` touches a *prefix* of the `ORDER BY` can skip whole granules.

Construction:

1. List the columns you filter and group by most. Ignore join keys — they don't help pruning.
2. Sort that list **low cardinality first, high cardinality last**. Low-cardinality leading columns produce long runs of equal values, which compress hard and let the index prune large contiguous ranges.
3. Keep it to **3–5 columns**. Extra columns past the useful prefix only cost insert-time sorting.
4. For timeseries, bucket the timestamp early and keep the raw timestamp last: `(tenant_id, toStartOfDay(ts), event_type, ts)`. The bucket prunes by day; the trailing raw `ts` orders within a granule for range scans.

A good key vs a bad key on the same data is routinely a ~100x query-time difference. This is the highest-leverage decision in the whole schema, and it is effectively immutable — changing it means a new table and an `INSERT ... SELECT` migration.

`PRIMARY KEY` may be a prefix of `ORDER BY` when you want a smaller index than the sort order (e.g. sort by `(a, b, c)` but index only `(a, b)`).

## PARTITION BY — sizing

Partitioning is for **data management**, not speed:

- TTL drops expired partitions during merges.
- `ALTER TABLE ... DROP PARTITION` removes a chunk instantly.
- Backfills and detaches operate per partition.

Budget: aim for **tens to low hundreds of active partitions**, not thousands. Each partition holds its own parts; merges never cross partitions, so over-partitioning multiplies tiny parts and starves the merge scheduler.

| Volume | Partition by |
|---|---|
| < ~100M rows/month | `toYYYYMM(ts)` (monthly) |
| Billions/month, time-bounded retention | `toYYYYMMDD(ts)` (daily) — only at this scale |
| Anything | never a raw high-cardinality column, never per-hour |

## Types and codecs

| Column shape | Type | Codec | Why |
|---|---|---|---|
| Enum-like string, < ~10k distinct | `LowCardinality(String)` | (built-in dict) | Dictionary-encodes; faster GROUP BY, smaller |
| Free-form string, high distinct | `String` | `ZSTD` | LowCardinality hurts above ~10k distinct |
| Monotonic timestamp / counter | `DateTime64(3)` / `UInt*` | `CODEC(Delta, ZSTD)` | Delta makes deltas tiny, ZSTD packs them |
| Float metric | `Float64` | `CODEC(ALP)` | ALP (26.3) beats Gorilla on many float series |
| Semi-structured payload | `JSON` (native, GA 26.3) | — | Real typed paths, not a `String` blob |
| Bounded fixed set | `Enum8` / `Enum16` | — | Stored as int, validated on insert |
| Integer | smallest that fits (`UInt8`…`UInt64`) | — | Narrower = less I/O |

`LowCardinality` threshold: under ~10k distinct values it wins; above that the dictionary overhead can cost more than it saves — fall back to plain `String` + `ZSTD`. Measure with `SELECT uniqExact(col) FROM table` on a sample.

## Migrating an ORDER BY / PARTITION BY

Because both are immutable, the migration is always: create a new table with the corrected key, `INSERT INTO new SELECT * FROM old` (ideally partition-by-partition to bound memory), verify counts, then `EXCHANGE TABLES new AND old` (atomic) and drop the old one.
