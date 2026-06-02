# Migrations and the Prisma 6 → 7 upgrade

Depth offloaded from `SKILL.md`. Prisma Migrate *mechanics* live here. ORM-independent
evolution strategy (expand/contract, dual-write, zero-downtime backfills) is
`../db-migrations/SKILL.md`.

## The migrate workflow

```bash
prisma migrate dev      # development: create migration + apply + regenerate client (shadow DB)
prisma migrate deploy   # CI/prod: apply pending migrations only — never generate, never reset
prisma db push          # prototyping: sync schema to DB, NO migration file written
prisma migrate diff     # compute the diff between two schema states (scripting/baselining)
prisma migrate resolve  # mark a migration applied/rolled-back without running it (drift fix)
prisma db seed          # run the seed script declared in prisma.config.ts
```

| Command | Environment | Writes a migration file? | Can reset data? |
| --- | --- | --- | --- |
| `migrate dev` | development only | yes | yes (on drift it can reset) |
| `migrate deploy` | CI / production | no (applies existing) | no |
| `db push` | spikes / prototyping | no | yes (`--accept-data-loss`) |

### The shadow database

`migrate dev` needs a second, disposable database (the shadow DB). It replays your migration
history into the shadow DB to detect drift — i.e. whether the real database schema diverged
from what the migrations describe. The shadow DB must be a separate database the user can
create/drop; never point it at production. In v7 it is configured through `prisma.config.ts`.

### CI / production deploy

```bash
# In CI, after building, against the real database:
prisma migrate deploy
```

`migrate deploy` applies every pending migration in order and stops. It never creates a
migration, never opens a shadow DB, never resets. This is the only migrate command that
should run against production.

## Recovering from drift and failed migrations

Drift = the database schema no longer matches the migration history (someone changed the DB by
hand, a migration half-applied, etc.). `migrate dev`/`deploy` will refuse to proceed.

1. **A migration failed mid-apply.** Fix the underlying cause (bad SQL, missing extension),
   then tell Prisma how to treat the failed entry:
   ```bash
   prisma migrate resolve --rolled-back "20260601_add_index"   # you reverted it
   # or
   prisma migrate resolve --applied     "20260601_add_index"   # you finished it by hand
   ```
2. **Never edit a migration that was already applied** anywhere. The migration file is a
   historical record; changing it makes every other environment drift. Create a new migration
   instead.
3. **Inspect the gap** with `prisma migrate diff` between the schema and the database before
   you decide.

## Baselining an existing database

When you adopt Prisma on a database that already has tables (no Prisma history):

```bash
mkdir -p prisma/migrations/0_init
prisma migrate diff \
  --from-empty \
  --to-schema-datamodel prisma/schema.prisma \
  --script > prisma/migrations/0_init/migration.sql
prisma migrate resolve --applied 0_init   # mark the baseline as already applied
```

This records the current state as migration `0_init` without re-running it, so future
`migrate dev`/`deploy` only apply changes after the baseline.

## Seeding

Declare the seed command in `prisma.config.ts`, then run `prisma db seed`:

```ts
// prisma.config.ts
import { defineConfig } from "prisma/config";
export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: { seed: "tsx prisma/seed.ts" },
});
```

```ts
// prisma/seed.ts
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) });

await prisma.user.upsert({
  where: { email: "admin@example.com" },
  create: { email: "admin@example.com", role: "ADMIN" },
  update: {},
});
await prisma.$disconnect();
```

Use `upsert` in seeds so re-running is idempotent.

## The Prisma 6 → 7 upgrade

Four mandatory changes. Miss any and the client will not build or will throw at runtime.

### 1. Generator: `prisma-client-js` → `prisma-client` with required `output`

```prisma
// v6
generator client {
  provider = "prisma-client-js"
}

// v7 — output is REQUIRED; client is no longer emitted into node_modules
generator client {
  provider = "prisma-client"
  output   = "../src/generated/prisma"
}
```

Then change every import from `@prisma/client` to your generated path:

```ts
// v6
import { PrismaClient } from "@prisma/client";
// v7
import { PrismaClient } from "../src/generated/prisma/client";
```

### 2. Driver adapter REQUIRED on the constructor

```ts
// v6: bare constructor worked
const prisma = new PrismaClient();

// v7: must pass an adapter (or accelerateUrl), else
// "requires either adapter or accelerateUrl"
import { PrismaPg } from "@prisma/adapter-pg";
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) });
```

Adapter packages by database: `@prisma/adapter-pg` (Postgres), `-better-sqlite3` (SQLite),
`-libsql` (libSQL/Turso), `-mariadb` (MySQL/MariaDB), `-mssql` (SQL Server), `-d1`
(Cloudflare D1). For Accelerate, pass `accelerateUrl` instead of `adapter`.

### 3. Connection config moves to `prisma.config.ts`

`url`, `directUrl`, and `shadowDatabaseUrl` in the `datasource` block are deprecated in v7.

```prisma
// v6 datasource
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// v7 datasource — provider only
datasource db {
  provider = "postgresql"
}
```

```ts
// v7: prisma.config.ts carries the connection
import "dotenv/config";
import { defineConfig } from "prisma/config";
export default defineConfig({
  schema: "prisma/schema.prisma",
  datasource: { url: process.env.DATABASE_URL! },
  migrations: { seed: "tsx prisma/seed.ts" },
});
```

### 4. Rust-free: delete `binaryTargets`

The query engine is TypeScript in v7 — no native binaries ship, queries run ~3x faster, and
bundles are ~90% smaller. `binaryTargets` no longer exists; remove it from the generator
block. Nothing replaces it.

### After the changes

```bash
npm i prisma@latest @prisma/client@latest @prisma/adapter-pg@latest
prisma generate          # regenerate into the new output path
```

Forward-looking note: "Prisma Next" — the future fully-TypeScript foundation, first announced
2026-03-04 in [The Next Evolution of Prisma ORM](https://www.prisma.io/blog/the-next-evolution-of-prisma-orm),
reached Early Access in May 2026 per the
[Prisma Next Roadmap](https://www.prisma.io/blog/prisma-next-roadmap) (2026-03-20, accessed
2026-06-02). It is **not** the install default. The latest stable 7.x is 7.7.0 (2026-04-07)
per the [Prisma changelog](https://www.prisma.io/changelog); pin `>=7.7` and stay on the
stable line for production work.
