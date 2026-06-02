# netlify.toml — full annotated reference

Source of truth: `netlify.toml` at the repo root (or under `base` if set). All tables are
optional; the dashboard fills gaps but the toml wins for keys it declares.

## [build]

```toml
[build]
  base      = "frontend"            # subdir to cd into before building (monorepo root)
  command   = "npm run build"       # the build command
  publish   = "dist"                # dir to deploy; relative to base
  functions = "netlify/functions"   # Functions source dir
  edge_functions = "netlify/edge-functions"
  [build.environment]
    NODE_VERSION = "22"             # also: NPM_FLAGS, PYTHON_VERSION, etc.
```

`base` shifts the working directory; `publish` and `functions` are then relative to it. Get
this wrong in a monorepo and the build can't find your output.

## [functions]

```toml
[functions]
  node_bundler          = "esbuild"          # default modern bundler
  included_files        = ["data/**", "!data/secret.json"]  # extra files to bundle (globs)
  external_node_modules = ["sharp"]          # leave these unbundled (native deps)
  # per-function overrides:
  [functions."heavy-job"]
    included_files = ["templates/**"]
```

`included_files` is how a function reads a file at runtime — by default only the handler and
its imports are bundled. Native modules that break under esbuild go in `external_node_modules`.

## [[redirects]]

```toml
[[redirects]]
  from   = "/old/*"
  to     = "/new/:splat"
  status = 301            # default 301 if omitted
  force  = false          # true = override an existing file at `from`
  query  = { id = ":id" } # match/forward query params
  conditions = { Role = ["admin"], Country = ["US"] }
  [redirects.headers]
    X-From = "redirect"
  signed = "API_SIGNATURE_TOKEN"  # for signed proxy redirects
```

Fields: `from`, `to`, `status`, `force`, `query`, `conditions`, `headers`, `signed`. SPA
fallback is `from="/*" to="/index.html" status=200`. Proxy/rewrite is `status=200` to a
remote URL. First matching rule wins, top-to-bottom; `_redirects` file rules run before these.

## [[headers]]

```toml
[[headers]]
  for = "/*"
  [headers.values]
    Content-Security-Policy = "default-src 'self'; script-src 'self'"
    X-Frame-Options         = "DENY"
    X-Content-Type-Options  = "nosniff"
    Referrer-Policy         = "strict-origin-when-cross-origin"
    # cache static assets aggressively under a hashed path
  [[headers]]
    for = "/assets/*"
    [headers.values]
      Cache-Control = "public, max-age=31536000, immutable"
```

`_headers` file rules are processed before these.

## [[edge_functions]]

```toml
[[edge_functions]]
  function     = "geo-rewrite"   # filename (no ext) in netlify/edge-functions/
  path         = "/*"            # URLPattern
  excludedPath = "/assets/*"     # carve-outs
```

Multiple matches on one path run in declaration order, top-to-bottom — the deterministic
reason to declare here rather than via inline `config`.

## [context.*]

```toml
[context.production]
  command = "npm run build"
[context.deploy-preview]
  command = "npm run build:preview"
  [context.deploy-preview.environment]
    SHOW_PREVIEW_BANNER = "true"
[context.branch-deploy]
  command = "npm run build:staging"
[context."release"]            # a specific branch named "release"
  command = "npm run build:release"
```

Any `[build]` key (command, publish, environment, edge_functions, …) can be overridden per
context. Contexts: `production`, `deploy-preview`, `branch-deploy`, `branch."name"`.

## [[plugins]]

```toml
[[plugins]]
  package = "@netlify/plugin-lighthouse"
  [plugins.inputs]
    output_path = "reports/lighthouse.html"
```

Build plugins run at build time around the build command. Install the package (or use a
UI-installed plugin) and configure inputs here.
