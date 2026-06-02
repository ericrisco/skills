# railway.json / railway.toml — full field reference

Config as code lives in `railway.json` **or** `railway.toml` at the service root. The fields a
file sets **override the dashboard**; per-environment overrides nest under `environments.<name>`
and take precedence over the base config. Schema: `https://railway.com/railway.schema.json`.

Precedence, highest to lowest: `environments.<active>.*` → base file config → dashboard.

## Build section

| Field | Type | Notes |
| --- | --- | --- |
| `builder` | `RAILPACK` \| `DOCKERFILE` | Default `RAILPACK` (successor to Nixpacks). A Dockerfile is auto-detected; `DOCKERFILE` forces it. |
| `buildCommand` | string | Overrides the inferred build step. |
| `watchPatterns` | string[] | Glob paths that, when changed, trigger a rebuild on auto-deploy (e.g. `["src/**"]`). |
| `dockerfilePath` | string | Path to the Dockerfile when not at root (with `builder: DOCKERFILE`). |
| `railpackVersion` | string | Pin the Railpack version for reproducible builds. |

## Deploy section

| Field | Type | Notes |
| --- | --- | --- |
| `startCommand` | string | Command to run the service. Set this if Railpack can't infer it. |
| `preDeployCommand` | string | Runs once before the new version goes live (e.g. DB migration). |
| `healthcheckPath` | string | Path Railway polls before marking the deploy healthy (e.g. `/healthz`). Must return 2xx. |
| `healthcheckTimeout` | number (s) | How long to wait for the healthcheck to pass before failing the deploy. |
| `restartPolicyType` | `ON_FAILURE` \| `ALWAYS` \| `NEVER` | What to do when the container exits. |
| `restartPolicyMaxRetries` | number | Cap on restart attempts under `ON_FAILURE`. |
| `numReplicas` | number | Horizontal replica count. Incompatible with an attached volume (volume pins to 1). |
| `multiRegionConfig` | object | Per-region replica config for multi-region deploys. |
| `cronSchedule` | string (cron) | Run the service as a cron job on this schedule instead of long-running. |
| `overlapSeconds` | number | Seconds the old + new versions overlap during a deploy (zero-downtime tuning). |
| `drainingSeconds` | number | Grace period to drain in-flight requests before the old version is killed. |

## JSON variant

```jsonc
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": {
    "builder": "RAILPACK",
    "buildCommand": "npm run build",
    "watchPatterns": ["src/**", "package.json"]
  },
  "deploy": {
    "startCommand": "node dist/server.js",
    "preDeployCommand": "npm run migrate:deploy",
    "healthcheckPath": "/healthz",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10,
    "overlapSeconds": 20,
    "drainingSeconds": 15
  },
  "environments": {
    "production": {
      "deploy": { "numReplicas": 2 }
    },
    "staging": {
      "build": { "buildCommand": "npm run build:staging" },
      "deploy": { "numReplicas": 1 }
    }
  }
}
```

## TOML variant (same fields)

```toml
"$schema" = "https://railway.com/railway.schema.json"

[build]
builder = "RAILPACK"
buildCommand = "npm run build"
watchPatterns = ["src/**", "package.json"]

[deploy]
startCommand = "node dist/server.js"
preDeployCommand = "npm run migrate:deploy"
healthcheckPath = "/healthz"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10
overlapSeconds = 20
drainingSeconds = 15

[environments.production.deploy]
numReplicas = 2

[environments.staging.build]
buildCommand = "npm run build:staging"

[environments.staging.deploy]
numReplicas = 1
```

## Dockerfile builds

```jsonc
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "docker/Dockerfile.prod"
  },
  "deploy": { "startCommand": "" }
}
```

With `DOCKERFILE`, the image's `CMD`/`ENTRYPOINT` drives startup; leave `startCommand` empty
unless you intend to override it. For Dockerfile authoring itself, see the `docker` and
`deployment` skills — this reference only covers wiring it into Railway.

## Notes

- Never inline secrets here. Anything sensitive belongs in variables, referenced as
  `${{Service.VAR}}`. The config file is committed to the repo.
- `cronSchedule` turns a service into a scheduled job; it should exit when done rather than
  staying resident.
- A volume forces a single replica — do not set `numReplicas > 1` on a service with a volume.
