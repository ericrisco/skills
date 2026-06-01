# Coolify (v4.1) — deploy target

Coolify v4.1 (mid-2026): a self-hosted PaaS using a Traefik reverse proxy and automatic Let's Encrypt SSL. This chapter maps every deploy decision to concrete Coolify fields. Back to the entrypoint: `../SKILL.md`.

## What Coolify is (v4)

- Self-hosted PaaS you run on your own server(s) — a Heroku/Vercel replacement without per-seat or per-build pricing.
- **Traefik** reverse proxy fronts every app: routing, automatic TLS, and the rolling-swap gate.
- Multi-server orchestration: one control plane manages many target servers (build on one, run on others).
- 280+ one-click services (databases, queues, dashboards) plus your own apps from Git or a registry.
- Positioning: Vercel-like DX (push to deploy, preview URLs) on infrastructure you own and price you control.

## Build packs — pick one

| Build pack | When | Notes |
| --- | --- | --- |
| Dockerfile | Repo has a Dockerfile | Full control + exact CI/prod parity — **default recommendation** |
| Nixpacks | Standard stack, no Dockerfile | Auto-detects language, zero-config |
| Railpack | Newer auto-builder | Build-time env + multi-stage + config merge |
| Static | SPA / static site, no server | Serves a build output directory |
| Docker Compose | Multi-service in one repo | Mirrors local `compose.yaml` |
| Docker Image | CI already builds & pushes | Deploy a prebuilt `ghcr.io` image — the recommended CI/Coolify split |

The clean split: CI builds, scans, and pushes to `ghcr.io`; Coolify uses the **Docker Image** pack to deploy that exact, already-scanned image — no rebuild, perfect parity.

Decision flow when you create a new resource:

1. Does the repo have a `Dockerfile`? → **Dockerfile** pack. Stop here; this is the default.
2. No Dockerfile, but it's a standard framework (Next.js, FastAPI, Go, Rails)? → **Nixpacks** or **Railpack** (auto-detect). Add a Dockerfile later for control.
3. Pure static output (Flutter web build, Vite/CRA `dist/`, Hugo)? → **Static** (point at the build directory).
4. Several services that must run together (app + worker + redis) and you already maintain a `compose.yaml`? → **Docker Compose**.
5. CI already pushes a tested image to a registry? → **Docker Image** (paste `ghcr.io/org/app:sha-<commit>`; Coolify pulls, never builds).

For the Docker Image pack, give Coolify a deploy-scoped registry credential (a GitHub PAT with `read:packages`, or a Coolify-managed registry connection) so it can pull the private image. The CI side stays as in `github-actions.md`; Coolify only pulls and runs.

## Env vars & secrets

