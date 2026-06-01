---
name: deployment
description: "Use when containerizing an app, writing a Dockerfile, setting up GitHub Actions CI/CD, or deploying to Coolify — multi-stage builds (FastAPI/uv, Go/distroless, Next.js standalone, Flutter web, Postgres), BuildKit build secrets, image scanning (trivy/hadolint), OIDC to registries (no long-lived secrets), least-privilege GITHUB_TOKEN, zero-downtime/rolling deploys, env/secrets flow GitHub→Coolify, healthchecks, and rollback strategy. Trigger phrases: 'dockerize', 'write a Dockerfile', 'CI pipeline', 'GitHub Actions', 'deploy', 'ship it', 'Coolify', 'docker-compose for local dev'."
origin: risco
---

# Ship it — Docker, GitHub Actions, Coolify

Take any app in this repo from source → hardened container → green CI/CD → live on
Coolify, with secrets that never leak into image layers or logs, and a defined rollback
path.

```text
source → Dockerfile (multi-stage) → CI (lint·test·build·scan) → registry (ghcr) → Coolify (rolling) → live + rollback
```

## When to use / When NOT to use

**When to use:**

- Authoring or auditing a `Dockerfile`, `.dockerignore`, or `compose.yaml`.
- Writing or hardening `.github/workflows/*.yml` (build, test, scan, release, deploy).
- Wiring a service onto Coolify: build-pack choice, env/secrets, domains, healthcheck, auto-deploy, previews, rollback.
- Designing the secrets flow GitHub → registry → Coolify, or choosing rolling vs blue-green.

**When NOT to use:**

- Kubernetes / Helm / ECS / Nomad orchestration → out of scope (this skill targets Docker + GHA + Coolify). Say so and stop.
- Application runtime code, DB schema/migration logic, or business logic → wrong skill (see the per-stack skills below).
- Cloud IaC (Terraform, Pulumi, CloudFormation) → out of scope; only the GHA↔cloud **OIDC handshake** is covered, not provisioning.
- Pure local dev with no container ambition → likely overkill; mention the `compose.yaml` option and defer.

## Decision rules

Consult these first. They settle 90% of choices before you write a line.

**Table A — Base image by stack**

| Stack | Base image | Notes |
| --- | --- | --- |
| FastAPI / Python | `gcr.io/distroless/python3-debian12:nonroot` (or `python:3.13-slim`) | UID 65532, no shell |
| Go | `gcr.io/distroless/static-debian12:nonroot` | `CGO_ENABLED=0` static, ~10 MB |
| Next.js | `node:22-bookworm-slim` | `output: "standalone"` |
| Flutter web | `nginxinc/nginx-unprivileged:1.27-alpine` | static SPA + `try_files` fallback |
| Postgres | `postgres:17-alpine` | managed/official — do NOT build a custom image |

**Table B — Coolify build pack**

| Situation | Pick |
| --- | --- |
| Repo has a Dockerfile | Dockerfile pack (always — CI/prod parity) |
| No Dockerfile, standard stack | Nixpacks / Railpack |
| Static SPA, no server | Static |
| Multi-service local parity | Docker Compose |
| CI already builds & pushes | Docker Image (deploy prebuilt ghcr image) |

**If it has a Dockerfile, use the Dockerfile pack.**

**Table C — Deploy strategy**

| Change type | Strategy |
| --- | --- |
| Backward-compatible | Rolling (Coolify default, healthcheck-gated) |
| Breaking / instant cutover / risky migration | Blue-green: two Coolify resources + domain swap |
| Want gradual % traffic (canary) | Canary = release to a small subset, watch metrics, then ramp. Vanilla Coolify has no traffic split — emulate with feature flags (in-app % gating) or a blue-green pair behind a flagged path |

**Table D — Secret delivery**

| Secret kind | Mechanism |
| --- | --- |
| Build-time non-secret | `ARG` |
| Build-time secret (private dep token) | BuildKit `--mount=type=secret` (NEVER `ARG`) |
| Runtime secret | Coolify env (Is Secret) / GHA `secrets` |
| Cloud auth | OIDC — never a stored key |

