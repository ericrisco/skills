# DESIGN SPEC — skill `deployment`

> Title: **Ship it — Docker, GitHub Actions, Coolify**
> Origin: `risco`. Audience: an LLM coding agent working inside the user's real repo
> (stack: FastAPI/Python, Next.js, Go, Flutter web, Postgres). Directive, dense,
> copy-pasteable. ECC `docker-patterns` + `deployment-patterns` are the FLOOR.

Research baseline folded into the spec (confirmed June 2026):

- Go **1.24.x** (`CGO_ENABLED=0` static → `gcr.io/distroless/static-debian12:nonroot`, UID 65532).
- Python **3.13.x**, **uv** ≥ 0.5 (`uv sync --frozen --no-dev`, `UV_COMPILE_BYTECODE=1`, `--link-mode=copy`), FastAPI + uvicorn/gunicorn; distroless `gcr.io/distroless/python3-debian12:nonroot`.
- Node **22 LTS** (`node:22-bookworm-slim` / `-alpine`), **Next.js 15.5** App Router with `output: "standalone"` (note Next 16 migration exists; standalone unchanged). React 19.
- Flutter **stable (Dart 3)** web → build with cirrusci/flutter, serve static via nginx-unprivileged or distroless static.
- PostgreSQL **17.x** (`postgres:17-bookworm` / `-alpine`).
- Coolify **v4.1** (May 2026): build packs = **Dockerfile / Nixpacks / Railpack / Static / Docker Compose / Docker Image**; Traefik proxy; Let's Encrypt auto-SSL; GitHub App auto-deploy; per-branch **preview deployments** (`{{pr_id}}.{{domain}}`); **healthcheck-gated rolling** swap (true Compose zero-downtime slated for v5); rollback to previously stored local images; CPU/memory **resource limits**; persistent **storage** (volumes/bind/file mounts); deploy **webhook API** (`POST /api/v1/deploy?uuid=...&force=...` with bearer token).
- Tooling gates: **hadolint** (Dockerfile linter), **actionlint** (workflow linter), **trivy** (image/fs CVE + secret scan), Docker **BuildKit** secrets (`--mount=type=secret`), GHA OIDC (`id-token: write`), `docker/build-push-action@v6`, `cache-from/to: type=gha,mode=max`.

---

## 1. Purpose & precise trigger

**Purpose (one line):** Take any app in this repo from source → hardened container →
green CI/CD pipeline → live on Coolify, with secrets that never leak into image layers
or logs, and a defined rollback path.

**Trigger description (frontmatter, verbatim target):**
> `Use when containerizing an app, writing a Dockerfile, setting up GitHub Actions CI/CD, or deploying to Coolify — multi-stage builds (FastAPI/uv, Go/distroless, Next.js standalone, Flutter web, Postgres), BuildKit build secrets, image scanning (trivy/hadolint), OIDC to registries (no long-lived secrets), least-privilege GITHUB_TOKEN, zero-downtime/rolling deploys, env/secrets flow GitHub→Coolify, healthchecks, and rollback strategy. Trigger phrases: 'dockerize', 'write a Dockerfile', 'CI pipeline', 'GitHub Actions', 'deploy', 'ship it', 'Coolify', 'docker-compose for local dev'.`

**When to use:**

- Authoring/auditing a `Dockerfile`, `.dockerignore`, or `docker-compose.yml`.
- Writing or hardening `.github/workflows/*.yml` (build, test, scan, release, deploy).
- Wiring a service onto Coolify (build pack choice, env/secrets, domains, healthcheck, auto-deploy, previews, rollback).
- Designing the secrets flow GitHub → registry → Coolify, or choosing rolling vs blue-green.

**When NOT to use:**

- Kubernetes / Helm / ECS / Nomad orchestration → out of scope (this skill targets Docker + GHA + Coolify single/multi-server PaaS). Say so and stop.
- Application runtime code, DB schema/migrations logic, or business logic → wrong skill.
- Cloud-specific IaC (Terraform, Pulumi, CloudFormation) → out of scope; only the GHA↔cloud **OIDC handshake** is covered, not provisioning.
- Pure local dev with no container ambition → likely overkill; mention compose option, defer.

---

## 2. `SKILL.md` outline (every heading + delivery note)

Target length **~330 lines**. One H1. Frontmatter: `name`, `description` (the trigger
block above, starting with "Use when"), `origin: risco`. Progressive disclosure: deep
material lives in `references/`.

