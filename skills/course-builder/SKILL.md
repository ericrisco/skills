---
name: course-builder
description: "Use when you must turn a vague \"I want to teach X\" into a defensible course/curriculum skeleton — writing measurable learning outcomes, designing assessment that proves them, sequencing modules, scoping a workshop/bootcamp/cohort/onboarding track, or building an outcome×module×assessment alignment matrix. Triggers: 'structure my course', 'turn these topics into a curriculum', 'write learning outcomes / objectives', 'design the final project and quizzes', 'map my modules to outcomes', 'is my course actually aligned?', 'my course just ends with no real endpoint — what should they be able to DO?', 'estructura el temario de mi curso', 'define los resultados de aprendizaje', 'dissenya el pla docent', 'quina avaluació demostra cada objectiu'. NOT making a concept land emotionally (that is course-storytelling)."
tags: [course, curriculum, instructional-design, learning-outcomes, assessment]
recommends: [course-storytelling, presentations, sop-builder]
origin: risco
---

# Course Builder — The Course Is a Contract

*Outcomes promise what the learner can DO. Assessment is the proof. Modules are the build order. If the three don't line up, you have a content dump, not a course. You design them backward — outcomes first, assessment second, content last — and you emit a matrix that makes the alignment checkable.*

This skill owns the **skeleton**: the measurable outcomes, the assessment that certifies each one, the module sequence that builds toward them, and the alignment matrix tying it all together. It does not own the *teaching* of any one concept.

## What this skill owns / does NOT own

**Owns:** desired results (outcomes), acceptable evidence (assessment), build order (module sequence), and the outcome×module×assessment matrix that proves nothing is orphaned or unproven.

**Does NOT own:**

- Making a single concept *click and stick* emotionally — epiphany, sticky names, grounded analogies. That is `../course-storytelling/SKILL.md`. Build the skeleton HERE first, then hand each module there to make it land.
- Auditing a *finished* course for gaps, redundancy, anachronisms with a written report → `../review/SKILL.md`.
- Turning a designed module into slides/decks → `../presentations/SKILL.md` (+ `../design/SKILL.md` for the visual system).
- Sales/landing copy and launch emails → `../marketing/SKILL.md`. You design the learning contract, never the pitch.
- Fact-checking or sourcing the subject matter → `../deep-research/SKILL.md`. You structure what the user already knows.
- A repeatable internal procedure with steps but no outcomes/assessment → `../sop-builder/SKILL.md`. An SOP tells someone the steps; a course changes what they can DO and proves it.

**The litmus.** If the question is *"what must the learner be able to DO, how do we prove it, and in what order do we build it?"* → here. If it's *"how do I make THIS concept click and stick?"* → `../course-storytelling/SKILL.md`.

## The grounding gate (read first — STOP if unmet)

You cannot design a course backward without knowing the destination. Do not write a single outcome until you have all three. Why: an outcome scoped for a senior engineer in a 90-minute workshop is wrong for a beginner in a 12-week cohort — same topic, different contract.

1. **WHO** — the learner and their *current* level (absolute beginner? practitioner? what can they already do?).
2. **WHAT transformation** — what must they be able to DO at the end that they cannot do now.
3. **FORMAT + constraints** — duration, modality (live cohort vs self-paced), group size, prerequisites, certification stakes.

If a `02-DOCS/wiki/teaching/` profile exists (the convention shared with `../course-storytelling/SKILL.md`), read it first and reuse it. Otherwise interview in ONE batch — ask all three at once, do not dribble questions. **Incomplete grounding = STOP and ask.** Depth, the interview script, and scope right-sizing by format → `references/grounding-and-scoping.md`.

## The non-negotiables

Each rule carries its one-line reason. Break one and the skeleton is not defensible.

