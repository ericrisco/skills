# Plan artifact template

Copy this skeleton into `02-DOCS/wiki/sdd/plans/<slug>.md` and fill every section. The `<slug>`
must match the spec's slug exactly — one plan per spec, same name. Delete the parenthetical
guidance once a section is written; never leave an empty section (an empty section is a `tasks`
phase that can't find its input). Keep everything at the *structure* altitude: contracts, shapes,
flows, levels — not framework syntax.

---

```markdown
# Plan — <feature name>

> Spec: ../specs/<slug>.md · Constitution: ../constitution.md · Status: draft | approved
> Last updated: YYYY-MM-DD

## 1. Context & constraints

(One or two lines each. Cite, don't re-paste, the spec and constitution.)

- Acceptance criteria that shape the design: spec §Acceptance #1, #3 …
- Non-functional bars: latency / throughput / scale / data residency …
- Constitution rules in play: stack canon, quality bar, naming/convention rules …
- Out of scope (from the spec) that the design must NOT creep into:

## 2. Architecture

(Box-and-arrow diagram + one sentence of single-responsibility per component. Mark each
component as INTERNAL or EXTERNAL. The arrows are the seams you'll test and parallelize.)

```text
[ component A ] --<protocol>--> [ component B ]
       |
       v
[ store / external ]
```

- **<component>** (internal/external) — single responsibility.
- …

**Top architectural decision:** <the one choice that matters> — chosen because <reason tied to a
constraint above>. (If two designs are viable, state both, the trade-off, and the recommendation.)

## 3. Interfaces & contracts

(One block per seam. Operation, inputs → outputs incl. error modes, invariants. Language-neutral.)

```text
<component>.<operation>(<input>: <Type>) -> <Success> | <Error1> | <Error2>
  - invariant: idempotent on … / transactional / ordered / …
  - precondition: …
  - postcondition: …
```

## 4. Data model & flow

(Entities at the model level — key fields and relationships, not DDL. Then trace one primary
scenario end to end. Concrete schema/indexes/migrations → ../<stack>/SKILL.md.)

**Entities**

- **<Entity>** — key fields; relationship to <Entity>.

**Primary flow** (`<scenario from spec>`)

1. <entry> receives <input> →
2. <component> does <X>, reads/writes <store> →
3. … → returns <output>.

- Consistency boundaries: <what's transactional together> / <what's eventually consistent>.
- Migration impact: new table? new column? backfill? destructive?

## 5. Testing strategy

(Per acceptance criterion: the level that proves it, what it asserts, what it fakes. Levels:
unit / contract / integration / e2e. Tooling is the stack skill's job — name the strategy here.)

| Acceptance criterion | Level | Asserts | Fakes / mocks |
| --- | --- | --- | --- |
| spec §Acceptance #1 | unit | … | … |
| spec §Acceptance #2 | integration | … | … |

- Where the e2e line is, and why.
- What MUST be a real dependency (not mocked) for the test to mean anything.

## 6. Sequencing & dependencies

(Ordered, independently-verifiable steps. Mark serial vs. parallelizable. This becomes the
`tasks` list.)

1. <step> — depends on: none — [serial | parallelizable]
2. <step> — depends on: #1 — …

- Parallel candidates (disjoint scope, no shared state): #…, #… (fan-out via the parallel phase)
- Hard ordering constraints and why.

## 7. Risks & open decisions

**Risks** (ranked, most likely/impactful first)

| Risk | Trigger | Impact | Mitigation / spike to retire it |
| --- | --- | --- | --- |
| … | … | … | … |

**Open decisions** (still genuinely undecided)

- <decision> — closes when <input/answer> arrives. (Significant decisions taken during planning
  go to ../decisions.md as well.)
```

---

## Notes on filling it

- **Altitude check.** If a section contains real framework code, you've dropped too low — restate
  it as a contract or a flow and let the stack skill render it at `implement`.
- **Citations over copies.** Reference `spec §…` and `constitution §…`; the plan is a derivative
  view, not a duplicate. Duplicated text drifts out of sync.
- **One decision, defended.** The architecture section's job is to make the load-bearing call and
  defend it, not to enumerate every option without choosing.
- **Empty section = defect.** Every one of the seven must say something real before `tasks` runs.
  If a section genuinely has no content (e.g. no migration), write "none — <why>", not silence.
- **Index it.** After writing, add the plan to the root `CLAUDE.md` `## Knowledge map` so the
  harness wiki and later phases can find it.
