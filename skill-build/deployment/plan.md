# IMPLEMENTATION PLAN — skill `deployment`

> **For the implementer subagent.** Follow this verbatim; make no design decisions.
> Source of truth: `/Volumes/EXTERN/DEV/skills/skill-build/deployment/spec.md` (read it once before starting).
> Output root: `/Volumes/EXTERN/DEV/skills/skills/deployment/`.
> Quality bar: match or exceed ECC `docker-patterns` + `deployment-patterns`. Current versions only:
> Go 1.24, Python 3.13 + uv ≥ 0.5, Node 22 LTS + Next.js 15.5 standalone (React 19),
> Flutter stable (Dart 3), PostgreSQL 17, Coolify v4.1. NO placeholders, NO TODOs, NO "etc."

---

## 0. Procedure (do these in order)

1. Create directories:
   ```bash
   mkdir -p /Volumes/EXTERN/DEV/skills/skills/deployment/references
   mkdir -p /Volumes/EXTERN/DEV/skills/skills/deployment/scripts
   ```
2. Write the 5 files (sections 2–6 below), each in full.
3. `chmod +x /Volumes/EXTERN/DEV/skills/skills/deployment/scripts/verify.sh`.
4. Run the acceptance self-check (section 7). Do NOT execute `verify.sh` in this repo (wrong stack).

## 1. File manifest (exact paths + line budgets)

```
/Volumes/EXTERN/DEV/skills/skills/deployment/SKILL.md                            ~330 lines (hard cap 450)
/Volumes/EXTERN/DEV/skills/skills/deployment/references/dockerfiles-by-stack.md  ~420 lines (200–500)
/Volumes/EXTERN/DEV/skills/skills/deployment/references/github-actions.md        ~460 lines (200–500)
/Volumes/EXTERN/DEV/skills/skills/deployment/references/coolify.md               ~380 lines (200–500)
/Volumes/EXTERN/DEV/skills/skills/deployment/scripts/verify.sh                   executable, chmod +x
```

Markdown rules for every `.md`: exactly one H1; every fenced block has a language tag
(`dockerfile`, `yaml`, `bash`, `python`, `typescript`, `go`, `nginx`, `sql`, `text`);
heading levels never skip (H1→H2→H3); relative links between files use `references/<f>.md`
and `../SKILL.md`.

---

## 2. `SKILL.md` — section-by-section

### Frontmatter (YAML, verbatim)

```yaml
---
name: deployment
description: "Use when containerizing an app, writing a Dockerfile, setting up GitHub Actions CI/CD, or deploying to Coolify — multi-stage builds (FastAPI/uv, Go/distroless, Next.js standalone, Flutter web, Postgres), BuildKit build secrets, image scanning (trivy/hadolint), OIDC to registries (no long-lived secrets), least-privilege GITHUB_TOKEN, zero-downtime/rolling deploys, env/secrets flow GitHub→Coolify, healthchecks, and rollback strategy. Trigger phrases: 'dockerize', 'write a Dockerfile', 'CI pipeline', 'GitHub Actions', 'deploy', 'ship it', 'Coolify', 'docker-compose for local dev'."
origin: risco
---
```

### Section order (H2 unless noted) and content per section

1. **`# Ship it — Docker, GitHub Actions, Coolify`** (H1, only one).
   One-line purpose: "Take any app in this repo from source → hardened container → green
   CI/CD → live on Coolify, with secrets that never leak into image layers or logs, and a
   defined rollback path." Then a `text` fenced block with the pipeline mental model:
   ```text
   source → Dockerfile (multi-stage) → CI (lint·test·build·scan) → registry (ghcr) → Coolify (rolling) → live + rollback
   ```

2. **`## When to use / When NOT to use`** — two bullet lists.
   - When to use (4 bullets): authoring/auditing `Dockerfile`/`.dockerignore`/`compose.yaml`;
     writing/hardening `.github/workflows/*.yml`; wiring a service onto Coolify; designing the
     GitHub→registry→Coolify secrets flow or choosing rolling vs blue-green.
   - When NOT to use (4 bullets, each names the redirect): Kubernetes/Helm/ECS/Nomad → out of
     scope, say so and stop; app runtime / DB migration / business logic → wrong skill;
     Terraform/Pulumi/CloudFormation IaC → out of scope (only the GHA↔cloud OIDC handshake is
     covered, not provisioning); pure local dev with no container ambition → mention compose, defer.

