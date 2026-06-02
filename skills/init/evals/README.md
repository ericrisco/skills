# Eval harness — `init`

Evaluates the `init` skill (the rsc-skills front door / bootstrapper) on two axes:
**triggering** (does it fire on the right prompts and stay quiet on near-misses) and
**capability** (does loading it measurably improve the agent's answer). Cases live in
`cases.yaml`. These run via an **agent harness**, not a pure shell script — a human or a
driver agent feeds prompts to Claude Code and judges the result against the rubrics.

## What's in `cases.yaml`

- `should_trigger` (7) — prompts that MUST invoke `init`.
- `should_not_trigger` (6) — near-misses that must route elsewhere (`route_to` names the
  correct sibling, or `none`).
- `capability` (2) — scenarios with `must_include` rubrics to grade WITH vs WITHOUT the skill.

## A. Triggering eval

1. Load **only** `init` into the agent (no other rsc skills available, so routing is honest).
2. For each `should_trigger` prompt: open a fresh session, paste the prompt verbatim, and
   record whether `init` activates (the agent should lead with the technical-level question /
   profiling, not jump into building). Run **3–5 trials** per prompt.
3. For each `should_not_trigger` prompt: same procedure, but a **pass** = `init` does NOT fire.
   Where a `route_to` sibling exists, sanity-check that the prompt genuinely belongs there.
4. Score: a prompt passes if the **majority of its trials** go the expected way.

**Pass bar:** ≥ 90% trigger accuracy across all `should_trigger` + `should_not_trigger`
prompts (i.e. at most 1 of the 13 prompts may misbehave).

## B. Capability eval

1. **Without the skill:** fresh session, skill NOT loaded, give the `scenario` prompt. Save output A.
2. **With the skill:** fresh session, `init` loaded, same prompt. Save output B.
3. Grade each output against that scenario's `must_include` points — count points clearly covered.
4. Repeat across **3 trials** per scenario per condition and average the coverage.

**Pass bar:** WITH the skill covers **≥ 80%** of `must_include` points; WITHOUT the skill is
materially lower (target a ≥ 30-point gap). If the skill doesn't measurably beat the baseline,
the skill — or these rubrics — needs work.

## Judging notes (honest caveats)

- This is **LLM-as-judge / human-in-the-loop**, not deterministic. Use a consistent grader
  (same model + rubric) across A/B to keep the comparison fair.
- The headline differentiators for `init`: technical-level question **first**, the L0–L3
  accompaniment dial, writing **only** the profile + decisions log + CLAUDE.md Knowledge-map
  link, and **handing off** scaffolding to `the harness skill` (never doing it itself).
- Watch the key confusable: the built-in `/init` (CLAUDE.md architecture doc generator) is a
  different thing — the rsc `init` does discovery/profiling/recommendation, not codebase docs.
- Run after any edit to `SKILL.md` or its `description`, since both axes are sensitive to wording.
