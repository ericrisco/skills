# nextjs — eval harness

Field-standard eval for the `nextjs` skill. These cases are run through an **agent harness**
(an agent with the skill catalog available), not a pure shell script — grading is semantic, so a
human or a judge-agent confirms each pass. `cases.yaml` is the source of truth.

## What's measured

1. **Triggering** — does the skill fire on in-scope prompts and stay quiet on near-misses?
2. **Capability** — does loading the skill measurably improve the answer vs. not loading it?

## A. Triggering

Load **only** the `nextjs` skill into the agent (plus the normal sibling catalog *names* for
routing, but not their bodies). For each prompt:

1. Feed the `prompt` to the agent in a fresh session.
2. Run **3–5 trials** per prompt (agents are stochastic).
3. Record whether the skill was invoked.

- `should_trigger` (7 cases): PASS if the skill fires in **≥ 90%** of trials.
- `should_not_trigger` (6 cases): PASS if the skill does **not** fire in **≥ 90%** of trials.
  For near-misses, also check the agent routes to the `route_to` sibling (or correctly handles it
  inline when `route_to: none`, e.g. Pages Router / Vite SPA).

**Trigger pass bar:** ≥ 90% correct decisions across all 13 prompts (≈ 12/13), with no single
`should_trigger` case sitting below 80%.

## B. Capability

For each `capability` scenario, run the agent **twice**:

- **WITHOUT** the skill (baseline) — skill body not loaded.
- **WITH** the skill loaded.

Grade each output against the scenario's `must_include` rubric (4–7 checkable points). Score =
fraction of points covered.

- **WITH the skill:** must cover **≥ 80%** of rubric points.
- **WITHOUT the skill:** expected materially lower (the delta is the skill's value). If the
  baseline already hits ≥ 80%, the scenario is too easy — tighten the rubric.

Run **3 trials** per condition and average. A scenario passes only if the WITH-skill average
clears 80% **and** beats the WITHOUT-skill average by a clear margin.

## Grading notes

- Rubric points are semantic, not string matches — "checks auth inside the action" counts however
  it's phrased. Judge on intent.
- The version-model points are load-bearing: prescribing v16 `"use cache"`/`updateTag` on a stated
  v15 repo (or vice-versa) is a **rubric failure**, not a near-miss.
- For `should_not_trigger`, a brief correct hand-off (naming the right sibling) is a PASS; the skill
  authoring its full Next.js playbook for an out-of-scope prompt is a FAIL.

## Counts

- should_trigger: 7
- should_not_trigger: 6
- capability scenarios: 2
