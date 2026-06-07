---
name: clarify
description: "Use when a spec exists and you need to de-risk it BEFORE planning — hunt the ambiguities, unstated assumptions, edge cases, and underspecified areas, ask the user the high-leverage questions, then bake the answers back into the spec. The fourth phase of the rsc SDD chain (constitution → specify → clarify → plan → tasks → analyze → implement → verify → review → ship). Triggers: 'clarify the spec', 'what's ambiguous here', 'poke holes in this spec', 'is this spec ready to plan', 'aclara el spec', 'qué falta en este spec', 'review the requirements before we build', 'de-risk before planning', 'what questions should I answer first', 'this spec feels vague', a spec under 02-DOCS/wiki/sdd/specs/ heading into planning, or a plan that keeps stalling on unknowns. Reads the spec + constitution + harness profile; writes resolved answers back into the same spec file. NOT spec authoring (specify) and NOT the technical plan (plan)."
tags: [sdd, clarify, questions]
recommends: [plan]
profiles: [core, full]
origin: risco
---

# Clarify — the de-risking gate before planning

A spec written in one sitting always lies a little. It states what the author *thought of*, and stays silent on everything they didn't — the edge cases, the unstated defaults, the words that mean two things. Those silences don't disappear; they get discovered later, mid-implementation, where they cost ten times as much to fix. **Clarify is the gate that drags those silences into the open while they are still cheap.**

This is the fourth phase of the rsc SDD chain. `specify` turned a fuzzy intent into a spec; `clarify` interrogates that spec, asks the user the questions that actually change the build, and writes the answers back so the spec becomes safe to plan from. It produces **no new artifact** — it sharpens the existing one in place. When clarify is done, `plan` can start without tripping over unknowns.

## When to use / when NOT to use

Use when:

- A spec exists (typically `02-DOCS/wiki/sdd/specs/<slug>.md`) and is heading into planning.
- A spec "feels vague", or planning keeps stalling because something wasn't decided.
- You want a structured pass over ambiguities, edge cases, and unstated assumptions before committing engineering effort.
- A review or a teammate flagged "this isn't ready to build yet".

Do NOT use when (delegate instead):

- The intent is still fuzzy and there is no spec yet → that's **specify** (capture the what & why first; clarify needs something to interrogate).
- The spec is clear and you want the technical *how* (architecture, interfaces, data flow) → that's **plan**.
- You want a consistency cross-check across constitution ↔ spec ↔ plan ↔ tasks → that's **analyze** (clarify works on the spec alone, before a plan exists).
- The thing you're "clarifying" is a runtime bug's root cause → that's **debug**.

The line: **specify creates, clarify de-risks, plan designs.** If you find yourself proposing how to *build* it, you've left clarify.

## Read first — the inputs

Clarify never works blind. Before asking a single question, load three things:

1. **The spec.** Read the target spec under `02-DOCS/wiki/sdd/specs/<slug>.md` end to end. If the path wasn't given, find the most recently touched spec or ask which one.
2. **The constitution.** Read `02-DOCS/wiki/sdd/constitution.md` if it exists. Its principles (stack canon, quality bars, conventions) resolve a surprising number of "ambiguities" without bothering the user — if the constitution already fixes the auth method or the data region, that's answered, not open.
3. **The harness profile.** Read `02-DOCS/wiki/harness/user-profile.md` for the technical level and accompaniment dial. This sets **how many questions you ask and how you phrase them** (see the dial section below). If no profile exists, default to non-technical framing and ask the two gauging questions first.

Citing what you read ("checked the constitution — auth is already fixed to OAuth, so that's not an open question") shows your work and prevents re-litigating settled decisions.

## The ambiguity taxonomy — where specs hide their gaps

Scan the spec against these categories. Most real gaps fall into one of them; walking the list is how you find the ones the author didn't think to write down.

| Category | What to hunt | Tell-tale phrasing in the spec |
| --- | --- | --- |
| **Underspecified behavior** | A described feature with a missing branch — what happens in the *other* case | "the user logs in" (and if it fails? locked out? wrong password vs no account?) |
| **Unstated assumptions** | Defaults the author assumed everyone shares | no mention of auth, tenancy, currency, timezone, locale |
| **Edge & boundary cases** | Empty, zero, max, duplicate, concurrent, first-run, offline | lists with no empty-state, counts with no upper bound |
| **Ambiguous terms** | A word doing two jobs | "user" (end-user or admin?), "delete" (soft or hard?), "fast" (how fast?) |
| **Missing acceptance criteria** | A goal with no observable done-condition | "should be performant", "easy to use", "handle errors gracefully" |
| **Scope edges** | What's explicitly OUT vs left dangling | features hinted at but never bounded — "for now", "eventually" |
| **Data & state** | Lifecycle, ownership, retention, migration of existing data | new entity with no story for what happens to old records |
| **Failure & recovery** | What happens when a dependency is down, a write half-completes, input is hostile | happy-path-only flows |
| **Non-functional** | Performance, scale, security, accessibility, i18n targets | vague "non-functional requirements" or none at all |
| **Actors & permissions** | Who can do each thing | a verb with no subject — "can be edited" (by whom?) |