## Core principles

1. Multi-stage always: a fat builder, a minimal runtime — never ship the toolchain.
2. Pin digests (`FROM img@sha256:…`) on prod base images so a moved tag can't change your runtime.
3. Non-root + read-only rootfs + `cap_drop: ALL`; add back only `NET_BIND_SERVICE` if you must bind <1024.
4. One process per container. No supervisord-managed bundles; let the orchestrator scale.
5. Write `.dockerignore` before the first build — it shrinks context, speeds builds, and keeps secrets out.
6. Secrets never in layers, logs, or `ARG`; use BuildKit `--mount=type=secret` at build, env injection at runtime.
7. Copy the lockfile and install deps **before** copying source, so source edits don't bust the dependency cache.
8. `HEALTHCHECK` hits a real readiness path (`/healthz`), not `/` — it gates the rolling swap.
9. 12-factor config: env only, validated at boot, fail-fast. No `.env` baked into images.
10. Least-privilege `GITHUB_TOKEN` (`permissions:` default-deny, escalate per job) and every pipeline runs `scripts/verify.sh`.

## Docker — the canonical multi-stage shape

```dockerfile
# syntax=docker/dockerfile:1
# ---- builder: full toolchain, deps cached before source ----
FROM <builder-base> AS builder
WORKDIR /app
COPY <lockfile> <manifest> ./           # lockfile FIRST → cached dep layer
RUN <install-deps-from-lockfile>        # changes only when the lockfile changes
COPY . .                                # source last
RUN <build>

# ---- runtime: minimal, non-root, no toolchain ----
FROM <runtime-base>                      # distroless / -slim / unprivileged nginx
WORKDIR /app
COPY --from=builder --chown=nonroot:nonroot /app/<artifact> ./
USER nonroot:nonroot
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["<readiness-probe>"]             # exec-form (distroless has no shell)
CMD ["<entrypoint>", "--host", "0.0.0.0", "--port", "8000"]
```

```dockerfile
# GOOD: secret consumed in-layer, never persisted
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN="$(cat /run/secrets/npm_token)" npm ci
# BAD: ARG bakes the token into image history forever
ARG NPM_TOKEN
RUN npm ci   # token now visible in `docker history`
```

```text
# .dockerignore — write this before your first build
.git
node_modules
.env*
dist
.next
__pycache__
*.log
coverage
Dockerfile*
compose*
README.md
.github
```

```bash
DOCKER_BUILDKIT=1 docker build --secret id=npm_token,env=NPM_TOKEN -t app:dev .
```

→ full per-stack Dockerfiles: `references/dockerfiles-by-stack.md`

## docker-compose for local dev + Postgres

```yaml
# compose.yaml — Compose Spec, no `version:` key
services:
  app:
    build:
      context: .
      target: dev                       # dev stage of the multi-stage Dockerfile
    ports:
      - "127.0.0.1:8000:8000"
    volumes:
      - .:/app                          # bind mount → hot reload
      - /app/.venv                      # anonymous volume guards container deps
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/app_dev
    develop:
      watch:
        - { path: ./pyproject.toml, action: rebuild }
        - { path: ./app, action: sync, target: /app/app }
    depends_on:
      db:
        condition: service_healthy
  db:
    image: postgres:17-alpine
    ports:
      - "127.0.0.1:5432:5432"           # host-only; NEVER 0.0.0.0 in prod
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app_dev
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d app_dev"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
```

- GOOD: bind-mount source for dev hot reload; BAD: bind-mount source over a prod image (it shadows the baked build).
- GOOD: bind Postgres to `127.0.0.1`; BAD: bind it to `0.0.0.0` in prod (publicly reachable DB).

→ prod overlay + mailpit: `references/dockerfiles-by-stack.md`

## GitHub Actions — least-privilege pipeline

