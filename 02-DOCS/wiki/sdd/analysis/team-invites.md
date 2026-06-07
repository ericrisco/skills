# Analyze report — team-invites

GATE: BLOCKED — 4 CRITICAL/HIGH (1 CRITICAL, 3 HIGH). Plus a pre-condition failure: the four artifacts are not on disk.
Dial: L2 (no `user-profile.md` found — the harness has not gauged this user yet).

## Pre-condition: artifacts missing on disk

`analyze` reads the four artifacts and gates them against each other; it cannot gate what isn't there, and it does not fabricate artifacts. On disk under `02-DOCS/wiki/sdd/` there is only `specs/profile.md` (an unrelated feature). For **team-invites** the following are all absent:

| Artifact | Expected location | Status | Produced by |
| --- | --- | --- | --- |
| Constitution | `02-DOCS/wiki/sdd/constitution.md` | MISSING | `constitution` |
| Spec | `02-DOCS/wiki/sdd/specs/team-invites.md` | MISSING | `specify` (+ `clarify`) |
| Plan | `02-DOCS/wiki/sdd/plans/team-invites.md` | MISSING | `plan` |
| Tasks | task list inside the plan artifact | MISSING | `tasks` |

The findings below are derived **solely from the contents described in the task request**, not from files read. Before acting on them, materialize the four artifacts at the paths above so a real line-by-line gate (with locations) can run. Treat this report as provisional until then.

## Coverage map (from stated contents)

```text
REQ-ID | Spec requirement (short)            | Plan section        | Task(s)        | Status
------ | ----------------------------------- | ------------------- | -------------- | ----------
R1     | Email invites (send)                | (invite flow)       | T-send         | covered
R2     | Rate-limit invites 5/min            | — (silent)          | —              | GAP
R3     | Invite expiry after 7 days          | (invite flow)       | T-expiry       | AMBIGUOUS (no done-check)
C1     | Constitution: Postgres only         | Redis-backed cache  | (cache task?)  | CONTRADICTION
C2     | Constitution: every endpoint        | — (silent on RL)    | —              | GAP (constitution breach)
       |   rate-limited                      |                     |                |
—      | Redis-backed cache (unrequested)    | Redis cache         | (impl)         | DRIFT
```

- `GAP` — spec/constitution requirement with no task → it will silently not ship.
- `DRIFT` — plan adds work no spec requirement asked for.
- `AMBIGUOUS` — covered but not verifiable as written (no done-check / no metric).

## Findings

| # | Severity | Type | Artifact A | Artifact B | Conflict | Resolve in |
| - | -------- | ---- | ---------- | ---------- | -------- | ---------- |
| 1 | CRITICAL | Constitution compliance | Constitution: "Postgres only" | Plan: adds Redis-backed cache | Plan introduces a second datastore the constitution forbids. The constitution wins by definition. | `plan` (drop Redis / use Postgres) — or `constitution` only if the principle itself is to change (user's call) |
| 2 | HIGH | Constitution compliance + coverage GAP | Constitution: "every endpoint rate-limited"; Spec: "5/min" rate limit | Plan: silent on rate limiting; Tasks: no rate-limit task | A mandated, spec'd requirement has no architecture and no task → it will not be built, and ships a constitution breach. | `plan` (add rate-limit design) → `tasks` (add the task) |
| 3 | HIGH | Scope drift | Plan: Redis-backed cache | Spec: never mentions caching | Unrequested scope — real cost, second moving part, and it is the very thing that violates the constitution in #1. | `plan` (cut it) — or amend `specify` if caching is genuinely wanted (then re-check #1) |
| 4 | MEDIUM→HIGH | Ambiguity / underspecification | Spec: "expiry after 7 days" | Tasks: expiry task has no done-check | Task is not verifiable — "done" can't be proven (e.g. no assertion that an 8-day-old invite is rejected, a 6-day-old one accepted, boundary at exactly 7d defined). Raised to HIGH because expiry is a core security-relevant requirement. | `tasks` (add an explicit, testable done-check) |
| 5 | LOW | Ambiguity | Spec: "5/min" rate limit | — | Scope of the limit is unstated: per IP? per inviter? per team? per recipient email? Needs nailing down before implement so the limiter is correct. | `clarify` |

No duplication findings.

## Verdict and routing

GATE: BLOCKED. Do not proceed to `implement`. Two independent reasons: (a) the artifacts don't exist on disk yet, and (b) even as described they carry 1 CRITICAL + 3 HIGH.

Route the fixes to their owning phases:

- **`constitution`** — only if you decide "Postgres only" should change to permit Redis. Default expectation: it does not change; the plan does. (Finding #1)
- **`plan`** — remove the Redis-backed cache (#1, #3); add the rate-limiting design that satisfies the constitution + the spec's 5/min (#2).
- **`tasks`** — add a rate-limiting task once the plan covers it (#2); add a concrete, testable done-check to the expiry task (#4).
- **`clarify`** — pin the rate-limit scope (per-IP vs per-inviter, etc.) and confirm the exact 7-day expiry boundary semantics (#5).

After the four artifacts are written/fixed at their canonical paths, re-run `analyze`. The gate only opens once all CRITICAL/HIGH are resolved or consciously accepted.
