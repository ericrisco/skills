# Eval harness — `building-agents`

This evaluates two things: (1) **triggering** — does the skill activate on the
right prompts and stay quiet on near-misses — and (2) **capability** — does
loading the skill measurably improve the agent's answer. These run through an
**agent harness** (a Claude Code / SDK session), not a pure shell script: a
human or a driver script feeds prompts and grades outcomes against
`cases.yaml`.

## Files

- `cases.yaml` — `should_trigger`, `should_not_trigger`, and `capability` cases.

## 1. Triggering eval

Goal: confirm the skill's `description` routes correctly.

1. Load **only** this skill into the agent (its `SKILL.md` description in the
   skill index). For near-miss realism, also expose the sibling skills named in
   each `route_to` so the agent can pick the better match instead of defaulting.
2. For each prompt in `should_trigger` and `should_not_trigger`, start a fresh
   session and send the prompt verbatim. Do **not** answer the task — observe
   only whether `building-agents` is selected.
3. Run **3–5 trials** per prompt (the selection is stochastic). Record the
   fire-rate per prompt.
4. Score:
   - `should_trigger` item passes if the skill fires in a strong majority of
     trials (>= 4/5).
   - `should_not_trigger` item passes if the skill does **not** fire, and
     ideally the agent routes to the `route_to` sibling (or to nothing when
     `route_to: none`).

**Pass bar:** >= 90% trigger accuracy across all items
(true-positives + true-negatives / total trials). Any `should_not_trigger`
that fires the skill is a false-positive and must be investigated — usually a
too-greedy `description`.

## 2. Capability eval

Goal: prove the skill changes the output, not just the routing.

1. For each `capability` scenario, run it **twice** in matched sessions:
   - **WITHOUT** the skill loaded (baseline).
   - **WITH** the skill loaded.
2. Grade each answer against that scenario's `must_include` rubric: count how
   many points are concretely present (code or prose), not merely gestured at.
3. Compute coverage = points covered / total points, for both runs.

**Pass bar:** WITH-skill coverage >= 80% of the rubric, AND a clear lift over
the WITHOUT-skill baseline (the skill must add the load-bearing points the
baseline misses — typically the adapter/Protocol, idempotency, cite-or-refuse,
CI gate exit code, and transient-only retries). If the baseline already scores
~as high, the skill isn't earning its place on those points.

## Honest caveats

- Selection is non-deterministic; always use multiple trials and report rates,
  not a single pass/fail.
- Grading `must_include` and "routes to the right sibling" requires judgment —
  an LLM-as-judge can assist but spot-check it.
- Keep `cases.yaml` in sync with `SKILL.md`: when the description's triggers or
  the "Do NOT use" list change, update the cases in the same commit.

## Counts

- should_trigger: 7
- should_not_trigger: 7
- capability: 2