1. **Design backward: outcomes first, then assessment, then content.** UbD has exactly three stages in order — desired results → acceptable evidence → learning experiences (Wiggins & McTighe, *Understanding by Design*). Content designed first is a dump with no destination.
2. **Every outcome uses a measurable Bloom verb.** The revised taxonomy (Anderson & Krathwohl, 2001) is six ascending levels of *verbs* — Remember → Understand → Apply → Analyze → Evaluate → Create — each supplying observable action verbs. A verb you can't observe, you can't assess.
3. **Banlist: never "understand", "know", "learn about", "appreciate", "be aware", "be familiar".** They name a private mental state, not an observable behavior. Replace with what the learner *does*: list, explain, build, debug, evaluate, design.
4. **Each outcome is ABCD-complete.** Audience + Behavior (verb + object) + Condition (situation/tools) + Degree (success criterion). A bare verb without a condition and a degree is not yet assessable — "write code" vs "given a failing test, write code that makes it pass".
5. **Every outcome is proven by ≥1 assessment.** No unproven outcomes. An outcome with no evidence is a promise you never keep.
6. **Every module ties to ≥1 outcome.** No orphan modules. If a module maps to no outcome, it's content the contract never asked for — cut it or write the outcome it serves.
7. **The verb in the outcome = the verb activated in teaching = the verb verified in assessment** (constructive alignment, Biggs). If the outcome says "design" and the quiz tests "recall", the assessment proves the wrong thing.
8. **Place BOTH formative and summative assessment.** Formative runs *during* learning (low/no stakes — quizzes, checklists, drafts) to give feedback; summative runs *at the end* (the project, the exam) to certify mastery. A course with only the final exam gives the learner no feedback loop.
9. **No content-first design.** "I already have these slides, build a course around them" inverts the contract. Outcomes decide what content survives.
10. **Right-size scope to format.** A 90-minute workshop earns ~1–2 outcomes; a 12-week cohort earns 5–8. Cramming a bootcamp's outcomes into a workshop guarantees none are actually achieved.

## The build workflow (one backward pass)

Run it in order. Do not jump to modules.

```text
Stage 0  Grounding gate         WHO + WHAT transformation + FORMAT. Incomplete → STOP.
Stage 1  Outcomes               3–8 course-level outcomes. Measurable Bloom verb + ABCD.
                                Verb banlist enforced. Right-sized to format.
Stage 2  Assessment             For EACH outcome, the evidence that proves it.
                                Verb-match the outcome. Place formative + summative.
                                Check content validity (covers the breadth of outcomes).
Stage 3  Modules + sequence     One focus per module, prerequisite order. Each module
                                maps to >=1 outcome. No orphans, no unproven outcomes.
Stage 4  Alignment matrix       Emit outcome x module x assessment. The checkable artifact.
Stage 5  QA gate                Run scripts/verify.sh over the curriculum doc. Fix warnings
                                or justify them. Then hand modules to course-storytelling.
```

## Writing measurable outcomes

Pick the verb at the level the learner must actually operate. Recall ≠ build.

```text
Level         What the learner does          Sample verbs
Remember      recall facts                   list, define, name, label, recall
Understand    explain in own words           explain, summarize, classify, compare
Apply         use in a new situation         apply, use, implement, solve, run
Analyze       break apart, find relations    analyze, differentiate, debug, diagram
Evaluate      judge against criteria         evaluate, critique, justify, prioritize, review
Create        produce something new          design, build, compose, construct, ship
```

The **ABCD template** for one outcome:

```text
[Audience]   the learner
[Behavior]   <Bloom verb> + <object>
[Condition]  given <situation / tools / inputs>
[Degree]     <criterion that counts as success>
```

Bad → Good (the banlist verb is the tell):

```markdown
Bad:  Students will understand REST APIs.
Good: Given a spec, the learner builds a REST endpoint that returns the correct
      status code for 3 named error cases (400, 404, 500).

Bad:  Learners will know SQL joins.
Good: Given two tables, the learner writes a query joining them that returns the
      expected rows for 2 of 2 test cases.

Bad:  Participants will appreciate good test design.
Good: Given a 20-line module, the learner writes 3 tests that cover the happy path
      and 2 edge cases, all passing.
```

Full per-level verb tables, the banlist, more worked ABCD examples, and course-level vs module-level granularity → `references/outcomes-and-blooms.md`.

## Designing aligned assessment

Assessment is the proof, not an afterthought. For every outcome, ask: *what would I have to SEE the learner do to believe they achieved it?* — and make that the assessment.