You are not filling every cell for every spec. You are scanning all ten so the gaps that *do* exist surface instead of hiding.

## The pass — five steps

Run in order. The discipline is: find many candidate gaps, keep only the ones that change the build, ask those well, write the answers back.

1. **Inventory.** Walk the spec against the taxonomy above. Produce a raw list of every candidate ambiguity, edge case, and unstated assumption. Over-collect here; you'll prune next. Note for each which category it is and where in the spec it lives.

2. **Resolve what you already can.** For each candidate, check the constitution and the spec's own later sections before asking the user. Many "gaps" are answered elsewhere. Mark each candidate **resolved-internally** (cite the source), **inferable** (a safe default you'll propose, not silently assume), or **must-ask** (only the user can decide).

3. **Rank by leverage.** Sort the must-ask list by impact: how much does the build change depending on the answer? A question whose two answers lead to two different architectures ranks above a cosmetic one. Cut low-leverage questions — clarify is not an interrogation, it's the *few* questions that matter. Cap the batch to the dial (below).

4. **Ask — one focused batch, the right size for the dial.** Present the high-leverage questions. For decisions with real trade-offs, frame them as a choice with a recommendation, not an open prompt (see the question-shape rule). Wait for answers. Never ask and answer in the same breath; never assume the user's intent on a must-ask item.

5. **Bake the answers back into the spec.** This is the deliverable. For each resolved item, edit the spec in place:
   - Tighten the relevant section with the decided behavior.
   - Add or sharpen acceptance criteria so the decision is now observable.
   - Append a `## Clarifications` log to the spec: dated entries of `Q → decision → why`, so the *reasoning* survives, not just the result.
   - Move anything explicitly dropped into an `## Out of scope` section so it's bounded, not dangling.
   Then re-read the spec once more: did resolving one gap open a new one? If so, one more short loop. Otherwise, the gate is passed.

## Question-shape rule

How you ask determines whether you get a usable answer.

- **Make it a decision, not an essay prompt.** "Should deletes be soft (recoverable, hidden) or hard (gone immediately)? I'd recommend soft because the spec mentions an audit trail — confirm?" beats "How should deletion work?".
- **Carry your own recommendation** when there's a defensible default, matched to the constitution. The user confirms or overrides — far less effort than authoring from scratch.
- **One batch, ranked, then stop.** Don't drip questions one at a time over many turns unless the dial is L3. Don't dump thirty at once. Ask the few that matter, together.
- **Quote the spec.** Anchor each question to the exact line or section it came from, so the user sees *why* it's open.

## Model tier — `balanced` (opt-in routing)

This phase's default model tier is **`balanced`** — it ranks and asks the few high-leverage questions, not architecture. Routing is **off** unless `models.enabled: true` in `02-DOCS/wiki/sdd/config.yaml`. When on: resolve this phase's tier (`models.overrides` wins over `models.phases`), map it to a model via `models.tiers`, and apply per `../sdd/references/model-routing.md` — announce the switch per the accompaniment dial when it differs from the session model, and dispatch any `Task`/`parallel` subagents on that model. Routing off or no profile → honor the session model silently. Never fake a switch a tool can't make; skip routing on a one-line change.

## The accompaniment dial

Read the level from `02-DOCS/wiki/harness/user-profile.md` and adapt **how many questions and how you frame them** — clarify is question-heavy, so the dial matters here more than almost anywhere:

- **L0 (cavernícola)** — ask ONLY the questions whose answer changes the architecture or scope. Propose safe defaults for everything else and list them tersely as "assumed unless you object". Minimal prose.
- **L1 (breve)** — the high-leverage batch, one line of *why* per question.
- **L2 (explica decisiones)** — the batch plus the trade-off behind each option, so the user chooses informed.
- **L3 (acompañamiento total)** — walk the taxonomy out loud, explain what each kind of gap costs if left unresolved, ask broadly (including the medium-leverage questions), and teach the *why* as you go. Ideal for non-technical users who benefit from seeing the hidden decisions.

