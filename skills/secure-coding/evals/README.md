# Eval harness — secure-coding

These evals are run through an **agent harness** (an agent with skills loadable
on demand), not a pure shell script. `cases.yaml` is the fixture; this file is
the procedure. Two things are measured: **triggering** (does the skill fire when
it should and stay quiet when it shouldn't) and **capability** (does the skill
make the answer materially better).

## Setup

- Use the same agent/model for every trial; vary only which skills are loaded.
- Triggering trials: load the **full skill catalog** (so the agent can route to
  siblings) and observe which skill the agent selects.
- Capability trials: compare **only this skill loaded** vs **no skill loaded**.

## 1. Triggering

For each item in `should_trigger` and `should_not_trigger`:

1. Start a fresh agent session with the full catalog available.
2. Feed the `prompt` verbatim as the user message.
3. Record which skill (if any) the agent invokes.
4. Run **3–5 trials** per prompt (the decision is stochastic).

Pass conditions:

- `should_trigger`: **secure-coding** is invoked in the majority of trials.
- `should_not_trigger`: secure-coding is **not** invoked; ideally the agent
  routes to the listed `route_to` sibling (or correctly declines when `none`).

**Pass bar: >= 90% trigger accuracy** across all trials (a single prompt that
flaps below majority counts as a fail for that prompt; >= 90% of prompts must
pass clean).

## 2. Capability

For each `capability` scenario, run two arms:

- **WITH**: only secure-coding loaded.
- **WITHOUT**: no skill loaded (baseline model behavior).

Run each arm 3 times. Grade every response against the scenario's
`must_include` rubric — one point per checkable item that is genuinely present
(correct, stack-appropriate, not hand-waved).

Pass conditions:

- **WITH** the skill covers **>= 80%** of `must_include` items on average.
- The skill **measurably improves** the output: WITH coverage must beat WITHOUT
  by a clear margin (target >= 25 percentage points). A skill that doesn't move
  the needle fails even if the baseline was already decent.

## Scoring summary

| Dimension | Metric | Pass bar |
|---|---|---|
| Triggering | trigger accuracy across all prompts/trials | >= 90% |
| Capability | rubric coverage WITH skill | >= 80% |
| Capability | WITH minus WITHOUT (lift) | >= 25 pts |

## Notes / honesty

- These are LLM-graded, stochastic evals — re-run on skill edits and treat
  small score deltas as noise, not signal.
- `route_to` targets assume the sibling skills (fastapi, nextjs, go, postgresdb,
  flutter, building-agents, deployment, …) are present in the catalog; a missing
  sibling can cause a near-miss to mis-route without it being a secure-coding
  fault — note it, don't count it against this skill.
