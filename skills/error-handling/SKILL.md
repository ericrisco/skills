---
name: error-handling
description: "Use when designing how code recognizes, recovers from, and reports failure — typed error taxonomies, retry/backoff/timeout policy, circuit breakers, React/Next error boundaries, and the user message + operator log line. Triggers: 'add retries with backoff', 'set up an error boundary', 'standardize our error types', 'stop swallowing exceptions', 'this catch block hides the real error', 'degrade gracefully when the payment provider is down', 'why does our retry storm take the database down', 'maneja los errores sin tragarte la excepción', 'afegeix reintents amb backoff i tallacircuits'. NOT finding why one specific thing broke (that is debug), NOT wiring logs/metrics/traces (that is observability), NOT the on-the-wire error envelope contract (that is api-design)."
tags: [error-handling, resilience, retry, circuit-breaker, error-boundary, typed-errors, fault-tolerance]
recommends: [debug, observability, monitoring, api-design, secure-coding, testing-web, nextjs]
origin: risco
---

# Error handling — classify, contain, surface

You are designing what happens *whenever anything in a class breaks*, not chasing
one crash (that is [`debug`](../debug/SKILL.md)). The deliverable is a typed error
taxonomy, a retry policy with caps and jitter, boundary placement, and a
two-audience message contract — never a pile of `try { … } catch {}`.

## The one rule

**Every failure gets classified, contained, and surfaced — never swallowed.**

- **Classify** — give the failure a type so the right code can react to the right
  kind. An untyped `catch (e)` cannot decide anything.
- **Contain** — stop one failing dependency from taking the process (or the DB)
  with it. No timeout, no cap = unbounded blast radius.
- **Surface** — emit two things: a human message that never leaks internals, and
  an operator log with the full cause chain.

The five steps below are those three jobs in order. Do them in order.

## Step 1 — Model failure as a taxonomy

Bucket every failure into one of three kinds. The bucket dictates the reaction;
get the bucket wrong and every downstream decision is wrong too.

| Bucket | Examples | Retry? | Tell the user | Tell the operator |
|---|---|---|---|---|
| **Domain / expected** | insufficient funds, slot taken, validation failed | No | Yes, actionable | info — it is normal |
| **Infrastructure / transient** | timeout, 503, connection reset, 429 | Yes (capped) | "temporary, retrying" | warn — watch the rate |
| **Programmer error / bug** | null deref, bad assertion, type error | No | generic "something broke" + id | error — page if frequent |

### Result vs throw

Decide per call site, not per codebase:

- **`Result<T, E>`** for *expected domain* failures the caller must handle. The
  type checker forces a branch — the failure cannot be ignored by accident.
- **`throw`** for *exceptional / programmer* errors. These should crash up to the
  nearest boundary, not be threaded through every signature.

In TypeScript, `neverthrow` (current) is the instrument for the Result path:

```ts
import { ok, err, Result } from "neverthrow";

type ChargeError = "insufficient_funds" | "card_declined";

// Expected domain failure → Result. The caller MUST handle both arms.
function charge(cents: number, balance: number): Result<number, ChargeError> {
  if (cents > balance) return err("insufficient_funds");
  return ok(balance - cents);
}

const r = charge(500, 200);
if (r.isErr()) {
  // r.error is the typed union — exhaustive, no `any`.
}
```

### Stable codes and cause chaining

Every error carries a **stable `code`** (a string the UI and logs key off, never
the human message) and **never drops the original cause**.

```ts
// BAD — string error, loses the original, nothing to branch on.
throw new Error("payment failed");

// GOOD — typed class, stable code, cause preserved.
class PaymentError extends Error {
  constructor(public code: "provider_down" | "declined", cause?: unknown) {
    super(code);
    this.name = "PaymentError";
    this.cause = cause; // the original error/stack survives for the log
  }
}
try {
  await provider.charge();
} catch (e) {
  throw new PaymentError("provider_down", e); // wrap, do not erase
}
```

Cross-language error-class skeletons (Python, Java, Go, .NET) live in
[`references/retry-and-resilience.md`](references/retry-and-resilience.md).

## Step 2 — Decide retryability

Retry **only** transient failures, and **only** on idempotent operations. Retrying
the wrong thing turns one slow dependency into a self-inflicted outage.

| Retry these (transient) | Never retry these (permanent) |
|---|---|
| Network error, connection reset | 400 bad request, 422 unprocessable |
| Timeout | 401 / 403 (auth/permission) |
| 429 too many requests (honor `Retry-After`) | 404 not found |
| 503 / 502 / 504 | Any business-rule rejection (insufficient funds) |
| 500 **on a GET** (idempotent) | 500 on a non-idempotent POST without a key |