```yaml
# .github/workflows/ci.yml
name: ci
on:
  push:
    branches: [main]
  pull_request:
permissions:
  contents: read                        # default-deny; escalate per job
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/verify.sh
  build-push:
    needs: verify
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha
            type=semver,pattern={{version}}
      - uses: docker/build-push-action@v6
        with:
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          provenance: true
      - uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0
        with:
          image-ref: ghcr.io/${{ github.repository }}:sha-${{ github.sha }}
          exit-code: "1"
          severity: "HIGH,CRITICAL"
          ignore-unfixed: true
```

- GOOD: scoped per-job `permissions` (only `build-push` gets `packages: write` / `id-token: write`).
- BAD: blanket `permissions: write-all` — any compromised step can push images or mint tokens.
- GOOD: third-party actions pinned to a full commit SHA with a version comment (`@<sha> # v0.36.0`). `trivy-action` had its tags force-pushed to credential-stealing malware in a 2026 supply-chain incident — a moving tag would have pulled it; a SHA pin would not. Let Dependabot bump the SHA.

→ matrix, reusable workflows, OIDC-to-cloud, environments/approvals, releases: `references/github-actions.md`

## Coolify — deploy target

- Pick the **Dockerfile** build pack when a Dockerfile exists — same artifact CI builds, full control, prod/CI parity.
- Set **Ports Exposes** to the container port your app listens on (e.g. `8000`); Traefik routes the domain to it.
- Mark sensitive env vars **Is Secret** — encrypted at rest, masked in logs and UI.
- Set the **Health Check** path/port → this is what gates the rolling swap to the new container.
- Attach **persistent storage** (volume/bind/file mount) for any stateful path; container FS is ephemeral.
- Bind a **custom domain** → automatic Let's Encrypt cert + **Force HTTPS**; point DNS A/AAAA at the server.
- Enable **GitHub App auto-deploy** on push, OR call the deploy webhook from CI (one or the other, not both).
- Turn on **preview deployments** per PR (`{{pr_id}}.{{domain}}`) with non-prod secrets; auto-teardown on PR close.
- Set **CPU/memory limits + reservations** per resource to prevent noisy-neighbor OOM.
- **Rollback** = redeploy a previously stored image in one click; pair with backward-compatible migrations.

```bash
curl --fail -X POST \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  "https://coolify.example.com/api/v1/deploy?uuid=$APP_UUID&force=false"
```

→ full Coolify walkthrough: `references/coolify.md`

## Secrets flow (GitHub → registry → Coolify)

```text
GitHub secrets / OIDC ──mint short-lived creds──▶ build pushes to ghcr.io (no key stored)
     │                                                        │
     └──── nothing long-lived in a workflow file             ▼
                                       Coolify pulls (deploy-scoped registry cred)
                                                     │
                                                     ▼
                                runtime env injected by Coolify (encrypted at rest)
```

- A secret crosses **at most one** trust boundary per hop — never forward a GHA secret into the running container; let Coolify inject runtime env.
- Nothing long-lived lives in a workflow file: `GITHUB_TOKEN` and OIDC tokens are minted per run and expire.
- `${{ }}` secrets are masked in logs, but `set -x` and `echo "$SECRET"` defeat the mask — forbid both.

## 12-factor config & observability

Config from env, validated at boot, fail-fast — a bad config crashes on startup, never at request time.

```python
from pydantic import PostgresDsn
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    database_url: PostgresDsn
    model_config = SettingsConfigDict(env_file=".env")

settings = Settings()  # raises at import → fail-fast
```

```typescript
import { z } from "zod";
const envSchema = z.object({ DATABASE_URL: z.string().url(), PORT: z.coerce.number().default(3000) });
export const env = envSchema.parse(process.env); // throws at boot → fail-fast
```

```go
import "github.com/caarlos0/env/v11"
type Config struct {
	DatabaseURL string `env:"DATABASE_URL,required"`
	Port        int    `env:"PORT" envDefault:"8080"`
}
cfg := env.Must(env.ParseAs[Config]()) // exits at boot if invalid → fail-fast
```

- Log JSON to stdout (slog for Go, structlog/uvicorn JSON for FastAPI, pino for Next.js); never log secrets; expose `/healthz` (liveness, no deps) + `/readyz` (checks deps).

