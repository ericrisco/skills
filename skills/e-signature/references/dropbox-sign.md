# Dropbox Sign (ex-HelloSign) — API key, send, embedded, callbacks

Node SDK: `@dropbox/sign` 1.11.0. It replaces the deprecated `hellosign-sdk`. If you find `hellosign-sdk` in a codebase, migrate.

## API key setup

A single API key authenticates as the account. Pass it as the HTTP basic username (no password), which the SDK handles via `api.username = process.env.DROPBOX_SIGN_API_KEY`. Never commit it; read from env / secret store.

## Which call?

| Call | Use when |
|------|----------|
| `signature_request/send` | One-off send with raw files |
| `signature_request/send_with_template` | Reusable template + role mapping |
| `signature_request/create_embedded` | Signer signs inside your own UI |
| `signature_request/create_embedded_with_template` | Embedded + template |

**Only non-`test_mode` POSTs to these endpoints count against quota.** Keep `testMode: true` for all development; flip to `false` only on a deliberate live send.

```javascript
import * as DropboxSign from "@dropbox/sign";

const api = new DropboxSign.SignatureRequestApi();
api.username = process.env.DROPBOX_SIGN_API_KEY;

// Template send with role mapping
const res = await api.signatureRequestSendWithTemplate({
  templateIds: ["<TEMPLATE_ID>"],
  subject: "Please sign",
  signers: [{ role: "Client", emailAddress: signer.email, name: signer.name }],
  testMode: true,
});
const id = res.body.signatureRequest.signatureRequestId;
```

Signing order is the `order` field on each signer; fields are `customFields` / form fields keyed by API id.

## Embedded signing

`create_embedded` returns signature ids; call `embedded/sign_url` for each to get a short-lived URL, then mount it with the Dropbox Sign embedded JS client. Embedded signing is included from the Essentials API plan up (~$75/mo, 50+ requests) — it is not gated to Standard. What you cannot do is embed on `test_mode` alone with no paid API plan.

## Event callback verification

Dropbox Sign POSTs a JSON callback for events (`signature_request_signed`, `signature_request_all_signed`, etc.). Verify before trusting:

`event_hash` = `HMAC-SHA256( event_time + event_type )` keyed by your **API key**.

```javascript
import crypto from "node:crypto";

function verify(event, apiKey) {
  const expected = crypto
    .createHmac("sha256", apiKey)
    .update(event.event.event_time + event.event.event_type)
    .digest("hex");
  return crypto.timingSafeEqual(
    Buffer.from(expected), Buffer.from(event.event.event_hash));
}
```

Your endpoint must respond with the literal body `Hello API Event Received` (HTTP 200) or Dropbox Sign treats the callback as failed and retries.

## On completion: retrieve both artifacts

```javascript
const files = new DropboxSign.SignatureRequestApi();
files.username = process.env.DROPBOX_SIGN_API_KEY;

const signed = await files.signatureRequestFiles(requestId, "pdf");
const audit  = await files.signatureRequestFiles(requestId, "pdf", { fileType: "audit" });
```

Store the signed PDF AND the audit-trail PDF. Persist the `signatureRequestId`; never log document bytes or signer PII.