```text
                 Formative (during)              Summative (at the end)
Job              feedback, guide improvement     certify mastery / accountability
Stakes           low / none                      high — the grade, the cert
Examples         quizzes, skill checklists,      capstone project, final exam,
                 drafts, peer review, exit        portfolio, graded build
                 tickets
Bloom fit        Remember/Understand/Apply        Apply/Analyze/Evaluate/Create
```

Two hard checks:

- **Verb match.** The assessment must require the *same* verb as the outcome. Outcome "build" → assessment is a build, not a multiple-choice quiz. Outcome "evaluate" → assessment asks for a judgement with justification, not recall.
- **Content validity.** The set of assessments must cover the *breadth* of the outcomes — every outcome touched, none over-weighted into a vanity exam. Competency-based design maps this via the matrix and certifies demonstrated mastery, not seat time.

The full formative↔summative menu mapped to Bloom levels, the content-validity / blueprint checklist, and the verb-match rule worked end-to-end → `references/assessment-design.md`.

## Sequencing modules + the alignment matrix

Order modules by **prerequisite** (you can't build before you can run), give each **one focus**, and map each to ≥1 outcome. Then emit the matrix — this is the artifact `scripts/verify.sh` checks.

```markdown
| Outcome                          | Module(s)        | Assessment (F=formative, S=summative) |
|----------------------------------|------------------|---------------------------------------|
| O1 build a REST endpoint         | M2, M3           | F: M2 quiz · S: capstone API          |
| O2 debug a failing request       | M4               | F: M4 debug drill · S: capstone API   |
| O3 evaluate an API's error model | M5               | F: M5 peer review · S: capstone rubric|
```

Read the matrix two ways: down a column finds **orphan modules** (a module in no row → cut or justify); across the outcome list finds **unproven outcomes** (an outcome with an empty assessment cell → design evidence). A complete matrix has no empty cells.

## Decision table (branch only where the flow actually splits)

```text
Situation                         Then
Live cohort                       Schedule synchronous formative checkpoints; peer
                                  assessment is cheap and valuable.
Self-paced                        Formative must be self-graded/auto-graded (quizzes,
                                  tests that run); no instructor in the loop.
Short workshop (<= half day)      1-2 outcomes, mostly Apply; one summative artifact, no exam.
Full course / bootcamp            5-8 outcomes spanning up to Create; staged formative +
                                  a capstone summative.
Knowledge outcome                 Assess with explanation/application, not recognition alone.
Skill outcome                     Assess with a performance/build, never a quiz.
Attitude/disposition outcome      Assess with reflection + observed behavior; hardest to
                                  prove — keep few and honest.
```

## Anti-patterns

| Bad | Why it fails | Do instead |
|-----|--------------|------------|
| Content-first: "build a course around my slides" | Inverts the contract; content with no destination | Write outcomes first; let them decide what content survives |
| Vanity outcome: "students will understand X" | Names a private state, not observable → unassessable | Use a measurable Bloom verb in ABCD form |
| Orphan module: a module mapped to no outcome | Content the contract never asked for | Cut it, or write the outcome it serves |
| Unproven outcome: an outcome with no assessment | A promise you never verify | Design evidence that requires the outcome's verb |
| Verb mismatch: outcome "design", quiz tests "recall" | Proves the wrong thing | Make the assessment require the outcome's verb |
| Summative-only: just a final exam | No feedback loop during learning | Place formative checkpoints throughout |
| Scope creep: bootcamp outcomes in a workshop | None are actually achievable in the time | Right-size outcome count to the format |

## Hand-off

The skeleton is the start, not the finish.

- Skeleton + matrix pass QA → hand **each module** to `../course-storytelling/SKILL.md` to make the teaching land (epiphany, named models, grounded analogies). You built *what* and *in what order*; that skill makes it stick.
- Need decks → `../presentations/SKILL.md` for slides, `../design/SKILL.md` for the visual system.
- A repeatable team procedure surfaced that isn't a course → `../sop-builder/SKILL.md`.

The boundary is executable: `scripts/verify.sh` checks your curriculum's STRUCTURE and ALIGNMENT (measurable verbs, the matrix, proven outcomes, formative + summative). It does not judge whether the teaching lands — that is `course-storytelling`'s job, and its verify.sh checks narrative, not structure.