3. **`## Decision rules`** — the load-bearing core. Four markdown tables.
   - **Table A — Base image by stack** columns `Stack | Base image | Notes`:
     `FastAPI/Python | gcr.io/distroless/python3-debian12:nonroot (or python:3.13-slim) | UID 65532, no shell`;
     `Go | gcr.io/distroless/static-debian12:nonroot | CGO_ENABLED=0 static, ~10 MB`;
     `Next.js | node:22-bookworm-slim | output: "standalone"`;
     `Flutter web | nginxinc/nginx-unprivileged:1.27-alpine | static SPA + fallback`;
     `Postgres | postgres:17-alpine | managed/official — do NOT build a custom image`.
   - **Table B — Coolify build pack** columns `Situation | Pick`:
     `Repo has a Dockerfile | Dockerfile pack (always — CI/prod parity)`;
     `No Dockerfile, standard stack | Nixpacks / Railpack`;
     `Static SPA, no server | Static`;
     `Multi-service local parity | Docker Compose`;
     `CI already builds & pushes | Docker Image (deploy prebuilt ghcr image)`.
     Bold rule line after table: **If it has a Dockerfile, use the Dockerfile pack.**
   - **Table C — Deploy strategy** columns `Change type | Strategy`:
     `Backward-compatible | Rolling (Coolify default, healthcheck-gated)`;
     `Breaking / instant cutover / risky migration | Blue-green: two Coolify resources + domain swap`;
     `Want gradual % traffic | Not on vanilla Coolify (no traffic split) — use feature flags`.
   - **Table D — Secret delivery** columns `Secret kind | Mechanism`:
     `Build-time non-secret | ARG`;
     `Build-time secret (private dep token) | BuildKit --mount=type=secret (NEVER ARG)`;
     `Runtime secret | Coolify env (Is Secret) / GHA secrets`;
     `Cloud auth | OIDC — never a stored key`.

4. **`## Core principles`** — 10 directive one-line bullets, exactly:
   multi-stage always; pin digests (`FROM img@sha256:…`) in prod base images; non-root + read-only
   rootfs + `cap_drop: ALL`; one process per container; write `.dockerignore` before the first
   build; secrets never in layers/logs/`ARG`; copy lockfile + install deps before copying source
   (cache); `HEALTHCHECK` hits a real readiness path; 12-factor config (env only, validated at
   boot, fail-fast); least-privilege `GITHUB_TOKEN` (`permissions:` default-deny) and every
   pipeline runs `scripts/verify.sh`.

5. **`## Docker — the canonical multi-stage shape`** — one annotated generic `dockerfile`
   skeleton (builder → runtime) showing: lockfile-first copy for cache, non-root user, exec-form
   `CMD`, `HEALTHCHECK`, and a BuildKit secret mount. Then a Good/Bad `dockerfile` block:
   ```dockerfile
   # GOOD: secret consumed in-layer, never persisted
   RUN --mount=type=secret,id=npm_token \
       NPM_TOKEN="$(cat /run/secrets/npm_token)" npm ci
   # BAD: ARG bakes the token into image history forever
   ARG NPM_TOKEN
   RUN npm ci   # token now visible in `docker history`
   ```
   Then a `text` `.dockerignore` snippet (10–12 lines: `.git`, `node_modules`, `.env*`,
   `dist`, `.next`, `__pycache__`, `*.log`, `coverage`, `Dockerfile*`, `compose*`, `README.md`,
   `.github`). Then the one-liner build in `bash`:
   `DOCKER_BUILDKIT=1 docker build --secret id=npm_token,env=NPM_TOKEN -t app:dev .`
   Close with pointer line: "→ full per-stack Dockerfiles: `references/dockerfiles-by-stack.md`".
   Keep this section ≤ 45 lines.

6. **`## docker-compose for local dev + Postgres`** — one `yaml` `compose.yaml` (~35 lines,
   Compose Spec, NO `version:` key): `app` building `target: dev`, bind mount `.:/app`, anonymous
   volume guard, `develop: { watch: [...] }` hot reload, `environment` with `DATABASE_URL`
   pointing at `db`, `depends_on: { db: { condition: service_healthy } }`; `db: postgres:17-alpine`
   with `127.0.0.1:5432:5432` bound port, `pg_isready` healthcheck (interval 5s/timeout 3s/retries 5),
   named volume `pgdata`. After the block, 2 Good/Bad bullets: bind-mount source for dev vs baked
   image for prod; never bind Postgres to `0.0.0.0` in prod. Pointer: "→ prod overlay + mailpit:
   `references/dockerfiles-by-stack.md`".

