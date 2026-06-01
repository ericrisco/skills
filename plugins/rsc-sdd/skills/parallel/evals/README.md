# Eval harness — `parallel` skill

Run by an **agent harness** (an LLM agent with the Skill tool), not a pure shell script.
`cases.yaml` is the fixture; this README is the honest run procedure. Three things to measure:
**triggering** (should fire), **anti-triggering** (must not fire), and **capability** (does the
skill make the fan-out safer and faster).

`parallel` is a process skill — it ships no `scripts/verify.sh`. It is judged on its safety rails
(the independence test before dispatch, self-contained briefs, frozen contracts, the combined-suite
reconcile gate), not on a deterministic command.

## 1. Triggering accuracy

For each prompt in `should_trigger` and `should_not_trigger`:

1. Start a fresh agent session with the `parallel` skill available in the catalog, plus its named
   routing siblings (`implement`, `tasks`, `worktrees`, `debug`) present but not the subject — so
   routing is realistic.
2. Feed the prompt verbatim. Do **not** hint that a skill exists.
3. Observe whether the agent invokes the `parallel` skill.
4. Run **3–5 trials** per prompt (LLM routing is stochastic); record the fire rate.

Pass conditions:
- Every `should_trigger` prompt fires `parallel` in **≥ 90%** of trials.
- Every `should_not_trigger` prompt does **not** fire it in ≥ 90% of trials, and the agent prefers
  the named `route_to` sibling. The boundaries to watch: `implement` (the serial/TDD work itself,
  and any ordering-dependent task), `tasks` (makes the list, doesn't fan it out), `worktrees`
  (isolation, not concurrency), and `debug` (the red post-merge seam). A near-miss leaking into
  `parallel` — especially parallelizing tasks that share a file or have an ordering edge — is a
  harder failure than a missed trigger, because it produces a merge race. Fix the description
  boundary before shipping.

## 2. Capability uplift (with vs without)

For the `capability` scenario:

1. **Without skill:** run the scenario in a clean session, no `parallel` skill loaded. Capture the
   answer.
2. **With skill:** run the same prompt with `parallel` (and the named `implement` sibling) loaded.
3. Grade both against the scenario's `must_include` checklist — one point per bullet that is
   *concretely* present (e.g. it actually catches that the two migration tasks share a file and
   collapses them, not just the phrase "check independence").
4. Use 3 trials each side; average the coverage.

Pass conditions:
- **With** the skill: `must_include` coverage **≥ 80%**.
- **Measurable uplift:** with-skill coverage beats without-skill. The expected gaps in the
  without-skill run are exactly the ones this skill exists to close: blindly parallelizing the two
  tasks that share the orders migration (the trap), writing briefs that tell subagents to "coordinate"
  instead of freezing the contract first, merging the fast units before the slow ones land, and
  declaring done on green-in-isolation without ever running the combined suite.

## What a failing eval tells you

- Trigger misses → the description's "Use when…" triggers are too narrow; widen the phrasings
  (including the Spanish and the non-obvious "concurrently / at the same time / reconcile" wordings).
- Near-miss leaks → the boundary against `implement` (serial/dependent work), `worktrees`
  (isolation), `tasks`, or `debug` is blurry in the description; sharpen the NOT clauses. The most
  important one to keep tight is the independence boundary — the skill must *refuse* to fan out
  coupled work.
- Capability gaps → the SKILL.md body under-specifies the independence test, the contract-freezing
  rule, the gather hold, or the combined-suite reconcile gate; tighten the relevant section.
