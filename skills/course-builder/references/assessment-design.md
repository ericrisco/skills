# Assessment design

Assessment is the proof that an outcome was achieved — not a grade-generating afterthought. The
backward-design question for every outcome is: *what would I have to SEE the learner do to believe
this outcome is met?* That sight IS the assessment. This file is the formative↔summative menu, the
content-validity check, and the verb-match rule worked end to end.

## Formative vs summative — different jobs

```text
                  Formative (DURING learning)        Summative (AT THE END)
Purpose           feedback; guide improvement        certify mastery; accountability
Stakes            low / none                         high — the grade, the certificate
When              throughout each module             after the module / the course
Owner of action   the learner adjusts                the institution decides
Examples          quizzes, skill checklists,         capstone project, final exam,
                  drafts + revision, peer review,     portfolio, graded build, defense
                  exit tickets, self-checks
```

A course needs both. Summative-only gives the learner no chance to course-correct; formative-only
never certifies the contract was met.

## Assessment type mapped to Bloom level

Match the assessment to where the outcome's verb sits. A quiz can't prove "build".

```text
Outcome level     Formative options              Summative options
Remember          flashcards, recall quiz        section of a written exam
Understand        explain-back, concept map      short-answer / explanation exam
Apply             guided exercise, lab drill     applied problem set, practical task
Analyze           debug drill, code review        case analysis, diagnostic task
Evaluate          peer review w/ rubric          critique + justification, defense
Create            draft + feedback cycles        capstone build / portfolio / project
```

## The verb-match rule, worked

Constructive alignment (Biggs): the verb in the outcome must be the verb the learner *performs* in
the assessment. Walk it through:

```markdown
Outcome:    Given a spec, the learner BUILDS a REST endpoint that returns the correct
            status code for 3 named error cases.   (verb = build, level = Create)

Wrong assessment:  A 10-question multiple-choice quiz on HTTP status codes.
Why wrong:         the learner RECALLS (Remember). Recall ≠ build. It proves a different,
                   lower outcome — the contract is unverified.

Right assessment:  The learner ships a working endpoint; a test run hits all 3 error
                   cases and asserts the status codes.  (verb performed = build)
```

If you find yourself assessing with a quiz an outcome that says "design" / "build" / "evaluate",
that's the mismatch anti-pattern — fix the assessment, not the outcome.

## Content-validity / blueprint check

Competency-based design certifies *demonstrated mastery*, not seat time, and the assessment set must
have **content validity**: it covers the breadth of the outcomes and aligns with them. Build a
one-row-per-outcome blueprint and confirm:

```text
[ ] Every course-level outcome has at least one assessment that requires its verb.
[ ] No outcome is over-weighted (one vanity exam carrying the whole grade).
[ ] No outcome is under-assessed (touched once, in passing, never certified).
[ ] Both formative AND summative evidence exist across the course.
[ ] The summative assessment(s) together cover all course-level outcomes.
[ ] Self-paced? Every formative check grades itself (auto-graded / a test that runs).
```

When the blueprint has no gaps and no over-weighting, the assessment plan is content-valid and the
outcomes are provable. That blueprint feeds straight into the alignment matrix in SKILL.md.
