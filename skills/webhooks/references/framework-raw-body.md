# Getting the raw body, per framework

If your signature check fails but the secret is correct, you are almost always
verifying over a **re-serialized** body instead of the raw bytes the sender
signed. Each framework hides the raw body somewhere different. The rule is the
same everywhere: **capture the raw bytes, verify, and only then parse.**

## Express

A global `express.json()` consumes the stream, so by the time your handler runs
the original bytes are gone. Mount `express.raw()` on the webhook route only.

```js
import express from "express";
const app = express();
app.use(express.json()); // fine for the rest of the app

// Webhook route gets RAW, mounted before/instead of the global parser for this path.
app.post("/webhooks", express.raw({ type: "*/*" }), (req, res) => {
  const raw = req.body; // Buffer — exact bytes
  if (!verify(raw, req.headers)) return res.sendStatus(400);
  const event = JSON.parse(raw.toString("utf8"));
  // dedupe + enqueue + res.sendStatus(200)
});
```

If a global parser already ran, recover the bytes with a `verify` callback:
`express.json({ verify: (req, _res, buf) => { req.rawBody = buf; } })`.

## Next.js (App Router)

Route handlers do **not** auto-parse, but `await req.json()` reads the stream and
discards the raw bytes. Read the text instead and parse it yourself after
verifying.

```ts
// app/api/webhooks/route.ts
export async function POST(req: Request) {
  const raw = await req.text(); // raw string; do NOT call req.json() first
  const headers = Object.fromEntries(req.headers);
  if (!verify(raw, headers)) return new Response("bad sig", { status: 400 });
  const event = JSON.parse(raw);
  // dedupe + enqueue
  return new Response("ok", { status: 200 });
}
```

(Pages Router differs: set `export const config = { api: { bodyParser: false } }`
and read the stream — prefer the App Router handler above.)

## FastAPI / Starlette

Typing the parameter as a Pydantic model parses the body for you and throws away
the bytes. Take the raw `bytes` from the `Request`.

```python
from fastapi import FastAPI, Request, Response
app = FastAPI()

@app.post("/webhooks")
async def webhooks(request: Request):
    raw = await request.body()  # bytes — do not declare a model param
    if not verify(raw, request.headers):
        return Response(status_code=400)
    event = json.loads(raw)
    # dedupe + enqueue
    return Response(status_code=200)
```

## Hono

```ts
app.post("/webhooks", async (c) => {
  const raw = await c.req.text(); // before any c.req.json()
  if (!verify(raw, c.req.header())) return c.text("bad sig", 400);
  const event = JSON.parse(raw);
  return c.text("ok", 200);
});
```

## Serverless (Lambda / Vercel / Cloudflare Workers)

- **AWS Lambda (API Gateway / function URL):** the body arrives as a string in
  `event.body`; if `event.isBase64Encoded` is true, `Buffer.from(event.body,
  "base64")` first. Verify over that, never over a parsed object.
- **Vercel Functions:** disable the body parser for the route and read the raw
  stream (Edge runtime: `await req.text()`).
- **Cloudflare Workers:** `await request.text()` / `await request.arrayBuffer()`
  in the `fetch` handler; the body is unbuffered, so read it once.

## Common traps

- A reverse proxy or middleware that re-encodes the body (gzip, charset
  normalization) changes the bytes after the sender signed them — verify before
  any transform, and disable response/transit re-encoding on the webhook path.
- Reading the body stream twice: many runtimes let you read it once. Capture the
  raw bytes into a variable and reuse that variable for both verify and parse.
