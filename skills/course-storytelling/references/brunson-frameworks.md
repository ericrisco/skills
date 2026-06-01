# Brunson Frameworks — Expert Secrets, Applied to Teaching

The *Expert Secrets* toolkit (Russell Brunson) repurposed for **comprehension and retention**, not for closing a sale. Each framework below is a teaching move: a way to make the realization happen *in the student* so the idea sticks and the student trusts the teacher. This is methodology — patterns and scripts you fill with the teacher's own true material, never reproduced text.

> Framework names and sequence confirmed against Brunson's *Expert Secrets*: the Epiphany Bridge, the Big Domino, the three false-belief patterns (vehicle / internal / external), the Hero's Two Journeys, and the Attractive Character. Summaries: [Shortform — Epiphany Bridge](https://www.shortform.com/blog/russell-brunson-epiphany-bridge/), [Dan Silvestre — Expert Secrets summary](https://dansilvestre.com/summaries/expert-secrets-summary/), [ReadingGraphics — Expert Secrets](https://readingraphics.com/book-summary-expert-secrets-russell-brunson/).

The SKILL.md runtime invokes these; this file holds the templates + worked teaching examples.

---

## 1. The Epiphany Bridge

The single most important teaching move. Instead of *stating* the conclusion ("idempotency makes retries safe"), you tell the story of how someone first *realized* it, so the student lives the realization and arrives at the conclusion themselves — feeling it.

### Why it works for teaching

A stated fact enters as information and is forgotten. A story is rehearsed by the listener's brain as lived experience; the emotion tags it for retention. You are not decorating the concept with a story — the story *is* the delivery vehicle for the belief.

### The six beats

```text
EPIPHANY BRIDGE (fill with a TRUE story — teacher's own, a student's, or a documented case)
1. BACKSTORY ......... who/where, the ordinary situation before — relatable, specific
2. THE DESIRE ........ what they wanted (the goal that pulls the story forward)
3. THE WALL .......... the struggle / the thing that kept failing (the pain, felt)
4. THE EPIPHANY ...... the "aha" — the moment the new way revealed itself
5. NEW OPPORTUNITY ... the new approach the epiphany opened up (= the concept you're teaching)
6. THE RESULT ........ the transformation it produced (proof + the so-what)
```

### Rules

- **Emotion before mechanics.** Tell the feeling of the wall before the technical fix. The student must *want* the epiphany.
- **Show the struggle honestly.** The wall must be real and a little embarrassing. A frictionless story teaches nothing.
- **Land on the concept at beat 5.** The "new opportunity" IS the thing you're teaching — that's the handoff from story to mental model.
- **Keep it true.** Use the teacher's real story, a real student's, or a documented case. If none exists, mark `[[NEEDS PROOF]]` and ask — never fabricate.

### Worked teaching example — "idempotency"

```text
1. BACKSTORY:  "Two years in, I owned the payments service. 4am, on-call."
2. DESIRE:     "I just wanted the failed charges to retry automatically so I could sleep."
3. WALL:       "The retry fired before the first response came back. We charged 4,000 people twice.
                Refunds, apologies, a very long morning."
4. EPIPHANY:   "The senior eng asked one question: 'What if the second request just... did nothing?'
                That reframed everything. The problem wasn't retrying — it was that the server
                couldn't tell 'try again' from 'do it again'."
5. NEW OPP:    "That's idempotency: design the operation so doing it five times equals doing it once."
6. RESULT:     "We added an idempotency key. Retries became free. I slept. Nobody got double-charged
                again." (-> hands off to the named model: 'The Elevator Button')
```

```text
Bad  — "Idempotency is the property that f(f(x)) = f(x)." (definition first, no one cares yet)
Good — the six-beat story above, THEN the definition lands because they want it.
```

---

## 2. The three false beliefs (break before you build)

Before a student adopts a concept, they must drop the belief that's blocking it. Teaching on top of an unbroken false belief bounces off — they nod and don't change. There are exactly **three** kinds, each broken by its own mini Epiphany Bridge.

| Belief type | The student's silent objection | What breaks it |
| --- | --- | --- |
| **Vehicle** | "This approach/tool/method doesn't actually work (for this)." | A story where the vehicle worked when nothing else did. |
| **Internal** | "Even if it works, *I'm* not the kind of person who can do it." | A story of someone just like them who did it (or you, before you could). |
| **External** | "Even if I can, something outside me will stop it (time, budget, my boss, the legacy system)." | A story where the external wall fell or got routed around. |

### How to use it

1. From the learner profile (`02-DOCS/wiki/teaching/false-beliefs.md`), pull the belief actually blocking *this* concept.
2. Identify which of the three types it is.
3. Pick the matching epiphany story and tell it *first* — clear the block — then install the concept.

### Worked example — concept "write tests first (TDD)"

```text
VEHICLE false belief:  "Tests just slow me down; they don't catch real bugs."
  -> Story: the refactor that would've shipped a data-loss bug, caught only because a test
     written first failed loudly. The vehicle (TDD) worked when review and manual QA didn't.

INTERNAL false belief: "Good engineers can do TDD; I just hack until it works."
  -> Story: you, year one, convinced TDD was for "real" engineers — until one boring CRUD feature
     where writing the test first made you faster, and you realized it's a habit, not a talent.

EXTERNAL false belief: "My team/deadline won't let me write tests first."
  -> Story: the sprint where the deadline was the reason TO do it — the test became the spec,
     cut the back-and-forth, and shipped early. The external wall was the excuse, not the cause.
```

Break all three that apply. A concept can be blocked by one or by all three; address each that the learner profile flags.

---

## 3. The Big Domino

The **one belief** that, if the student fully accepts it, makes every other concept in the module fall on its own. You don't have to win every micro-argument — you have to knock over the Big Domino.

### Finding it

Ask: *"If they believed only ONE thing after this module, which belief would make all the rest obvious?"* That's the domino. Everything in the module is either the story that knocks it over or a consequence that falls after it.

```text
BIG DOMINO statement (one sentence, a belief — not a topic)
"If I [adopt this one idea], then [the hard thing] becomes [easy/safe/possible]."
```

### Worked examples

```text
Module: "Reliability"        Domino: "If I make every operation safe to retry, outages stop being scary."
Module: "Teaching"           Domino: "If I make the student arrive at the insight, they never forget it."
Module: "Personal finance"   Domino: "If I automate the saving before I can spend it, willpower stops mattering."
```

Once the domino is set, sequence the module as the arc that topples it (see the Hero's Two Journeys below and `course-analysis.md` for resequencing).

---

## 4. The Hero's Two Journeys

Every lesson runs two journeys in parallel. Teach both; the inner one is why the student loves the teacher.

| Journey | What it is | What the student gets |
| --- | --- | --- |
| **Outer** | The skill, the result, the mechanics ("how to do X") | Competence — they can DO the thing |
| **Inner** | The identity shift ("I'm now the kind of person who…") | Belief — they SEE themselves differently |

```text
Bad  (outer only)  — "Here's the retry-with-backoff algorithm. Memorize the formula."
Good (both)        — outer: the backoff algorithm + a demo;
                     inner: "You stop being the person who fears the pager and become the one
                     who ships resilient systems on purpose." (the identity shift = why they care)
```

The student is the hero. The teacher is the **guide** who already walked the road — which is the bridge to the next framework.

---

## 5. The Attractive Character (the teacher persona)

Students bond to a character, not a curriculum. The Attractive Character is the trustworthy guide persona the teaching is delivered through. Four levers:

- **Relatable backstory** — the teacher was once where the student is now (the "before" of the transformation). Establishes the guide earned the road.
- **Admitted flaws** — the double-charge, the year of avoiding TDD, the thing you got wrong. Flaws make the guide trustworthy and the student's struggle normal.
- **Parables** — short repeatable stories that each carry one lesson (the epiphany bridges become the parables).
- **Polarity** — a clear point of view. A teacher who stands for something ("tests are a design tool, not a chore") is memorable; a neutral one is wallpaper. Polarity attracts the right students and is fine to repel the wrong fit.

```text
Bad  — neutral, omniscient narrator: "One should always validate inputs."
Good — "I learned input validation the day a single emoji in a username took down prod.
        I'm paranoid about it now, and you should be too." (backstory + flaw + polarity)
```

Persist the chosen Attractive Character in `02-DOCS/wiki/teaching/` so the persona stays consistent across every lesson.

---

## 6. Story-selling, grounded (abstraction → earth)

Brunson's story-selling, used to make abstractions *tangible* rather than to sell. The mechanics of analogy/metaphor engineering live in `mental-models.md`; the teaching moves here are:

- **Explain it in their world.** Translate the concept into the learner's daily vocabulary and objects (from `02-DOCS/wiki/teaching/learner.md`), not the discipline's.
- **Future-pace.** Walk the student through a near-future moment where they use the idea and it pays off ("Next time a deploy fails at 5pm, you'll…"). The brain pre-experiences the win and wants it.
- **One idea per story.** A parable that teaches three things teaches none. Split it.

---

## Putting it together (per concept)

```text
1. From the profile, name the false belief blocking this concept (vehicle / internal / external).
2. Tell the matching Epiphany Bridge to break it (six beats).
3. The "new opportunity" beat hands off to the named mental model (-> mental-models.md).
4. Ground the model with a concrete analogy from the learner's world.
5. Show proof (demo / before-after / receipt) — true only.
6. Run both journeys: the skill (outer) and the identity shift (inner).
7. Keep one Big Domino per module in view; this concept is a step toward toppling it.
```

This is the engine behind the per-concept landing recipe → `concept-landing-recipe.md`.

## See Also

- `../SKILL.md` — the runtime that invokes these frameworks and the non-negotiables.
- `mental-models.md` — naming + analogy engineering for the "new opportunity" handoff.
- `concept-landing-recipe.md` — the seven-beat per-concept output these frameworks feed.
- `learner-grounding.md` — where the false beliefs and transformation come from.
- `course-analysis.md` — resequencing the module as the arc that topples the Big Domino.
