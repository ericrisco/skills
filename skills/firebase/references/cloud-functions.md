# Cloud Functions — 2nd gen catalogue

2nd gen is the default and the only generation that runs Node.js 22. Use `firebase-functions` v7
(current major; the modular v2 trigger API is unchanged from v6) and `firebase-admin`. Functions require the Blaze (pay-as-you-go) plan, and any
outbound network call from a function also requires Blaze.

## Trigger catalogue

```ts
import { onDocumentWritten, onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { beforeUserCreated } from "firebase-functions/v2/identity"; // Auth blocking

export const onPostCreated = onDocumentCreated("posts/{postId}", async (event) => {
  const data = event.data?.data();
  // event.id is stable per delivery attempt — use it for idempotency
});

export const tidy = onSchedule("every 24 hours", async () => { /* cron */ });
```

## Callable vs HTTPS auth

- **`onCall`** — the SDK passes and verifies the caller's auth automatically. `request.auth` is the
  decoded, verified identity (or undefined). Custom claims are in `request.auth.token`.

  ```ts
  export const promote = onCall(async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "sign in");
    if (request.auth.token.admin !== true) throw new HttpsError("permission-denied", "admins only");
    // do privileged work
  });
  ```

- **`onRequest`** — raw HTTP. There is NO automatic auth. You must read the `Authorization: Bearer`
  header and call `getAuth().verifyIdToken(token)` yourself. Use this for webhooks and public
  endpoints, not for trusted-client RPC.

## Secrets

Never put secrets in code or in `functions.config()` literals. Define them and grant access:

```ts
import { defineSecret } from "firebase-functions/params";
const STRIPE_KEY = defineSecret("STRIPE_KEY");

export const charge = onCall({ secrets: [STRIPE_KEY] }, async (req) => {
  const key = STRIPE_KEY.value(); // resolved at runtime from Secret Manager
});
```

Set the value with `firebase functions:secrets:set STRIPE_KEY`.

## Idempotency

Background event triggers (`onDocumentWritten`, `onDocumentCreated`, etc.) deliver **at least once** —
the same event can fire more than once. Any side effect (charge, email, increment) must be guarded.

```ts
export const fulfil = onDocumentCreated("orders/{orderId}", async (event) => {
  const marker = db.doc(`processed/${event.id}`);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(marker)).exists) return; // already handled this delivery
    // ... do the side effect ...
    tx.set(marker, { at: FieldValue.serverTimestamp() });
  });
});
```

## Region, concurrency, cost

- Pin region near your users/data: `onCall({ region: "europe-west1" }, ...)`. Cross-region hops add
  latency and egress cost.
- 2nd gen runs multiple requests per instance (`concurrency`) — tune it to cut cold starts and cost,
  but only if your handler is concurrency-safe (no shared mutable global state per request).
- Cold starts: keep dependencies lean, do heavy init lazily, and set `minInstances` for latency-
  critical callables (it costs idle time — only where it matters).

## Auth blocking functions

`beforeUserCreated` / `beforeUserSignedIn` run inside the auth flow and can reject or mutate. Use them
to enforce email-domain allow-lists or to set initial custom claims at sign-up.

```ts
import { beforeUserCreated, HttpsError } from "firebase-functions/v2/identity";
export const gate = beforeUserCreated((event) => {
  if (!event.data?.email?.endsWith("@acme.com")) {
    throw new HttpsError("permission-denied", "company accounts only");
  }
});
```

## firebase.json wiring

```json
{
  "functions": { "source": "functions", "runtime": "nodejs22" },
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "emulators": { "functions": { "port": 5001 }, "firestore": { "port": 8080 } }
}
```
