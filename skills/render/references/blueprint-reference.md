# render.yaml — full key reference and recipes

The exhaustive Blueprint surface. Dated 2026-06-02 against render.com/docs/blueprint-spec.
Pull the key you need; copy a recipe and adapt.

## Top-level keys

| Key | What |
| --- | --- |
| `services` | every web / pserv / worker / cron / keyvalue service |
| `databases` | managed Postgres instances |
| `envVarGroups` | named, reusable env var bundles shared across services |
| `projects` | group services into a Render project |
| `previews` | preview-environment config (`generation: automatic \| manual \| off`) |

## Common service keys (web / pserv / worker / cron)

| Key | Notes |
| --- | --- |
| `type` | `web` \| `pserv` \| `worker` \| `cron` \| `keyvalue` |
| `name` | unique within the workspace |
| `runtime` | `node` \| `python` \| `docker` \| `image` \| `static` \| `go` \| `ruby` \| `elixir` \| `rust` (required except `keyvalue`) |
| `region` | `oregon` \| `ohio` \| `virginia` \| `frankfurt` \| `singapore` |
| `plan` | `free` \| `starter` \| `standard` \| `pro` \| `pro plus` \| `pro max` \| `pro ultra` |
| `buildCommand` | build step (native runtimes) |
| `startCommand` | process entrypoint |
| `preDeployCommand` | runs once before the new instance serves traffic — migrations |
| `healthCheckPath` | path Render polls to gate zero-downtime rollout (web only) |
| `autoDeployTrigger` | `commit` \| `checksPass` \| `off` |
| `numInstances` | fixed replica count |
| `scaling` | `{ minInstances, maxInstances, targetCPUPercent, targetMemoryPercent }` |
| `disk` | `{ name, mountPath, sizeGB }` — pins to a single instance |
| `rootDir` | subdirectory to treat as the build root (monorepos) |
| `buildFilter` | `{ paths, ignoredPaths }` — only deploy when matching files change |
| `envVars` | env var list (see reference forms below) |

### Docker-runtime keys

| Key | Notes |
| --- | --- |
| `runtime: docker` | build from a Dockerfile in the repo |
| `dockerfilePath` | path to the Dockerfile (e.g. `./apps/api/Dockerfile`) |
| `dockerContext` | build context directory |
| `runtime: image` | deploy a prebuilt image — `image: { url, creds }` |

### Static-site keys (`runtime: static`)

| Key | Notes |
| --- | --- |
| `staticPublishPath` | directory of built assets (e.g. `dist`, `build`, `out`) |
| `routes` | rewrite/redirect rules: `{ type: rewrite \| redirect, source, destination }` |
| `headers` | `{ path, name, value }` custom response headers |

### Cron-only keys

| Key | Notes |
| --- | --- |
| `schedule` | **required** cron expression; run killed after 12h; one active run at a time |

## envVars reference forms

| Form | Resolves to |
| --- | --- |
| `{ key, value }` | a literal (avoid for secrets) |
| `{ key, sync: false }` | typed once at setup, not stored in the repo |
| `{ key, generateValue: true }` | random secret Render generates and stores |
| `{ key, fromDatabase: { name, property } }` | `property`: `connectionString`, `host`, `port`, `user`, `password`, `database` |
| `{ key, fromService: { name, type, property } }` | `property`: `hostport`, `host`, `port` (and for keyvalue, `connectionString`) |
| `{ fromGroup: <name> }` | pull a whole env var group |

## Database keys (`databases:`)

| Key | Notes |
| --- | --- |
| `name` | unique name |
| `plan` | `free` (expires 30 days after creation, 14-day grace, one per workspace) \| `starter` \| `standard` \| … |
| `postgresMajorVersion` | e.g. `"17"` |
| `region` | same enum as services |
| `diskSizeGB` | storage size |
| `databaseName` / `user` | optional explicit names |
| `readReplicas` | `[{ name }]` read-replica list |
| `highAvailability` | `{ enabled: true }` (paid) |
| `previewPlan` | plan used for preview-env databases |
| `ipAllowList` | `[{ source, description }]` — `0.0.0.0/0` for public, omit for internal-only |

## Recipe 1 — Next.js web + Postgres

```yaml
databases:
  - name: web-db
    plan: starter
    postgresMajorVersion: "17"

services:
  - type: web
    name: nextjs-app
    runtime: node
    plan: starter
    buildCommand: npm ci && npm run build
    startCommand: npm start           # next start binds 0.0.0.0:$PORT by default
    healthCheckPath: /api/health
    preDeployCommand: npx prisma migrate deploy
    envVars:
      - key: DATABASE_URL
        fromDatabase: { name: web-db, property: connectionString }
      - key: NEXTAUTH_SECRET
        generateValue: true
      - key: NODE_ENV
        value: production
```

## Recipe 2 — FastAPI web + worker + cron + Key Value

```yaml
databases:
  - name: api-db
    plan: starter
    postgresMajorVersion: "17"

services:
  - type: keyvalue
    name: cache
    plan: starter
    ipAllowList: []                   # internal only

  - type: web
    name: api
    runtime: python
    plan: starter
    buildCommand: pip install -r requirements.txt
    startCommand: gunicorn -k uvicorn.workers.UvicornWorker app.main:app --bind 0.0.0.0:$PORT
    healthCheckPath: /health
    preDeployCommand: alembic upgrade head
    envVars:
      - key: DATABASE_URL
        fromDatabase: { name: api-db, property: connectionString }
      - key: REDIS_URL
        fromService: { name: cache, type: keyvalue, property: connectionString }

  - type: worker
    name: tasks
    runtime: python
    plan: starter
    buildCommand: pip install -r requirements.txt
    startCommand: celery -A app.worker worker -l info
    envVars:
      - key: DATABASE_URL
        fromDatabase: { name: api-db, property: connectionString }
      - key: REDIS_URL
        fromService: { name: cache, type: keyvalue, property: connectionString }

  - type: cron
    name: send-digest
    runtime: python
    schedule: "*/5 * * * *"           # every 5 minutes
    buildCommand: pip install -r requirements.txt
    startCommand: python -m app.jobs.digest
    envVars:
      - key: DATABASE_URL
        fromDatabase: { name: api-db, property: connectionString }
```

## Recipe 3 — Docker monorepo (rootDir + dockerfilePath + buildFilter)

```yaml
services:
  - type: web
    name: api
    runtime: docker
    rootDir: apps/api
    dockerfilePath: apps/api/Dockerfile
    buildFilter:
      paths:
        - apps/api/**
        - packages/shared/**          # only redeploy when these change
    plan: starter
    healthCheckPath: /healthz
    envVars:
      - key: PORT
        value: "10000"                # your Dockerfile CMD must bind 0.0.0.0:$PORT
```

## Recipe 4 — static SPA with rewrites and headers

```yaml
services:
  - type: web
    name: spa
    runtime: static
    buildCommand: npm ci && npm run build
    staticPublishPath: dist
    routes:
      - type: rewrite
        source: /*
        destination: /index.html      # SPA fallback so client routing works
    headers:
      - path: /*
        name: X-Frame-Options
        value: DENY
      - path: /assets/*
        name: Cache-Control
        value: public, max-age=31536000, immutable
```
