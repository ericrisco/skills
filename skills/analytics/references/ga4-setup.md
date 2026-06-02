# GA4 setup reference

Depth offloaded from `../SKILL.md` Steps 2-3. Use current gtag.js APIs.

## Install — Next.js App Router

Load the tag once, globally. The consent default block (below) MUST execute before `gtag('config', ...)`.

```tsx
// app/layout.tsx
import Script from 'next/script';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        <Script id="ga-consent" strategy="beforeInteractive">{`
          window.dataLayer = window.dataLayer || [];
          function gtag(){ dataLayer.push(arguments); }
          gtag('consent', 'default', {
            ad_storage: 'denied',
            ad_user_data: 'denied',
            ad_personalization: 'denied',
            analytics_storage: 'denied',
            wait_for_update: 500,
          });
        `}</Script>
        <Script src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX" strategy="afterInteractive" />
        <Script id="ga-config" strategy="afterInteractive">{`
          gtag('js', new Date());
          gtag('config', 'G-XXXXXXXXXX');
        `}</Script>
      </body>
    </html>
  );
}
```

Custom event from the client:

```ts
gtag('event', 'purchase', { value: 49.0, currency: 'EUR', transaction_id: 'ord_123' });
```

## Consent Mode v2 — region-scoped defaults

Default to `denied` for EEA/UK/CH; you may default `granted` elsewhere. Enforced for EEA/UK traffic since
**21 July 2025** — tags without connected consent lose conversion tracking, remarketing, and demographics.

```html
<script>
  // EEA/UK/CH: deny by default
  gtag('consent', 'default', {
    ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied',
    analytics_storage: 'denied', wait_for_update: 500,
    region: ['ES','FR','DE','IT','PT','NL','BE','IE','PL','SE','DK','FI','AT','GR','CZ','RO','HU','GB','CH','NO','IS','LI'],
  });
  // rest of world: allow by default
  gtag('consent', 'default', {
    ad_storage: 'granted', ad_user_data: 'granted', ad_personalization: 'granted',
    analytics_storage: 'granted',
  });
  // on banner accept:
  function onConsentAccepted() {
    gtag('consent', 'update', {
      ad_storage: 'granted', ad_user_data: 'granted',
      ad_personalization: 'granted', analytics_storage: 'granted',
    });
  }
</script>
```

The four params are required: `ad_storage`, `ad_user_data`, `ad_personalization`, `analytics_storage`.
`wait_for_update` (ms) holds tags briefly so a fast banner choice is respected before the first hit.

## Measurement Protocol — server-side event

For actions off the browser (payment confirmation, webhook, cron). Send the **same `client_id`** the
browser used so the event stitches to the right user. Must arrive within **48h** of the client timestamp.

```bash
curl -X POST \
  "https://www.google-analytics.com/mp/collect?measurement_id=G-XXXXXXXXXX&api_secret=YOUR_SECRET" \
  -H 'Content-Type: application/json' \
  -d '{
    "client_id": "1234567.7654321",
    "user_id": "db_user_42",
    "events": [{ "name": "purchase",
      "params": { "value": 49.0, "currency": "EUR", "transaction_id": "ord_123" } }]
  }'
```

Limits: ≤ 25 events per request; event name ≤ 40 chars, alphanumeric + underscore, must start with a letter;
≤ 25 params/event; ≤ 25 user properties. If you set `user_id` server-side, set the **same** value
browser-side or you create duplicate users.

## Recommended events (prefer over custom names)

| Event | Key params | Unlocks |
| --- | --- | --- |
| `sign_up` | `method` | sign-up reports / audiences |
| `login` | `method` | engaged-user segments |
| `purchase` | `value`, `currency`, `transaction_id`, `items` | revenue reports, ecommerce |
| `add_to_cart` | `value`, `currency`, `items` | cart-abandon funnels |
| `search` | `search_term` | site-search reports |
| `generate_lead` | `value`, `currency` | lead audiences for Ads |

## Validate before shipping

Open **Admin → DebugView** (or filter the network tab for `/g/collect`). Confirm each event fires **once**
with the expected params and that the `client_id` is stable. A double `/g/collect` for one action means a
render-fired event — guard it.

## Sources

- Consent guide + July-2025 enforcement: https://developers.google.com/tag-platform/security/guides/consent
- Measurement Protocol: https://developers.google.com/analytics/devguides/collection/protocol/ga4
- Sending events: https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events
- Recommended events: https://support.google.com/analytics/answer/9267735

Accessed 2026-06-02.
