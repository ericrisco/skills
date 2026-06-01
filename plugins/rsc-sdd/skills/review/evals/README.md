# Eval harness — review

These evals run through an **agent harness** (an agent that loads skills on
demand), not a plain shell script. `cases.yaml` is the fixture; this file is the
procedure. Two things are measured: **triggering** (does `review` fire when it
should and stay quiet when it shouldn't, vs its siblings) and **capability**
(does loading `review` make the answer materially better — sharper findings when
giving a review, correct verify-before-acting when receiving one).

## Setup

- Use the same agent/model for every trial; vary only which skills are loaded.
- Triggering trials: load the **full skill catalog** so the agent can route to a
  sibling, then observe which skill it selects.
- Capability trials: compare **only `review` loaded** vs **no skill loaded**.

## 1. Triggering

For each item in `should_trigger` and `should_not_trigger`:

1. Start a fresh agent session with the full catalog available.
2. Feed the `prompt` verbatim as the user message.
3. Record which skill (if any) the agent invokes.
4. Run **3–5 trials** per prompt — selection is stochastic.

Pass conditions:

- `should_trigger`: **review** is invoked in the majority of trials. This set
  deliberately mixes the two roles — *giving* a review ("review this PR", "tear
  this apart", "critique against the spec") and *receiving* one ("do I have to
  change it?", "which bot comments should I act on?"). Both must fire `review`.
- `should_not_trigger`: review is **not** invoked; ideally the agent routes to
  the listed `route_to` sibling (or declines when appropriate).

**Pass bar: >= 90% trigger accuracy** across all trials. A prompt that flaps
below majority counts as a fail for that prompt; >= 90% of prompts must pass
clean.

## 2. Capability

For each `capability` scenario, run two arms:

- **WITH**: only `review` loaded.
- **WITHOUT**: no skill loaded (baseline model behavior).

Run each arm 3 times. Grade every response against the scenario's `must_include`
rubric — one point per item that is genuinely present (correct, traced to the
code, not hand-waved). The two scenarios test opposite halves of the skill: one
**receiving** a *false* finding (the win is declining the change with evidence
and adding a regression test, not editing working code), one **giving** a review
of a real IDOR (the win is a ranked, repro-backed blocker with a concrete fix and
an explicit verdict).

Pass conditions:

- **WITH** the skill covers **>= 80%** of `must_include` items on average.
- The skill **measurably improves** the output: WITH coverage must beat WITHOUT
  by a clear margin (target **>= 25 percentage points**). The receiving scenario
  is the discriminating one — baselines tend to performatively "fix" the false
  NPE finding; the skill's verify-before-acting gate should flip that to a
  correct, evidenced decline.

## Scoring summary

| Dimension | Metric | Pass bar |
|---|---|---|
| Triggering | trigger accuracy across all prompts/trials | >= 90% |
| Capability | rubric coverage WITH skill | >= 80% |
| Capability | WITH minus WITHOUT (lift) | >= 25 pts |

## Notes / honesty

- These are LLM-graded, stochastic evals — re-run on skill edits and treat small
  score deltas as noise, not signal.
- `route_to` targets name the sibling skill the prompt should land on instead of
  `review`. The adjacent SDD phases this skill hands off to — **verify** before it
  and **ship** after it — are present as their own skills in this repo, so the two
  phase-boundary near-misses route straight to them (`verify` for the run-the-gates
  prompt, `ship` for the open-the-PR-and-merge prompt). Every `route_to` target
  must resolve to a real sibling skill; a mis-route to the wrong sibling counts
  against `review`'s triggering accuracy.
- The receiving-side capability scenario is intentionally a *false* finding. A
  pass means the skill declined the edit with a trace; "fixed the NPE" is a
  failure even though it looks responsive.
