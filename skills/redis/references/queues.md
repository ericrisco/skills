# Queues — depth

Full reliable-list and Streams consumer-group implementations, stalled/pending recovery, dead-letter
queues, idempotency, and the library comparison. Client-agnostic.

## Reliable list pattern

Never `RPOP` straight into a worker: a crash between the pop and the work loses the job. Move it
atomically to a per-worker processing list, do the work idempotently, then ack by removing it. A
separate reaper requeues anything orphaned in a processing list whose worker has died.

```bash
# 1. Atomic claim: pop from the queue, push onto THIS worker's processing list, in one command.
job=$(redis-cli LMOVE jobs jobs:proc:w1 LEFT RIGHT)     # BLMOVE for a blocking variant

# 2. Do the work — idempotently, because delivery is at-least-once (see below).

# 3. Ack: remove the job from the processing list.
redis-cli LREM jobs:proc:w1 1 "$job"
```

Reaper (runs periodically): for each `jobs:proc:*`, if its worker is gone (heartbeat key expired),
`LMOVE` every element back to `jobs`. The trade-off: a job that was *almost* done but un-acked gets
re-run — hence handlers must be idempotent.

`LMOVE`/`BLMOVE` (Redis 6.2+) replace the older `RPOPLPUSH`/`BRPOPLPUSH`, which still work.

## Streams + consumer groups (preferred for reliable jobs)

Streams give per-message acks and a Pending Entries List (PEL) for free — no hand-rolled processing
list. This is the right native primitive for reliable jobs.

```bash
# Create the group once (MKSTREAM creates the stream if absent). '$' = only new messages.
redis-cli XGROUP CREATE jobs g1 '$' MKSTREAM

# Producer: append, capping growth so the stream can't grow unbounded.
redis-cli XADD jobs MAXLEN '~' 100000 '*' type email to user@x.com

# Consumer: read new messages ('>'), each delivered message enters this consumer's PEL.
redis-cli XREADGROUP GROUP g1 worker1 COUNT 10 BLOCK 5000 STREAMS jobs '>'

# Ack a finished message — removes it from the PEL.
redis-cli XACK jobs g1 <id>
```

### Stalled / pending recovery

A worker that dies leaves its in-flight messages in the PEL, un-acked. Reclaim them with
`XAUTOCLAIM` (Redis 6.2+), which transfers messages idle longer than a threshold to a live consumer:

```bash
# Claim messages in group g1 idle > 60000ms, reassigning them to worker2, starting at id 0.
redis-cli XAUTOCLAIM jobs g1 worker2 60000 0
# Inspect the backlog: XPENDING jobs g1   (summary)  /  XPENDING jobs g1 - + 10  (detail)
```

Track a delivery count per message (`XPENDING` reports it); after K deliveries, stop retrying and
route to a dead-letter stream instead of looping forever on a poison message.

### Dead-letter queue

```bash
# Poison message exceeded max deliveries: copy to a DLQ stream, then ack it off the main group.
redis-cli XADD jobs:dead '*' orig_id <id> reason max-deliveries-exceeded payload "$payload"
redis-cli XACK jobs g1 <id>
```

Trim both the main and DLQ streams (`MAXLEN ~`) so neither grows without bound. Redis 8.2 adds
`XDELEX`/`XACKDEL` for ack-and-delete in one step.

## Idempotency and at-least-once

Every Redis queue (list or stream) is **at-least-once**: a crash after work but before ack re-runs
the job. Make handlers idempotent:

- Carry an **idempotency key** (a job id or a hash of the payload). Before the side effect, `SET
  done:<key> 1 NX EX <ttl>`; if it returns nil, the job already ran — skip the side effect, just ack.
- Or make the side effect itself idempotent (upserts keyed by id, conditional writes with a fencing
  token, external APIs that accept an idempotency key).

Exactly-once delivery does not exist over a network; exactly-once *effect* is achievable only by
making the effect idempotent.

## When to use a library instead of hand-rolling

| Library | Language | You get |
| --- | --- | --- |
| **BullMQ** | TypeScript/Node | retries, delays, repeatable jobs, priorities, a dashboard, **stalled-job lock renewal** via `lockDuration`/`lockRenewTime` |
| **Sidekiq** | Ruby | multi-threaded workers, retries, scheduling, web UI |
| **RQ** | Python | simple, list-based, easy to reason about |
| **Celery** (Redis broker) | Python | mature, broad feature set, can use Redis or others |

Reach for a library the moment you need retries with backoff, scheduled/delayed jobs, priorities, or a
dashboard — do not reinvent them. BullMQ's stalled-job handling is the canonical example: a worker
holds a lock on its active job and renews it every `lockRenewTime`; if a worker dies, the lock lapses
after `lockDuration` and the job is moved back to be retried up to its attempt limit. Setting
`lockDuration` below your real job duration is the usual cause of "my jobs keep getting marked
stalled and reprocessed" — raise it above the worst-case job time (and renew), don't lower your
expectations.

Hand-roll lists/streams only for the simplest cases or when no good library exists for your runtime.
