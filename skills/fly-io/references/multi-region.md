# Multi-region playbook

Most deploys do not need this — run Machines in more regions and let anycast do the rest. Reach here when you have **state** that must stay correct across regions. Sources: https://fly.io/docs/networking/dynamic-request-routing/ , https://fly.io/docs/blueprints/multi-region-fly-replay/ , https://fly.io/docs/launch/scale-count/ (accessed 2026-06-02).

## Decide the shape

| Your state lives in... | Pattern |
| --- | --- |
| Nowhere local (DB is external/managed, app is stateless) | **Stateless replicate** — just add regions |
| A Fly Volume / embedded DB (SQLite, LiteFS) | **Primary + read replicas** with `fly-replay` write forwarding |
| Fly Postgres | One primary region; route writes there, reads to local replicas |

## Stateless replicate

The easy path. No volumes, no write coordination.

```bash
fly scale count 1 --region iad,ams,syd   # one Machine in each of three regions
fly scale show
```

Anycast sends each caller to the nearest Machine. All Machines are identical and talk to the same external datastore. Done.

## Primary + read replicas (fly-replay write forwarding)

When reads can be local but **writes must hit one region** (the `primary_region`), use the `fly-replay` header. Replicas serve reads instantly; on a write, the app tells the Proxy to replay the entire request in the primary region.

Header forms the app can return:

```text
fly-replay: region=iad        # replay this request in region iad
fly-replay: instance=<id>      # replay on a specific Machine
fly-replay: app=other-app      # replay against a different app
fly-replay: elsewhere=true     # "not me" — let the Proxy pick another Machine
```

Sketch (Node/Express), forwarding writes to the primary region:

```javascript
const PRIMARY = process.env.PRIMARY_REGION;   // Fly injects PRIMARY_REGION
const HERE    = process.env.FLY_REGION;       // and FLY_REGION for the current Machine

app.use((req, res, next) => {
  const isWrite = req.method !== "GET" && req.method !== "HEAD";
  if (isWrite && HERE !== PRIMARY) {
    res.set("fly-replay", `region=${PRIMARY}`);
    return res.status(409).end();   // body is discarded; Proxy re-runs the request in PRIMARY
  }
  next();
});
```

Why a status like 409: the response is never sent to the client — the Proxy intercepts the `fly-replay` header and re-runs the original request (method, path, body) in the target. Your replica code just needs to *refuse locally and tag it*.

`PRIMARY_REGION` and `FLY_REGION` are environment variables Fly injects into every Machine — read them to know "am I the writer."

## Volume strategy across regions

- A volume is pinned to one Machine in one region; there is no cross-region replication.
- For per-region read replicas, give **each region its own volume** and replicate at the application layer.
- **LiteFS** is Fly's distributed SQLite layer: it ships the primary's writes to replica nodes and integrates with `fly-replay` so writes route to the primary automatically. Use it when you want SQLite semantics with multi-region reads.
- For Postgres, run a primary in `primary_region` and read replicas elsewhere; send writes to the primary (via connection routing or `fly-replay`). Operating the engine itself belongs to ../postgresdb/SKILL.md.

## Capacity caveat

`fly scale count N --region a,b,c` places N Machines in **each** listed region. If **any** region is out of capacity the whole operation fails atomically — nothing is placed. Retry with fewer regions, a different code (`fly platform regions` for alternatives), or place granularly with `fly machine clone <id> --region <code>`.
