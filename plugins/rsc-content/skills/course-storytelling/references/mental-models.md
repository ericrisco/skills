# Mental Models — Naming, Analogy Engineering & Grounding

A concept the student can't *name* is a concept they can't repeat — and what can't be repeated isn't retained. A concept they can't picture is one that never gets concrete enough to *use*. This file is the craft of both: designing sticky, ownable names and engineering the analogies that drop an abstraction down to earth. It feeds the "MENTAL MODEL" and "GROUNDED ANALOGY" beats of the landing recipe (`concept-landing-recipe.md`) and the "new opportunity" handoff from `brunson-frameworks.md`.

---

## Part 1 — Designing a named mental model

A mental model is a short, ownable handle the student carries out of the lesson and reuses. Good names do three jobs: **compress** (one phrase recalls the whole idea), **transfer** (it applies beyond the example), and **stick** (it's easy to say and hard to forget).

### The naming tests (a name must pass all four)

1. **Sayable** — a student can repeat it out loud, from memory, a week later. 2–4 words.
2. **Picturable** — it evokes a concrete image or object, not an abstraction. ("The Elevator Button" pictures; "Operational Convergence" does not.)
3. **Ownable** — it's specific enough to feel like *this* teacher's coinage, not a generic term they could Google.
4. **Load-bearing** — the name encodes the *mechanism*, so recalling the name recalls how it works.

### Naming patterns that work

| Pattern | Shape | Example (for a concept) |
| --- | --- | --- |
| Concrete object | "The [familiar object]" | "The Elevator Button" (idempotency) |
| Vivid action | "[Verb] the [noun]" | "Shrink the Blast Radius" (fault isolation) |
| Memorable contrast | "[X], not [Y]" | "Spec, Not Chore" (test-first) |
| Rule of N | "The [N] [things]" | "The Two-Pizza Rule" (team size) |
| Named law/effect | "The [Name] [Law/Effect]" | "The Last-Mile Tax" (deployment friction) |

```text
Bad  (no name)    — "We should design operations so repeated execution is safe."
Bad  (jargon name)— "Operational Idempotence Convergence" (unsayable, unpicturable, un-ownable)
Good (named)      — "The Elevator Button: press it five times, one elevator still comes."
```

### Where names live

Persist every coined model in `02-DOCS/wiki/stack/course-storytelling.md` (or under `wiki/teaching/`) so names stay consistent across lessons and the student hears the same handle every time. A model renamed mid-course is a model un-learned.

---

## Part 2 — Analogy & metaphor engineering

An analogy maps an unfamiliar concept onto something the student already understands deeply. Engineered well, it does the explaining for you. Engineered carelessly, it teaches the wrong thing.

### The mapping method

```text
ANALOGY MAP
Target (unfamiliar) ... the concept you're teaching
Source (familiar) ..... something from the LEARNER'S world (from wiki/teaching/learner.md)
Mapped parts .......... list each piece of the target -> its match in the source
Where it breaks ....... the ONE place the analogy fails (state it — prevents over-extension)
```

### Rules

- **Source from THEIR world, not yours.** A cooking analogy for chefs, a sports analogy for athletes, a spreadsheet analogy for finance folks. Pull the source domain from the learner profile.
- **Map the mechanism, not just the vibe.** A good analogy survives "okay, so what happens when…" — the parts correspond. A vibe-only analogy ("it's like magic") collapses on the first follow-up.
- **State where it breaks.** Every analogy fails somewhere. Naming the break point *before* a student finds it keeps trust and prevents them from learning the wrong thing.
- **One analogy per concept.** Stacking three analogies for one idea dilutes all three. Pick the strongest.

### Worked example — "idempotency" → "The Elevator Button"

```text
Target: an idempotent operation (repeated calls = one effect)
Source: pressing an elevator call button
Mapped parts:
  - the request          -> pressing the button
  - the side effect      -> one elevator dispatched
  - retries / dup sends  -> pressing the lit button again
  - the idempotency key  -> the button's "already lit" state
Where it breaks: a real elevator eventually arrives regardless; an idempotent API needs the key
  to RECOGNIZE the duplicate — name this so they don't think "it just works by magic".
```

```text
Bad  (vibe only)  — "Idempotency is like, you know, it just handles duplicates gracefully."
Good (mapped)     — the elevator map above: every part corresponds, and the break is named.
```

---

## Part 3 — Grounding abstract → concrete

Three moves that pull an abstraction down to where the student lives.

1. **Replace the variable with a value.** Don't say "for any request"; say "for *your* 4pm deploy." Specifics are graspable; generalities float.
2. **Explain it like their day.** Recast the concept inside a moment from the learner's actual routine (commute, standup, the ticket they're avoiding). Pulled from `wiki/teaching/learner.md`.
3. **Future-pace it.** Walk them through a near-future moment where they use the idea and it pays off. The brain pre-experiences the win and wants the concept that delivers it. (Story-selling move — see `brunson-frameworks.md`.)

```text
Bad  (abstract)  — "Backoff prevents thundering-herd retries from overwhelming a recovering service."
Good (grounded)  — "Your service just came back from an outage. The instant it's up, 10,000 queued
                    retries hit it at once and knock it over again. Backoff is everyone waiting a
                    polite, increasing beat before knocking — so the recovering service can breathe.
                    Next incident, you'll add jittered backoff and watch the recovery actually hold."
```

---

## Part 4 — "Make it land" tests

Apply these to any reframed concept before shipping. If it fails one, it isn't landed.

- **The repeat-back test.** Could the student explain this to a peer in one sentence using your name for it? If not, the name or analogy is weak.
- **The week-later test.** Will they still recall the name and the picture next week with no notes? If it needs notes, it's not sticky.
- **The follow-up test.** Does the analogy survive "okay, but what about…"? If it collapses, the mapping is vibe-only — re-map or name the break.
- **The so-what test.** Can the student say why it matters to *them*, in their world? If not, you stopped before grounding.
- **The jargon test.** Every term either glossed, grounded, or cut. An unexplained term is a leak where attention drains out.

## See Also

- `../SKILL.md` — the non-negotiables (name everything, ground everything).
- `concept-landing-recipe.md` — where the named model + analogy slot into the seven beats.
- `brunson-frameworks.md` — the "new opportunity" beat that hands off to the named model; future-pacing.
- `learner-grounding.md` — the learner's world that analogy source domains are drawn from.
