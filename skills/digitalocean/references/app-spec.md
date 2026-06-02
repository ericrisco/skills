# App Platform app spec — full reference

The app spec is the single source of truth for an App Platform app. Version it in
`.do/app.yaml`, validate, then `create`/`update`. Below is a multi-component spec with the
fields you'll actually reach for.

```yaml
name: my-platform
region: nyc

# --- HTTP service: gets a public URL + auto TLS ------------------------------
services:
  - name: web
    github:
      repo: me/my-platform
      branch: main
      deploy_on_push: true
    build_command: npm ci && npm run build
    run_command: node dist/server.js
    instance_size_slug: apps-s-1vcpu-1gb
    instance_count: 2
    http_port: 8080
    routes:
      - path: /                       # ingress route for this component
    health_check:
      http_path: /healthz
      initial_delay_seconds: 10
      period_seconds: 10
      failure_threshold: 3
    autoscaling:                      # optional: scale instances on CPU
      min_instance_count: 2
      max_instance_count: 5
      metrics:
        cpu:
          percent: 70
    envs:
      - key: DATABASE_URL
        value: ${db.DATABASE_URL}
        scope: RUN_TIME
      - key: STRIPE_SECRET
        value: ${STRIPE_SECRET}
        type: SECRET
        scope: RUN_TIME

# --- background worker: no public route --------------------------------------
workers:
  - name: queue-worker
    github:
      repo: me/my-platform
      branch: main
      deploy_on_push: true
    run_command: node dist/worker.js
    instance_size_slug: apps-s-1vcpu-1gb
    instance_count: 1
    envs:
      - key: DATABASE_URL
        value: ${db.DATABASE_URL}
        scope: RUN_TIME

# --- static frontend: free (up to 3), served from the edge -------------------
static_sites:
  - name: marketing
    github:
      repo: me/my-platform-web
      branch: main
    build_command: npm ci && npm run build
    output_dir: dist
    routes:
      - path: /site

# --- one-off / pre-deploy job (e.g. migrations) ------------------------------
jobs:
  - name: migrate
    kind: PRE_DEPLOY                  # PRE_DEPLOY | POST_DEPLOY | FAILED_DEPLOY
    github:
      repo: me/my-platform
      branch: main
    run_command: npm run migrate
    instance_size_slug: apps-s-1vcpu-1gb
    envs:
      - key: DATABASE_URL
        value: ${db.DATABASE_URL}
        scope: RUN_TIME

# --- managed database referenced by ${db.*} ----------------------------------
databases:
  - name: db
    engine: PG                        # PG | MYSQL | REDIS (Valkey)
    production: true
    # or attach an existing cluster:
    # cluster_name: my-existing-cluster

# --- alerts ------------------------------------------------------------------
alerts:
  - rule: DEPLOYMENT_FAILED
  - rule: DOMAIN_FAILED
```

## Env scoping

| Field | Values | Use it for |
| --- | --- | --- |
| `scope` | `RUN_TIME`, `BUILD_TIME`, `RUN_AND_BUILD_TIME` | Keep build-only secrets out of the running container; runtime-only out of the build |
| `type` | (default plaintext), `SECRET` | `SECRET` for every token/password/key — encrypted at rest, hidden in dashboard |
| `value` | literal or `${...}` | `${db.DATABASE_URL}` / `${db.HOSTNAME}` from a `databases:` entry; `${OTHER_COMPONENT.HOSTNAME}` for inter-component |

## Instance size slugs (common)

| Slug | Class | Rough price |
| --- | --- | --- |
| `apps-s-1vcpu-0.5gb` / `apps-s-1vcpu-1gb` | Basic | from ~$5/mo per service |
| `apps-s-1vcpu-2gb` | Basic | ~$25/mo |
| `apps-d-1vcpu-2gb` / `apps-d-2vcpu-4gb` | Dedicated | ~$78/mo at the 2vcpu/4gb tier |

Start at the smallest basic slug. Move to dedicated only when shared-CPU contention shows up
in real metrics. Dynamic apps start at $5/mo per service; data-transfer overage is $0.02/GiB.

## Commands

```bash
doctl apps spec validate .do/app.yaml          # offline structural lint
doctl apps create --spec .do/app.yaml          # first deploy
doctl apps update <app-id> --spec .do/app.yaml # apply / roll back (re-apply prior spec)
doctl apps spec get <app-id> > .do/app.yaml    # pull the live spec back into git
doctl apps logs <app-id> <component> --type run --follow
```