### `# Ship it — Docker, GitHub Actions, Coolify`
One-line purpose + the pipeline mental model in one fenced block:
```
source → Dockerfile (multi-stage) → CI (lint·test·build·scan) → registry (ghcr) → Coolify (rolling) → live + rollback
```

### `## When to use / When NOT to use`
Two tight bullet lists (mirrors §1). Includes the explicit out-of-scope redirects (k8s, IaC).

### `## Decision rules` (the load-bearing core)
Four compact decision tables the agent consults first:
1. **Base image by stack** — FastAPI→distroless-python or `python:3.13-slim`; Go→`distroless/static:nonroot`; Next.js→`node:22-bookworm-slim` (standalone); Flutter web→`nginxinc/nginx-unprivileged`; Postgres→`postgres:17` (managed, not built).
2. **Build pack on Coolify** — have a Dockerfile → **Dockerfile pack** (always prefer; full control + parity with CI); no Dockerfile + standard stack → Nixpacks/Railpack; static SPA → Static; multi-service local parity → Compose. Rule: *if it has a Dockerfile, use the Dockerfile pack.*
3. **Deploy strategy** — backward-compatible change → **rolling** (Coolify default, healthcheck-gated); breaking/instant-cutover or risky migration → **blue-green** via two Coolify resources + domain swap; never canary on vanilla Coolify (no traffic split) → use feature flags instead.
4. **Secret delivery** — build-time non-secret → `ARG`; build-time secret (private dep token) → BuildKit `--mount=type=secret` (never `ARG`); runtime secret → Coolify env (marked secret) / GHA `secrets`; cloud auth → **OIDC, never a stored key**.

### `## Core principles`
8–10 directive one-liners: multi-stage always; pin digests in prod base images; non-root + read-only rootfs; one process per container; `.dockerignore` before first build; secrets never in layers/logs/`ARG`; cache deps before source; HEALTHCHECK that hits a real readiness path; 12-factor config (env only, validated at boot, fail-fast); least-privilege `GITHUB_TOKEN` (`permissions:` default-deny); every pipeline calls `scripts/verify.sh`.

### `## Docker — the canonical multi-stage shape`
Generic annotated multi-stage skeleton (builder → runtime) showing layer-cache ordering,
non-root user creation, `HEALTHCHECK`, and a **BuildKit secret mount** Good/Bad contrast:
```dockerfile
# GOOD: secret consumed in-layer, never persisted
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN="$(cat /run/secrets/npm_token)" npm ci
# BAD: ARG bakes the token into image history forever
ARG NPM_TOKEN
RUN npm ci   # token now in `docker history`
```
Plus a `.dockerignore` block and the one-liner build: `DOCKER_BUILDKIT=1 docker build --secret id=npm_token,env=NPM_TOKEN .`
→ pointer: **full per-stack Dockerfiles in `references/dockerfiles-by-stack.md`**.

### `## docker-compose for local dev + Postgres`
One ~35-line `compose.yaml` (Compose Spec, no `version:` key): app (build target `dev`,
bind mount, `develop.watch` hot reload), `db: postgres:17-alpine` with `pg_isready`
healthcheck + `depends_on: condition: service_healthy`, named volume, `127.0.0.1`-bound
port. Good/Bad note: bind-mount source for dev vs baked image for prod; never expose
Postgres `0.0.0.0` in prod. → pointer to references for prod overlay & `mailpit`.

### `## GitHub Actions — least-privilege pipeline`
A **complete, runnable** `ci.yml` excerpt: top-level `permissions: { contents: read }`,
`concurrency` group cancelling in-progress, a `verify` job calling
`./skills/.../verify.sh` (or repo `scripts/verify.sh`), and a `build-push` job with
`permissions: { contents: read, packages: write, id-token: write }`,
`docker/login-action@v3` to `ghcr.io` via `GITHUB_TOKEN`,
`docker/build-push-action@v6` with `cache-from/to: type=gha,mode=max`,
`provenance: true`, and a **trivy scan gate** (`exit-code: 1` on HIGH/CRITICAL).
Good/Bad contrast: scoped per-job `permissions` vs a blanket `write-all`.
→ pointer: **matrix, reusable workflows, OIDC-to-cloud, environments/approvals, release automation in `references/github-actions.md`**.

