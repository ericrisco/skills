# Nitro server routes & rendering strategy

Companion to the SKILL "Nitro server routes" and "Rendering strategy" sections. Nitro is Nuxt's
server engine; everything under `server/` runs there.

## Server route handlers

| File | Maps to |
|---|---|
| `server/api/users.get.ts` | `GET /api/users` |
| `server/api/users.post.ts` | `POST /api/users` |
| `server/api/users/[id].get.ts` | `GET /api/users/:id` |
| `server/routes/sitemap.xml.ts` | `GET /sitemap.xml` (non-`/api` route) |
| `server/middleware/auth.ts` | runs on every request before handlers |

```ts
// server/api/users.post.ts
export default defineEventHandler(async (event) => {
  const body = await readBody<{ email: string }>(event)
  if (!body?.email?.includes('@')) {
    throw createError({ statusCode: 422, statusMessage: 'invalid email' })
  }
  const config = useRuntimeConfig(event)            // pass event for request-scoped config
  const created = await db.insert(body, config.dbUrl)
  setResponseStatus(event, 201)
  return created
})
```

Useful helpers: `getQuery(event)`, `getRouterParam(event, 'id')`, `readBody(event)`,
`getHeader(event, 'x-...')`, `setResponseHeader`, `setResponseStatus`, `sendRedirect`,
`getCookie`/`setCookie`, `createError`.

## Server middleware

```ts
// server/middleware/log.ts
export default defineEventHandler((event) => {
  // runs on every request; do not return a body unless you mean to short-circuit
  console.log(`${event.method} ${getRequestURL(event).pathname}`)
})
```

## Runtime config (private vs public)

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  runtimeConfig: {
    apiSecret: '',                 // server-only; override via NUXT_API_SECRET
    dbUrl: '',                     // server-only; NUXT_DB_URL
    public: {
      apiBase: '/api',             // shipped to the browser; NUXT_PUBLIC_API_BASE
    },
  },
})
```

Rule: anything under `public` (or any `NUXT_PUBLIC_*` env) is bundled into client JS and readable
by every visitor. Keep secrets at the top level and read them only in `server/` code via
`useRuntimeConfig(event)`. Empty-string defaults force the env var to be set in production.

## Route-rule recipes

`routeRules` in `nuxt.config.ts` sets per-route rendering and caching at the Nitro layer.

```ts
export default defineNuxtConfig({
  routeRules: {
    '/':              { prerender: true },                 // SSG at build time
    '/docs/**':       { prerender: true },
    '/blog/**':       { swr: 600 },                        // stale-while-revalidate, 10 min
    '/products/**':   { isr: true },                       // ISR — cache until next deploy/revalidate
    '/products/[id]': { isr: 3600 },                       // ISR with 1h TTL
    '/dashboard/**':  { ssr: false },                      // client-only SPA island
    '/legacy':        { redirect: '/new' },
    '/feed.xml':      { headers: { 'content-type': 'application/xml' } },
    '/api/**':        { cors: true, headers: { 'cache-control': 's-maxage=60' } },
  },
})
```

| Rule | Meaning |
|---|---|
| `prerender: true` | rendered at build, served as static HTML |
| `swr: <s>` | cached server render, revalidated in the background after `<s>` seconds |
| `isr: true \| <s>` | incremental static regeneration (needs a supporting preset, e.g. Vercel) |
| `ssr: false` | no server render; ship an SPA shell for this route |
| `redirect` / `headers` / `cors` | edge-level redirect, response headers, CORS |

## Cached event handlers

Cache expensive server work with `defineCachedEventHandler` (or `cachedFunction`):

```ts
export default defineCachedEventHandler(async (event) => {
  return await expensiveAggregate()
}, { maxAge: 60, swr: true, name: 'aggregate' })
```

Backed by Nitro storage; pick a KV/Redis storage driver for multi-instance deployments so the cache
is shared.

## Build & preset selection

- `nuxt build` → SSR/hybrid server output in `.output/`.
- `nuxt generate` → fully prerendered static site (every route must be prerenderable).
- The **Nitro preset** picks the deploy target. Auto-detected on most platforms; set explicitly via
  `nitro.preset` or the `NITRO_PRESET` env: `node-server`, `vercel`, `netlify`,
  `cloudflare-pages`/`cloudflare-module`, `bun`, `static`, and more.

```ts
export default defineNuxtConfig({ nitro: { preset: 'node-server' } })
```

Choose the preset here, then defer platform specifics (env, edge config, adapters, domains) to
`../deployment/SKILL.md`, `../vercel/SKILL.md`, `../netlify/SKILL.md`, `../cloudflare/SKILL.md`.
