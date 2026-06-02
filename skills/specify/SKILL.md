---
name: specify
description: "Use when a feature, change, or product idea is still fuzzy and needs to become a written spec BEFORE any planning or code — turn a one-line intent into a WHAT/WHY specification (problem, goals, users, scope, behaviour, acceptance criteria) with zero implementation detail. Triggers: 'write a spec for…', 'spec this out', 'especifica esta feature', 'I want to add X but haven't thought it through', 'capture requirements for…', 'what should this feature do', 'draft a PRD', 'define the feature before we build', kicking off an SDD feature after the constitution exists, or any moment someone jumps to HOW before WHAT is agreed. Asks ONE focused question at a time only where it cannot infer, then writes 02-DOCS/wiki/sdd/specs/<slug>.md and marks open points to clarify. NOT the technical plan (that's `plan`), NOT the de-risking ambiguity sweep (that's `clarify`), NOT project-wide principles (that's `constitution`)."
tags: [sdd, spec, requirements]
recommends: [clarify, plan]
profiles: [core, full]
origin: risco
---

# Specify — intent becomes a spec

This is the **specify** phase of the rsc-sdd chain: `constitution` → **`specify`** → `clarify` → `plan` → `tasks` → `analyze` → `implement` → `verify` → `review` → `ship`. Its single job is to turn a fuzzy intent into a written specification that states **WHAT** the change is and **WHY** it matters — and nothing about **HOW** it gets built.

A spec is a contract about behaviour and outcomes, readable by a non-technical stakeholder and precise enough that a `plan` can be derived from it. The output is one file: `02-DOCS/wiki/sdd/specs/<slug>.md`, indexed in the root `CLAUDE.md` Knowledge map.

## The one rule that defines this skill

**No implementation leaks.** The moment the spec names a framework, a table schema, a library, an endpoint shape, a file path, or an algorithm, it has stopped being a spec. Those decisions belong to `plan` and the stack skills. Specify describes the *observable behaviour and the reason for it*; the system that delivers it is deliberately left open.

If you cannot describe a requirement without naming the technology, you have found a real question — record it as a point to clarify, do not guess the answer.

## Read the room first (accompaniment dial)

Before asking anything, read `02-DOCS/wiki/harness/user-profile.md` for the technical level and accompaniment level, and adapt:

- **L0 "cavernícola"** — infer aggressively from the intent and any existing wiki/constitution. Ask only the questions whose answer would change the spec's scope. Draft, show, move on.
- **L1 "breve"** — one line of *why* per question; ask the few that genuinely matter.
- **L2 "explica decisiones"** — justify each requirement as you record it; surface the trade-offs you inferred.
- **L3 "acompañamiento total"** — explain what a spec is and is not, walk every section, ask freely (still one question at a time), confirm each answer before recording it. Ideal for non-technical users.

If no profile exists, default to non-technical framing and keep questions plain. Never assume fluency.

## Questioning discipline — one at a time, only where you can't infer

The failure mode of specs is the wall of twenty questions. Avoid it:

1. **Infer first.** Read the `constitution` (`02-DOCS/wiki/sdd/constitution.md`), the existing wiki, and sibling specs. Fill every section you reasonably can from what already exists.
2. **Ask only the gaps that change the spec.** A question earns its place only if a different answer would change scope, a goal, a user, or an acceptance criterion. Cosmetic gaps become *points to clarify*, not questions.
3. **One focused question per turn.** Ask, wait, record, then ask the next. Never batch. Phrase in the user's technical register.
4. **When inference and asking both fail, mark it.** Anything you cannot resolve in this pass becomes an explicit entry in *Points to clarify* — that list is the handoff contract to the `clarify` phase, not a defect.

Stop asking when the WHAT and WHY are complete enough to plan against. Remaining unknowns live in *Points to clarify*; you do not need every answer before writing the file.

## What a good spec contains

Write these sections into `02-DOCS/wiki/sdd/specs/<slug>.md` using `references/spec-template.md`. Keep every line about behaviour and intent.

| Section | Holds | Watch for |
| --- | --- | --- |
| Problem & why | The pain, the cost of not solving it, the trigger | A "solution" disguised as a problem |
| Goals | What success delivers, in outcome terms | A "goal" that's actually a HOW |
| Non-goals / out of scope | What is explicitly NOT done now — adjacent work, deferred features | Silence — unsaid scope becomes assumed scope |
| Users & context | Who acts, their context, what they're trying to achieve | An imagined user no one asked for |
| Behaviour | What the system does, in observable terms, incl. main + edge + error paths | A verb that's actually a HOW ("queries", "caches") |
| Acceptance criteria | Testable, binary checks that say "done" | Vague critera ("works well", "is fast") |
| Points to clarify | Open questions, assumptions made, decisions deferred | Pretending there are none |

### Acceptance criteria carry the weight

Each criterion is a binary, observable statement — true or false, no judgement call — phrased so `verify` can later check it and `tasks` can derive a done-check from it. Prefer the **Given / When / Then** shape; it forces a concrete trigger and a concrete outcome.

```text
Given a signed-in user with an empty cart
When they open the checkout page
Then they see an empty-cart message and the "pay" button is disabled
```

