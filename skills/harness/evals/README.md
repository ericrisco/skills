# Eval harness — `harness` skill

This evaluates the `harness` skill on two axes: **triggering** (does it fire on
the right prompts and stay quiet on near-misses) and **capability** (does loading
it measurably improve the agent's output). These run via an **agent harness**
(an agent loop with skills loadable on/off), not a pure shell script — grading the
triggering and rubric coverage requires a model in the loop.

`cases.yaml` is the source of truth: `should_trigger` (7), `should_not_trigger`
(6), `capability` (2 scenarios).

## Triggering

1. Load **only** the `harness` skill into the agent (plus its declared siblings'
   *names/descriptions* so routing is realistic — do not load their bodies).
2. For each `should_trigger` prompt: feed it cold to the agent, run **3–5 trials**,
   record whether the agent invokes `harness`. Pass = it fires on every trial.
3. For each `should_not_trigger` prompt: same protocol. Pass = `harness` does
   **not** fire; bonus-check that it routes toward the `route_to` sibling (or
   correctly declines when `route_to: none`).
4. Score = (correct trigger decisions) / (total prompts × trials).

**Pass bar: >= 90% trigger accuracy** across all prompts and trials, with **no
single `should_not_trigger` prompt firing harness in a majority of its trials**
(a consistent false-positive is a hard fail even if the average clears 90%).

## Capability

For each `capability` scenario, run it twice with an identical agent:

- **WITHOUT** the skill (baseline) — skill not loaded.
- **WITH** the skill loaded.

Grade each transcript against that scenario's `must_include` checklist: one point
per checkable point that appears, correct and unprompted, in the output. A second
agent (or a human) grades; keep the grading rubric = the literal `must_include`
list so it stays reproducible.

**Pass bar:**
- WITH the skill covers **>= 80%** of the `must_include` points.
- WITH must **beat** WITHOUT by a clear margin (>= 30 percentage points). If the
  baseline already covers most points, the skill isn't adding value — investigate.

## Honesty notes

- These are **model-graded** evals; expect run-to-run variance. Always run
  multiple trials and report the spread, not a single number.
- Keep prompts **cold** — no system hint that the harness skill exists, or the
  trigger test is meaningless.
- Do **not** let the capability runs actually write to disk; the skill is
  destructive-by-consent. Run in a throwaway/sandbox workspace, or grade on the
  *proposed plan* (AUDIT output) rather than executed APPLY.
- When a case starts failing after a SKILL.md edit, fix the skill or the case —
  don't tune the grader to pass.
