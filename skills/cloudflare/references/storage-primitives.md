# Storage primitives — config, code, limits

Each primitive is a binding in `wrangler.jsonc` and a typed field on `Env`. Pick by access pattern and consistency.

## D1 — serverless SQLite

Relational data with strong consistency. Billed on rows read, rows written, and storage; scales to zero. Each database stores up to **10 GB**; D1 is designed for horizontal scale-out — create a database per tenant/user rather than one monolith. D1 is **SQLite, not Postgres**: no Postgres extensions, accessed over HTTP (not a connection pool).

```jsonc
"d1_databases": [{ "binding": "DB", "database_name": "app", "database_id": "<id>" }]
```

```ts
// Single statement
const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?")
  .bind(id).first<User>();

// Batch (one round trip, implicit transaction over the batch)
await env.DB.batch([
  env.DB.prepare("INSERT INTO orders (id, user_id) VALUES (?, ?)").bind(oid, id),
  env.DB.prepare("UPDATE users SET orders = orders + 1 WHERE id = ?").bind(id),
]);
```

Create + migrate:

```bash
wrangler d1 create app
wrangler d1 execute app --file=./schema.sql --remote
```

Need real Postgres at the edge? Use **Hyperdrive** to pool and accelerate an external Postgres connection — that is not D1. For standalone Postgres work see `../../postgresdb/SKILL.md`.

## KV — eventually-consistent edge key/value

Read-optimized global key/value. **Eventually consistent**: a write can take up to ~60s to propagate to all edge locations, so a read right after a write may be stale. Max value size **25 MiB**. Use for read-heavy, change-rarely data (config, feature flags, cached renders). Not for counters, sessions you read after writing, or anything strongly consistent — use D1 or a Durable Object. KV is not Redis (no atomic ops, no pub/sub); for Redis semantics see `../../redis/SKILL.md`.

```jsonc
"kv_namespaces": [{ "binding": "CACHE", "id": "<namespace-id>" }]
```

```ts
await env.CACHE.put("flags", JSON.stringify(flags), { expirationTtl: 3600 });
const flags = await env.CACHE.get("flags", { type: "json", cacheTtl: 3600 });
```

## R2 — object storage, zero egress

S3-compatible object storage with **no egress charges**. Billed on stored volume plus Class A operations (mutating, pricier) and Class B operations (reads). Use for uploads, blobs, backups, large media. Not for querying structured data.

```jsonc
"r2_buckets": [{ "binding": "BUCKET", "bucket_name": "uploads" }]
```

```ts
await env.BUCKET.put(key, req.body, { httpMetadata: { contentType: req.headers.get("content-type") ?? "" } });
const obj = await env.BUCKET.get(key);
if (!obj) return new Response("not found", { status: 404 });
return new Response(obj.body, { headers: { "content-type": obj.httpMetadata?.contentType ?? "application/octet-stream" } });
```

## Queues — async batch processing

At-least-once delivery; producers send, consumers process batches. Defaults: `max_batch_size` 10 (max **100**), `max_retries` 3, plus `max_batch_timeout`. Exhausted messages route to a `dead_letter_queue`. Make consumers idempotent.

```jsonc
"queues": {
  "producers": [{ "binding": "JOBS", "queue": "thumbnails" }],
  "consumers": [{
    "queue": "thumbnails",
    "max_batch_size": 10,
    "max_batch_timeout": 5,
    "max_retries": 3,
    "dead_letter_queue": "thumbnails-dlq"
  }]
}
```

```ts
await env.JOBS.send({ key });           // single
await env.JOBS.sendBatch(items.map(i => ({ body: i }))); // batch enqueue

async queue(batch: MessageBatch<Job>, env: Env) {
  for (const m of batch.messages) {
    try { await handle(m.body, env); m.ack(); }
    catch { m.retry(); }   // or batch.retryAll()
  }
}
```

## Durable Objects — strongly-consistent coordination

A single-threaded actor with strongly-consistent transactional storage, addressable by ID. Use for per-entity state, counters, locks, rate limiters, and WebSocket coordination — the things KV cannot do consistently. Each object serializes its own requests. Included in the Workers Paid plan bundle. Full lifecycle and storage API in the Cloudflare docs; reach for a DO whenever you need read-after-write on a single logical entity.

## Limits quick table

| Resource | Limit |
|---|---|
| KV value size | 25 MiB |
| D1 database size | 10 GB each (shard per tenant) |
| Queue batch size | 10 default, 100 max |
| Queue retries | 3 default |
| R2 egress | none (free) |
| Subrequests / CPU time | bounded per request; raised on Workers Paid ($5/mo min) |
