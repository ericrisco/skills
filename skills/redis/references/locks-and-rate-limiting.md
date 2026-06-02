# Locks and rate limiting — depth

The full Redlock algorithm and its critique, lease renewal, fencing tokens, and all four
rate-limit algorithms with complete Lua. Client-agnostic.

## Single-instance lock (the baseline)

```text
SET resource:lock <random-token> NX PX <ttl-ms>   # acquire: only if absent, auto-expires
# ... protected work ...
# release via the compare-and-delete Lua below — NEVER a bare DEL
```

The token must be unguessable and unique per acquisition (a UUID or `<host>:<pid>:<rand>`), because
release is "delete only if the value is still mine":

```lua
-- KEYS[1] = lock key, ARGV[1] = my token. Returns 1 if I held and released, else 0.
if redis.call('GET', KEYS[1]) == ARGV[1] then
  return redis.call('DEL', KEYS[1])
else
  return 0
end
```

## Lease renewal (watchdog)

If protected work can outlast the TTL, the lock expires mid-task and a second worker starts. Renew
the TTL periodically — but only if you still own it (same token guard), or you will extend a lock
someone else now holds:

```lua
-- KEYS[1] = lock key, ARGV[1] = my token, ARGV[2] = new ttl ms.
if redis.call('GET', KEYS[1]) == ARGV[1] then
  return redis.call('PEXPIRE', KEYS[1], ARGV[2])
else
  return 0
end
```

Run this from a watchdog at ~`ttl/3`. If a renewal ever returns 0, you lost the lock — stop the work,
do not assume you still hold it.

## Redlock (multi-instance) and why it is contested

Redlock acquires the same lock on a majority of N independent masters (e.g. 3 of 5), each with
`SET NX PX`, and considers the lock held only if the majority succeeded *within* a small fraction of
the TTL (so the remaining validity time is still positive). Release deletes on all N.

The critique (Kleppmann; acknowledged by antirez): Redlock's safety rests on **bounded clock drift**
and **no long process pauses**. A GC pause, a hypervisor stop-the-world, or an NTP jump can let the
TTL expire on the holder's wall clock while the holder still believes it is inside the lease; a second
client then acquires, and both act. Majority-acquisition does not fix this — it is a *timing* problem,
not a *quorum* problem.

### Fencing tokens — the only real fix

Issue a **monotonically increasing token** with every successful acquisition (e.g. `INCR
resource:fence`). The protected resource (DB, file store, queue) records the highest token it has
accepted and **rejects any write carrying a lower token**. Now even a paused-then-resumed holder is
harmless: its token is stale, so its write is refused. No pure-Redis lock provides fencing; you must
add the counter and enforce it at the resource.

### Decision

- **Idempotent / best-effort work** (cron de-dup, cache warm): single-instance `SET NX PX` is fine —
  an occasional double-run is harmless.
- **Hard mutual exclusion** (money, non-idempotent side effects): a Redis lock alone is *not* a safety
  guarantee. Fence the resource, or use a real lease/consensus system (ZooKeeper, etcd, a DB advisory
  lock). Redlock buys availability across instances, not correctness under pauses.

## Rate limiting — four algorithms

Every one must be a **single atomic `EVAL`**. The classic bug is splitting count and TTL: if the
process dies between `INCR` and `EXPIRE`, the key never expires and the user is throttled forever.

### Fixed window

```lua
-- KEYS[1]=counter, ARGV[1]=limit, ARGV[2]=window-seconds. 1=allow, 0=deny.
local n = redis.call('INCR', KEYS[1])
if n == 1 then redis.call('EXPIRE', KEYS[1], ARGV[2]) end
if n > tonumber(ARGV[1]) then return 0 end
return 1
```

Cheapest (one integer per key). Flaw: allows up to ~2× the limit across a window boundary (a burst at
the end of one window plus a burst at the start of the next).

### Sliding-window log

Exact: store one timestamp per request in a sorted set, prune the old, count what remains.

```lua
-- KEYS[1]=zset, ARGV[1]=now-ms, ARGV[2]=window-ms, ARGV[3]=limit, ARGV[4]=member.
redis.call('ZREMRANGEBYSCORE', KEYS[1], 0, ARGV[1] - ARGV[2])   -- drop entries older than window
local count = redis.call('ZCARD', KEYS[1])
if count >= tonumber(ARGV[3]) then return 0 end
redis.call('ZADD', KEYS[1], ARGV[1], ARGV[4])                   -- record this request
redis.call('PEXPIRE', KEYS[1], ARGV[2])                         -- self-clean idle keys
return 1
```

Exact, but O(requests) memory per key — expensive at high limits.

### Sliding-window counter

Approximates the log with two fixed-window counters (current + previous), weighting the previous one
by how far into the current window you are. Near-exact at a fraction of the memory of the log. Keep
both counters and compute `prev * (1 - elapsed_fraction) + curr` in Lua; deny if that exceeds the limit.

### Token bucket

Allows controlled bursts: a bucket of capacity C refills at R tokens/sec; each request costs one token.

```lua
-- KEYS[1]=hash{tokens,ts}, ARGV[1]=capacity, ARGV[2]=refill/sec, ARGV[3]=now-sec, ARGV[4]=cost.
local s = redis.call('HMGET', KEYS[1], 'tokens', 'ts')
local tokens = tonumber(s[1]) or tonumber(ARGV[1])
local ts     = tonumber(s[2]) or tonumber(ARGV[3])
tokens = math.min(tonumber(ARGV[1]), tokens + (ARGV[3] - ts) * ARGV[2])   -- refill by elapsed time
if tokens < tonumber(ARGV[4]) then
  redis.call('HSET', KEYS[1], 'tokens', tokens, 'ts', ARGV[3]); return 0
end
tokens = tokens - tonumber(ARGV[4])
redis.call('HSET', KEYS[1], 'tokens', tokens, 'ts', ARGV[3])
redis.call('PEXPIRE', KEYS[1], math.ceil(tonumber(ARGV[1]) / tonumber(ARGV[2]) * 1000))
return 1
```

Smallest memory (one small hash per key), smooth average rate, configurable burst. The usual default.

### Choosing

| Need | Pick |
| --- | --- |
| Cheapest, OK with 2× edge bursts | fixed window |
| Exact, low traffic | sliding-window log |
| Near-exact, high traffic | sliding-window counter |
| Smooth rate + intentional bursts | token bucket |
