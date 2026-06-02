# Functions & Edge Functions — deeper dimensions

Covers what the SKILL body offloads: scheduled, background, streaming functions, and the
Node-vs-Deno runtime split. Base directory is `netlify/functions/` (Node) and
`netlify/edge-functions/` (Deno edge).

## The context object

```typescript
import type { Config, Context } from "@netlify/functions";

export default async (req: Request, context: Context) => {
  context.geo;        // { city, country: { code, name }, subdivision, ... }
  context.cookies;    // get / set / delete cookies
  context.params;     // matched path params from config.path patterns
  context.ip;         // client IP
  return Response.json({ city: context.geo?.city });
};
```

## Scheduled functions (cron)

Add `schedule` to the config — no separate cron service needed.

```typescript
// netlify/functions/cleanup.mts
import type { Config } from "@netlify/functions";

export default async () => {
  // runs on the schedule; no request to respond to
  return new Response("done");
};

export const config: Config = { schedule: "@hourly" }; // or "0 5 * * *"
```

Scheduled functions get no live HTTP route; they fire on the cron expression.

## Background functions

Suffix the filename with `-background` (e.g. `process-background.mts`). The HTTP call returns
**202 immediately** and the function keeps running asynchronously (longer execution budget).
Use for work the caller shouldn't wait on — webhooks fan-out, image processing, emails.

```typescript
// netlify/functions/notify-background.mts
export default async (req: Request) => {
  // long async work; the response is already 202 to the caller
  await doSlowWork(await req.json());
};
```

## Streaming / SSE responses

Return a `ReadableStream` body to stream incrementally (LLM tokens, SSE, large payloads).

```typescript
export default async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode("data: hello\n\n"));
      controller.close();
    },
  });
  return new Response(stream, {
    headers: { "content-type": "text/event-stream" },
  });
};
```

## Node (Functions) vs Deno (Edge Functions)

| Dimension | Functions (Node) | Edge Functions (Deno) |
| --- | --- | --- |
| Runtime | Node, AWS-Lambda-backed | Deno at the CDN edge |
| Directory | `netlify/functions/` | `netlify/edge-functions/` |
| Files | `.mts` / `.mjs` | `.ts` / `.js` |
| Env access | `process.env` and `Netlify.env.get` | `Netlify.env.get` (no `process`) |
| npm deps | full npm + native modules | limited; prefer URL/std imports, no native modules |
| Best for | DB calls, heavy logic, scheduled/background work | rewrites, geolocation, auth gating, A/B at low latency |
| Routing | `export const config = { path }` | `[[edge_functions]]` in netlify.toml (deterministic order) |

Rule of thumb: reach for an Edge Function only when latency or per-request rewriting matters
and the dependency footprint is light. Anything that wants the Node ecosystem or runs on a
schedule belongs in a regular Function.

## Reading env safely

```typescript
// Node function
const key = process.env.STRIPE_SECRET ?? Netlify.env.get("STRIPE_SECRET");
// Edge function
const key = Netlify.env.get("STRIPE_SECRET");
```

Set values with `netlify env:set NAME value --context production`. Never hardcode — the
build's secrets scanner fails on leaked secret values in the bundle.