7. **`## GitHub Actions — least-privilege pipeline`** — one complete runnable `yaml` `ci.yml`
   excerpt that passes actionlint: top-level `permissions: { contents: read }`;
   `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }`;
   `on: { push: { branches: [main] }, pull_request: {} }`; a `verify` job (`actions/checkout@v4`
   then `run: bash scripts/verify.sh`); a `build-push` job `needs: verify`,
   `permissions: { contents: read, packages: write, id-token: write }`,
   `docker/login-action@v3` to `ghcr.io` with `username: ${{ github.actor }}` /
   `password: ${{ secrets.GITHUB_TOKEN }}`, `docker/metadata-action@v5`,
   `docker/build-push-action@v6` with `cache-from: type=gha` / `cache-to: type=gha,mode=max` /
   `provenance: true`, then a trivy scan step using `aquasecurity/trivy-action@0.28.0` with
   `exit-code: '1'` and `severity: 'HIGH,CRITICAL'`. After the block, a Good/Bad bullet pair:
   scoped per-job `permissions` (GOOD) vs blanket `permissions: write-all` (BAD).
   Pointer: "→ matrix, reusable workflows, OIDC-to-cloud, environments/approvals, releases:
   `references/github-actions.md`". Keep ≤ 60 lines.

8. **`## Coolify — deploy target`** — dense bullet list (8–10 bullets): pick Dockerfile build
   pack (CI parity); set **Ports Exposes**; mark env vars **Is Secret** (encrypted at rest);
   set **Health Check** path → enables rolling swap; attach **persistent storage** for stateful
   paths; bind **custom domain** → auto Let's Encrypt + Force HTTPS; enable **GitHub App
   auto-deploy** OR call the deploy webhook from CI; **preview deployments** per PR
   (`{{pr_id}}.{{domain}}`); set **CPU/memory limits**; **rollback** = redeploy a prior stored
   image. Then one `bash` block — the CI→Coolify webhook:
   ```bash
   curl --fail -X POST \
     -H "Authorization: Bearer $COOLIFY_TOKEN" \
     "https://coolify.example.com/api/v1/deploy?uuid=$APP_UUID&force=false"
   ```
   Pointer: "→ full Coolify walkthrough: `references/coolify.md`".

9. **`## Secrets flow (GitHub → registry → Coolify)`** — one `text` ASCII diagram then rules:
   ```text
   GitHub secrets / OIDC ──mint short-lived creds──▶ build pushes to ghcr.io (no key stored)
        │                                                        │
        └──── nothing long-lived in a workflow file             ▼
                                          Coolify pulls (deploy-scoped registry cred)
                                                        │
                                                        ▼
                                   runtime env injected by Coolify (encrypted at rest)
   ```
   Rules (3 bullets): a secret crosses at most one trust boundary per hop; nothing long-lived
   in a workflow file (OIDC/`GITHUB_TOKEN` mint per run); `${{ }}` secrets are masked but
   `set -x` / `echo $SECRET` leaks them — forbid both.

10. **`## 12-factor config & observability`** — config from env, validated at boot, fail-fast.
    Three tiny snippets (4–6 lines each):
    - `python` — Pydantic v2 `BaseSettings` (`from pydantic_settings import BaseSettings`,
      one `Settings` class with `database_url: PostgresDsn`, `model_config = SettingsConfigDict(env_file=".env")`,
      `settings = Settings()` at import → fail-fast).
    - `typescript` — Zod `envSchema.parse(process.env)` (Next.js), 4 lines.
    - `go` — `caarlos0/env/v11` `env.Must(env.ParseAs[Config]())` or `env.Parse(&cfg)`, 4 lines.
    Then a 1-bullet logging rule: logs to stdout as JSON (slog for Go, structlog/uvicorn JSON
    for FastAPI, pino for Next.js); never log secrets; expose `/healthz` (liveness) + `/readyz`
    (deps). Keep ≤ 35 lines.

11. **`## Anti-patterns — rationalizations → STOP`** — markdown table, 12 rows, columns
    `Rationalization | STOP — do this instead`. Use exactly the 12 rows in spec §SKILL.md
    "Anti-patterns" (`:latest` is fine; pass token as `ARG`; `permissions: write-all` simpler;
    store registry password in GHA secrets; run as root; skip healthcheck; copy repo then install;
    Nixpacks easier than my Dockerfile; secrets in `compose.yaml` env; destructive deploy
    migration; `echo $SECRET` to debug; build once per env with different secrets).

12. **`## Quick reference`** — table `Task | Command / file` (8 rows): build with secret
    (`DOCKER_BUILDKIT=1 docker build --secret id=…`); scan image (`trivy image --severity HIGH,CRITICAL --exit-code 1 IMG`);
    lint Dockerfile (`hadolint Dockerfile`); lint workflows (`actionlint`); run verify gate
    (`bash scripts/verify.sh`); local up (`docker compose up --watch`); trigger Coolify deploy
    (`curl --fail -X POST …/api/v1/deploy?uuid=…`); roll back (Coolify → redeploy prior image).
    Then a **Pre-ship checklist** (8 `- [ ]` boxes): non-root; pinned base+digest; `.dockerignore`;
    `HEALTHCHECK`; no secrets in layers; least-priv token; trivy clean; rollback path known.