```python
# FastAPI: liveness is dependency-free; readiness probes the DB so a node that
# can't reach Postgres never takes traffic during the rolling swap.
@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}

@app.get("/readyz")
async def readyz() -> dict[str, str]:
    await db.execute("SELECT 1")   # raises 500 if the DB is unreachable
    return {"status": "ready"}
```

## Anti-patterns — rationalizations → STOP

| Rationalization | STOP — do this instead |
| --- | --- |
| `:latest` is fine for now | Pin tag+digest; `:latest` breaks reproducibility and rollback |
| I'll pass the token as `ARG` | BuildKit `--mount=type=secret`; `ARG` persists in `docker history` |
| `permissions: write-all` is simpler | Default-deny; grant per job (`packages: write`, `id-token: write`) |
| Store a registry password in GHA secrets | Use OIDC / `GITHUB_TOKEN`; no long-lived key |
| Run as root, it's just a container | Non-root UID + read-only rootfs + `cap_drop: ALL` |
| Skip the healthcheck, the app boots fast | No healthcheck = no rolling gate = downtime / bad version live |
| Copy the whole repo then `RUN install` | Copy the lockfile first; cache the deps layer |
| Nixpacks is easier than my Dockerfile | If a Dockerfile exists, use it — CI/prod parity |
| Secrets in `compose.yaml` env | `.env` (gitignored) / Coolify secret env |
| Migrate the DB destructively in deploy | Backward-compatible migrations, or rolling breaks |
| `echo $SECRET` to debug CI | Never; masked vars still leak via `set -x` and logs |
| Build once per env with different secrets | Build one image; inject config at runtime (12-factor) |

## Quick reference

| Task | Command / file |
| --- | --- |
| Build with secret | `DOCKER_BUILDKIT=1 docker build --secret id=npm_token,env=NPM_TOKEN -t app:dev .` |
| Scan image | `trivy image --severity HIGH,CRITICAL --exit-code 1 IMG` |
| Lint Dockerfile | `hadolint Dockerfile` |
| Lint workflows | `actionlint` |
| Run verify gate | `bash scripts/verify.sh` |
| Local up | `docker compose up --watch` |
| Trigger Coolify deploy | `curl --fail -X POST …/api/v1/deploy?uuid=…&force=false` |
| Roll back | Coolify → redeploy prior image |

**Pre-ship checklist**

- [ ] Runs as non-root
- [ ] Base image pinned (tag + digest)
- [ ] `.dockerignore` present
- [ ] `HEALTHCHECK` hits a real readiness path
- [ ] No secrets in layers or logs
- [ ] Least-privilege `GITHUB_TOKEN`
- [ ] trivy clean (no HIGH/CRITICAL)
- [ ] Rollback path known

## See Also

- `../risco-project-harness/SKILL.md` — 01-TOOLS provider creds (Stripe, Postgres, OAuth…) that become Coolify runtime env.
- `../secure-coding/SKILL.md` — input validation, authn/z, and secret-handling that this skill assumes the app already does.
- `../fastapi/SKILL.md`, `../go/SKILL.md`, `../flutter/SKILL.md` — runtime code for the stacks you containerize here (this skill stops at the container boundary; `nextjs` and `postgresdb` skills if present cover those runtimes).
- `references/dockerfiles-by-stack.md`, `references/github-actions.md`, `references/coolify.md`, and `scripts/verify.sh`.

FastAPI / Next.js / Go application-code skills (if present in this skills dir) own runtime code — this skill stops at the container boundary.

## References

- `references/dockerfiles-by-stack.md` — complete runnable Dockerfile + .dockerignore per stack.
- `references/github-actions.md` — least-privilege workflows, OIDC, matrix, releases, deploy.
- `references/coolify.md` — build packs, secrets, volumes, SSL, previews, rolling, blue-green, rollback.
- `scripts/verify.sh` — the hadolint+actionlint+trivy+build-smoke gate (runs locally and in CI).
