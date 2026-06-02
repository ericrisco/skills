# Caching — depth

Read this when the cache is more than `SET k v EX`: read-through/write-through/write-behind,
multi-level caches, probabilistic early expiry, negative caching, and hot/big-key mitigation.
All patterns are client-agnostic (`redis-cli` / Lua / pseudo-client).

## Cache topologies

| Pattern | Who reads/writes the DB | Failure mode | Use when |
| --- | --- | --- | --- |
| **Cache-aside** (lazy) | the app, on a miss | stale until TTL; first read is slow | the default; read-heavy, tolerant of brief staleness |
| **Read-through** | the cache layer/lib | same as aside, hidden behind the lib | you want the cache to own the fetch |
| **Write-through** | app writes cache + DB synchronously | write latency = DB + cache; double write to keep consistent | reads must never see stale after a write |
| **Write-behind** (write-back) | app writes cache, a worker flushes to DB later | data loss window if Redis dies before flush | write-heavy, can tolerate a flush-lag loss window |

Default to **cache-aside with a TTL**. Reach for write-through only when a read immediately after a
write must reflect it; reach for write-behind only when you can afford to lose the un-flushed window
(and you have AOF or a durable journal to bound it).

## TTL + jitter

A fixed TTL applied to keys warmed together synchronizes their expiry — they all die in the same
second and stampede the origin simultaneously. Always jitter.

```text
ttl = base + random(0, base * 0.2)   # e.g. 300s base, up to +60s jitter
SET product:42 <json> EX ttl
```

*Why:* spreading expirations turns one giant stampede into a trickle of independent misses.

## Negative caching

Caching only hits means every request for a non-existent id falls through to the origin — an easy
DoS via random ids. Cache the miss too, with a *short* TTL so a row that appears soon isn't hidden long.

```text
val = GET product:42
if val == "__MISS__": return null          # cached absence, no DB call
if val == nil:
    row = db.fetch(42)
    if row == null: SET product:42 "__MISS__" EX 30   # short negative TTL
    else:           SET product:42 row EX 300
```

Keep the negative TTL much shorter than the positive one (seconds, not minutes) so freshly created
rows surface quickly.

## Stampede prevention

When a hot key expires, N concurrent readers all miss and hit the origin at once. Three approaches,
in increasing sophistication:

### 1. Recompute lock (request coalescing)

One reader claims the rebuild; the rest serve stale or briefly wait.

```text
val = GET product:42
if val != nil: return val
if SET product:42:lock 1 NX PX 5000 == OK:   # 5000ms MUST exceed worst-case rebuild
    val = db.fetch(42); SET product:42 val EX (300 + jitter); DEL product:42:lock
    return val
else:
    return GET product:42:stale  or  sleep(50ms) and retry GET
```

*Why the lock TTL matters:* if it is shorter than the rebuild, a second reader claims the lock while
the first is still rebuilding and you stampede anyway. Size it above the slowest origin call.

### 2. Probabilistic early expiration (XFetch)

Refresh *before* the key actually expires, with a probability that rises as expiry approaches, so one
reader renews early while everyone else still hits a warm key. The classic XFetch test:

```text
# delta  = how long the last recompute took (seconds)
# beta   = tuning knob, ~1.0 (higher = refresh earlier)
# expiry = absolute unix time the key expires
recompute if  now - delta * beta * ln(random(0,1))  >= expiry
```

Store `delta` and `expiry` alongside the value (a small hash works). Because the random term only
crosses the threshold for an unlucky few before TTL, exactly one or two readers refresh early and the
stampede never forms. No lock, no stale window.

### 3. Serve-stale-while-revalidate

Keep two TTLs: a soft "fresh until" and a hard "evict at". Past the soft TTL, serve the stale value
*and* kick off one async refresh. Readers never block; the origin sees one refresh per key per window.

## Multi-level caching

In-process LRU (per app instance) in front of Redis cuts Redis round-trips for the hottest keys. The
cost is coherence: a write must invalidate *both* levels, and different instances can hold different
local copies for up to the local TTL. Keep the local TTL very short (1-5s) so divergence is bounded,
and treat Redis as the source of truth the local cache merely fronts.

## Invalidation

- **On write, delete the key** (cache-aside) — the next read rebuilds. Simple and correct as long as
  every write path deletes.
- **Never** rely on manual invalidation *instead of* a TTL: you will miss a code path and serve stale
  forever. TTL is the backstop; explicit invalidation is the latency optimization on top.
- **Tag/group invalidation** (drop everything for a tenant): keep a set of member keys per tag and
  `DEL` them together, or namespace by a version counter you bump (`v:tenant:7 -> 12`, keys read
  `tenant:7:v12:*`) so a bump orphans the whole old generation to be evicted by LRU.

## Hot keys and big keys

- **Hot key** (one key, enormous read rate) can saturate a single shard/CPU. Mitigate with a
  per-instance local cache in front, or shard the value across N suffixed keys read at random.
- **Big key** (one huge value or a multi-million-element collection) blocks the single thread on
  every access and on eviction. Find them with `redis-cli --bigkeys` and `MEMORY USAGE <key>`; split
  big hashes/lists into smaller keyed chunks; never `DEL` a giant key on the hot path — `UNLINK` it
  (frees memory in a background thread).
