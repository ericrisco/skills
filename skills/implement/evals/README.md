# Eval harness — `implement` skill

Run by an **agent harness** (an LLM agent with the Skill tool), not a pure shell script.
`cases.yaml` is the fixture; this README is the honest run procedure. Three things to measure:
**triggering** (should fire), **anti-triggering** (must not fire), and **capability** (does the
skill make the build better).

`implement` is a process skill — it ships no `scripts/verify.sh`. It is judged on its safety rails
(test-first ordering, per-task checkpoints, decision logging, constitution adherence), not on a
deterministic command.

## 1. Triggering accuracy

For each prompt in `should_trigger` and `should_not_trigger`:

1. Start a fresh agent session with the `implement` skill available in the catalog, plus its named
   routing siblings (`verify`, `tasks`, `debug`, `worktrees`, and the stack skills such as
   `fastapi`) present but not the subject — so routing is realistic.
2. Feed the prompt verbatim. Do **not** hint that a skill exists.
3. Observe whether the agent invokes the `implement` skill.
4. Run **3–5 trials** per prompt (LLM routing is stochastic); record the fire rate.

Pass conditions:
- Every `should_trigger` prompt fires `implement` in **≥ 90%** of trials.
- Every `should_not_trigger` prompt does **not** fire it in ≥ 90% of trials, and the agent prefers
  the named `route_to` sibling. The boundaries to watch: `tasks` (makes the list, doesn't build it),
  `verify` (the final whole-suite gate, not per-task tests), `debug` (mysterious failures), and the
  stack skills (concrete test tooling). A near-miss leaking into `implement` is a harder failure
  than a missed trigger — fix the description boundary before shipping.

## 2. Capability uplift (with vs without)

For the `capability` scenario:

1. **Without skill:** run the scenario in a clean session, no `implement` skill loaded. Capture the
   answer.
2. **With skill:** run the same prompt with `implement` (and the named stack sibling) loaded.
3. Grade both against the scenario's `must_include` checklist — one point per bullet that is
   *concretely* present (e.g. an actual failing test shown first, not just the phrase "test-first").
4. Use 3 trials each side; average the coverage.

Pass conditions:
- **With** the skill: `must_include` coverage **≥ 80%**.
- **Measurable uplift:** with-skill coverage beats without-skill. The expected gaps in the
  without-skill run are the ones this skill exists to close: writing the test *after* the code (or
  skipping the red step), barrelling through multiple tasks with no checkpoint, hand-rolling a test
  runner instead of delegating to the stack reference, omitting the decisions.md trail, and claiming
  "done" without tying it to the done-check + acceptance criterion.

## What a failing eval tells you

- Trigger misses → the description's "Use when…" triggers are too narrow; widen the phrasings.
- Near-miss leaks → the boundary against `tasks`/`verify`/`debug` is blurry in the description; sharpen
  the NOT clauses.
- Capability gaps → the SKILL.md body under-specifies the loop (red→green→refactor), the checkpoint,
  the delegation, or the decision log; tighten the relevant section.
