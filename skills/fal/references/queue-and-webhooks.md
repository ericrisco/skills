# Queue & webhooks — full async lifecycle

The complete async path for fal jobs you cannot block on: submit, deliver by webhook, verify, dedupe.

## Lifecycle

```text
submit(endpoint, { input, webhook_url })
        │  returns { request_id } instantly
        ▼
   fal queue:  IN_QUEUE ──▶ IN_PROGRESS ──▶ COMPLETED
        │                                      │
        │  (you poll)                          │  (fal pushes)
        ▼                                      ▼
 queue.status(endpoint, { requestId })   POST webhook_url  { request_id, status, payload }
 queue.result(endpoint, { requestId })   ── verify signature, dedupe, act ──
```

Pick **one** delivery mechanism per job: poll the queue *or* receive a webhook. Webhooks win for long jobs — no held connection, no polling cost.

## Webhook payload shapes

```jsonc
// Success — result is in payload
{ "request_id": "764cabcf-...", "gateway_request_id": "764cabcf-...", "status": "OK", "payload": { "images": [{ "url": "https://..." }] } }

// Job failed
{ "request_id": "764cabcf-...", "status": "ERROR", "error": "..." }

// Job succeeded but result couldn't be serialized into the webhook
{ "request_id": "764cabcf-...", "status": "OK", "payload": null, "payload_error": "..." }
```

`gateway_request_id` equals `request_id` in normal cases. Always branch on `status` first, then check `payload` vs `payload_error`.

## Delivery, retries, idempotency

- Initial POST has a **15-second timeout**. Respond fast — enqueue the work, return 200, process async.
- On timeout or any non-2xx, fal **retries up to 10 times over roughly 2 hours**.
- Your handler **must be idempotent**: the same `request_id` can arrive multiple times. Dedupe before side effects.

```ts
// Idempotent guard — record the request_id first; skip if already seen.
const seen = await db.webhookEvents.findUnique({ where: { requestId } });
if (seen) return res.status(200).end();      // already processed, ack the retry
await db.webhookEvents.create({ data: { requestId } });
// ...now do the side effect exactly once
```

## ED25519 signature verification

Four headers travel with every webhook:

| Header | Meaning |
| --- | --- |
| `X-Fal-Webhook-Request-Id` | the job's request id |
| `X-Fal-Webhook-User-Id` | your fal user id |
| `X-Fal-Webhook-Timestamp` | unix seconds when fal signed |
| `X-Fal-Webhook-Signature` | hex-encoded ED25519 signature |

Verification algorithm:

1. Reject if `|now - timestamp| > 300` seconds (±5 min) — blocks replay.
2. Fetch the JWKS from `https://rest.fal.ai/.well-known/jwks.json`; **cache it ≤ 24h**. Each key's `x` field is a base64url-encoded ED25519 public key.
3. Build the signed message as four newline-joined parts: `request_id`, `user_id`, `timestamp`, and the **hex SHA-256 of the raw request body**.
4. Hex-decode the signature.
5. ED25519-verify the message against each JWKS key until one passes. If none pass, reject.

Use the **raw** request body for the SHA-256 — re-serialized JSON will not match.

### Node

```ts
import { createHash, verify } from "node:crypto";

let jwksCache: { keys: any[]; at: number } | null = null;
async function getJwks() {
  if (jwksCache && Date.now() - jwksCache.at < 24 * 3600_000) return jwksCache.keys;
  const r = await fetch("https://rest.fal.ai/.well-known/jwks.json");
  const { keys } = await r.json();
  jwksCache = { keys, at: Date.now() };
  return keys;
}

export async function verifyFalWebhook(headers: Record<string, string>, rawBody: Buffer) {
  const reqId = headers["x-fal-webhook-request-id"];
  const userId = headers["x-fal-webhook-user-id"];
  const ts = headers["x-fal-webhook-timestamp"];
  const sigHex = headers["x-fal-webhook-signature"];
  if (!reqId || !userId || !ts || !sigHex) return false;
  if (Math.abs(Date.now() / 1000 - Number(ts)) > 300) return false;

  const bodyHash = createHash("sha256").update(rawBody).digest("hex");
  const message = Buffer.from([reqId, userId, ts, bodyHash].join("\n"), "utf-8");
  const sig = Buffer.from(sigHex, "hex");

  for (const jwk of await getJwks()) {
    const pub = Buffer.from(jwk.x, "base64url"); // 32-byte raw ed25519 key
    const der = Buffer.concat([
      Buffer.from("302a300506032b6570032100", "hex"), // SPKI prefix for ed25519
      pub,
    ]);
    const keyObj = { key: der, format: "der" as const, type: "spki" as const };
    if (verify(null, message, keyObj as any, sig)) return true;
  }
  return false;
}
```

### Python

```python
import time, hashlib, httpx
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from cryptography.exceptions import InvalidSignature

_jwks = {"keys": None, "at": 0.0}

def _get_jwks():
    if _jwks["keys"] and time.time() - _jwks["at"] < 24 * 3600:
        return _jwks["keys"]
    keys = httpx.get("https://rest.fal.ai/.well-known/jwks.json").json()["keys"]
    _jwks.update(keys=keys, at=time.time())
    return keys

def verify_fal_webhook(headers: dict, raw_body: bytes) -> bool:
    import base64
    req_id = headers.get("x-fal-webhook-request-id")
    user_id = headers.get("x-fal-webhook-user-id")
    ts = headers.get("x-fal-webhook-timestamp")
    sig_hex = headers.get("x-fal-webhook-signature")
    if not all([req_id, user_id, ts, sig_hex]):
        return False
    if abs(time.time() - int(ts)) > 300:
        return False

    body_hash = hashlib.sha256(raw_body).hexdigest()
    message = "\n".join([req_id, user_id, ts, body_hash]).encode()
    sig = bytes.fromhex(sig_hex)

    for jwk in _get_jwks():
        pub = base64.urlsafe_b64decode(jwk["x"] + "==")  # 32-byte raw key
        try:
            Ed25519PublicKey.from_public_bytes(pub).verify(sig, message)
            return True
        except InvalidSignature:
            continue
    return False
```

## Optional: IP allowlisting

For an extra layer, restrict your endpoint to fal's egress ranges. Fetch `webhook_ip_ranges` from `https://api.fal.ai/v1/meta`. Ranges rotate — refresh periodically; do not hardcode. Signature verification is the primary defense; IP allowlisting is belt-and-suspenders.
