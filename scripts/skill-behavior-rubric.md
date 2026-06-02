# skill-behavior-rubric — how a skill's OUTPUT is graded (the behavioral gate)

Sibling of `skill-rubric.md`. That one scores the skill as a **document**; this one scores what
the skill **produces when run**. A skill ships only if BOTH gates are green.

## How the behavioral eval works

For each `capability` scenario in the skill's `evals/cases.yaml`, the engine
(`scripts/skill-behavior-eval.workflow.js`) runs the scenario twice — once with the skill's
`SKILL.md` injected (**treatment**), once without it (**baseline**) — and an independent, blind
grader scores both outputs. The grader never learns which output used the skill; outputs are
presented as X and Y, their slot varied by scenario index parity so a "first output" bias can't
systematically favor the skill.

## What the grader returns (per output)

1. **must_include coverage.** For each `must_include` item: `satisfied` true/false **and a quoted
   line** from the output that satisfies it. Evidence, not vibes. If unsure, mark unmet.
2. **Quality, four axes 0-10:** `completeness`, `actionability`, `correctness`, `grounding`
   (no invented facts / APIs / numbers).

The grader returns raw signals only. It does **not** compute the score — that keeps the number
deterministic and auditable.

## How signals become the /10 (computed by `scripts/lib/behavior-score.js`)

- Per output: `score = 0.6 × (satisfied / total × 10) + 0.4 × mean(quality axes)`.
  Empty output → 0. No checklist → quality only.
- Per scenario: `absolute` = treatment's score; `delta` = treatment − baseline.
- Per skill: `absolute_score` = mean of absolutes; `lift` = mean of deltas.

## The gate (both required)

- `absolute_score ≥ 8.5` — the skill genuinely produces a good result.
- `lift ≥ +1.0` — the skill measurably beats no-skill. `lift ≤ 0` is an automatic FAIL even at a
  high absolute: the skill adds nothing the bare agent didn't already do.

## Anti-gaming

- Independent, blind grader; default-skeptical on coverage.
- Errors fail closed: a scenario whose run or grade errored is dropped; if all drop, FAIL.
- A skill with no `capability` scenario cannot be behaviorally evaluated → FAIL until one exists.
- v1 uses a single grader per scenario. Upgrade path: N=3 graders, majority vote.

## Running it

```
# 1) execute + grade — invoke the Workflow tool with the engine script and the skill id:
#      scriptPath: scripts/skill-behavior-eval.workflow.js   args: "<skill-id>"
#    capture the workflow's returned object to a JSON file (e.g. /tmp/<skill>-raw.json)
# 2) score + gate (exit 0 pass / 1 fail):
node scripts/skill-behavior-eval.js --score /tmp/<skill>-raw.json
```
