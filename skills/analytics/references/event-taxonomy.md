# Event taxonomy reference

Depth offloaded from `../SKILL.md` Step 1. The taxonomy is the contract; design it before SDK code.

## Naming rules

- **`object_action`, `snake_case`, action in past tense.** `signup_completed`, `checkout_started`,
  `invoice_paid`. Object = noun, action = what happened.
- **Detail goes in properties, not the name.** One `cta_clicked` with `{ location }` beats four named
  variants you can never aggregate.
- **GA4 hard limits** (the SDK silently truncates/drops violators): name ≤ 40 chars, `[a-z0-9_]` only,
  **must start with a letter**; ≤ 25 params/event; ≤ 25 user properties.
- **Prefer GA4 recommended events** (`sign_up`, `login`, `purchase`, `add_to_cart`, `search`,
  `generate_lead`) — they unlock prebuilt reports/audiences a custom name cannot.
- **The anti-rename rule:** you may add events forever; never rename a live one. A rename forks the metric —
  the old funnel flatlines, the new one starts at zero. Deprecate in a doc instead.

## Property conventions

- Stable, lowercase, snake_case keys: `plan`, `source`, `value`, `currency`, `referrer`.
- Types stay consistent: `value` is always a number, `currency` always an ISO code. Mixed types break
  aggregation downstream.
- **No PII in props** — see the banlist below. Identity goes on the person profile via `identify`, set once,
  not stamped on every event.

## Identify vs anonymous vs group

| Concept | When | Call |
| --- | --- | --- |
| Anonymous | pre-login; identity is `client_id` / `distinct_id` | nothing — auto |
| Identify | on authentication; merge anonymous history into the user | `identify(stableId, { plan })` — `stableId` is a DB id / UUID, **never email** |
| Group | B2B account-level rollups (per company/workspace) | `group('company', orgId, { name })` |
| Reset | on logout, especially shared machines | `reset()` — prevents identity bleed |

## PII banlist (never in event props)

`email`, `phone`, full name, raw IP, geo coordinates, `password`, `token`, `secret`, API keys,
`session_id`, `credit_card`, `ssn`, IBAN. Scrub these at a single `capture()` wrapper rather than trusting
every call site.

## Starter SaaS catalog

| Event | Key properties | Funnel stage |
| --- | --- | --- |
| `signup_started` | `source` | acquisition |
| `signup_completed` | `method` (`google` / `email`) | acquisition |
| `onboarding_step_completed` | `step`, `step_number` | activation |
| `project_created` | `template` | activation |
| `invite_sent` | `count` | activation |
| `subscription_started` | `plan`, `value`, `currency` | revenue |
| `invoice_paid` | `value`, `currency`, `invoice_id` | revenue |
| `feature_used` | `feature` | retention |

Example funnel: `signup_started → signup_completed → project_created → invoice_paid`.

## Starter e-commerce catalog (GA4-aligned)

| Event | Key properties |
| --- | --- |
| `view_item` | `items`, `value`, `currency` |
| `add_to_cart` | `items`, `value`, `currency` |
| `begin_checkout` | `items`, `value`, `currency` |
| `add_payment_info` | `payment_type` |
| `purchase` | `transaction_id`, `value`, `currency`, `items` |
| `refund` | `transaction_id`, `value`, `currency` |

Example funnel: `view_item → add_to_cart → begin_checkout → purchase`.

## Sources

- GA4 event-name constraints / Measurement Protocol: https://developers.google.com/analytics/devguides/collection/protocol/ga4
- GA4 recommended events: https://support.google.com/analytics/answer/9267735
- PostHog identify/group: https://posthog.com/docs/references/posthog-js

Accessed 2026-06-02.