**Idempotency is a precondition, not a nicety.** A retried POST that creates a
charge can double-charge. Retry only operations that are idempotent by nature
(GET, PUT, DELETE) or that carry an **idempotency key** so the server dedupes.
Key design itself belongs to [`../api-design/SKILL.md`](../api-design/SKILL.md);
here you just require one before you retry a mutation.

**Caps (industry-converged — AWS Builders' Library, REL05-BP03):**

- Max **3–5** total attempts.
- Base delay **100–200ms**, doubling per attempt.
- Per-delay cap **10–30s**; total retry budget **10–60s** then give up.
- **Full jitter** to spread load — beats fixed and equal jitter:

```text
delay = random_between(0, min(cap, base * 2 ** attempt))
```

Set a **per-attempt timeout first**, then retry — a retry on a call that never
times out just stacks hung requests.

```ts
// GOOD — classify before retrying; cap; full jitter; per-attempt timeout.
async function withRetry<T>(fn: () => Promise<T>, max = 4): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await fn(); // fn must enforce its own per-attempt timeout
    } catch (e) {
      if (!isTransient(e) || attempt >= max - 1) throw e; // permanent or budget spent
      const cap = 10_000, base = 150;
      const delay = Math.random() * Math.min(cap, base * 2 ** attempt); // full jitter
      await new Promise((r) => setTimeout(r, delay));
    }
  }
}
```

Per-language `withRetry` (Python `tenacity`, Java Resilience4j, .NET Polly) is in
[`references/retry-and-resilience.md`](references/retry-and-resilience.md).

## Step 3 — Contain blast radius

Retries alone make a struggling dependency worse. Contain it.

- **Timeout every outbound call.** No timeout is a bug, not a default. An
  un-timed call holds a connection until the OS gives up — minutes you do not have.
- **Circuit breaker** — stop hammering a dead dependency. Three states:
  - **Closed**: requests flow; count failures.
  - **Open**: trip at ~**50% failure** over a ~**20-request** window; reject fast
    for **30–60s** without calling downstream.
  - **Half-Open**: after the cooldown, let a probe through; success → Closed,
    failure → Open again.
  - Critical services trip tighter (~30%); tolerant ones up to ~70%.
- **Instruments (current):** Opossum (Node — defaults timeout 3000ms /
  errorThresholdPercentage 50 / resetTimeout 30000ms), Polly 8.6.5 (.NET fluent
  pipelines), Resilience4j 2.2.0 (Java). The config matrix is in
  [`references/retry-and-resilience.md`](references/retry-and-resilience.md).
- **Fallback / graceful degradation** — when the breaker is Open, serve a stale
  cache, a safe default, or an honest "this feature is temporarily unavailable".
  Degrade; do not 500 the whole page.
- **Bulkhead** — isolate resource pools (separate connection pool / worker queue
  per dependency) so one saturated downstream cannot starve the rest. Sizing in
  the reference.

## Step 4 — Boundaries

A boundary is where an unhandled failure is *caught and converted* into a
contained reaction. Place one at each level that can fail independently.

### React / Next.js App Router

- **`error.tsx`** is a **route-segment** boundary. It MUST be a Client Component
  (`'use client'`) and receives `{ error, reset }`. An error in a segment bubbles
  to the nearest *parent* `error.tsx`.
- **`error.tsx` does NOT catch an error thrown in its own segment's `layout.tsx`
  or `template.tsx`.** Those run *outside* the boundary — move the boundary to the
  parent segment to cover them.
- **`global-error.tsx`** wraps the whole app and must render its own `<html>` and
  `<body>` (it replaces the root layout when the root itself fails).
- **Boundaries only catch errors during *render*.** Errors in event handlers,
  `async` callbacks, `setTimeout`, or server-side data fetching are invisible to
  them — handle those with explicit `try/catch` + state.

```tsx
"use client"; // app/dashboard/error.tsx — REQUIRED

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  // Log to your telemetry sink (see observability); show the user the digest id.
  return (
    <div role="alert">
      <p>Something went wrong. Quote id {error.digest} to support.</p>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```

The full segment-tree placement map and the `global-error.tsx` skeleton are in
[`references/boundaries-and-messaging.md`](references/boundaries-and-messaging.md).
Framework specifics: [`../nextjs/SKILL.md`](../nextjs/SKILL.md).

### Server and process

- **Request boundary** — one error handler / middleware that maps the taxonomy →
  HTTP status, attaches a correlation id, and emits the operator log. Every route
  funnels through it instead of formatting errors ad hoc.
- **Process boundary** — a top-level `unhandledRejection` / `uncaughtException`
  handler (Node) or equivalent. Log the cause chain, then **exit and let the
  supervisor restart**. A process that keeps running after an unhandled error is
  running corrupted.

## Step 5 — Surface it

Two audiences. Never conflate them — that is how stack traces reach end users and
how logs become useless.

| | User message | Operator log |
|---|---|---|
| **Goal** | tell them what to do next | let you reconstruct what happened |
| **Content** | plain language, one action, a correlation id | code, cause chain, request context, structured fields |
| **Never** | stack trace, SQL, internal hostnames, PII | a swallowed/lost cause |

**Taxonomy → HTTP status** (the in-process map; the *wire envelope* shape —
RFC 9457 problem+json — belongs to [`../api-design/SKILL.md`](../api-design/SKILL.md);
*shipping* the log to a sink belongs to [`../observability/SKILL.md`](../observability/SKILL.md)):

| Bucket / code | Status |
|---|---|
| validation / bad input | 400 / 422 |
| unauthenticated / forbidden | 401 / 403 |
| not found | 404 |
| domain conflict (slot taken) | 409 |
| transient downstream / breaker open | 503 (+ `Retry-After`) |
| programmer error / unknown | 500 |

```text
BAD  → alert("TypeError: cannot read 'id' of undefined")
GOOD → "We couldn't load your orders. Try again in a moment — id a1b2c3."

BAD  → 500 { "error": "ECONNREFUSED 10.0.3.12:5432" }   // leaks topology
GOOD → 503 { "code": "upstream_unavailable", "correlationId": "a1b2c3" }
```

More before/after rewrites and the copy contract are in
[`references/boundaries-and-messaging.md`](references/boundaries-and-messaging.md).

## Decision table

| Situation | Reaction |
|---|---|
| Expected domain outcome the caller must handle | `Result<T,E>` |
| Programmer bug / invariant violation | `throw` → nearest boundary |
| Transient failure on an idempotent call | retry (capped + full jitter) |
| Transient failure on a mutation without a key | do **not** retry; require idempotency key first |
| Dependency failing repeatedly | circuit-break + fallback |
| Failure during React render | `error.tsx` boundary |
| Failure in an event handler / async callback | explicit `try/catch` + state |
| Unhandled at the top of the process | process handler → log + exit |

## Anti-patterns

| Anti-pattern | Why it bites | Fix |
|---|---|---|
| Empty `catch {}` / `except: pass` | failure vanishes; you debug blind later | handle, or rethrow with context |
| Bare `except:` (Python) | swallows `KeyboardInterrupt`/`SystemExit` too | catch the specific type |
| Retry everything, including 4xx | retrying a 400 just burns budget; never succeeds | retry only the transient table |
| Retry a non-idempotent POST without a key | double-charges, duplicate rows | require an idempotency key first |
| Infinite retry, no cap or jitter | thundering herd; turns a blip into an outage | cap attempts + full jitter + budget |
| Leak stack trace / SQL to the user | hands attackers your internals | generic message + id; detail to the log |
| Expect `error.tsx` to catch its own segment's `layout` error | it runs outside the boundary; nothing catches it | move the boundary to the parent |
| `alert(e.message)` as the handler | blocks the UI, leaks internals, no recovery | render an `error.tsx` with `reset` |
| Catch-and-rethrow that drops `cause` | the root error is gone; logs are a dead end | wrap, set `cause`, preserve the chain |
| Log the error **and** rethrow | double-logged at every layer; noise buries signal | log at the boundary, or rethrow — not both |
| Swallow, then `return null` | callers deref null later, far from the cause | return a typed `Result` error |
| Outbound call with no timeout | one hung dependency exhausts the pool | timeout every call, then retry |
| One giant `try` around 200 lines | you cannot tell which call failed | scope `try` to the fallible call |
| Treat every error as a retryable transient | masks real bugs as "flaky" | classify first (Step 1), then react |

## Verification checklist

Before claiming the failure path is handled:

- [ ] Every failure maps to one of the three buckets (Step 1).
- [ ] No empty `catch {}` / `except: pass` / bare `except:`.
- [ ] Retries are capped, jittered, transient-only, and idempotent-only.
- [ ] Every outbound call has a per-attempt timeout.
- [ ] Repeatedly-failing dependencies have a circuit breaker + fallback.
- [ ] `error.tsx` / `global-error.tsx` placed correctly; render-only limits known.
- [ ] User message has no internals + carries a correlation id; the log has the cause chain.
- [ ] Cause is preserved on every wrap (no lost root error).

Run `scripts/verify.sh <path>` to scan the working tree for the highest-signal
anti-patterns above. It is **advisory** (exit 0 with warnings); pass `--strict` to
make any hit fail. It is heuristic — it flags, you judge.
