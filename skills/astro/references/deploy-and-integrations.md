# Deploy adapters & integrations

Static output needs no adapter — Astro builds HTML you can host anywhere. The moment any route uses
`prerender = false` (on-demand rendering) or a server island, you need an **adapter** for the target
platform.

## Adapter table

| Platform        | Adapter                | Install                                   | Notes                                          |
| --------------- | ---------------------- | ----------------------------------------- | ---------------------------------------------- |
| Vercel          | `@astrojs/vercel`      | `npx astro add vercel`                     | Serverless/edge functions for on-demand routes |
| Netlify         | `@astrojs/netlify`     | `npx astro add netlify`                    | Netlify Functions for SSR                      |
| Cloudflare      | `@astrojs/cloudflare`  | `npx astro add cloudflare`                 | Workers runtime; v6 dev runs this in dev too   |
| Node (self-host)| `@astrojs/node`        | `npx astro add node`                       | `mode: "standalone"` for a standalone server   |

Platform mechanics (DNS, env vars in the dashboard, build settings) are out of scope here — those
belong to `../vercel/SKILL.md`, `../netlify/SKILL.md`, `../cloudflare/SKILL.md`. This file covers the
*code* side: which adapter, and how rendering modes interact with it.

## Rendering modes

Astro renders static by default; you opt routes into on-demand individually.

```javascript
// astro.config.mjs — add an adapter once; static routes still build to HTML.
import { defineConfig } from "astro/config";
import vercel from "@astrojs/vercel";

export default defineConfig({
  adapter: vercel(),
  // no top-level `output` needed in v6: per-route `prerender` decides static vs on-demand
});
```

```astro
---
// A route that needs request data on every load → on-demand.
export const prerender = false;
---
```

Astro 6's dev server runs the production runtime via Vite 7's Environment API, so adapter-specific
behavior (Cloudflare Workers APIs, Bun, Deno) shows up in dev — far fewer deploy-only surprises.

## SSR endpoints (API routes)

Server endpoints live in `src/pages/api/*.ts` and export HTTP-method functions. They need an adapter
(they are on-demand by definition).

```typescript
// src/pages/api/subscribe.ts
import type { APIRoute } from "astro";

export const prerender = false;

export const POST: APIRoute = async ({ request }) => {
  const data = await request.formData();
  const email = String(data.get("email") ?? "");
  if (!email.includes("@")) {
    return new Response(JSON.stringify({ error: "invalid" }), { status: 422 });
  }
  // ... persist / forward
  return new Response(JSON.stringify({ ok: true }), { status: 201 });
};
```

## Env handling

Use `astro:env` for typed, validated env with a clear client/server split — never leak a secret to
the client bundle.

```javascript
// astro.config.mjs
import { defineConfig, envField } from "astro/config";

export default defineConfig({
  env: {
    schema: {
      // server-only secret: never reaches the browser
      CMS_TOKEN: envField.string({ context: "server", access: "secret" }),
      // safe to expose to the client
      PUBLIC_SITE_NAME: envField.string({ context: "client", access: "public" }),
    },
  },
});
```

```astro
---
import { CMS_TOKEN } from "astro:env/server"; // server context only
---
```

## `astro add` recipes

`astro add` patches `astro.config.mjs` and installs peers in one step:

```bash
npx astro add react          # React islands
npx astro add mdx            # .mdx content
npx astro add sitemap        # sitemap.xml at build
npx astro add vercel         # (or netlify / cloudflare / node) adapter for on-demand
```

## Fonts API (stable in Astro 6)

Stable as of the [Astro 6.0 release, 2026-03-10](https://astro.build/blog/astro-6/). Self-host and
optimize fonts from config — no manual `@font-face`, no extra round-trip, zero CLS.

```javascript
// astro.config.mjs
import { defineConfig, fontProviders } from "astro/config";

export default defineConfig({
  experimental: {}, // Fonts API is stable in v6; configure under `fonts`
  fonts: [
    {
      provider: fontProviders.google(),
      name: "Inter",
      cssVariable: "--font-inter",
      weights: [400, 600, 700],
    },
  ],
});
```

Use the CSS variable in your styles. Reference:
[Fonts guide](https://docs.astro.build/en/guides/fonts/).

## CSP API (stable in Astro 6)

Stable as of the [Astro 6.0 release, 2026-03-10](https://astro.build/blog/astro-6/). Astro can emit a
Content-Security-Policy with hashes for your inline scripts/styles, tightening XSS defenses on static
and on-demand pages alike.

```javascript
// astro.config.mjs
export default defineConfig({
  csp: true, // or an object to extend directives (e.g. allowed connect-src for islands)
});
```

Reference: [Content Security Policy guide](https://docs.astro.build/en/reference/configuration-reference/#csp).

## Tailwind 4

Tailwind 4 wires through the official Vite plugin, **not** the legacy `@astrojs/tailwind`
integration (that was for Tailwind 3).

```javascript
// astro.config.mjs
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  vite: { plugins: [tailwindcss()] },
});
```

```css
/* src/styles/global.css */
@import "tailwindcss";
```
