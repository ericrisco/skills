# Capacity, pricing, limits

All numbers are us-east-1, standard table class, as of mid-2026. Prices change; treat ratios as durable,
absolute cents as a snapshot.

## Capacity modes

| mode | when | mechanics |
|---|---|---|
| On-demand | Spiky / unpredictable, new tables, < ~10M req/month | Pay per request; no capacity planning. **AWS's recommended default** since the Nov-2024 cut. |
| Provisioned + auto-scaling | Sustained utilization > ~40% | Reserve RCU/WCU; auto-scaling adjusts within bounds. |
| Provisioned + reserved capacity | Predictable, long-running, > ~70% util | Commit 1- or 3-year for the steep discount. |

**The Nov-2024 change.** AWS cut on-demand throughput price by **~50%**, which made on-demand cheaper than
provisioned for most workloads and shifted the default recommendation to on-demand. Only commit to
provisioned/reserved once you can show steady high utilization.

## Pricing snapshot (on-demand, us-east-1, standard class)

- Read request units (RRU): **$0.125 / million**
- Write request units (WRU): **$0.625 / million** (writes are 5× reads — write-heavy designs cost more)

At **full** utilization, provisioned beats on-demand hard:

- Provisioned write ~ **$0.047 / million** WCU → roughly **26×** cheaper than on-demand WRU.
- 3-year reserved write ~ **$0.013 / million** → roughly **96×** cheaper than on-demand.

These ratios only apply if utilization is genuinely high and steady; idle provisioned capacity is pure
waste. That is the whole point of the >40% / >70% thresholds.

## Warm throughput

Warm throughput is the **instantaneous** read/write a table or index can already serve. It is exposed by
default at **no cost** and rises automatically as the table scales. You are charged a one-time fee only if
you **proactively pre-warm** ahead of a known spike (e.g. a launch or a sale), priced at the per-unit
RCU/WCU regional rate for the increase you request. Default behavior costs nothing.

## Hot partitions and write-sharding

Every physical partition has a hard ceiling, independent of table capacity:

- **3,000 RCU/sec** and **1,000 WCU/sec** per partition.

Concentrate traffic on one partition key and you throttle even while well under the table's provisioned
or on-demand limit. Symptom: `ProvisionedThroughputExceededException` / throttles "but I'm under capacity."

Fix — **write-sharding** spreads a hot key across N buckets:

```text
# Hot: a single counter, one partition
PK = COUNTER#global

# Sharded across 10 buckets
PK = COUNTER#global#<0..9>     # write: random bucket; read: query all 10 and sum (scatter-gather)
```

Choose N from peak WCU / 1,000 (round up). Higher N spreads heat but multiplies read fan-out — size it to
the real peak, not a guess.

## Quotas and operation limits

| limit | value | note |
|---|---|---|
| Item size | **400 KB** | attribute names + values, binary length; offload big blobs to S3 |
| GSIs per table | **20** (default, adjustable) | each adds standing write cost |
| LSIs per table | **5** | must be defined at table creation; share base PK |
| Item-collection size (with any LSI) | **10 GB** | all items under one PK; GSI-only tables have no cap |
| Query / Scan response | **1 MB / request** | paginate via `LastEvaluatedKey` |
| TransactWriteItems / TransactGetItems | **100 unique items** | transactional write = **2× WCU** |
| BatchWriteItem | **25 put/delete requests** | per call |
| Table / item count | no practical limit | only the per-item and per-partition caps bind |

## FilterExpression vs key condition

`FilterExpression` is applied **after** the read has already consumed capacity. It reduces the bytes sent
over the wire, never the RCU billed. A pattern that filters away most of what it scanned is a key-design
failure — fix the key or add the right (often sparse) GSI. Filtering ≤10% of a small, key-bounded result
is fine; filtering a Scan is not.
