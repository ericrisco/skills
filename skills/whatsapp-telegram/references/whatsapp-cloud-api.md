# WhatsApp Cloud API reference

Endpoint base: `https://graph.facebook.com/v25.0/{WA_PHONE_NUMBER_ID}/messages` (POST, `Authorization: Bearer ${WA_TOKEN}`). v25.0 current (2026-02-18); v24.0 is the floor. Facts accessed 2026-06-02.

## Message payload shapes

Every body starts with `messaging_product: "whatsapp"`, `to`, `type`.

### text
```json
{ "messaging_product": "whatsapp", "to": "34699999999", "type": "text",
  "text": { "preview_url": false, "body": "Your order shipped." } }
```

### template
```json
{ "messaging_product": "whatsapp", "to": "34699999999", "type": "template",
  "template": {
    "name": "order_update",
    "language": { "code": "es" },
    "components": [
      { "type": "header", "parameters": [ { "type": "text", "text": "1234" } ] },
      { "type": "body",   "parameters": [ { "type": "text", "text": "Maria" }, { "type": "currency", "currency": { "fallback_value": "€19.90", "code": "EUR", "amount_1000": 19900 } } ] },
      { "type": "button", "sub_type": "url", "index": 0, "parameters": [ { "type": "text", "text": "track/1234" } ] }
    ]
  } }
```
Parameter order MUST match the `{{1}} {{2}}` placeholders in the approved template.

### image / document (media)
```json
{ "messaging_product": "whatsapp", "to": "34699999999", "type": "image",
  "image": { "link": "https://example.com/receipt.png", "caption": "Receipt" } }
```
Use `link` (public URL) or a pre-uploaded `id` from the media endpoint.

### interactive (buttons / list)
```json
{ "messaging_product": "whatsapp", "to": "34699999999", "type": "interactive",
  "interactive": {
    "type": "button",
    "body": { "text": "Confirm your slot?" },
    "action": { "buttons": [
      { "type": "reply", "reply": { "id": "yes", "title": "Yes" } },
      { "type": "reply", "reply": { "id": "no",  "title": "No" } }
    ] } } }
```
Interactive messages are free-form → only deliver inside the open 24h window.

## Common error codes

| Code | Meaning | Fix |
| --- | --- | --- |
| 131047 | Re-engagement required (24h window closed) | Send an approved template, not free-form. |
| 131026 | Message undeliverable | Recipient not on WhatsApp / number invalid / not opted in. |
| 131051 | Unsupported message type | Check `type` + matching object key. |
| 100 | Invalid parameter | Bad `to` format, missing `messaging_product`, malformed component. |
| 132000–132xxx | Template errors | Param count mismatch, template paused/disabled, language mismatch. |
| 80007 / 130429 | Rate limit hit | Back off; throttle send rate. |

## Inbound webhook

### GET verification (one-time, on subscribe)
Meta calls `GET /your-callback?hub.mode=subscribe&hub.verify_token=...&hub.challenge=...`. If `hub.verify_token` equals your configured value, respond `200` with the raw `hub.challenge` as the body.

### POST event signature verify
```ts
import { createHmac, timingSafeEqual } from "node:crypto";

export function verifyMeta(rawBody: Buffer, header = ""): boolean {
  const expected = "sha256=" + createHmac("sha256", process.env.WA_APP_SECRET!).update(rawBody).digest("hex");
  const a = Buffer.from(expected, "utf8");
  const b = Buffer.from(header, "utf8");
  return a.length === b.length && timingSafeEqual(a, b);
}
```
Verify against the **raw** request body (not re-serialized JSON) or the HMAC will not match.

### Event payload (inbound message)
```json
{ "object": "whatsapp_business_account",
  "entry": [ { "id": "WABA_ID", "changes": [ { "field": "messages", "value": {
    "messaging_product": "whatsapp",
    "metadata": { "phone_number_id": "PHONE_NUMBER_ID" },
    "contacts": [ { "wa_id": "34699999999" } ],
    "messages": [ { "from": "34699999999", "id": "wamid.XXX", "timestamp": "1733400000", "type": "text", "text": { "body": "hi" } } ]
  } } ] } ] }
```
An inbound `messages[]` entry opens (or refreshes) the 24h window for that `from`.

## Pricing categories (per-message since 2025-07-01)

| Category | When | Cost |
| --- | --- | --- |
| marketing | promos, offers, re-engagement | Paid per message, country rate. |
| utility | order/account updates tied to a transaction | Free inside open window; paid out-of-window. |
| authentication | OTP / login codes | Paid per message, country rate. |
| service | free-form replies inside the window | Free. |

Free-entry-point conversations (user taps an ad/CTA) are free for 72h. Rates vary by recipient country code; check the current Meta rate card.

## Policy (2026)
Since 2026-01-15, Meta prohibits general-purpose AI assistants (open ChatGPT-wrapper bots with no clear business purpose) on WhatsApp. Scoped business automation is allowed.