### `## Coolify — deploy target`
Dense bullets: pick **Dockerfile build pack** (parity with CI); set **Port Exposes**;
mark env vars **secret** (Coolify injects at runtime, encrypted at rest); set
**Health Check** path → enables rolling swap; attach **persistent storage** for stateful
paths; bind **custom domain** → automatic Let's Encrypt + Force HTTPS; enable **GitHub App
auto-deploy** OR call the **deploy webhook** from CI; **preview deployments** per PR;
set **CPU/memory limits**; **rollback** = redeploy a prior stored image. One fenced block:
the CI→Coolify deploy webhook call:
```bash
curl --fail -X POST \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  "https://coolify.example.com/api/v1/deploy?uuid=$APP_UUID&force=false"
```
→ pointer: **full Coolify walkthrough (build packs, secrets, volumes, SSL, previews, blue-green, rollback) in `references/coolify.md`**.

### `## Secrets flow (GitHub → registry → Coolify)`
One ASCII diagram + rules: GitHub `secrets`/OIDC mint short-lived creds → build pushes to
`ghcr.io` (no key stored) → Coolify pulls with a deploy-scoped PAT/registry cred → runtime
env injected by Coolify (encrypted). Rule: a secret crosses **at most one** trust boundary
per hop; nothing long-lived in a workflow file; `${{ }}` secrets are masked but
`set -x`/`echo` can leak them — forbid.

### `## 12-factor config & observability`
Compact: config strictly from env, validated at boot and **fail-fast** (Pydantic
`BaseSettings` for FastAPI; Zod for Next.js; `env.Parse` for Go — one 4-line example each).
Logs to **stdout as JSON** (slog for Go, structlog/uvicorn JSON for FastAPI, pino for
Next.js); never log secrets; expose `/healthz` (liveness) + `/readyz` (deps).

### `## Anti-patterns — rationalizations → STOP`
Markdown table, ~12 rows. Examples:
| Rationalization | STOP — do this instead |
| `:latest` is fine for now | Pin a tag+digest; `:latest` breaks reproducibility & rollback |
| I'll pass the token as `ARG` | BuildKit `--mount=type=secret`; `ARG` persists in history |
| `permissions: write-all` is simpler | Default-deny; grant per job (`packages: write`, `id-token: write`) |
| Store a registry password in GHA secrets | Use OIDC / `GITHUB_TOKEN`; no long-lived key |
| Run as root, it's just a container | Non-root UID + read-only rootfs + `cap_drop: ALL` |
| Skip the healthcheck, app boots fast | No healthcheck = no rolling gate = downtime/bad-version live |
| Copy the whole repo then `RUN install` | Copy lockfile first; cache deps layer |
| Nixpacks is easier than my Dockerfile | If a Dockerfile exists, use it — CI/prod parity |
| Secrets in `compose.yaml` env | `.env` (gitignored) / Coolify secret env |
| Migrate DB destructively in deploy | Backward-compatible migrations or rolling breaks |
| `echo $SECRET` to debug CI | Never; masked vars still leak via logs |
| Build once per env with different secrets | Build one image, inject config at runtime (12-factor) |

### `## Quick reference`
One table: task → command/file. Rows: build w/ secret, scan image (trivy), lint Dockerfile
(hadolint), lint workflows (actionlint), run verify gate, local up (`docker compose up --watch`),
trigger Coolify deploy, roll back. Plus a "pre-ship checklist" (8 boxes:
non-root · pinned base · `.dockerignore` · HEALTHCHECK · no secrets in layers · least-priv
token · trivy clean · rollback path known).

### `## See Also`
Links to sibling skills: `risco-project-harness` (01-TOOLS provider creds that become
Coolify env), and references files. Note FastAPI/Next.js/Go app-code skills if present.

### `## References`
Bullet list pointing to the three `references/*.md` + `scripts/verify.sh`, one line each.

---

## 3. `references/` files — outlines + key code

### 3a. `references/dockerfiles-by-stack.md` (~420 lines)

One H1, then one H2 per stack. Each: the **complete runnable Dockerfile**, a matching
`.dockerignore`, the build command, image-size expectation, and a "gotchas" note.

- `## FastAPI + uv (Python 3.13)` — multi-stage: builder uses `ghcr.io/astral-sh/uv` to
  `uv sync --frozen --no-dev --no-install-project` (cache layer) then project; runtime =
  `gcr.io/distroless/python3-debian12:nonroot` copying `/app/.venv`; `ENV PATH=/app/.venv/bin:$PATH`,
  `UV_COMPILE_BYTECODE=1`, `UV_LINK_MODE=copy`; `HEALTHCHECK` via python urllib to `/healthz`;
  `CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8000"]`. Gunicorn+uvicorn-worker
  variant for multi-core. Gotcha: distroless has no shell → exec-form CMD only, healthcheck via python not curl.