13. **`## See Also`** — bullets linking sibling skills + references:
    `- risco-project-harness — 01-TOOLS provider creds (Stripe, Postgres, OAuth…) that become Coolify runtime env`
    (link `../risco-project-harness/SKILL.md`); plus the three references files and `scripts/verify.sh`.
    Add a line: "FastAPI / Next.js / Go application-code skills (if present in this skills dir) for runtime code — this skill stops at the container boundary."

14. **`## References`** — bullet list, one line each:
    `references/dockerfiles-by-stack.md — complete runnable Dockerfile + .dockerignore per stack`;
    `references/github-actions.md — least-privilege workflows, OIDC, matrix, releases, deploy`;
    `references/coolify.md — build packs, secrets, volumes, SSL, previews, rolling, blue-green, rollback`;
    `scripts/verify.sh — the hadolint+actionlint+trivy+build-smoke gate (runs locally and in CI)`.

**Budget enforcement:** if SKILL.md exceeds ~450 lines, move the longest code block from §5/§7
into its reference file and leave only the pointer. Target ~330.

---

## 3. `references/dockerfiles-by-stack.md` — outline + exact code

H1: `# Dockerfiles by stack`. One sentence intro. Then one H2 per stack. Each stack section must
contain: complete runnable `dockerfile`, matching `.dockerignore` (`text`), the `bash` build
command, an image-size expectation line, and a **Gotchas** bullet sub-list.

### `## FastAPI + uv (Python 3.13)`
- `dockerfile` multi-stage. Builder `FROM ghcr.io/astral-sh/uv:0.5-python3.13-bookworm-slim AS builder`,
  `WORKDIR /app`, `ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy`; first
  `RUN --mount=type=cache,target=/root/.cache/uv --mount=type=bind,source=uv.lock,target=uv.lock --mount=type=bind,source=pyproject.toml,target=pyproject.toml uv sync --frozen --no-dev --no-install-project`,
  then `COPY . .` then `RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-dev`.
  Runtime `FROM gcr.io/distroless/python3-debian12:nonroot`, `WORKDIR /app`,
  `COPY --from=builder --chown=nonroot:nonroot /app /app`,
  `ENV PATH="/app/.venv/bin:$PATH"`, `EXPOSE 8000`,
  `HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD ["python","-c","import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/healthz').status==200 else 1)"]`,
  `CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8000"]`.
- A second `dockerfile` snippet: gunicorn multi-core CMD variant:
  `CMD ["gunicorn","app.main:app","-k","uvicorn.workers.UvicornWorker","-w","4","-b","0.0.0.0:8000"]`.
- `.dockerignore` (`text`): `.venv`, `__pycache__`, `*.pyc`, `.pytest_cache`, `.git`, `.env*`, `tests/`.
- Build (`bash`): `docker build -t api:prod .`. Size expectation: ~70–90 MB.
- Gotchas: distroless has no shell → exec-form CMD/HEALTHCHECK only, no `curl`/`wget` (use python
  urllib); `uv sync --frozen` requires committed `uv.lock`; `--no-install-project` on the deps
  layer so source changes don't bust the dep cache.

### `## Go (1.24, static + distroless)`
- `dockerfile`: builder `FROM golang:1.24-bookworm AS builder`, `WORKDIR /src`,
  `RUN --mount=type=cache,target=/go/pkg/mod --mount=type=bind,source=go.sum,target=go.sum --mount=type=bind,source=go.mod,target=go.mod go mod download`,
  `COPY . .`,
  `RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /bin/server ./cmd/server`.
  Runtime `FROM gcr.io/distroless/static-debian12:nonroot`, `COPY --from=builder /bin/server /server`,
  `USER nonroot:nonroot`, `EXPOSE 8080`,
  `HEALTHCHECK --interval=30s --timeout=3s CMD ["/server","-health"]`,
  `ENTRYPOINT ["/server"]`.
- Note (`go` snippet, 6 lines): Go 1.22+ `net/http.ServeMux` method-prefixed routing
  (`mux.HandleFunc("GET /healthz", handler)`) and `slog` JSON handler
  (`slog.New(slog.NewJSONHandler(os.Stdout, nil))`).
- `.dockerignore` (`text`): `.git`, `*_test.go` (optional), `bin/`, `.env*`.
- Build: `docker build -t svc:prod .`. Size: ~8–12 MB.
- Gotchas: no shell/wget in static distroless → healthcheck must be a self-`-health` subcommand
  of the binary; `CGO_ENABLED=0` mandatory for static; `-trimpath` for reproducibility.