- Add env vars in the resource's **Environment Variables** tab (UI) or via the API.
- Toggle **Is Secret** → the value is encrypted at rest and masked in the UI and logs.
- Toggle **Build-time** vs **Runtime**: `NEXT_PUBLIC_*` and other build-baked vars must be **Build-time** (they're inlined during `npm run build`); everything else is **Runtime** and injected into the container env.
- Scope: **shared** variables (team/project-wide) vs **resource-scoped**; reference shared values with Coolify's `{{ }}` interpolation.
- Mapping a GitHub secret → Coolify: the GitHub secret is consumed in CI (build/scan); the runtime equivalent is set independently as a Coolify Runtime secret. Don't try to forward GHA secrets into the running container — set them in Coolify.

```bash
# Set a runtime secret via the API (token from Coolify → Keys & Tokens)
curl --fail -X PATCH \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"key":"DATABASE_URL","value":"postgres://...","is_secret":true,"is_build_time":false}' \
  "https://coolify.example.com/api/v1/applications/$APP_UUID/envs"
```

## Persistent storage

- **Volume mounts**: Docker-managed named volumes for app data (the default for stateful paths).
- **Bind mounts**: a host path into the container — for host-managed files.
- **File mounts**: paste file contents (e.g. a `config.yaml`) that Coolify writes into the container at a path.
- Only mounted paths survive a redeploy — the container filesystem is **ephemeral** and reset on every deploy.
- Database data must live on a volume or, better, a Coolify **managed database** — never on the app container's FS.

## Healthchecks → rolling deploys

- Set **Health Check** Path, Port, Interval, Timeout, and Retries on the resource.
- On deploy, Coolify starts the new container and waits for it to report healthy **before** routing traffic and stopping the old one — a healthcheck-gated rolling swap.
- A failing healthcheck aborts the swap: the old container keeps serving, so a broken build never goes live.
- True zero-downtime for multi-service **Compose** is slated for v5; single-service rolling is solid in v4.1.
- The Dockerfile `HEALTHCHECK` documents intent and works in `docker compose`; **Coolify's configured check is what gates the swap** — set it explicitly in the UI.

Field reference (UI → Health Checks):

| Field | Typical value | Meaning |
| --- | --- | --- |
| Path | `/readyz` | Endpoint that returns 200 only when deps (DB, cache) are reachable |
| Port | container port (`8000`) | The internal port to probe, not the public domain |
| Interval | `10` s | Time between probes once running |
| Timeout | `5` s | A probe slower than this counts as a failure |
| Retries | `3` | Consecutive failures before the container is unhealthy |
| Start Period | `30` s | Grace window on boot where failures don't count (cold start, migrations) |

Use `/readyz` (checks DB connectivity) for the swap gate so a new container that can't reach Postgres never takes traffic; keep `/healthz` (liveness, no deps) for the in-Dockerfile `HEALTHCHECK`.

## Custom domains & SSL

- Assign one or more domains to the resource; point DNS **A/AAAA** records at the server IP.
- Coolify provisions a **Let's Encrypt** certificate automatically via Traefik and renews it.
- Enable **Force HTTPS** to redirect all HTTP to HTTPS.
- A **wildcard** domain (`*.example.com`) enables per-PR preview URLs.
- Configure www → apex (or apex → www) redirects in the domain settings.

## Managed databases

- Provision **PostgreSQL 17**, Redis, MySQL, MongoDB, and ClickHouse as first-class Coolify resources.
- Apps reach them over the internal network via the service name (no public exposure by default).
- Enable **scheduled S3 backups** on the database resource — Coolify runs `pg_dump`/equivalent to object storage.
- Keep databases internal: only expose a public port for a deliberate, firewalled admin path.

A managed Postgres resource exposes an internal hostname (the service name). Wire the app's `DATABASE_URL` to it as a Runtime secret:

```bash
# DATABASE_URL on the app resource (Runtime, Is Secret) — host is the DB service name,
# resolvable only on Coolify's internal network, never the public internet.
postgres://app:S3cret@postgres-abc123:5432/appdb
```

Backups and restore runbook:

1. On the database resource, enable **Scheduled Backups** → choose an S3 bucket + cron (e.g. nightly `0 3 * * *`).
2. Verify the first backup object lands in the bucket before trusting it.
3. To restore: provision a fresh DB resource, `pg_restore` (or `psql <dump`) the chosen backup into it, then repoint the app's `DATABASE_URL`.
4. Practice the restore at least once in a preview environment — an untested backup is not a backup.

## Auto-deploy & webhooks

Two trigger options — use exactly one:

- **GitHub App** (recommended): fine-grained per-repo access, push-to-deploy, and automatic preview deployments. Coolify builds + deploys on push.
- **Deploy webhook**: CI calls Coolify after it builds/scans. Pair with a webhook secret and a branch filter.

```bash
curl --fail -X POST \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  "https://coolify.example.com/api/v1/deploy?uuid=$APP_UUID&force=false"
```

`force=false` lets Coolify skip a redeploy when nothing changed; `force=true` forces a rebuild. The webhook secret validates GitHub push events; the branch filter limits which branch triggers a deploy.

## Preview deployments

- Enable **Preview Deployments** on the resource to spin up an ephemeral environment per pull request.
- URL template: `{{pr_id}}.{{domain}}` (requires the wildcard domain above).
- Previews get their own **non-prod** secrets — never reuse production credentials in a PR preview.
- Coolify **auto-tears-down** the preview when the PR is closed or merged.

## Resource limits

Set CPU and memory **limits** and **reservations** per resource to prevent a noisy neighbor from starving others and to enable OOM protection. These map directly to Compose `deploy.resources`:

```yaml
deploy:
  resources:
    limits:
      cpus: "1.0"
      memory: 512M
    reservations:
      cpus: "0.25"
      memory: 128M
```

## Rollback

Coolify keeps previously built images locally, so rolling back is a one-click redeploy of a prior version. Pair it with backward-compatible migrations so an older app version still runs against the current schema.

Runbook:

1. Verify the regression (error rate, logs, healthcheck).
2. Coolify → the resource → Deployments → select the last known-good build → **Redeploy**.
3. Confirm the new container passes the healthcheck and traffic is restored.
4. Investigate the bad build offline; do not redeploy `main` until fixed.

## Blue-green on Coolify

Vanilla Coolify rolling cannot fully prevent overlap for stateful Compose stacks or guarantee an instant atomic cutover. For breaking changes or risky migrations, run blue-green manually:

1. Create two resources, **blue** and **green**, from the same image.
2. The domain points at the live one (say blue).
3. Deploy the new version to the idle one (green) and verify it in isolation (its own preview domain).
4. Swap the custom domain from blue to green → instant cutover.
5. Keep blue warm for instant rollback (swap the domain back); decommission once green is proven.

Use blue-green for breaking/instant-cutover changes; use the default rolling swap for backward-compatible ones.

## Observability

- Coolify's **log viewer** streams each container's stdout/stderr and stores per-deployment logs.
- Ship logs as **JSON to stdout** (slog / structlog / pino) so they're parseable downstream.
- For retention and search, forward to an external aggregator (Loki/Grafana, or an OTLP collector).
- Configure **notification channels** (Discord, Slack, email, webhook) for deploy success/failure so a failed rolling swap pages you instead of silently keeping the old version live.
- Per-deployment logs are retained per build, so when a swap aborts you can read exactly why the new container failed its healthcheck without re-running anything.

## End-to-end checklist for a new service

A repeatable order that gets a containerized app live on Coolify with no rework:

1. Confirm the repo has a `Dockerfile` and `.dockerignore`; run `scripts/verify.sh` locally — it must be green.
2. Create the resource, choose the **Dockerfile** build pack (or **Docker Image** if CI pushes to ghcr).
3. Set **Ports Exposes** to the internal container port.
4. Add **Runtime** env vars; mark every credential **Is Secret**. Add `NEXT_PUBLIC_*` and other baked vars as **Build-time**.
5. Configure the **Health Check** (`/readyz`, container port, start period covering migrations).
6. Attach **persistent storage** for any stateful path, or wire a **managed database** resource and reference its internal connection string.
7. Bind the **custom domain**, enable **Force HTTPS**, point DNS at the server.
8. Choose **one** deploy trigger: GitHub App auto-deploy *or* the CI deploy webhook.
9. Set **CPU/memory limits** so the resource can't OOM the host.
10. Deploy. Watch the deployment log until the healthcheck passes and the swap completes.
11. Verify the rollback path: confirm a prior build is listed under Deployments before you ship the next change.

## Common failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| 502 / Bad Gateway via Traefik | App binds `127.0.0.1`, not `0.0.0.0`; or Ports Exposes is wrong | Bind `0.0.0.0` (set `HOSTNAME=0.0.0.0` for Next.js); match Ports Exposes to the listen port |
| Swap never completes, old version stays live | Healthcheck path 404s or the start period is too short | Point the check at a real `/readyz`; raise Start Period to cover migrations |
| Secret visible in build logs | Passed as a `NEXT_PUBLIC_*` or build ARG | Move it to a Runtime secret; never bake credentials at build time |
| Data lost on redeploy | Stateful path not mounted | Attach a volume, or move state to a managed database |
| `NEXT_PUBLIC_*` value is empty in the browser | Set as Runtime instead of Build-time | Toggle the var to Build-time and redeploy (it's inlined at build) |
