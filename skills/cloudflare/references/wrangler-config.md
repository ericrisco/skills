# wrangler.jsonc — full config, environments, migration

Config may be `wrangler.toml`, `wrangler.json`, or `wrangler.jsonc`. Prefer **jsonc** so bindings can carry comments. Wrangler is **v4**. Minimum keys: `name`, `main`, `compatibility_date`.

## Annotated config

```jsonc
{
  "name": "my-app",
  "main": "src/index.ts",
  // Set to the date you start the project. It pins runtime + flag defaults so deploys
  // are reproducible. Bump it deliberately to opt into newer behavior.
  "compatibility_date": "2026-06-02",
  // Flags toggle behaviors not yet default for your date. nodejs_compat auto-enables
  // at compatibility_date 2025-10-01+, so you can drop it once you bump past that.
  "compatibility_flags": ["nodejs_compat"],

  "observability": { "enabled": true },     // structured logs in the dashboard
  "vars": { "API_BASE": "https://api.example.com" },  // non-secret config only

  "assets": {
    "directory": "./dist",
    "binding": "ASSETS",
    "not_found_handling": "single-page-application", // or "404-page"
    "run_worker_first": true                 // Worker runs before static serving (API routes)
  },

  "r2_buckets":   [{ "binding": "BUCKET",  "bucket_name": "uploads" }],
  "d1_databases": [{ "binding": "DB", "database_name": "app", "database_id": "<id>" }],
  "kv_namespaces":[{ "binding": "CACHE",  "id": "<namespace-id>" }],
  "queues": {
    "producers": [{ "binding": "JOBS", "queue": "thumbnails" }],
    "consumers": [{ "queue": "thumbnails", "max_batch_size": 10, "max_retries": 3,
                    "dead_letter_queue": "thumbnails-dlq" }]
  },

  // Named environments inherit top-level config and override per env.
  "env": {
    "staging": {
      "vars": { "API_BASE": "https://staging-api.example.com" },
      "d1_databases": [{ "binding": "DB", "database_name": "app-staging", "database_id": "<id>" }]
    }
  }
}
```

Deploy a named env: `wrangler deploy --env staging`.

## Routes & custom domains

```jsonc
"routes": [
  { "pattern": "app.example.com", "custom_domain": true },     // Cloudflare-managed cert
  { "pattern": "example.com/api/*", "zone_name": "example.com" }
]
```

`workers_dev: false` disables the `*.workers.dev` URL once you have a custom domain. DNS records themselves (A/CNAME/MX) are the Cloudflare DNS product — see `../../domains-dns/SKILL.md`.

## Compatibility dates & flags

- `compatibility_date` pins the runtime semantics for your Worker. Set it once at project start; bumping it can change defaults.
- `compatibility_flags` opt into individual behaviors ahead of or behind the date. Example: `nodejs_compat` auto-enables at `2025-10-01`+.
- Reproducibility rule: never leave `compatibility_date` unset. An unpinned Worker silently shifts behavior across deploys.

## Static Assets routing options

- `not_found_handling: "single-page-application"` — serve `index.html` on any miss (client-side router).
- `not_found_handling: "404-page"` — serve `/404.html`.
- `run_worker_first: true` — invoke the Worker before serving assets, so `/api/*` reaches your handler.
- Without `run_worker_first`, a matching static file is served and the Worker never runs for that path.

## Pages → Workers migration checklist

Workers Static Assets is the recommended target for new full-stack work; Pages still functions but new projects point at Workers. Workers Sites is deprecated in Wrangler v4 — do not use it.

1. Move build output dir into `assets.directory` (e.g. `./dist`).
2. Replace Pages Functions in `functions/` with a single Worker `main` entrypoint that routes (`run_worker_first` for API paths).
3. Convert Pages bindings (dashboard) into `wrangler.jsonc` binding blocks.
4. Set `compatibility_date` + needed `compatibility_flags`.
5. `wrangler deploy` and verify each binding resolves (run `verify.sh` / `--dry-run`).
6. Remove any `[site]` / `site =` Workers-Sites config — it is deprecated and unsupported by the Vite plugin.

## Scaffolding

```bash
npm create cloudflare@latest my-app                       # plain Worker
npm create cloudflare@latest my-app -- --framework=react  # Vite + React SPA (GA plugin)
```

C3 picks a correct `compatibility_date` and generates `Env` types — start here rather than hand-writing config.