- `## Go (1.24, static + distroless)` — builder `golang:1.24-bookworm`, cache `go mod download`
  via `--mount=type=cache`, `CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w"`;
  runtime `gcr.io/distroless/static-debian12:nonroot`; `USER nonroot:nonroot`; ~10MB image;
  Go 1.22+ `net/http.ServeMux` routing + `slog` note. Healthcheck via the binary's own
  `-health` subcommand (no shell/wget in static). `--mount=type=cache` for build cache.
- `## Next.js 15 (standalone)` — require `output: "standalone"` in `next.config.ts` (show the
  3-line config); 3 stages: `deps` (npm ci / pnpm), `builder` (`npm run build`), `runner`
  `node:22-bookworm-slim` copying `.next/standalone`, `.next/static`, `public`; non-root
  `nextjs:nodejs` (uid/gid 1001); `ENV HOSTNAME=0.0.0.0 PORT=3000`; `CMD ["node","server.js"]`;
  build-time public env via `ARG NEXT_PUBLIC_*`, runtime secrets injected by Coolify. Gotcha:
  `NEXT_PUBLIC_*` are baked at build → not secret; standalone needs static/public copied manually.
- `## Flutter web (Dart 3 stable)` — builder `ghcr.io/cirruslabs/flutter:stable`
  `flutter build web --release --base-href=/`; runtime `nginxinc/nginx-unprivileged:1.27-alpine`
  serving `/usr/share/nginx/html`; ship a minimal `nginx.conf` with SPA fallback
  (`try_files $uri $uri/ /index.html`), gzip, cache headers; non-root by default. Gotcha:
  Flutter web runtime config via `--dart-define` at build or a fetched `config.json` at runtime.
- `## Postgres (17)` — *don't build a custom Postgres image for prod* — use managed Coolify DB
  or the official `postgres:17-alpine`. Show local dev service + init SQL mount +
  `pg_isready` healthcheck + tuned `shared_buffers` via `command`. Backups note (Coolify S3).
- `## Cross-cutting` — `.dockerignore` master template; HEALTHCHECK patterns per base
  (shell vs distroless); **reproducible builds** (pin digest `FROM img@sha256:...`,
  `SOURCE_DATE_EPOCH`, `--no-cache` caveat); **trivy** local scan command
  (`trivy image --severity HIGH,CRITICAL --exit-code 1 myimg`) and `hadolint Dockerfile`;
  multi-arch note (`docker buildx --platform linux/amd64,linux/arm64`).

### 3b. `references/github-actions.md` (~460 lines)

One H1, H2 per concern. Every workflow is complete and valid (passes actionlint).

- `## Workflow anatomy & least privilege` — top-level `permissions: { contents: read }`
  default-deny, escalate per job; `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }`; pin actions by major (`@v4`) with note on SHA-pinning for supply-chain hardening.
- `## Caching` — `setup-python`/`setup-node`/`setup-go` built-in `cache:`; `astral-sh/setup-uv@v6` with `enable-cache: true`; `actions/cache@v4` keyed on lockfile hash; Docker `cache-from/to: type=gha,mode=max`. Good/Bad: cache key including OS+lockfile hash vs a static key.
- `## Job matrix` — `strategy.matrix` across the repo's stacks (python/go/node) calling each
  stack's verify step; `fail-fast: false`.
- `## Build & push to ghcr (OIDC-style, no stored key)` — full job: `permissions:{contents:read,packages:write,id-token:write}`, `docker/metadata-action@v5` for tags/labels (sha + semver), `docker/login-action@v3` w/ `GITHUB_TOKEN`, `docker/build-push-action@v6` (`provenance:true`, `sbom:true`, gha cache), passing a build secret via `secrets:`.
- `## OIDC to cloud (AWS example)` — `aws-actions/configure-aws-credentials@v4` with
  `role-to-assume` + `id-token: write`, **no** `aws-access-key-id` secret; one paragraph
  on the trust policy `sub` claim (`repo:org/repo:ref:refs/heads/main`) to scope the role.
- `## Reusable & composite workflows` — a `workflow_call` reusable that takes `inputs` +
  `secrets: inherit`; a `composite` action wrapping checkout+setup+verify; how the matrix calls it.
- `## Security gates` — required checks: lint (ruff/eslint/golangci-lint), test, `trivy fs`
  (deps/secrets) + `trivy image`, `actionlint`, `hadolint`. Block merge via branch protection
  note. **gitleaks/trivy secret** scan to catch leaked creds.
