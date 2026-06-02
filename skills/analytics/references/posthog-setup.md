# PostHog setup reference

Depth offloaded from `../SKILL.md` Step 2. Use current `posthog-js` and `@posthog/next` APIs.

## `posthog.init` options that matter

```ts
import posthog from 'posthog-js';

posthog.init('phc_xxx', {
  api_host: '/ingest',                 // reverse proxy first-party path (recommended)
  ui_host: 'https://eu.posthog.com',   // EU cloud; use https://us.posthog.com for US
  person_profiles: 'identified_only',  // no profile per anonymous visitor — cost + privacy default
  defaults: '2025-05-24',              // pin behavior defaults to a known date
  autocapture: true,                   // clicks/inputs/forms on a, button, form, input, select, textarea, label
  capture_pageview: true,
});
```

- `person_profiles: 'identified_only'` — the recommended default. Without it you create a person profile for
  every anonymous visitor (more cost, more data).
- **EU vs US host:** pick the region your account is in; EU keeps data in the EU for residency.
- `autocapture: false` — set this if you want a deliberate, named-only taxonomy with no DOM noise.

## Core API

```ts
posthog.capture('signup_completed', { method: 'google' }); // never put email/token in props
posthog.identify(user.id, { plan: user.plan });            // stable id, NOT the email
posthog.group('company', org.id, { name: org.name });      // B2B account-level analytics
posthog.register({ app_version: '2.1.0' });                // super-properties on every event
posthog.unregister('app_version');
posthog.reset();                                           // on logout — critical on shared machines
```

## Consent

```ts
// EEA visitor: start opted-out; opt in only on banner accept.
posthog.opt_out_capturing();
function onConsentAccepted() { posthog.opt_in_capturing(); }
```

The legal banner text is `gdpr-privacy`'s job; this only wires the opt-in/opt-out signal.

## Reverse proxy (Next.js rewrite)

Serving the SDK + ingestion under a first-party path beats ad-blockers and tracking-prevention, which
otherwise eat a meaningful share of events.

```ts
// next.config.js
async rewrites() {
  return [
    { source: '/ingest/static/:path*', destination: 'https://eu-assets.i.posthog.com/static/:path*' },
    { source: '/ingest/:path*',        destination: 'https://eu.i.posthog.com/:path*' },
  ];
}
```

## Server-side capture with `@posthog/next`

Use for trusted server-side captures (payment confirmation, webhook, server action). `getPostHog()` reads
identity from the PostHog cookie and opts the route into dynamic rendering (it calls `cookies()`).

```ts
// app/api/checkout/route.ts
import { getPostHog } from '@posthog/next';

export async function POST(req: Request) {
  const posthog = await getPostHog();
  posthog.capture({ event: 'invoice_paid', properties: { value: 49, currency: 'EUR' } });
  return Response.json({ ok: true });
}
```

## Feature flags

```ts
if (posthog.isFeatureEnabled('new-checkout')) { /* ... */ }
const variant = posthog.getFeatureFlag('pricing-test');
```

Reading a flag emits a `$feature_flag_called` event — expected, not a bug; budget for it in event volume.
Experiment *design and stats* belong to `ab-testing`, not here.

## Validate

Watch the **Activity / live events** feed in PostHog after a test action. Confirm each named event arrives
**once** and that `distinct_id` stays stable across the session and survives login (via `identify`).

## Sources

- JS SDK: https://posthog.com/docs/references/posthog-js — repo: https://github.com/posthog/posthog-js
- Config: https://posthog.com/docs/libraries/js/config
- Feature flags: https://posthog.com/docs/feature-flags
- `@posthog/next`: https://github.com/posthog/posthog-js/tree/main/packages/next
- Reverse proxy: https://posthog.com/docs/advanced/proxy

Accessed 2026-06-02.
