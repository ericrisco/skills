# Provider matrix — Resend / SendGrid / Postmark

Side-by-side reference for the three HTTP email providers `email-connector`
supports. Versions current as of June 2026. The SKILL.md body is the
instructional path; this file is the branch-specific lookup.

## At a glance

| Dimension | Resend | SendGrid (Twilio) | Postmark |
|-----------|--------|-------------------|----------|
| Node SDK | `resend` 6.12.4 | `@sendgrid/mail` 8.1.6 | none official — raw HTTP |
| Auth | `new Resend(process.env.RESEND_API_KEY)` (Bearer) | `sgMail.setApiKey(process.env.SENDGRID_API_KEY)` | `X-Postmark-Server-Token` header |
| Single send | `resend.emails.send({from,to,subject,html|text|react})` | `sgMail.send(msg)` | `POST /email` |
| Batch | `resend.batch.send([...])`, ≤100, no attachments/scheduling | `personalizations[]` in one Mail Send call | per-stream send / `POST /email/batch` |
| Native idempotency | Yes — 2nd arg `{ idempotencyKey }`, 24h, ≤256 chars | No → self-dedupe | No → self-dedupe |
| Batch idempotency | key represents whole batch (`team-quota/123456789`) | n/a | n/a |
| Template model | React Email JSX via `react:` (lazy `@react-email/render`) | `templateId: 'd-…'` + `dynamicTemplateData` | server-side Postmark templates |
| Stream model | sending domains / separate API keys | suppression groups + IP pools | Message Streams: `outbound` (txn) + `broadcast` |
| Rate limit | per-plan | up to 10,000 req/s on Mail Send; 429 over | per-plan; broadcast throttled separately |

## Resend

```ts
import { Resend } from 'resend';
const resend = new Resend(process.env.RESEND_API_KEY);

// single
await resend.emails.send(
  { from: 'App <noreply@notify.yourdomain.com>', to, subject, react: <Welcome /> },
  { idempotencyKey: `welcome:${userId}:v3` }, // ≤256 chars, retained 24h
);

// batch — ≤100 per call, no attachments/scheduling
await resend.batch.send(rows.map((r) => ({ from, to: r.email, subject, react: <Digest /> })),
  { idempotencyKey: `digest-2026-06/${chunkIndex}`, batchValidation: 'permissive' });
```

Webhook events: `email.sent`, `email.delivered`, `email.bounced`,
`email.complained`, `email.opened`, `email.clicked`. Signature is verified via
the Svix headers on the raw payload.

## SendGrid (Twilio) v3 Mail Send

```ts
import sgMail from '@sendgrid/mail';
sgMail.setApiKey(process.env.SENDGRID_API_KEY!);

await sgMail.send({
  to, from: 'noreply@notify.yourdomain.com',
  templateId: 'd-abc123…',                 // dynamic template, id starts with d-
  dynamicTemplateData: { name, confirm_url },
});
// bulk: one call, multiple personalizations[] entries
```

No idempotency key: dedupe against your own `sent_emails` table before sending.
Mail Send allows up to 10,000 requests/second and returns 429 over the limit —
back off and retry with the same dedupe key. Event webhook posts
`delivered`, `bounce`, `dropped`, `spamreport`, `unsubscribe`; verify the
signed event-webhook signature on the raw body.

## Postmark

```ts
await fetch('https://api.postmarkapp.com/email', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json', Accept: 'application/json',
    'X-Postmark-Server-Token': process.env.POSTMARK_SERVER_TOKEN!,
  },
  body: JSON.stringify({
    From: 'noreply@notify.yourdomain.com', To: to, Subject: subject,
    HtmlBody: html, TextBody: text,
    MessageStream: 'outbound', // 'broadcast' for marketing — never mix
  }),
});
```

No idempotency key — self-dedupe on your own id and reconcile with the message
and bounce webhooks. Message Streams hard-separate transactional (`outbound`)
from `broadcast` so a marketing reputation hit cannot reach receipts/resets.
Webhook event types include `Delivery`, `Bounce`, `SpamComplaint`,
`SubscriptionChange`; verify the configured webhook auth before parsing.

## Suppression-webhook handler skeleton

Same shape for all three: read raw body → verify signature → parse → on a
bounce/complaint event upsert the address into the suppression table.

```ts
export async function POST(req: Request) {
  const raw = await req.text();
  if (!verifyProviderSignature(raw, req.headers)) return new Response('bad sig', { status: 401 });
  const e = JSON.parse(raw);
  const bounced =
    e.type === 'email.bounced' || e.type === 'email.complained' || // Resend
    e.event === 'bounce' || e.event === 'spamreport' ||            // SendGrid
    e.RecordType === 'Bounce' || e.RecordType === 'SpamComplaint'; // Postmark
  if (bounced) await db.suppressions.upsert({ email: addressFrom(e), reason: kindOf(e) });
  return new Response('ok');
}
```

Then filter every outbound recipient list against `db.suppressions` before
sending (single or batch). Generic webhook hardening lives in
`../../webhooks/SKILL.md`; inbox auth/reputation in
`../../email-deliverability/SKILL.md`.
