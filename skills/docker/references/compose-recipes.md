# Compose recipes

Fuller `compose.yaml` patterns. Canonical filename is `compose.yaml`; omit `version:`; use the
`docker compose` v2 subcommand.

## Watch per stack

| Stack | `sync` paths | `rebuild` triggers |
|---|---|---|
| Node/Vite/Next | `./src`, `./public` | `package-lock.json` |
| Python/uv | `./app` | `uv.lock`, `pyproject.toml` |
| Go (live reload via `air`) | `./` | `go.mod`, `go.sum` |

`sync` copies changed files into the running container (the process must itself hot-reload).
`rebuild` rebuilds the image when a dependency manifest changes. `sync+restart` syncs then restarts
PID 1 — use it for config files the process reads only at startup. Use `ignore:` under a watch
rule to exclude noisy paths (e.g. `node_modules`).

## Healthcheck graph: postgres + redis + app

```yaml
services:
  app:
    build: .
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://postgres:dev@db:5432/app
      REDIS_URL: redis://cache:6379
    develop:
      watch:
        - { action: sync, path: ./app, target: /app/app }
        - { action: rebuild, path: ./uv.lock }
  db:
    image: postgres:17-bookworm
    environment: { POSTGRES_PASSWORD: dev, POSTGRES_DB: app }
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d app"]
      interval: 5s
      timeout: 3s
      retries: 5
    volumes: ["pgdata:/var/lib/postgresql/data"]
  cache:
    image: redis:7-bookworm
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
```

`condition: service_healthy` makes `app` wait until both backing services report healthy, instead
of merely "container started" — which avoids the classic "connection refused on boot" race.

## Profiles

```yaml
services:
  app: { build: . }
  seed:
    profiles: ["tools"]
    build: .
    command: ["python", "-m", "app.seed"]
  mailpit:
    profiles: ["tools"]
    image: axllent/mailpit:latest
```

Services with a `profiles:` key are inert unless their profile is requested:
`docker compose --profile tools up`. Use it for seeders, mail catchers, admin UIs.

## env_file vs secrets

- `env_file: [.env]` — convenient for non-sensitive dev config; values become container env.
- `secrets:` — mounts a file at `/run/secrets/<name>`; the value is not in the process environment
  and not in `docker inspect`. Prefer it for anything sensitive even in dev.

```yaml
services:
  app:
    build: .
    secrets: [db_password]
secrets:
  db_password:
    file: ./secrets/db_password.txt
```

## Override files

`docker compose` automatically merges `compose.override.yaml` on top of `compose.yaml`. Keep dev-only
bind mounts and `develop.watch` in the base for local use; create an explicit
`-f compose.yaml -f compose.prod.yaml` pair if you must describe a prod-ish stack — but that is the
edge of this skill's scope.

## When to graduate

Compose is a single-host orchestrator. The moment you need rolling deploys, multi-host scheduling,
autoscaling, or a registry/CI pipeline, stop here:

- registry push, CI build, deploy to a host, rollback → `../deployment/SKILL.md`
- horizontal autoscaling, k8s, HPA, ingress → `scaling`
- running Compose on a managed host / self-hosted PaaS → `../coolify/SKILL.md`,
  `../railway/SKILL.md`, `../fly-io/SKILL.md`
