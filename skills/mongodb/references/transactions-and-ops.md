# Transactions & operations (MongoDB 8.2)

## When a transaction is the wrong tool

A single-document write — including an update that touches many fields, arrays, and subdocuments —
is **already atomic**. You only need a multi-document transaction when two or more documents must
commit or roll back together (move money between two accounts, flip an order and append a ledger
entry). If you can restructure so the atomic unit is one document, do that instead: it is faster and
needs no replica set.

Transactions require a **replica set or sharded cluster**; they do not run on a standalone `mongod`.
The default has a **60-second** time limit — keep the body short; a long-running transaction holds
locks and is more likely to abort.

## Retry wrappers

Two distinct retries are mandatory:

- Retry the whole transaction body when the error carries the **`TransientTransactionError`** label.
- Retry the **commit** when it carries **`UnknownTransactionCommitResult`** (the commit's outcome is
  unknown; retrying is safe because commit is idempotent).

`withTransaction` does both for you — prefer it.

```javascript
const session = db.getMongo().startSession();
try {
  session.withTransaction(() => {
    const accts = session.getDatabase("bank").accounts;
    accts.updateOne({ _id: "A" }, { $inc: { balance: NumberDecimal("-100") } }, { session });
    accts.updateOne({ _id: "B" }, { $inc: { balance: NumberDecimal("100")  } }, { session });
  }, { readConcern: { level: "snapshot" }, writeConcern: { w: "majority" } });
} finally {
  session.endSession();
}
```

If you must hand-roll (no `withTransaction`), the loop is: start → run body → commit; on a
`TransientTransactionError` label, restart the whole thing; on `UnknownTransactionCommitResult`,
retry only `commitTransaction()`. Cap retries with a deadline so a persistent error can't spin
forever.

## Read & write concern semantics

- **`w:"majority"`** — acknowledged once a majority of replica-set members have the write; it cannot
  be rolled back by a failover. Use it for money and state transitions.
- **`w:1`** — acknowledged by the primary only; a failover before replication can roll it back. Fine
  for logs and fire-and-forget.
- **read concern `"majority"`** — returns data acknowledged by a majority (no dirty reads).
- **read concern `"snapshot"`** — a consistent point-in-time view; the transaction default.
- **read concern `"local"`** — the node's latest, possibly un-replicated; fastest, weakest.
- A **causally consistent session** lets a client read its own writes across operations.

## Atlas tiers

| Tier | For | Limits / features |
| --- | --- | --- |
| **M0** | learning, tiny prototypes | free forever, ≤ 5 GB, shared, no SLA; not for real Vector Search |
| **Flex** (GA Feb 2025) | small prod / spiky load | $8 base, capped at $30/mo, 100 ops/sec (burst 500), 5 GB; supports Atlas Search, Vector Search, Change Streams, Triggers |
| **M10+** dedicated | production, scale, isolation | from ~$0.08/hr (~$57/mo); dedicated compute, full feature set |

Legacy Serverless / M2 / M5 instances were auto-migrated to Flex. Move off M0 before you depend on
Search or Vector Search at any real volume.

## Atlas Search & Vector Search

As of MongoDB 8.2, Search and Vector Search ship with Community and Enterprise Server, not just
Atlas. They are built on a separate search index you define on a collection; queries run through the
`$search` / `$vectorSearch` aggregation stages. For hybrid (keyword + semantic) ranking, fuse the two
rankings with `$scoreFusion` (8.2) rather than blending scores in application code.

```javascript
// Vector similarity search (index defined out of band on the embedding field).
db.docs.aggregate([
  { $vectorSearch: {
      index: "embedding_idx",
      path: "embedding",
      queryVector: queryEmbedding,
      numCandidates: 200,
      limit: 10
  }}
])
```

## Queryable Encryption

Encrypts fields client-side; the server stores and queries ciphertext without ever seeing
plaintext. The supported query types have grown:

- **8.0** added **range** queries (`$lt/$lte/$gt/$gte`) on encrypted fields — previously only `$eq`.
- **8.2** added **prefix, suffix, and substring** query types on encrypted fields.

Use it for regulated/sensitive fields (SSNs, card data). Never store such a value, or any database
credential, as plaintext.

## Role-based access control

Grant least privilege: a per-application user scoped with the built-in roles (`readWrite` on one
database, `read` for reporting users) or a custom role, never the cluster-admin user for app
traffic. The connection string carries the credential — keep it in a secret store, not in the repo.

## Connection-pool knobs

The driver maintains a pool per `MongoClient`; create one client and reuse it for the process
lifetime (a new client per request exhausts connections — the classic serverless foot-gun).

| Option | What it controls |
| --- | --- |
| `maxPoolSize` (default 100) | upper bound on concurrent connections per client |
| `minPoolSize` | warm connections kept open to avoid cold-start latency |
| `maxIdleTimeMS` | close a connection idle this long (useful behind a proxy/firewall) |
| `waitQueueTimeoutMS` | how long an operation waits for a free connection before erroring |

In a serverless/Lambda runtime, cache the client across invocations and keep `maxPoolSize` small —
many short-lived containers each opening a large pool overruns the server's connection limit.

## Change streams

A resumable feed of collection/database/cluster events, built on the oplog (needs a replica set).
Filter with a pipeline and persist the `resumeToken` so a restart picks up without gaps.

```javascript
const cs = db.orders.watch(
  [{ $match: { operationType: { $in: ["insert", "update"] } } }],
  { fullDocument: "updateLookup" }   // include the full post-update document
);
while (cs.hasNext()) { const change = cs.next(); /* process; save change._id as resume token */ }
```
