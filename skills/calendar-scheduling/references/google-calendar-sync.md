# Google Calendar sync — payloads and edge cases

Facts dated 2026-06-02. Source: developers.google.com/workspace/calendar/api.
For non-booking calendar work (internal dashboards, raw event CRUD), use the
`google-workspace` sibling — this file is the booking-specific subset.

## 1. Availability — `freebusy.query`

POST `https://www.googleapis.com/calendar/v3/freeBusy`. Always query every
calendar that can block time (primary plus secondary calendars).

```json
{
  "timeMin": "2026-06-02T00:00:00Z",
  "timeMax": "2026-06-09T00:00:00Z",
  "timeZone": "Europe/Andorra",
  "items": [{ "id": "primary" }, { "id": "team-room@group.calendar.google.com" }]
}
```

Response returns `calendars.<id>.busy` as an array of `{start, end}` blocks.
Compute open slots = working hours − busy − buffers − minimum-notice window,
**server-side**. The browser renders the result; it never computes it.

## 2. Write — `events.insert` (with a Meet link)

POST `.../calendars/{calendarId}/events?conferenceDataVersion=1`. Set
`timeZone` on both `start` and `end`, or the time drifts to the calendar's
default zone.

```json
{
  "summary": "Intro call",
  "start": { "dateTime": "2026-10-25T10:00:00", "timeZone": "Europe/Andorra" },
  "end":   { "dateTime": "2026-10-25T10:30:00", "timeZone": "Europe/Andorra" },
  "attendees": [{ "email": "invitee@example.com" }],
  "conferenceData": {
    "createRequest": {
      "requestId": "uuid-per-booking",
      "conferenceSolutionKey": { "type": "hangoutsMeet" }
    }
  }
}
```

Persist the returned event `id` — you need it for reschedule and cancel.

## 3. Reschedule / cancel — no orphans

- Reschedule → `events.update` (or PATCH) the **stored event id** with new
  times. Never `events.insert` a second event.
- Cancel → `events.delete` the stored id (or PATCH `status: "cancelled"`), then
  release any slot lock so the old time is offerable again.

## 4. Stay in sync — `watch` + sync tokens, not polling

- **Push channels:** `events.watch` registers a channel that POSTs to your
  callback URL on changes. Channels expire — renew before expiry.
- **Incremental sync:** store the `nextSyncToken` from a list call; pass it as
  `syncToken` next time to fetch only deltas. A `410 Gone` means the token
  expired → do a full resync and capture a fresh token.
- Polling instead is slower, rate-limited, and misses edits between polls.

## 5. Recurring-event edge cases

- A recurring series has one master event; individual occurrences carry a
  `recurringEventId` pointing back to it.
- Editing a single occurrence creates an **exception instance** — update that
  instance's id, not the master, or you mutate the whole series.
- When reading availability, expand instances (`singleEvents=true`) so each
  occurrence's busy block is counted, not just the master.

## 6. Refresh tokens

- The refresh token arrives once (first consent with `access_type=offline`).
  Store it; access tokens are short-lived and you mint new ones from it.
- A `401` on an API call means refresh the access token and retry; a hard
  refresh failure means re-consent (token revoked or scope changed).
