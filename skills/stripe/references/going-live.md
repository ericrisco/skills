# Going live — production hardening

The Checkout/webhook code is the easy part. These are the things that bite in
production.

## Test → live cutover

- Test and live mode have **separate keys, separate webhook endpoints, separate
  signing secrets, and separate data**. Nothing crosses over.
- Create the live webhook endpoint in the dashboard; copy its **own**
  `whsec_…`. The CLI secret from `stripe listen` is for local only.
- Swap keys via environment/secret manager, never by editing code. A `sk_live_`
  literal in source is a drainable credential.

## Restricted API keys

Do not run the server with the account's unrestricted secret key. Create a
**restricted key** granting only the resources you touch (e.g. write on
Checkout Sessions, Customers, Subscriptions; read on Prices). If it leaks, blast
radius is bounded. Rotate it on suspicion of exposure.

## Webhook secret rotation

When rotating a webhook signing secret, Stripe lets you keep the old secret
valid during a roll window. Verify against both during the overlap, then drop
the old one. Never log the secret or the raw signature header.

## Idempotency keys

Every create call that a retry could duplicate (`checkout.sessions.create`,
`subscriptions.create`, `customers.create`) takes an `idempotencyKey`. Derive it
from the operation (`checkout:${userId}:${planId}`), not `Math.random()`, so a
genuine retry collides and Stripe returns the original result instead of making
a second object.

## SCA / 3DS

Strong Customer Authentication and 3D Secure are handled for you by Checkout and
the Payment Element — that is a core reason to prefer them over hand-rolled
PaymentIntents + cards. Don't reimplement the authentication dance.

## Test clocks

To exercise renewals, trials ending, and dunning without waiting real days,
attach a Customer to a **test clock** and advance time. This is the only sane
way to test the multi-day subscription lifecycle.

## PCI scope

With Checkout (Stripe-hosted) or the Payment Element, card data never touches
your server, keeping you in the lightest PCI tier (SAQ A-class). Raw card
numbers hitting your backend escalate scope dramatically — don't.

## Pre-launch checklist

- [ ] `apiVersion` pinned in the client.
- [ ] Live keys/secret in env, not code; test literals gone.
- [ ] Live webhook endpoint created; its own signing secret wired.
- [ ] Event subscription restricted to the allowlist you actually handle.
- [ ] Restricted API key in use on the server.
- [ ] Idempotency keys on all create calls.
- [ ] Webhook handler verifies signature, returns 2xx fast, dedupes on `event.id`.
- [ ] Access gated on `subscription.status`, refreshed by webhooks.
- [ ] Tested the renewal/dunning path against a test clock.