When no profile exists: default to non-technical framing, ask the two gauging questions (technical level + accompaniment) first, then proceed at the stated level.

## Worked micro-example

Spec line: *"Users can upload a profile photo."*

Clarify's inventory against the taxonomy:

```text
- Ambiguous term  : "photo" — which formats? (PNG/JPG/HEIC/SVG?)
- Boundary        : max file size? max dimensions? what if it's 50 MB?
- Edge case       : no photo uploaded — is there a default/placeholder?
- Failure         : upload fails mid-transfer — retry, or lose it?
- Data lifecycle  : replacing a photo — is the old file deleted or orphaned?
- Actors          : can an admin change another user's photo?
- Non-functional  : is the image resized/compressed server-side? stored where?
- Security        : is the file type validated, or can someone upload an .svg with script?
```

Resolved-internally (cite): constitution fixes storage to the project's object store → "stored where" is answered. Must-ask, ranked: formats + max size (changes validation and UX), security validation (changes the upload path), old-file deletion (changes data model). Cosmetic placeholder choice → propose a default, don't burn a question on it.

After baking back, the spec line becomes a bounded, testable behavior with acceptance criteria ("rejects files >5 MB with a clear message", "accepts PNG/JPG/HEIC only", "replacing a photo deletes the prior file") and a `## Clarifications` entry recording why.

## Anti-patterns → STOP

| Rationalization | Reality / fix |
| --- | --- |
| "The spec reads clear enough, skip clarify" | Clear to the author ≠ unambiguous. Run the taxonomy; the gaps you can't see are exactly the expensive ones. |
| "I'll just assume the sensible default and move on" | An assumption is an unrecorded decision. Either it's resolvable from the constitution (cite it) or it's a must-ask. Silent defaults resurface as bugs. |
| "Let me also sketch how we'd build this while I'm here" | That's `plan`. Clarify decides *what*, not *how*. Proposing architecture means you left the gate. |
| "I'll ask everything I can think of to be safe" | Thirty questions is noise that buries the three that matter. Rank by leverage; ask the few; default the rest. |
| "I'll fire questions one at a time across many turns" | Below L3 that's death by a thousand prompts. Batch the high-leverage set once. |
| "I answered the questions in my head, the spec is fine as-is" | The deliverable is the *edited spec* + the Clarifications log. An un-baked answer is a lost answer. |
| "Edge cases are the implementer's problem" | Edge cases are *spec* problems. Resolving them now is the whole point of the gate. |
| "It's ambiguous but the user is busy, I'll guess" | A wrong guess costs more than a question. Frame it as a one-tap decision with a recommendation. |

## Done check — is the gate passed?

- [ ] Spec, constitution, and harness profile all read; settled questions cited, not re-asked.
- [ ] The spec was scanned against the full ambiguity taxonomy (all ten categories considered).
- [ ] Candidate gaps were ranked by leverage; only the build-changing ones were put to the user.
- [ ] Questions were framed as decisions with recommendations, in one dial-sized batch.
- [ ] Every resolved answer is baked into the spec body (behavior tightened, acceptance criteria added).
- [ ] A dated `## Clarifications` log captures Q → decision → why for each resolved item.
- [ ] Dropped items are bounded under `## Out of scope`, not left dangling.
- [ ] A final re-read confirmed resolving gaps didn't open new ones (or a short loop closed them).

## Next in the chain

When the gate is passed and the spec is de-risked, hand off to **plan** — turn the now-sharp spec into a technical implementation plan (architecture, interfaces, data flow, testing strategy, risks), deferring stack specifics to the relevant stack skill. The SDD chain continues: clarify → **plan** → tasks → analyze → implement → verify → review → ship.

## See Also

- `../harness/SKILL.md` — the accompaniment dial and the `02-DOCS/wiki/` convention this skill reads and writes into.
- The SDD chain (sibling phases): `specify` (creates the spec clarify interrogates), `plan` (consumes the de-risked spec), `analyze` (cross-checks constitution ↔ spec ↔ plan ↔ tasks), `debug` (root-cause diagnosis, callable any time), `constitution` (the principles clarify reads as guardrails).

## Orientación (siempre)

Cierra cada turno con el **bloque-brújula** (📍 dónde estás · ✅ qué hiciste · 🧭 por qué · ➡️ siguiente, terminando en pregunta), calibrado al dial de `02-DOCS/wiki/harness/user-profile.md`. **Nunca termines en seco.** Protocolo completo: skill `orient` → `skills/orient/references/orientation-contract.md`. (Defiere a `suggest` el "¿instalo la skill que falta?".)

