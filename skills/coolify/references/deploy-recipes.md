# Deploy recipes — build packs & a lint-clean compose

Source facts: Coolify GitHub + v4.1 release notes, accessed 2026-06-02.

## Build-pack decision

| Build pack | Reach for it when | Trade-off |
| --- | --- | --- |
| **Nixpacks** (default) | Standard app; want zero config | Auto-detects runtime; least control over the build |
| **Railpack** (v4.1, beta) | Need build-time env vars, config merge, or multi-stage control Nixpacks can't express | Newer/beta; expect rougher edges than Nixpacks |
| **Dockerfile** | You already have (or want to own) the build | You maintain the Dockerfile; pin the base image |
| **docker-compose** | Multi-service app deployed as one unit | You own the compose — keep it lint-clean (below) |

Start with Nixpacks. Escalate to Railpack only when a build-time env var or multi-stage step is required.
Drop to a Dockerfile when you need full control of the build. Use compose when one deploy is several
services. For image-authoring depth (multi-stage layering, cache mounts) that is the `docker` skill.

## Git source & env

1. Connect the Git provider (GitHub/GitLab app, or a deploy key) and pick the branch.
2. Enable auto-deploy on push, or trigger the deploy from CI (that's the `github-actions` skill).
3. Set every secret as a **Coolify environment variable / secret**, injected at runtime. Never bake a
   secret into the image and never commit it to the compose — a baked secret ships in every layer.
4. Add a **named volume** for any path that must survive a redeploy (uploads, sqlite, caches you care
   about). Anonymous volumes are wiped on recreate.
5. Add the domain (`app.example.com`), point its A record at the box (`domains-dns`), and Traefik issues
   the Let's Encrypt cert automatically on 80/443.

## A worked, lint-clean compose (the verify.sh target)

This is the shape `scripts/verify.sh` asserts: secrets are env-refs (no literals), every DB has a named
volume, services have a `healthcheck:`, and the build-context app does not float on `:latest`. Coolify
injects the `${...}` values from its secrets store.

```yaml
# docker-compose.yml — GOOD: env-ref secrets, named volume, healthchecks, pinned db image.
services:
  web:
    build:
      context: .            # build-context service: pinned via the Dockerfile's FROM, not :latest here
    restart: unless-stopped
    environment:
      # Secrets are REFERENCES, injected by Coolify — never literals committed to git.
      DATABASE_URL: ${DATABASE_URL}
      APP_SECRET: ${APP_SECRET}
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    labels:
      # Coolify/Traefik routing + auto-SSL is wired from the UI domain field; labels shown for reference.
      - "traefik.enable=true"

  db:
    image: postgres:16          # pinned major tag, not :latest
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}   # env-ref, injected by Coolify
    volumes:
      - pgdata:/var/lib/postgresql/data         # NAMED volume — survives recreate
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
    # NOTE: no `ports:` mapping — db is reached over the internal network, not exposed publicly.

volumes:
  pgdata:                        # declared named volume
```

```yaml
# BAD — every line here is a verify.sh failure or a production incident:
services:
  web:
    image: myapp:latest                 # floating tag — irreproducible redeploys
    environment:
      DATABASE_URL: postgres://app:hunter2@db:5432/app   # hardcoded secret literal in git
    # no healthcheck
  db:
    image: postgres:latest              # floating tag
    environment:
      POSTGRES_PASSWORD: hunter2         # hardcoded secret literal
    ports:
      - "5432:5432"                     # DB port exposed to the public internet
    # no volume — data is wiped on every recreate
```

## Why each rule earns its place

- **Pinned image** — `:latest` silently changes the base; a redeploy you can't reproduce is a redeploy you
  can't roll back.
- **Named volume on the DB** — recreate without it and the data is gone. This is the top Coolify footgun.
- **Healthcheck** — Coolify/Traefik use it to know when the container is actually ready; without it,
  traffic hits a half-started app and `depends_on: service_healthy` can't gate startup.
- **Env-ref secrets** — a literal in the compose leaks in git history and image layers. Inject from
  Coolify's secret store.
- **No public DB port** — reach the database over the internal hostname; an exposed port is scanned in
  minutes.