- `## Environments & approvals` — `environment: production` with required reviewers + wait
  timer; environment-scoped secrets; protected by deployment branch rules.
- `## Release automation` — tag-triggered (`on: push: tags: ['v*']`) job: build, push
  `:latest` + `:vX.Y.Z`, `softprops/action-gh-release@v2` with generated notes; semantic
  version from tag via metadata-action.
- `## Calling verify.sh` — the canonical `- run: bash scripts/verify.sh` step and why the
  same gate runs locally + in CI (parity). Show invoking it inside the matrix.
- `## Deploy step (→ Coolify)` — final job gated on `environment`, curl the Coolify webhook
  (`secrets.COOLIFY_TOKEN`, `vars.COOLIFY_APP_UUID`), `--fail` + poll deployment status; or
  rely on Coolify GitHub App (then CI only builds/scans, Coolify builds+deploys).

### 3c. `references/coolify.md` (~380 lines) — RESEARCHED, v4.1-current

One H1, H2 per Coolify concern. Concrete field names from current docs.

- `## What Coolify is (v4)` — self-hosted PaaS; Traefik reverse proxy; multi-server
  orchestration; 280+ one-click services; positions vs Heroku/Vercel. Version-dated note (v4.1, May 2026).
- `## Build packs — pick one` — table: **Dockerfile** (full control, CI parity — default
  recommendation), **Nixpacks** (auto-detect, zero-config), **Railpack** (newer, build-time
  env + multi-stage + config merge), **Static**, **Docker Compose**, **Docker Image**
  (deploy a prebuilt `ghcr.io` image from CI — the recommended split: CI builds, Coolify deploys).
- `## Env vars & secrets` — add via UI/API; mark **Is Secret** (encrypted at rest, hidden in
  logs/UI); **Build-time** vs **Runtime** toggle (`NEXT_PUBLIC_*` need build-time); shared
  (team/project) vs resource-scoped; never commit; mapping from GitHub secret → Coolify env.
- `## Persistent storage` — volume mounts, bind mounts, file mounts (e.g. a config file);
  what survives redeploys; warning that container FS is ephemeral; DB data must be a volume/managed DB.
- `## Healthchecks → rolling deploys` — set Health Check Path/Port/interval; Coolify waits
  for healthy new container before swapping (rolling, gated); note true Compose zero-downtime
  is v5; the Dockerfile `HEALTHCHECK` vs Coolify's configured check (Coolify's wins for the swap gate).
- `## Custom domains & SSL` — assign domain(s), automatic Let's Encrypt, **Force HTTPS**,
  wildcard for previews, redirect www. DNS A/AAAA pointing to the server.
- `## Managed databases` — provision Postgres 17 / Redis / etc. as a Coolify resource; internal
  connection string via service name; **S3 backups**; not exposing publicly by default.
- `## Auto-deploy & webhooks` — GitHub App (recommended, fine-grained) vs deploy-key + webhook;
  the **deploy API**: `POST /api/v1/deploy?uuid=<app>&force=<bool>` with `Authorization: Bearer <token>`;
  webhook secret for GitHub push events; branch filter.
- `## Preview deployments` — enable per-PR; URL template `{{pr_id}}.{{domain}}`; ephemeral env;
  separate (non-prod) secrets; auto-teardown on PR close.
- `## Resource limits` — CPU/memory limits + reservations per resource; why to set them
  (noisy-neighbor, OOM protection); maps to compose `deploy.resources`.
- `## Rollback` — Coolify keeps prior built images locally → one-click redeploy of a previous
  version; combine with backward-compatible migrations; documented rollback runbook.
