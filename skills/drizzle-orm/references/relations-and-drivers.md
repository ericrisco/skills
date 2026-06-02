# Drizzle: driver matrix & v1↔v2 relations migration

Offloaded depth for `../SKILL.md`. Facts current as of 2026-06-02: npm `latest` is
`drizzle-orm@0.45.2` (0.45 line `latest` since 2025-12-04), and the `rc` dist-tag is
`1.0.0-rc.3` (2026-05-18).

## Driver entrypoint matrix

`drizzle()` is imported from a driver-specific path and wraps that driver's own client. Match the
import to your database and host runtime.

| Database / host | Import | Client dep | Notes |
|---|---|---|---|
| Postgres (Node, pooled) | `drizzle-orm/node-postgres` | `pg` | `new Pool(...)`; classic Node server |
| Postgres (postgres-js) | `drizzle-orm/postgres-js` | `postgres` | fast; fine for Node and long-lived workers |
| Neon (HTTP, edge) | `drizzle-orm/neon-http` | `@neondatabase/serverless` | HTTP — no TCP; ideal for edge/serverless. Platform setup → `../neon/SKILL.md` |
| Neon (WebSocket) | `drizzle-orm/neon-serverless` | `@neondatabase/serverless` | supports transactions over WS |
| Turso / libSQL | `drizzle-orm/libsql` | `@libsql/client` | SQLite-compatible; edge. Platform → `../sqlite-turso/SKILL.md` |
| PlanetScale | `drizzle-orm/planetscale-serverless` | `@planetscale/database` | MySQL over HTTP; serverless. Platform → `../planetscale/SKILL.md` |
| MySQL (Node) | `drizzle-orm/mysql2` | `mysql2` | standard MySQL server |
| SQLite (Node native) | `drizzle-orm/better-sqlite3` | `better-sqlite3` | synchronous local SQLite |
| SQLite (Bun) | `drizzle-orm/bun-sqlite` | built into Bun | Bun runtime only |
| SQLite (`node:sqlite`) | `drizzle-orm/node-sqlite` | Node ≥ built-in | auto-detected by recent drizzle-kit for migrate + Studio |

Supabase: it is Postgres — connect with `postgres-js` or `node-postgres` against the Supabase
connection string. Platform/auth specifics → `../supabase/SKILL.md`.

### Edge / serverless caveats

- Edge runtimes (Vercel Edge, Cloudflare Workers) have no TCP sockets — use HTTP drivers
  (`neon-http`, `planetscale-serverless`, libSQL HTTP).
- HTTP drivers run each statement as a separate request; multi-statement interactive transactions
  need a WebSocket driver (`neon-serverless`) or a pooled TCP connection.
- Create the client at module scope and reuse it; do not open a new client per request in a
  long-lived process.

### Connect shapes

```ts
// node-postgres
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
export const db = drizzle(new Pool({ connectionString: process.env.DATABASE_URL }), { schema });

// neon-http (edge)
import { drizzle } from 'drizzle-orm/neon-http';
import { neon } from '@neondatabase/serverless';
export const db = drizzle(neon(process.env.DATABASE_URL!), { schema });

// libsql / Turso
import { drizzle } from 'drizzle-orm/libsql';
import { createClient } from '@libsql/client';
export const db = drizzle(createClient({ url: process.env.TURSO_URL!, authToken: process.env.TURSO_TOKEN }), { schema });
```

## Relations v1 vs v2

### 0.45 / v1-compat — `relations()`

Define relations next to the tables, pass the whole module as `{ schema }`.

```ts
import { relations } from 'drizzle-orm';

export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}));
export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, { fields: [posts.authorId], references: [users.id] }),
}));
```

```ts
import * as schema from './schema';
export const db = drizzle(client, { schema });

const data = await db.query.users.findMany({ with: { posts: true } });
```

### v1.0 beta — `defineRelations()`

One call describes every relation; pass the result as `{ relations }`.

```ts
import { defineRelations } from 'drizzle-orm';
import * as schema from './schema';

export const relations = defineRelations(schema, (r) => ({
  users: { posts: r.many.posts() },
  posts: { author: r.one.users({ from: r.posts.authorId, to: r.users.id }) },
}));
```

```ts
export const db = drizzle(client, { relations });

// db.query is RQBv2
const data = await db.query.users.findMany({ with: { posts: true } });

// db._query keeps the v1 syntax for back-compat during migration
const legacy = await db._query.users.findMany({ with: { posts: true } });
```

### Migration walkthrough (v1 → v2)

1. Upgrade `drizzle-orm` to `1.0.0-beta.x` and `drizzle-kit` to the matching beta.
2. Keep tables in `schema.ts` unchanged — only the relation declarations move.
3. Replace each `relations(table, ...)` block with one entry in a single `defineRelations(schema, ...)`.
4. Swap `drizzle(client, { schema })` → `drizzle(client, { relations })`.
5. New code calls `db.query`; existing v1 relational calls can stay on `db._query` until ported.
6. Do not leave both `relations()` and `defineRelations` active for the same tables — pick one.

## Decision: relational query vs manual join

- **Relational query (`db.query` + `with`)** → nested reads: a user with their posts as a tree. The
  builder returns shaped objects.
- **Manual `.leftJoin()` / `.innerJoin()`** → flat projections, aggregates, `GROUP BY`, or when you
  need exact control over the emitted SQL. Returns rows, not trees; you assemble the shape.
