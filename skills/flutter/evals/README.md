# Eval harness — `flutter` skill

These evals are run by an **agent harness** (an LLM agent with the Skill tool), not a
pure shell script. `cases.yaml` is the fixture; this README is the run procedure. There
are three things to measure: **triggering** (should fire), **anti-triggering** (must not
fire), and **capability** (does the skill make the answer better).

## 1. Triggering accuracy

For each prompt in `should_trigger` and `should_not_trigger`:

1. Start a fresh agent session with **only the `flutter` skill** available in the catalog
   (plus its named siblings present but not the subject — so routing is realistic).
2. Feed the prompt verbatim. Do **not** hint that a skill exists.
3. Observe whether the agent invokes the `flutter` skill.
4. Run **3–5 trials** per prompt (LLM routing is stochastic); record the fire rate.

Pass conditions:
- Every `should_trigger` prompt fires the skill in **≥ 90%** of trials.
- Every `should_not_trigger` prompt **does not** fire it in ≥ 90% of trials. For routes
  with a named sibling, the agent should prefer that sibling (or correctly defer when
  `route_to: none`).

A single near-miss leaking into the skill is a harder failure than a missed trigger —
investigate the description boundary before shipping.

## 2. Capability uplift (with vs without)

For each `capability` scenario:

1. **Without skill:** run the scenario in a clean session, no `flutter` skill loaded.
   Capture the answer.
2. **With skill:** run the same prompt with the `flutter` skill loaded.
3. Grade both answers against the scenario's `must_include` checklist — one point per
   bullet that is concretely present (not just gestured at).
4. Use 3 trials each side; average the coverage.

Pass conditions:
- **With** the skill: `must_include` coverage **≥ 80%**.
- The skill produces a **measurable uplift**: with-skill coverage should beat without-skill
  by a clear margin (target **≥ +25 percentage points**). If a baseline model already
  scores high without the skill, the scenario is too easy — tighten `must_include`.

## 3. Reporting

Record per prompt: fire rate, trials, pass/fail. Per scenario: with/without coverage and
delta. The harness passes overall when triggering ≥ 90% on both sets **and** every
capability scenario clears the 80% bar with positive uplift.

## Counts

- `should_trigger`: 7
- `should_not_trigger`: 6
- `capability`: 2
