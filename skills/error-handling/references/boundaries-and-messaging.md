# Boundaries & messaging

Companion to Steps 4–5 of `../SKILL.md`. The Next.js segment-tree placement map,
the `global-error.tsx` skeleton, the user-message copy contract, before/after
rewrites, and the taxonomy→status map. Next.js facts verified 2026-06-02 against
the App Router error-handling docs.

## Next.js segment tree — what bubbles where

```text
app/
  layout.tsx            ← root layout; if THIS throws, only global-error.tsx catches it
  global-error.tsx      ← whole-app boundary; must render its own <html>/<body>
  error.tsx             ← catches errors in app/page.tsx and below (but NOT app/layout.tsx)
  page.tsx
  dashboard/
    layout.tsx          ← NOT caught by dashboard/error.tsx (runs outside it);
                          a throw here bubbles to app/error.tsx
    error.tsx           ← catches dashboard/page.tsx and dashboard/*/page.tsx render errors
    page.tsx
    settings/
      page.tsx          ← its render error bubbles UP to dashboard/error.tsx
                          (add settings/error.tsx to contain it locally)
```

Rules that decide placement:

1. `error.tsx` catches the **children** of its segment, not the segment's own
   `layout.tsx` / `template.tsx`. To cover a layout's error, put the boundary one
   segment **up**.
2. An uncaught render error bubbles to the **nearest ancestor** `error.tsx`. Add a
   local `error.tsx` wherever you want the failure contained instead of taking out
   a larger subtree.
3. `error.tsx` MUST be a Client Component and gets `{ error, reset }`. `error.digest`
   is the server-generated id to show the user and correlate in logs.
4. Only **render** errors are caught. Event handlers, `async`/`setTimeout`
   callbacks, and Server-Component data-fetch errors need explicit `try/catch` +
   state.

## global-error.tsx skeleton

```tsx
"use client"; // app/global-error.tsx — replaces the root layout when it fails

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    // It replaces app/layout.tsx, so it MUST render <html> and <body> itself.
    <html lang="en">
      <body>
        <h1>Something went wrong</h1>
        <p>Reference id {error.digest}.</p>
        <button onClick={reset}>Reload</button>
      </body>
    </html>
  );
}
```

## Server request boundary

```ts
// One handler maps the taxonomy → status + correlation id + operator log.
function toResponse(e: unknown, correlationId: string) {
  if (e instanceof PaymentError && e.code === "declined") {
    return { status: 402, body: { code: e.code, correlationId } };
  }
  if (isTransient(e)) {
    return { status: 503, body: { code: "upstream_unavailable", correlationId } };
  }
  // unknown/programmer error: generic to the client, full chain to the log.
  log.error({ correlationId, err: e }); // see ../../observability/SKILL.md for the sink
  return { status: 500, body: { code: "internal_error", correlationId } };
}
```

## User-message copy contract

A user message is good when it is:

1. **Actionable** — names one next step ("try again", "check the amount").
2. **Plain** — no error codes, stack frames, table names, or hostnames.
3. **Honest about scope** — "your orders didn't load", not "an error occurred".
4. **Traceable** — carries a short correlation id the user can quote to support.
5. **Calm** — no blame, no exclamation marks, no "fatal".

## Before / after rewrites

| Bad (leaks / useless) | Good (actionable + safe) |
|---|---|
| `alert("TypeError: cannot read 'id' of undefined")` | "We couldn't load your orders. Try again in a moment — id a1b2c3." |
| `500 { "error": "ECONNREFUSED 10.0.3.12:5432" }` | `503 { "code": "upstream_unavailable", "correlationId": "a1b2c3" }` |
| "Error 0x80004005" | "Payment didn't go through. Your card wasn't charged. Try again or use another card." |
| "Invalid input" (which field?) | "Email looks incomplete — it needs an @ and a domain." |
| "Server error, contact admin" | "Something broke on our side. We've logged it (id a1b2c3); please try again shortly." |
| Silent failure, empty screen | "We couldn't reach the schedule service. Showing your last saved view." (degraded, not blank) |

## Taxonomy → HTTP status

| Bucket / code | Status |
|---|---|
| validation / bad input | 400 / 422 |
| unauthenticated | 401 |
| forbidden | 403 |
| not found | 404 |
| domain conflict (slot taken, duplicate) | 409 |
| payment declined | 402 |
| rate limited | 429 (+ `Retry-After`) |
| transient downstream / breaker open | 503 (+ `Retry-After`) |
| programmer error / unknown | 500 |

The **wire envelope** that carries these (RFC 9457 problem+json: `type`/`title`/
`status`/`detail`/`instance`, versioning, content negotiation) is owned by
`../../api-design/SKILL.md`. This skill produces the status and code; api-design
decides the bytes.
