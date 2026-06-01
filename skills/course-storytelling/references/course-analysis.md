# Course Analysis — Ingest, Extract, Map Gaps, Sequence for Belief

Before you can make teaching land, you have to *see* what's there: what the material actually teaches, the story it already tells (if any), and exactly where it goes flat. This file is the analysis pass that runs after grounding and before reframing (step 2 of the SKILL.md workflow). It produces three artifacts — concept inventory, existing narrative spine, gap map — and then resequences the whole module into a belief-building arc.

---

## Step 1 — Ingest the material

Accept whatever the user has: slides, a transcript, lecture notes, a one-line outline, a notebook. Save anything pasted verbatim into `02-DOCS/raw/teaching/` (see `learner-grounding.md`), then read for structure, not polish.

```text
INGEST CHECKLIST
[ ] Identify the unit: is this one lesson, a module, or a whole course? (sets the Big Domino scope)
[ ] Note the medium and length budget (from wiki/teaching/constraints.md)
[ ] Find the implied teaching order (what comes before what)
[ ] Flag anything that's actually missing (a concept referenced but never taught)
```

If the material is thin (just an outline), extract the *intended* concepts and treat every beat as a gap to fill rather than a thing to rework.

---

## Step 2 — Concept inventory

List every distinct idea the material teaches, in teaching order, each with a one-line "what the student should be able to DO after this" (pulled from / checked against `wiki/teaching/learner.md`'s "do after").

```text
CONCEPT INVENTORY
#  | concept              | what the student can DO after
---+----------------------+-------------------------------------------------
1  | idempotency          | add an idempotency key to a POST and explain why
2  | retry with backoff   | configure jittered backoff instead of fixed retries
3  | circuit breaker      | wrap a flaky dependency so it fails fast, not slow
```

Rules:

- **One concept per row.** If a "concept" needs two "do" lines, it's two concepts — split it.
- **DO, not KNOW.** "Understand retries" is not a row; "configure jittered backoff" is. Capability is the unit.
- **Mark dependencies.** Note which concepts presuppose an earlier one — this drives sequencing.

---

## Step 3 — Extract the existing narrative spine

Most material already has *some* throughline, even if accidental. Find it and judge it honestly.

```text
SPINE EXTRACTION
- Opening: how does it start? (hook / cold definition / agenda slide?)
- Throughline: is there a story or just a topic stack?
- Belief work: does it break any false belief, or assume the student already agrees?
- Climax: is there a moment the whole thing builds to (a Big Domino), or does it just end?
- Close: does it future-pace a payoff, or summarize?
```

```text
Bad  (topic stack)  — "Agenda -> definition -> definition -> definition -> Q&A."
Good (belief arc)   — "A 4am failure (hook) -> why retries scared us (false belief) -> the elevator-
                       button realization (epiphany) -> retry fearlessly (Big Domino) -> what you'll
                       do next incident (future-pace)."
```

Write the extracted spine into `02-DOCS/wiki/stack/course-storytelling.md` so the rework is diffable against the original.

---

## Step 4 — The gap map

Per concept, flag what's missing. These flags are the work list and mirror exactly what `scripts/verify.sh` greps for.

| Flag | Meaning | Fix (where) |
| --- | --- | --- |
| `no-story` | concept stated as fact, no epiphany | `brunson-frameworks.md` (Epiphany Bridge) |
| `unnamed` | no sticky, ownable handle | `mental-models.md` (naming) |
| `no-analogy` | abstract, nothing concrete | `mental-models.md` (analogy engineering) |
| `jargon-dense` | unglossed terms stacked | `mental-models.md` (grounding) |
| `no-application` | no do-this-now step | `concept-landing-recipe.md` (application beat) |
| `no-so-what` | no future-paced payoff | `concept-landing-recipe.md` (so-what beat) |
| `belief-not-broken` | teaches on top of a live false belief | `brunson-frameworks.md` (three beliefs) |

```text
GAP MAP (one row per concept)
concept            | story | named | analogy | jargon | applic. | so-what | belief targeted
-------------------+-------+-------+---------+--------+---------+---------+----------------------
idempotency        | no    | no    | no      | HIGH   | no      | no      | (none) -> internal
retry w/ backoff   | part  | no    | weak    | MED    | yes     | no      | vehicle
circuit breaker    | no    | no    | no      | HIGH   | no      | no      | external
```

The map turns "this lesson is flat" into a concrete, finishable task list. Every flagged cell becomes a beat to write.

---

## Step 5 — Sequence for belief-building

A topic list orders concepts by logical dependency. A *belief-building* spine orders them by what the student must come to believe, in what order, to topple the Big Domino. Resequence with these moves:

1. **Set the Big Domino** for the module (→ `brunson-frameworks.md`). Every concept is either the story that knocks it over or a consequence that falls after.
2. **Open on the wall, not the agenda.** Lead with the felt pain (the hook + the false belief), not a definition or a table of contents.
3. **Break belief before building skill.** Put the belief-breaking epiphany *before* the mechanics of each concept, not after.
4. **Order by emotional dependency, then logical.** Sometimes the logically-second concept should come first because it breaks the belief that unlocks the first. Story order ≠ dependency order.
5. **Stack toward the domino.** Each concept should make the Big Domino more inevitable, so by the climax the student believes it almost before you say it.
6. **Close on the future-paced payoff**, not a recap. Leave them seeing themselves using it.

```text
Bad  (dependency order)  — idempotency -> backoff -> circuit breaker (correct but flat)
Good (belief order)      — the 4am double-charge (hook+pain) -> "retries are dangerous" (false
                            belief) -> idempotency breaks it (epiphany+Big Domino: 'retry
                            fearlessly') -> backoff and circuit breakers now land as obvious
                            consequences -> "next incident you'll..." (future-pace)
```

### Output: the reworked narrative spine

Produce a one-page spine for the module: the Big Domino, the opening hook, the ordered concept arc (with the false belief each one breaks), and the closing future-pace. Each concept in the arc then gets its full seven-beat treatment via `concept-landing-recipe.md`.

## See Also

- `../SKILL.md` — step 2 of the workflow invokes this analysis pass.
- `brunson-frameworks.md` — the Big Domino and false-belief work the sequencing is built on.
- `concept-landing-recipe.md` — each concept in the resequenced spine gets the seven-beat recipe.
- `mental-models.md` — fixes for the `unnamed` / `no-analogy` / `jargon-dense` flags.
- `learner-grounding.md` — the "do after" + transformation the inventory and spine are checked against.
