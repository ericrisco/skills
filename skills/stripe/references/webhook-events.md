# Stripe webhook events — catalog per flow

What to listen for and what each event should do to your DB. Subscribe to only
the events a flow needs; "send all events" is discouraged.

## Subscription paywall

| Event | What it means | DB action |
|---|---|---|
| `checkout.session.completed` | Customer finished Checkout (paid or trial started) | Link `client_reference_id` (your user) to `session.customer`; mark provisional access. |
| `customer.subscription.created` | Subscription now exists | Store `subscription.id`, `status`, `current_period_end`, price ID. |
| `customer.subscription.updated` | Plan changed, renewed, trial→active, past_due, canceled-at-period-end | Re-sync `status` and `current_period_end`. This is the workhorse; gate access on `status`. |
| `customer.subscription.deleted` | Subscription ended | Revoke access. |
| `invoice.paid` | A billing cycle was paid | Confirm/extend access; optionally store the invoice ref. |
| `invoice.payment_failed` | A charge failed | Enter dunning (below); do not revoke immediately. |

Gate access on `subscription.status` (`active` or `trialing` = entitled;
`past_due`/`unpaid`/`canceled` = not), not on a single "is_pro" boolean you
set once at checkout.

## One-time payment

| Event | DB action |
|---|---|
| `checkout.session.completed` (mode `payment`) | Fulfill the order / unlock the download. The primary signal. |
| `payment_intent.succeeded` | Optional confirmation if you also create PaymentIntents directly. |

## Dunning (failed payment)

`invoice.payment_failed` starts Stripe's automatic retry schedule (Smart
Retries / your dunning settings). Do not revoke on the first failure — Stripe
will retry. Mark the account `past_due` and surface a "update your card"
prompt (link to the billing portal). Revoke only when
`customer.subscription.deleted` fires.

## Thin events vs snapshot events

- **Snapshot events** (`event.data.object`) embed a full object snapshot at send
  time. Convenient, but the object may already be stale by the time you process
  it out of order.
- **Thin events** carry only IDs; you fetch the current object yourself. They
  are inherently fresher.

Whichever you receive, for state that matters (subscription status), re-fetch
or trust the latest `customer.subscription.updated` rather than reconstructing
state from an ordered sequence — events are not ordered.

## Raw-body recipes by framework

```ts
// Express — raw on this route only; keep express.json() for other routes.
app.post("/webhook", express.raw({ type: "application/json" }), handler);
```

```ts
// Next.js App Router — route segment runs on Node by default; read raw text.
export async function POST(req: Request) {
  const body = await req.text();
  const sig = req.headers.get("stripe-signature")!;
  const event = stripe.webhooks.constructEvent(body, sig, secret);
  // ...
  return new Response(null, { status: 200 });
}
```

```ts
// Next.js Pages Router — disable the body parser, read the raw stream.
export const config = { api: { bodyParser: false } };
```

```ts
// Edge / Workers — no Node crypto; use the async API + Web Crypto provider.
const event = await stripe.webhooks.constructEventAsync(
  body, sig, secret, undefined, Stripe.createSubtleCryptoProvider(),
);
```

The header name is lowercase `stripe-signature`. Default replay tolerance is
5 minutes; a clock skew larger than that rejects valid events.
