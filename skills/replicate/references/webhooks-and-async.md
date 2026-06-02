# Webhooks & async — full reference

Source: https://replicate.com/docs/topics/webhooks/verify-webhook and the client READMEs
(accessed 2026-06-02).

## Event filters

`webhook_events_filter` controls which lifecycle events POST to your URL. Filter to what you need —
`["completed"]` for most apps, add `"start"`/`"output"`/`"logs"` only if you stream progress.

```python
client.predictions.create(
    model="owner/model",
    input={"prompt": "..."},
    webhook="https://your.app/hooks/replicate",
    webhook_events_filter=["completed"],
)
```

## Signature verification — Python

Replicate signs every delivery. The secret (fetch once from the API / dashboard) has a `whsec_`
prefix. Signed content is `{webhook-id}.{webhook-timestamp}.{raw-body}`. Verify before trusting:

```python
import base64, hashlib, hmac

def verify_replicate_webhook(headers: dict, raw_body: bytes, signing_secret: str) -> bool:
    webhook_id = headers["webhook-id"]
    timestamp  = headers["webhook-timestamp"]
    signature_header = headers["webhook-signature"]   # e.g. "v1,<b64sig> v1,<b64sig2>"

    secret_bytes = base64.b64decode(signing_secret.split("_", 1)[1])  # strip "whsec_"
    signed_content = f"{webhook_id}.{timestamp}.{raw_body.decode()}".encode()
    expected = base64.b64encode(
        hmac.new(secret_bytes, signed_content, hashlib.sha256).digest()
    ).decode()

    # header may carry multiple space-separated "v1,<sig>" tokens; match any
    for token in signature_header.split():
        _, _, sig = token.partition(",")
        if hmac.compare_digest(sig, expected):
            return True
    return False
```

- Use the **raw** request body bytes, not a re-serialized JSON dict — re-serialization changes bytes
  and breaks the HMAC.
- Always `hmac.compare_digest` (constant time), never `==` — `==` leaks timing.
- Optionally validate the `webhook-timestamp` is recent (reject if older than ~5 min) to blunt replay.

## Signature verification — Node

```javascript
import crypto from "node:crypto";

export function verifyReplicateWebhook(headers, rawBody, signingSecret) {
  const id = headers["webhook-id"];
  const timestamp = headers["webhook-timestamp"];
  const sigHeader = headers["webhook-signature"]; // "v1,<b64> v1,<b64>"

  const secretBytes = Buffer.from(signingSecret.split("_")[1], "base64"); // strip "whsec_"
  const signedContent = `${id}.${timestamp}.${rawBody}`;
  const expected = crypto.createHmac("sha256", secretBytes)
    .update(signedContent).digest("base64");

  return sigHeader.split(" ").some((tok) => {
    const sig = tok.split(",")[1];
    const a = Buffer.from(sig);
    const b = Buffer.from(expected);
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  });
}
```

The official clients also expose a built-in helper — prefer it when available; the manual recipe above
is for frameworks where you only have raw headers + body.

## Idempotency

Webhooks can be delivered more than once. Dedupe on the `webhook-id` header (store processed ids,
skip repeats) so a retry does not double-charge a user or re-run side effects.

## 5xx and retries

Return `2xx` fast once you have verified + enqueued the work. If your handler returns a `5xx`,
Replicate retries — so keep the handler thin (verify, persist, enqueue) and do heavy work
asynchronously. A handler that does slow work inline risks timing out and getting retried, compounding
load.

## Polling loop with backoff (when you don't use webhooks)

```python
import time

def wait_for(client, prediction, max_wait=600):
    deadline = time.monotonic() + max_wait
    delay = 1.0
    while prediction.status not in ("succeeded", "failed", "canceled"):
        if time.monotonic() > deadline:
            prediction.cancel()
            raise TimeoutError("prediction exceeded max_wait")
        time.sleep(delay)
        delay = min(delay * 1.5, 10.0)   # capped exponential backoff
        prediction.reload()
    return prediction
```

Prefer webhooks for long jobs — polling ties up a process. Set a server-side prediction **deadline**
too so a job auto-cancels even if your poller dies.