A criterion that needs a human to "decide if it's good enough" is not done yet — sharpen it or move the soft part to *Points to clarify*.

## The pass, end to end

```text
1. READ profile + constitution + existing specs    → set verbosity, inherit principles, avoid dupes
2. RESTATE the intent in one sentence              → confirm you understood before drafting
3. INFER every section you can                     → from constitution, wiki, the intent itself
4. ASK the gaps that change scope, one at a time   → record each answer, then ask the next
5. DRAFT 02-DOCS/wiki/sdd/specs/<slug>.md           → WHAT/WHY only, template sections filled
6. LIST Points to clarify                          → open questions + assumptions, the clarify handoff
7. INDEX it in root CLAUDE.md Knowledge map         → under the sdd/specs topic
8. HAND OFF to clarify                              → name the next phase explicitly
```

`<slug>` is a short kebab-case name derived from the feature (e.g. `bulk-csv-import`, `magic-link-login`). If a spec with that slug exists, read it and update rather than overwrite.

## Worked shape (abridged)

```markdown
# Spec — Magic-link login

## Problem & why
Password resets are the #1 support ticket and a sign-up drop-off point.
A passwordless email link removes the password entirely.

## Goals
- A user can sign in with only their email, via a one-time link.
- No password is ever stored or required.

## Non-goals / out of scope
- Social login (Google/Apple) — deferred.
- Replacing existing sessions for already-signed-in users.

## Users & context
A returning user on a new device who does not remember a password.

## Behaviour
- Main: user enters email → receives a link → following it signs them in.
- Edge: an expired link shows a "request a new link" path.
- Error: an unknown email reveals nothing (same response as a known one).

## Acceptance criteria
- Given a registered email, When the user requests a link and follows it within
  its validity window, Then they are signed in.
- Given an expired link, When it is followed, Then sign-in is refused and a new
  link can be requested.

## Points to clarify
- Link validity window? (assumed: short, exact value deferred to clarify)
- Rate-limit on requests per email? (deferred)
```

Note what is *absent*: no token format, no table, no email provider, no framework. Those are `plan`'s job.

## Anti-patterns → STOP

| If you're about to… | Reality / Fix |
| --- | --- |
| Name a framework, table, endpoint, or library | That's HOW. Strip it; describe the behaviour instead, or log the open question. |
| Dump 12 questions in one message | One focused question per turn. Infer the rest from the constitution and wiki. |
| Ask a question you could answer from the constitution | Read it first. Only ask what genuinely changes the spec. |
| Write "it should work well / be fast / be intuitive" | Not testable. Make it a binary Given/When/Then or move it to Points to clarify. |
| Skip non-goals because "it's obvious" | Unsaid scope becomes assumed scope. State what you are *not* doing. |
| Resolve every ambiguity yourself to look finished | Inventing answers is worse than naming gaps. List them in Points to clarify. |
| Start designing the solution because it's clearer | Stay on WHAT/WHY. The plan is a later, separate phase. |
| Write the spec somewhere other than 02-DOCS/wiki/sdd/specs/ | That's the canonical location the rest of the chain reads. Use it. |

## Project grounding (02-DOCS + CLAUDE.md)

- Read `02-DOCS/wiki/sdd/constitution.md` first — its principles are inherited constraints, not things to re-decide. If it's missing, note that the project has no constitution yet and suggest the `constitution` phase before continuing (you can still draft a spec, but flag the absence).
- **No constitution yet?** Still write the spec, but inherit nothing — lean harder on the wiki and the user's answers, and record every constraint you would have inherited as a *point to clarify* instead of assuming it.
- Write the spec to `02-DOCS/wiki/sdd/specs/<slug>.md`. Create the directory if absent.
- Add a row under the `## Knowledge map` section of the root `CLAUDE.md` linking the new spec under the `sdd/specs` topic (additive only — never delete existing rows). Create `CLAUDE.md` if absent.
- Log the spec's creation and any significant scoping decision to `02-DOCS/wiki/sdd/decisions.md` (append-only), so the chain keeps a trace of why scope landed where it did. This is the canonical SDD decisions log shared with `constitution` and `plan` — not the harness's own `02-DOCS/wiki/harness/decisions.md`.

## Next in the chain

A spec is the input to **`clarify`**, not the finish line. End by pointing there:

> "Spec written to `02-DOCS/wiki/sdd/specs/<slug>.md` with N open points. Next: run **`clarify`** to resolve them and de-risk the spec before planning."

If `clarify` surfaces answers, they get baked back into this same spec file. Only once the spec is de-risked does `plan` derive the technical approach.

## See Also

- `../constitution/SKILL.md` — the project principles this spec inherits as constraints.
- `../clarify/SKILL.md` — the next phase: resolves the Points to clarify and de-risks the spec.
- `../plan/SKILL.md` — turns the de-risked spec into a technical implementation plan (the HOW).
- `../harness/SKILL.md` — the 02-DOCS wiki + accompaniment dial + decisions log this skill honors.
- `references/spec-template.md` — the exact section template written to `02-DOCS/wiki/sdd/specs/<slug>.md`.
- `references/eliciting-requirements.md` — inference checklist + the one-question-at-a-time elicitation patterns.