- `## Blue-green on Coolify` — pattern: two resources (blue/green) behind one domain, deploy to
  idle, verify, swap the domain → instant cutover + instant rollback (since vanilla Coolify
  rolling can't fully prevent overlap for stateful Compose). When to use vs default rolling.
- `## Observability` — Coolify log viewer (stdout/stderr), per-deployment logs; ship JSON logs;
  external aggregation (Loki/Grafana) note; notification channels on deploy success/failure.

---

## 4. `scripts/verify.sh` contract

Idempotent, end-user runs it **inside their own project** (and CI runs the same file →
parity). Starts `#!/usr/bin/env bash` + `set -euo pipefail`. Top usage comment block.
Tool-detect pattern: `command -v <tool>` → if missing, print a **yellow** warning
(`\033[33m`) and `skip` (continue); never fail on a missing tool. Exit non-zero **only**
on a real check failure. `chmod +x` after writing. **Do NOT execute it in this repo.**

Helpers: `have() { command -v "$1" >/dev/null 2>&1; }`, color vars (respect `NO_COLOR`),
`warn`/`ok`/`fail` printers, a `FAILED=0` accumulator so all checks run before exiting.

Exact checks, **in order**:

1. **Discover artifacts** — glob `Dockerfile*`, `**/Dockerfile`, `compose*.y*ml`,
   `.github/workflows/*.y*ml`. If none found at all → print info, exit 0 (nothing to gate).
2. **hadolint** — if present, run on each discovered `Dockerfile*`
   (`hadolint --failure-threshold warning <file>`). Missing → yellow skip. Failure → `FAILED=1`.
3. **actionlint** — if present and `.github/workflows` exists, run `actionlint`
   (it self-discovers). Missing → yellow skip. Findings → `FAILED=1`.
4. **trivy config** (optional, fast) — if present, `trivy config --exit-code 1 --severity HIGH,CRITICAL .`
   to catch Dockerfile/compose misconfig + IaC. Missing → skip.
5. **docker build smoke** — only if `docker` present AND BuildKit usable AND a `Dockerfile`
   exists: `DOCKER_BUILDKIT=1 docker build --pull --target '' -t verify-smoke:local -f <Dockerfile> .`
   guarded so build failure → `FAILED=1` but absence of docker → skip. Honor env
   `SKIP_DOCKER_BUILD=1` to opt out (CI without docker, slow machines).
6. **trivy image** — only if step 5 actually built an image: `trivy image --exit-code 1
   --severity HIGH,CRITICAL --ignore-unfixed verify-smoke:local`. Missing trivy → skip.
7. **Summary** — print per-check status table; `exit $FAILED`.

Guarantees: missing tool ⇒ warn+skip+exit-0 for that check; real failure ⇒ exit 1; safe to
re-run; no writes outside a throwaway local image tag; usage comment documents
`SKIP_DOCKER_BUILD` and `NO_COLOR`.

---

## 5. Quality differentiators (why this beats the ECC equivalents)

1. **Current & version-stated everywhere** — Go 1.24, Python 3.13 + uv, Node 22 + Next 15.5
   standalone, Postgres 17, Coolify v4.1. ECC `deployment-patterns` still shows Go 1.22 /
   Python 3.12 / `npm prune --production` and no uv, no distroless, no BuildKit secrets.
2. **BuildKit `--mount=type=secret` as a first-class rule** with a Good/Bad `docker history`
   leak demo — ECC only says "use env vars," never shows the layer-leak failure mode.
3. **Distroless + non-root UID 65532 + read-only rootfs** per stack with the shell-less
   HEALTHCHECK gotchas spelled out — ECC uses alpine + root-ish patterns and shell wget healthchecks.
4. **OIDC-first, zero long-lived keys** — least-privilege `permissions:` per job, OIDC to
   cloud, `GITHUB_TOKEN` to ghcr, provenance+SBOM — ECC's sample uses blanket implicit perms
   and shows registry login but no privilege scoping or supply-chain attestation.
5. **Real Coolify v4 chapter** (researched, not generic) — exact build-pack decision, the
   `/api/v1/deploy?uuid=` webhook, preview-URL template, healthcheck-gated rolling, and a
   **blue-green-via-two-resources** recipe to work around vanilla Coolify's rolling limits —
   ECC has no Coolify content at all.
6. **One runnable `verify.sh` gate that runs identically locally and in CI** (hadolint +
   actionlint + trivy + build smoke, skip-on-missing) — turns the skill into an enforceable
   contract, not prose; ECC offers checklists but no executable gate.
7. **Stack-matched config validation + JSON logging trio** (Pydantic Settings / Zod /
   `env.Parse` + slog) wired to fail-fast 12-factor boot — concrete per-language, not the
   single TS snippet ECC shows.
8. **Explicit secrets-flow trust-boundary model** (GitHub → ghcr → Coolify, one hop per
   boundary, nothing long-lived) and a `set -x`/`echo`-leak prohibition — ECC treats secrets
   as a one-line "use a secrets manager."

---

## File manifest to produce next

```
skills/deployment/SKILL.md                              (~330 lines)
skills/deployment/references/dockerfiles-by-stack.md    (~420 lines)
skills/deployment/references/github-actions.md          (~460 lines)
skills/deployment/references/coolify.md                 (~380 lines)
skills/deployment/scripts/verify.sh                     (executable, chmod +x, not run here)
```
