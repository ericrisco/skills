# Platform APIs — review surfaces

Per-surface wiring: endpoints, auth, roles, limits, and the gotchas that bite. Facts
dated 2026-06-02. APIs here change faster than the playbook — confirm against the live
docs before you ship a quota-sensitive integration.

## Google Business Profile (GBP)

**Still on v4 for reviews.** Review management was *not* migrated to the v1 Business
Profile APIs and has no announced deprecation. List and reply both live under v4.

- **Reply (create or update):**
  ```text
  PUT https://mybusiness.googleapis.com/v4/{name=accounts/*/locations/*/reviews/*}/reply
  body: { "comment": "your reply text" }
  ```
  The same `PUT` creates a reply if none exists and overwrites it if one does. There is
  one reply per review.
- **Delete a reply:**
  ```text
  DELETE https://mybusiness.googleapis.com/v4/{name=...}/reply
  ```
- **Auth:** OAuth 2.0, scope `https://www.googleapis.com/auth/business.manage`.
- **Gate:** only **verified** locations can reply. Unverified → the call fails.
- **Dead — do not build:** the **Questions-and-Answers API was shut down in November
  2025.** Any `.../questions` endpoint is gone. Review listing + reply survive; Q&A does
  not. If old code references Q&A, rip it out.
- **Quota:** GBP APIs are quota-gated per project; request increases via the API console
  if you batch replies across many locations.

## Trustpilot

Two **separate** APIs — don't conflate them.

- **Invitation / Invitations API** (earn reviews): generates unique service- or
  product-review invitation links and emails.
  - Needs: **Business Unit ID**, customer email, customer name, locale, a `reference`
    (your order/txn id), and a **template ID**.
  - Templates exist in **16 languages** — pass the matching `locale`.
  - This is how you send the FTC-clean ask without gating: same invite to every
    customer, no sentiment screen.
- **Service Reviews API** (respond): post a public reply to a service review.
  - Auth: **Business user OAuth token** (not the public API key).
  - One reply per review, editable.

## Apple — App Store Connect

**Customer Review Responses** resource: get / create / update / delete.

- **Exactly one response per review**, and it is **editable** (re-`update` to revise).
- **Roles:** the API user must be **Account Holder, Admin, or Customer Support**. Other
  roles can read reviews but not respond.
- **AI review summaries (iOS 18.4+, 2025):** Apple auto-generates a summary of your
  reviews on the product page. Recurring complaint themes now feed that digest — fixing
  the underlying issue changes the summary, replying alone does not.
- Auth: App Store Connect API JWT (issuer + key id + private key), standard ASC scopes.

## Google Play

**Reply-to-Reviews API** via the Google Play Developer API (also available in Play
Console).

- A developer response is **public** and, per Google's own figure, raises that review's
  rating by **~0.7 stars on average** — the strongest single argument for ~100% response
  rate.
- **Reply window:** Play historically restricts programmatic replies to reviews within a
  rolling window (commonly cited as ~7 days for the reply API; **confirm against the
  current Developer API docs** before relying on it for old reviews — answer fresh ones
  fast).
- Auth: a Google Play service account with the Developer API enabled.

## Flag / dispute paths (removal, not reply)

Use these only for fake / off-topic / conflict-of-interest / policy-violation reviews —
never for legitimate negatives.

- **Google:** flag the review from the GBP reviews UI (the three-dot menu → "Report
  review") or the Business Profile "report a review" support flow. There is no public
  removal API — it's a human review against Google's content policy.
- **Trustpilot:** flag the review in the Business portal with a reported reason
  (defamatory, fake, not based on a genuine experience, etc.); Trustpilot adjudicates.
- **Apple / Google Play:** report policy-violating reviews through the respective
  console; removal is at the platform's discretion.

Expect days, not minutes — and expect most legitimate-but-harsh reviews to stay up.
Plan to reply, not to delete.
