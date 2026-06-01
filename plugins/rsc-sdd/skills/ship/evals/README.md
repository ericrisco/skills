# Eval harness — ship

These evals run through an **agent harness** (an agent that loads skills on
demand), not a plain shell script. `cases.yaml` is the fixture; this file is the
procedure. Two things are measured: **triggering** (does `ship` fire on
"close the branch / merge / open the PR" and stay quiet for its siblings) and
**capability** (does loading `ship` produce a safe, Eric-only landing — runs the
pre-ship checklist, strips AI authorship, picks the right of three options).

## Setup

- Use the same agent/model for every trial; vary only which skills are loaded.
- Triggering trials: load the **full skill catalog** so the agent can route to a
  sibling, then observe which skill it selects.
- Capability trials: compare **only `ship` loaded** vs **no skill loaded**.

## 1. Triggering

For each item in `should_trigger` and `should_not_trigger`:

1. Start a fresh agent session with the full catalog available.
2. Feed the `prompt` verbatim as the user message.
3. Record which skill (if any) the agent invokes.
4. Run **3–5 trials** per prompt — selection is stochastic.

Pass conditions:

- `should_trigger`: **ship** is invoked in the majority of trials. The set mixes
  the three landing modes — direct merge ("merge into main", "squash and merge"),
  pull request ("open the PR"), and park/discard ("clean up the branch, shouldn't
  merge") — plus the authorship concern ("don't credit Claude", "strip the
  generated-with footer"). All must fire `ship`.
- `should_not_trigger`: ship is **not** invoked; ideally the agent routes to the
  listed `route_to` sibling. These near-misses are the adjacent phases that ship
  explicitly defers to: **verify** (run the gates), **review** (read the diff),
  **deployment** (reach a server), **worktrees** (open isolated work), and the
  **postgresdb** stack skill (author SQL). All five siblings exist in this repo,
  so a correct routing lands on the named target.

**Pass bar: >= 90% trigger accuracy** across all trials. A prompt that flaps
below majority counts as a fail for that prompt; >= 90% of prompts must pass
clean.

## 2. Capability

For the `capability` scenario, run two arms:

- **WITH**: only `ship` loaded.
- **WITHOUT**: no skill loaded (baseline model behavior).

Run each arm 3 times. Grade every response against the scenario's `must_include`
rubric — one point per item that is genuinely present (actually performed, not
hand-waved). The scenario is built to discriminate on the skill's reason to
exist: an approved branch carrying a leftover `Co-Authored-By: Claude` trailer
and a "Generated with Claude Code" footer, in a repo with a protected `main`. The
win is (a) detecting and **stripping** the AI authorship before pushing, (b)
recommending the **PR** option because `main` is protected, and (c) producing a
spec-linked commit/PR body with **no AI attribution**.

Pass conditions:

- **WITH** the skill covers **>= 80%** of `must_include` items on average.
- The skill **measurably improves** the output: WITH coverage must beat WITHOUT
  by a clear margin (target **>= 25 percentage points**). The discriminating
  items are the authorship ones — baselines frequently *add* a Co-Authored-By
  Claude trailer or a "generated with" footer as a default courtesy; the skill
  should flip that to actively stripping it. A response that adds any AI
  attribution is a hard fail on those items regardless of other coverage.

## Scoring summary

| Dimension | Metric | Pass bar |
|---|---|---|
| Triggering | trigger accuracy across all prompts/trials | >= 90% |
| Capability | rubric coverage WITH skill | >= 80% |
| Capability | WITH minus WITHOUT (lift) | >= 25 pts |

## Notes / honesty

- These are LLM-graded, stochastic evals — re-run on skill edits and treat small
  score deltas as noise, not signal.
- `route_to` targets (`verify`, `review`, `deployment`, `worktrees`,
  `postgresdb`) all exist in this repo's catalog, so a near-miss that lands on
  the named sibling is a clean pass. A mis-route to an *absent* skill would be a
  catalog gap, not a `ship` fault — but none of these targets are absent.
- The authorship items are the point of the skill, not a side check. Grade them
  strictly: "stripped the trailer" must be an actual amend/edit, and the produced
  commit/PR body must contain zero AI attribution. "Mentioned authorship" without
  acting is not a pass.
