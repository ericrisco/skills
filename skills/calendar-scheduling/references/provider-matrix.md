# Provider matrix — which scheduling stack wins when

Facts dated 2026-06-02. Pick by what you must *own*, not by brand familiarity.

## Cal.com

- **Hosting:** open-source, cloud or **self-hostable**. Self-host = full
  white-label (point the embed script at your own domain, zero Cal.com brand)
  and **unlimited API access** — no cloud rate limit to design around.
- **REST API:** base `https://api.cal.com/v2`. `POST /v2/bookings` creates
  regular, recurring, and instant bookings with attendee info, metadata, and
  booking-field responses.
- **Booking surfaces:** (a) **embed** — inline / button / modal triggers,
  identical on cloud and self-hosted; (b) **Booker atom** — an open-source
  modular component for a fully custom booking UI inside your app; (c) the v2
  API for headless booking.
- **Webhooks:** `BOOKING_CREATED` / `BOOKING_CANCELLED` / `BOOKING_RESCHEDULED`
  (plus more). Verify the signature; dedupe on the booking id.
- **Wins when:** you want OSS / self-host / white-label, or you need a custom UI
  (atom) without owning calendar sync, or you want no rate-limit anxiety.

## Calendly

- **Auth:** OAuth 2.1 or personal access token. **v1 API and v1 webhooks were
  discontinued in May 2025** — v2 only for new work (REST, JSON).
- **Scheduling API:** the Create Event Invitee endpoint books meetings via API
  with **no redirect / iframe / hosted UI** — headless booking.
- **Single-use scheduling links expire after 90 days** if unused.
- **Webhooks:** `invitee.created`, `invitee.canceled`, and routing-form
  submissions. Scoped `user` or `organization`. **Require a paid plan**
  (Standard / Teams / Enterprise).
- **Wins when:** the org already runs Calendly and you want API booking + events
  without standing up your own scheduler.

## Google Calendar (direct, single provider)

- **Availability:** `freebusy.query` (POST) returns busy blocks per calendar.
- **Write:** `events.insert` (add `conferenceData` to attach a Meet link).
- **Scopes:** `calendar` / `calendar.events` are **restricted** (require a
  third-party security assessment for production). Prefer granular:
  `calendar.app.created`, `calendar.freebusy`, `calendar.events.freebusy`,
  `calendar.events.owned`, `calendar.readonly`.
- **What you own:** OAuth, token refresh, `watch` push channels, incremental
  sync via sync tokens, recurring-event edge cases.
- **Wins when:** one provider, you need direct read/write, and you accept owning
  the integration. Pure CRUD with no booking surface → use `google-workspace`.

## Nylas v3 (unified)

- **Coverage:** Google + Outlook/Exchange + Apple/iCloud behind one API, with
  availability and free/busy endpoints.
- **Caveat:** **domain-scoped** — availability queries are restricted within an
  organization, so **cross-company scheduling needs multiple external calls**.
- **Wins when:** multi-provider but single-org scheduling is fine and you don't
  want to maintain three integrations.

## Cronofy (unified)

- **Coverage:** Google + Outlook/Exchange + Apple/iCloud behind one API.
- **No domain restriction:** a single call can span domains; caches free/busy in
  a Sync Engine.
- **Wins when:** multi-provider AND **cross-domain** scheduling matters (booking
  across companies in one availability call).

## Quick chooser

- Fastest page, no UI work → Cal.com / Calendly **embed**.
- Own UI + own data model → Cal.com **Booker atom** or **Scheduling API**.
- One provider, direct control → **Google direct** (`freebusy.query` + `events.insert`).
- Many providers, single org → **Nylas v3**.
- Many providers, cross-domain → **Cronofy**.
