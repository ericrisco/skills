# fly.toml field reference

The full configuration surface. The SKILL.md body covers the common case; reach here for a key it did not show. Source: https://fly.io/docs/reference/configuration/ (accessed 2026-06-02).

## Top level

```toml
app              = "my-api"      # required, unique app name
primary_region   = "iad"        # 3-letter region code; the write/anchor region
kill_signal      = "SIGINT"     # signal sent on shutdown
kill_timeout     = "5s"         # grace period before SIGKILL
swap_size_mb     = 512          # optional swap file (helps memory-spiky workloads)

[experimental]
  # rarely needed; flags for unreleased behavior
```

## [build]

```toml
[build]
  dockerfile      = "Dockerfile"   # default if present
  # builder        = "paketobuildpacks/builder:base"   # buildpack instead of Dockerfile
  # image          = "flyio/myimage:latest"            # deploy a prebuilt image, skip build
  [build.args]
    NODE_VERSION = "22"
```

The image mechanics belong to ../docker/SKILL.md — Fly only consumes the build.

## Services: [http_service] vs [[services]]

`[http_service]` is the sugar for the common single HTTP service. Use `[[services]]` when you need raw TCP, multiple ports, or several services.

```toml
# Lower-level, explicit form
[[services]]
  internal_port = 8080
  protocol      = "tcp"
  processes     = ["web"]

  [[services.ports]]
    port     = 443
    handlers = ["tls", "http"]
  [[services.ports]]
    port        = 80
    handlers    = ["http"]
    force_https = true

  [services.concurrency]
    type       = "requests"   # "requests" | "connections"
    soft_limit = 200
    hard_limit = 250

  [[services.tcp_checks]]
    interval = "15s"
    timeout  = "2s"
  [[services.http_checks]]
    interval = "15s"
    timeout  = "2s"
    method   = "get"
    path     = "/health"
```

`internal_port` is the port your process listens on inside the container. `handlers` tell the Proxy how to terminate (`tls`, `http`). Exactly one service should define the public HTTP entrypoint.

## [[vm]]

Formerly `[[compute]]`. Bind to process groups via `processes`.

```toml
[[vm]]
  size       = "shared-cpu-1x"   # preset; sets cpus + memory together
  memory     = "512mb"           # override the preset memory
  cpu_kind   = "shared"          # "shared" | "performance"
  cpus       = 1
  processes  = ["web"]
```

Common sizes: `shared-cpu-1x/2x/4x/8x` (burstable), `performance-1x/2x/4x/8x` (dedicated). Memory presets scale with the size; override with `memory` for memory-heavy, low-CPU work.

## [processes]

```toml
[processes]
  web    = "node server.js"
  worker = "node worker.js"
```

Each key is a process group running the same image with a different command. `[[vm]]`, `[http_service]`, `[[mounts]]`, and `[[services]]` all target groups via `processes`. A group with no service takes no inbound traffic.

## [[mounts]]

```toml
[[mounts]]
  source             = "data"     # volume name
  destination        = "/data"    # mount path in the guest
  processes          = ["web"]
  initial_size       = "1gb"
  snapshot_retention = 7          # days of automatic volume snapshots
```

One volume per Machine, region-pinned, no replication. See the SKILL.md Volumes section and `multi-region.md`.

## [deploy]

```toml
[deploy]
  release_command = "npm run migrate"   # one-shot Machine run before the rollout goes live
  strategy        = "rolling"            # rolling | bluegreen | canary | immediate
  max_unavailable = 0.33                 # fraction (or int) of Machines down at once during rolling
```

`release_command` runs in a temporary Machine with the new image + secrets; if it exits nonzero, the deploy aborts. Ideal for migrations.

## [[statics]]

Serve static assets directly from the Proxy / object storage instead of your process:

```toml
[[statics]]
  guest_path = "/app/public"
  url_prefix = "/static/"
```

## [[files]]

Write files into the guest at boot — including secrets as files:

```toml
[[files]]
  guest_path  = "/etc/app/config.yaml"
  local_path  = "config/prod.yaml"     # ship a local file
[[files]]
  guest_path  = "/etc/app/sa.json"
  secret_name = "GCP_SA_JSON"          # materialize a secret as a file
[[files]]
  guest_path  = "/etc/app/banner.txt"
  raw_value   = "aGVsbG8="             # base64 inline content
```

Use `secret_name` for credentials a library expects on disk (e.g. a service-account JSON) rather than in an env var.

## [restart] and [metrics]

```toml
[restart]
  policy = "on-failure"   # "no" | "on-failure" | "always"

[metrics]
  port = 9091
  path = "/metrics"       # Prometheus scrape endpoint Fly ingests
```

The `[metrics]` endpoint is what `fly-autoscaler` reads to scale by custom metrics (see `multi-region.md` / the SKILL.md scaling table).