### `## Next.js 15 (standalone)`
- `typescript` `next.config.ts` 3-liner: `const nextConfig = { output: "standalone" as const }; export default nextConfig;`.
- `dockerfile` 3 stages: `deps` (`FROM node:22-bookworm-slim AS deps`, `WORKDIR /app`,
  `COPY package.json package-lock.json ./`, `RUN npm ci`); `builder`
  (`COPY --from=deps /app/node_modules ./node_modules`, `COPY . .`,
  `ARG NEXT_PUBLIC_API_URL`, `ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL`, `RUN npm run build`);
  `runner` (`FROM node:22-bookworm-slim AS runner`, `WORKDIR /app`, `ENV NODE_ENV=production`,
  `RUN groupadd -g 1001 nodejs && useradd -u 1001 -g nodejs nextjs`,
  `COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./`,
  `COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static`,
  `COPY --from=builder --chown=nextjs:nodejs /app/public ./public`,
  `USER nextjs`, `ENV HOSTNAME=0.0.0.0 PORT=3000`, `EXPOSE 3000`,
  `CMD ["node","server.js"]`).
- `.dockerignore` (`text`): `node_modules`, `.next`, `.git`, `.env*`, `npm-debug.log*`.
- Build (`bash`): `docker build --build-arg NEXT_PUBLIC_API_URL=https://api.example.com -t web:prod .`. Size: ~150–200 MB.
- Gotchas: `NEXT_PUBLIC_*` are baked at build → NOT secret, never put runtime secrets there;
  standalone output requires copying `.next/static` and `public` manually (they're not bundled);
  set `HOSTNAME=0.0.0.0` or the container won't accept external connections.

### `## Flutter web (Dart 3 stable)`
- `dockerfile`: builder `FROM ghcr.io/cirruslabs/flutter:stable AS builder`, `WORKDIR /app`,
  `COPY pubspec.* ./`, `RUN flutter pub get`, `COPY . .`,
  `RUN flutter build web --release --base-href=/`. Runtime
  `FROM nginxinc/nginx-unprivileged:1.27-alpine`,
  `COPY --from=builder /app/build/web /usr/share/nginx/html`,
  `COPY nginx.conf /etc/nginx/conf.d/default.conf`, `EXPOSE 8080`.
- `nginx` `nginx.conf` snippet: `server { listen 8080; root /usr/share/nginx/html; gzip on;
  location / { try_files $uri $uri/ /index.html; } location ~* \.(js|css|png|woff2)$ { expires 30d; } }`.
- `.dockerignore` (`text`): `build/`, `.dart_tool/`, `.git`, `.env*`.
- Build: `docker build -t flutterweb:prod .`. Size: ~25–40 MB.
- Gotchas: nginx-unprivileged listens on 8080 (non-root, not 80); SPA needs the `try_files`
  fallback or deep links 404; runtime config via `--dart-define` at build or a fetched
  `config.json` (NEXT_PUBLIC-style: baked unless fetched at runtime).

### `## Postgres (17)`
- Bold note: **Do NOT build a custom Postgres image for prod** — use a Coolify managed DB or
  official `postgres:17-alpine`.
- `yaml` local-dev service: `postgres:17-alpine`, `environment` (`POSTGRES_USER/PASSWORD/DB`),
  `command: ["postgres","-c","shared_buffers=256MB","-c","max_connections=100"]`,
  volume `pgdata:/var/lib/postgresql/data`, init mount
  `./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql`,
  healthcheck `["CMD-SHELL","pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]`.
- Backups bullet: Coolify scheduled S3 backups; never rely on the container FS.

### `## Cross-cutting`
- `.dockerignore` master template (`text`, ~15 lines superset).
- HEALTHCHECK patterns table `Base | Healthcheck`: shell base → `CMD wget -qO- http://localhost:PORT/healthz || exit 1`;
  distroless python → python urllib exec-form; distroless static (Go) → binary `-health` subcommand.
- Reproducible builds bullets: pin digest `FROM image@sha256:…`, set `SOURCE_DATE_EPOCH`,
  caveat that `--no-cache` defeats layer caching (use only for clean rebuilds).
- Scanning (`bash`): `hadolint Dockerfile` and
  `trivy image --severity HIGH,CRITICAL --exit-code 1 --ignore-unfixed myimg`.
- Multi-arch (`bash`): `docker buildx build --platform linux/amd64,linux/arm64 -t img --push .`.

---

## 4. `references/github-actions.md` — outline + exact code

H1: `# GitHub Actions — CI/CD playbook`. Intro line: every workflow here passes `actionlint`.
H2 per concern. All `yaml`.

- `## Workflow anatomy & least privilege` — top-level `permissions: { contents: read }` (default-deny,
  escalate per job); `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }`;
  actions pinned by major (`@v4`) with a note on full-SHA pinning for supply-chain hardening
  (one example `uses: actions/checkout@<40-char-sha> # v4.2.2`).
- `## Caching` — `setup-python`/`setup-node`/`setup-go` built-in `cache:`; `astral-sh/setup-uv@v6`
  with `enable-cache: true`; `actions/cache@v4` keyed on `${{ runner.os }}-${{ hashFiles('**/lockfile') }}`;
  Docker `cache-from/to: type=gha,mode=max`. Good/Bad: lockfile-hash key (GOOD) vs static key (BAD).
- `## Job matrix` — `strategy: { fail-fast: false, matrix: { stack: [python, go, node] } }`
  calling the per-stack verify step.
- `## Build & push to ghcr (no stored key)` — full job: `permissions: { contents: read, packages: write, id-token: write }`,
  `docker/setup-buildx-action@v3`, `docker/metadata-action@v5` (tags: `type=sha`, `type=semver,pattern={{version}}`),
  `docker/login-action@v3` with `GITHUB_TOKEN`, `docker/build-push-action@v6`
  (`push: true`, `provenance: true`, `sbom: true`, gha cache, and a build secret passed via
  `secrets: | npm_token=${{ secrets.NPM_TOKEN }}`).
- `## OIDC to cloud (AWS example)` — `permissions: { id-token: write, contents: read }`,
  `aws-actions/configure-aws-credentials@v4` with `role-to-assume: arn:aws:iam::123:role/gha`
  and `aws-region`, NO `aws-access-key-id`. One paragraph: the trust policy `sub` claim
  `repo:ORG/REPO:ref:refs/heads/main` scopes which repo/branch may assume the role.
- `## Reusable & composite workflows` — a `workflow_call` reusable (`on: workflow_call: { inputs: {…}, secrets: { … } }`)
  invoked with `secrets: inherit`; a `composite` action (`runs: { using: composite, steps: [...] }`)
  wrapping checkout+setup+verify; how the matrix calls the reusable.
- `## Security gates` — required checks: lint (`ruff`/`eslint`/`golangci-lint`), test,
  `trivy fs --scanners vuln,secret --exit-code 1 .`, `trivy image`, `actionlint`, `hadolint`;
  `gitleaks/gitleaks-action@v2` for leaked creds; note to enforce via branch protection required checks.
- `## Environments & approvals` — `environment: { name: production, url: … }` with required
  reviewers + wait timer; environment-scoped secrets; protected by deployment branch rules.
- `## Release automation` — `on: { push: { tags: ['v*'] } }`; build, push `:latest` + `:${{ github.ref_name }}`;
  `softprops/action-gh-release@v2` with `generate_release_notes: true`; semver from tag via metadata-action.
- `## Calling verify.sh` — the canonical `- run: bash scripts/verify.sh` step; one paragraph on
  local↔CI parity (same gate both places); show it inside the matrix job.
- `## Deploy step (→ Coolify)` — final job gated `environment: production`, curl the webhook
  (`--fail -X POST -H "Authorization: Bearer ${{ secrets.COOLIFY_TOKEN }}"
  "https://coolify.example.com/api/v1/deploy?uuid=${{ vars.COOLIFY_APP_UUID }}&force=false"`),
  with a note: alternatively rely on the Coolify GitHub App (then CI only builds/scans and
  Coolify builds+deploys).

---

## 5. `references/coolify.md` — outline + exact code (v4.1, May 2026)

H1: `# Coolify (v4.1) — deploy target`. Intro: version-dated note (self-hosted PaaS, Traefik
proxy, Let's Encrypt). H2 per concern.

- `## What Coolify is (v4)` — self-hosted PaaS; Traefik reverse proxy; multi-server orchestration;
  280+ one-click services; vs Heroku/Vercel; dated v4.1 (May 2026).
- `## Build packs — pick one` — table `Build pack | When | Notes`: Dockerfile (has a Dockerfile;
  full control + CI parity — default); Nixpacks (auto-detect, zero-config); Railpack (newer;
  build-time env + multi-stage + config merge); Static (SPA, no server); Docker Compose
  (multi-service); Docker Image (deploy a prebuilt `ghcr.io` image from CI — the recommended split).
- `## Env vars & secrets` — add via UI/API; **Is Secret** toggle (encrypted at rest, hidden in
  logs/UI); **Build-time vs Runtime** toggle (`NEXT_PUBLIC_*` must be Build-time); shared
  (team/project) vs resource-scoped; mapping GitHub secret → Coolify env. `bash` example of the
  env API call if documented; otherwise describe UI path.
- `## Persistent storage` — volume mounts, bind mounts, file mounts (e.g. a mounted config file);
  what survives redeploys; warning container FS is ephemeral; DB data must be a volume/managed DB.
- `## Healthchecks → rolling deploys` — set Health Check Path/Port/Interval; Coolify waits for a
  healthy new container before swapping (rolling, gated); note true Compose zero-downtime is v5;
  Dockerfile `HEALTHCHECK` vs Coolify's configured check (Coolify's wins for the swap gate).
- `## Custom domains & SSL` — assign domain(s); automatic Let's Encrypt; **Force HTTPS**; wildcard
  for previews; redirect www; DNS A/AAAA → server IP.
- `## Managed databases` — provision Postgres 17 / Redis as a Coolify resource; internal connection
  string via service name; S3 backups; not publicly exposed by default.
- `## Auto-deploy & webhooks` — GitHub App (recommended, fine-grained) vs deploy-key + webhook;
  the deploy API `POST /api/v1/deploy?uuid=<app>&force=<bool>` with `Authorization: Bearer <token>`
  (`bash` block); webhook secret for push events; branch filter.
- `## Preview deployments` — enable per-PR; URL template `{{pr_id}}.{{domain}}`; ephemeral env;
  separate non-prod secrets; auto-teardown on PR close.
- `## Resource limits` — CPU/memory limits + reservations per resource; why (noisy-neighbor, OOM);
  maps to compose `deploy.resources`. Small `yaml` mapping example.
- `## Rollback` — Coolify keeps prior built images locally → one-click redeploy of a previous
  version; combine with backward-compatible migrations; short runbook (verify → redeploy prior →
  confirm health → investigate).
- `## Blue-green on Coolify` — pattern: two resources (blue/green) behind one domain; deploy to
  idle, verify, swap the domain → instant cutover + instant rollback; when to use vs default rolling.
- `## Observability` — Coolify log viewer (stdout/stderr), per-deployment logs; ship JSON logs;
  external aggregation (Loki/Grafana) note; notification channels on deploy success/failure.

---

## 6. `scripts/verify.sh` — exact contract

Write this file EXACTLY as below (the implementer may reflow comments but must preserve every
check, the skip-on-missing semantics, the `FAILED` accumulator, and the usage block). After
writing, run `chmod +x`. **Do NOT execute it in this repo.**

```bash
#!/usr/bin/env bash
# verify.sh — deployment gate. Run inside YOUR project; CI runs the same file (parity).
#
# Checks (each skips with a yellow warning if its tool is missing — never fails on absence):
#   1. discover Dockerfiles / compose / workflows  (no artifacts -> exit 0)
#   2. hadolint     each Dockerfile
#   3. actionlint   .github/workflows
#   4. trivy config (Dockerfile/compose/IaC misconfig)
#   5. docker build smoke  (skippable: SKIP_DOCKER_BUILD=1)
#   6. trivy image  (only if step 5 built an image)
#   7. summary; exit non-zero only on a real failure
#
# Env: SKIP_DOCKER_BUILD=1 to skip the build smoke; NO_COLOR=1 to disable color.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

if [[ -n "${NO_COLOR:-}" ]]; then YEL=""; GRN=""; RED=""; RST=""
else YEL=$'\033[33m'; GRN=$'\033[32m'; RED=$'\033[31m'; RST=$'\033[0m'; fi
warn() { printf '%s[skip]%s %s\n' "$YEL" "$RST" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "$GRN" "$RST" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED" "$RST" "$*"; }

FAILED=0
BUILT_IMAGE=""
SMOKE_TAG="verify-smoke:local"

# 1. discover
mapfile -t DOCKERFILES < <(find . -name 'Dockerfile' -o -name 'Dockerfile.*' 2>/dev/null | grep -v node_modules || true)
WORKFLOWS_DIR=".github/workflows"
HAVE_WORKFLOWS=0; [[ -d "$WORKFLOWS_DIR" ]] && HAVE_WORKFLOWS=1
COMPOSE=$(find . -maxdepth 2 \( -name 'compose*.y*ml' -o -name 'docker-compose*.y*ml' \) 2>/dev/null | head -n1 || true)
if [[ ${#DOCKERFILES[@]} -eq 0 && $HAVE_WORKFLOWS -eq 0 && -z "$COMPOSE" ]]; then
  printf 'No Dockerfiles, compose files, or workflows found — nothing to gate.\n'; exit 0
fi

# 2. hadolint
if have hadolint; then
  for df in "${DOCKERFILES[@]}"; do
    if hadolint --failure-threshold warning "$df"; then ok "hadolint $df"
    else fail "hadolint $df"; FAILED=1; fi
  done
else warn "hadolint not installed — skipping Dockerfile lint"; fi

# 3. actionlint
if [[ $HAVE_WORKFLOWS -eq 1 ]]; then
  if have actionlint; then
    if actionlint; then ok "actionlint"; else fail "actionlint"; FAILED=1; fi
  else warn "actionlint not installed — skipping workflow lint"; fi
fi

# 4. trivy config
if have trivy; then
  if trivy config --exit-code 1 --severity HIGH,CRITICAL .; then ok "trivy config"
  else fail "trivy config"; FAILED=1; fi
else warn "trivy not installed — skipping config/image scan"; fi

# 5. docker build smoke
if [[ -n "${SKIP_DOCKER_BUILD:-}" ]]; then
  warn "SKIP_DOCKER_BUILD set — skipping build smoke"
elif have docker && [[ ${#DOCKERFILES[@]} -gt 0 ]]; then
  DF="${DOCKERFILES[0]}"
  if DOCKER_BUILDKIT=1 docker build --pull -t "$SMOKE_TAG" -f "$DF" "$(dirname "$DF")"; then
    ok "docker build $DF"; BUILT_IMAGE="$SMOKE_TAG"
  else fail "docker build $DF"; FAILED=1; fi
else warn "docker not available or no Dockerfile — skipping build smoke"; fi

# 6. trivy image (only if we built one)
if [[ -n "$BUILT_IMAGE" ]]; then
  if have trivy; then
    if trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$BUILT_IMAGE"; then
      ok "trivy image $BUILT_IMAGE"
    else fail "trivy image $BUILT_IMAGE"; FAILED=1; fi
  else warn "trivy not installed — skipping image scan"; fi
fi

# 7. summary
if [[ $FAILED -eq 0 ]]; then ok "all checks passed (skips are not failures)"
else fail "one or more checks failed"; fi
exit "$FAILED"
```

Then: `chmod +x /Volumes/EXTERN/DEV/skills/skills/deployment/scripts/verify.sh`.

---

## 7. Acceptance self-checks (implementer must verify all before finishing)

1. **Files exist** at the 5 exact paths in section 1; directories `references/` and `scripts/`
   created.
2. **Frontmatter**: `name: deployment`, `origin: risco`, `description` starts with `Use when `
   and is the verbatim trigger block from section 2.
3. **One H1 per file**; no skipped heading levels; every fenced block has a language tag.
4. **No placeholders**: zero occurrences of `TODO`, `FIXME`, `...`, `<placeholder>`, `etc.`
   (run `grep -rnE 'TODO|FIXME|\.\.\.|etc\.' /Volumes/EXTERN/DEV/skills/skills/deployment` and
   confirm only legitimate code ellipses, if any, remain — there should be none in prose).
5. **Code correctness spot-checks**: distroless stages use exec-form `CMD`/`HEALTHCHECK` (no
   shell builtins); BuildKit secret example uses `--mount=type=secret`, never `ARG` for the token;
   GHA workflows have top-level `permissions: { contents: read }` and per-job escalation;
   Coolify webhook is `POST /api/v1/deploy?uuid=…&force=…` with bearer auth; `compose.yaml` has
   no `version:` key and binds Postgres to `127.0.0.1`.
6. **verify.sh is executable**: `test -x …/scripts/verify.sh` passes; first line is
   `#!/usr/bin/env bash`; line 2 region contains `set -euo pipefail`; every tool guarded by
   `have`/`command -v`; missing tool → yellow `[skip]`, never exit non-zero; usage comment
   documents `SKIP_DOCKER_BUILD` and `NO_COLOR`. Do NOT run it here.
7. **See Also** links resolve relatively: `../risco-project-harness/SKILL.md` and the three
   `references/*.md` and `scripts/verify.sh` paths are spelled correctly.
8. **Line budgets**: SKILL.md ≤ 450 (target ~330); each reference 200–500. If SKILL.md overflows,
   push code to references and keep pointers.
9. **Version currency**: confirm Go 1.24, Python 3.13/uv, Node 22/Next 15.5 standalone,
   Postgres 17, Coolify v4.1 appear; confirm NO `npm prune --production`, NO `python:3.12`,
   NO `golang:1.22`, NO alpine-root healthcheck-via-wget in the *prod* distroless stacks.
10. **Cross-references**: SKILL.md §Docker/§GHA/§Coolify each end with a `→ references/<file>.md`
    pointer; references back-link to `../SKILL.md` where natural.
```
