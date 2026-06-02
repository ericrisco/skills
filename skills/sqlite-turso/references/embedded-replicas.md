# Embedded replicas — deep reference

Offloaded from SKILL.md because it is branch-specific and longer than the body should carry. Read
this when you are actually building or operating an embedded-replica deployment.

## What a replica actually is

An embedded replica is a real local SQLite file (`url: "file:local.db"`) plus a `syncUrl` pointing at
a remote primary. The client maintains the local copy and pulls a stream of **frames** (the unit of
replication — roughly a batch of committed changes) from the primary. Reads execute against the local
file with in-process latency. Writes are forwarded to the primary; they do not mutate the local file
directly, they come back via the next sync.

This is why the local file is mandatory: there is no replica without somewhere local to materialize
the data. A `syncUrl` next to a `libsql://` url is a contradiction — there is no local store to sync
into, so the client behaves as a plain remote client and never replicates.

## Sync mechanics and frame numbers

`await client.sync()` returns `{ frame_no, frames_synced }`:

- `frame_no` — the replication frame the local replica is now at (a monotonically advancing
  position in the primary's change log). Useful for logging/observability and reasoning about how far
  behind a replica was.
- `frames_synced` — how many frames this particular `sync()` call pulled. `0` means the replica was
  already current.

Two ways to drive sync:

- **`syncInterval` (seconds)** in `createClient` — background periodic pull. Good for read-mostly
  apps that tolerate eventual consistency up to one interval. Pick the interval from how stale a read
  may be, not from a default.
- **Manual `client.sync()`** — pull on demand: at request start, after a known remote write, on app
  resume from background. Combine both: a slow `syncInterval` safety net plus targeted manual syncs
  where freshness matters.

Calling `sync()` on a client without a `syncUrl` + local `file:` (a remote-only or pure HTTP/WS
client) throws `LibsqlError` with code `SYNC_NOT_SUPPORTED`. Guard the call by construction — only
sync clients you built as replicas.

## `readYourWrites` semantics

Default is `true`. With it on, a write you issue through the client is immediately visible to your
own subsequent reads on that client, even before the next background sync — the client tracks your
write position and waits for the local replica to catch up to it on read. This is what most apps
want: you click "save", you re-read, you see your change.

Set `readYourWrites: false` only when you deliberately want a sync's effect to be observable on its
own timeline — e.g. tests that assert "this row is not visible until I explicitly `sync()`", or
benchmarks measuring pure replica staleness. If you turn it off in a normal app you will get
confusing "I just wrote that, why is it gone?" reports.

## Offline and bidirectional writes

Classic libSQL embedded replicas are read-local / write-through-primary: you need connectivity to
the primary to commit a write. True **offline writes** with bidirectional sync (write locally while
disconnected, reconcile later) is a capability of **Turso Database (the Rust rewrite)**, not the
production libSQL path. If a requirement says "must accept writes fully offline and merge later",
that is the Rust engine's roadmap territory — flag it as not-yet-default-production rather than
promising it on libSQL today.

## Database-per-user / per-tenant patterns

Turso's unlimited-databases free tier makes a separate database per tenant economical, which gives
hard data isolation without row-level-security gymnastics.

- **One primary per tenant**, each with its own `libsql://` URL and token. Mint tokens per database
  with the `turso` CLI.
- **Connection management**: do not create one `createClient` per request — cache clients keyed by
  tenant id (a `Map<tenantId, Client>`), and reuse. Each embedded replica holds an open local file;
  thousands of unmanaged replicas will exhaust file handles and disk.
- **Replica per tenant** only where the access pattern is local-heavy for that tenant (e.g. a desktop
  or edge node dedicated to one tenant). For a multi-tenant server hitting many tenants, prefer
  remote clients (shape #2) and let the edge do the work, or you will be syncing a fleet of files.
- **Provisioning**: tenant signup creates a database (`turso db create`) and a scoped token; store
  the URL/token in your secrets store keyed by tenant, never in source.

## Staleness, failure, and consistency

- A replica serves the **last successfully synced state**. If sync fails (network, auth), reads keep
  working against the stale local copy — this is a feature for availability, a trap for correctness.
  Surface sync errors; do not swallow them.
- `frames_synced: 0` over many calls when you expect changes means the primary genuinely has nothing
  new, or your client is pointed at the wrong primary — check `syncUrl` and token scope.
- Writes are linearized at the primary, so cross-tenant/global invariants belong at the primary, not
  asserted against a possibly-stale replica.
- For "must always read the absolute latest", call `sync()` immediately before the read, or use a
  remote-only client (shape #2) for that path and accept the round-trip.

## Where this hands off

- Type-safe schema and queries on top of any of these clients → `drizzle-orm`.
- Versioned, ordered, reversible schema changes (up/down files, a runner) → `db-migrations`. This
  reference only covers ad-hoc DDL through `execute`/`batch`.
- Backup/restore and point-in-time strategy as the goal → `backups`.
- Generic SQL authoring independent of engine (window functions, query tuning) → `sql`.
