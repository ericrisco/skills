# Eval harness — `clarify` skill

These evals check two things: that the skill **triggers** on the right prompts
(and stays quiet on near-misses that belong to a neighbouring SDD phase), and
that it **measurably improves** the de-risking pass over a spec. Cases live in
`cases.yaml`. There is no pure shell runner — grading is a judgment call done by
an **agent harness** (a Claude Code agent with the skill catalog loaded) plus a
human spot-check.

## What's in `cases.yaml`

- `should_trigger` — prompts that MUST load `clarify` (a spec exists; the user
  wants it de-risked / hole-poked / readiness-checked before planning).
- `should_not_trigger` — near-misses routed to the genuinely correct sibling
  via `route_to` (`specify`, `plan`, `analyze`, `debug`, `constitution`).
- `capability` — a scenario with a `must_include` rubric to grade WITH vs
  WITHOUT the skill loaded.

## Triggering eval

Goal: the skill fires when a spec needs de-risking, and never on an adjacent
SDD phase.

1. Configure an agent with the **full catalog of skill descriptions** available
   for routing — the SDD chain siblings (`specify`, `plan`, `analyze`, `debug`,
   `constitution`, and the rest) plus the stack/process skills (`harness`,
   `init`, `fastapi`, `nextjs`, `go`, `postgresdb`, `flutter`, `design`,
   `marketing`, …) so routing competes realistically.
2. For each `should_trigger` prompt: feed it cold and record whether `clarify`
   is the skill loaded. Run **3–5 trials** per prompt with fresh context.
3. For each `should_not_trigger` prompt: confirm `clarify` does NOT load and
   that the chosen skill matches `route_to`. Same 3–5 trials.
4. Score: `triggered_correctly / total_trials` across both lists.

**Pass bar: ≥ 90% trigger accuracy** over all prompts and trials, with **zero
systematic false-positives** on the `specify` and `plan` near-misses — those are
the known traps. The boundary clarify must hold: no-spec-yet is `specify`,
how-to-build-it is `plan`. If it grabs either, the description is leaking.

## Capability eval

Goal: prove the skill changes the de-risking pass, not just the routing.

1. For the `capability` scenario, run it **twice**:
   - **WITHOUT** the skill (base agent, no `clarify` loaded).
   - **WITH** the `clarify` skill loaded.
2. Grade each output against the `must_include` checklist — one point per
   checkable item covered. A human or grading agent marks each present / absent.
3. Compute coverage = `items_covered / total_items` per run.

**Pass bar: WITH the skill covers ≥ 80% of `must_include`; WITHOUT clearly
lower** (target a ≥ 30-point gap). The discriminating behaviors are the ones a
base agent reliably misses: reading the constitution and citing what's already
resolved, ranking gaps by leverage instead of dumping every question, framing
questions as decisions-with-a-recommendation, and — the highest-signal item —
actually **baking answers back into the spec with a dated Clarifications log**
rather than just listing questions in chat.

## Notes on honesty

- Trials are stochastic; report the raw fraction, not a rounded "pass".
- The single highest-signal capability check is **the edit-back**: an answer
  that asks good questions but never modifies the spec or records the reasoning
  is a capability failure even if the questions are sharp. Clarify's deliverable
  is the sharpened spec, not the conversation.
- A second tell: a base agent often slides into proposing *how to build* the
  feature. A correct clarify pass stays on WHAT and defers HOW to `plan`. Treat
  architecture suggestions as a scope-leak failure.
- Re-run after any edit to `SKILL.md` — wording changes shift both triggering
  (especially the `specify`/`plan` boundary) and rubric coverage.
