# Eval harness — `course-storytelling`

This is an **agent-run** eval, not a shell script. You drive a Claude Code agent
(or equivalent) and judge its behaviour against `cases.yaml`. There is no
automated grader here; a human or a judge-agent reads the transcript and scores it.

`cases.yaml` has three blocks: `should_trigger` (6), `should_not_trigger` (5),
and `capability` (2 scenarios with rubrics).

## A. Triggering accuracy

Goal: the skill fires on real teaching-narrative work and stays quiet on near-misses.

1. Load **only** `course-storytelling` into the agent (no sibling skills loaded,
   so a miss can't be masked by another skill picking up the slack).
2. For **each** prompt in `should_trigger` and `should_not_trigger`, start a fresh
   session and paste the prompt verbatim. Run **3–5 trials** per prompt (the
   trigger decision is stochastic).
3. Record per trial:
   - `should_trigger` → PASS if the agent invokes/announces `course-storytelling`.
   - `should_not_trigger` → PASS if it does **not** invoke it. Bonus: it routes to
     the `route_to` sibling named in the case (or correctly declines when `none`).
4. **Pass bar: ≥90% correct decisions** across all trials (both blocks combined).
   Any prompt that fails on a majority of its trials is a real defect — fix the
   SKILL.md description/trigger list, don't loosen the case.

## B. Capability uplift (with vs without)

Goal: the skill **measurably improves** the teaching output, not just fires.

1. For each `capability` scenario, run it **twice**:
   - **WITHOUT** the skill (baseline — agent answers from general knowledge).
   - **WITH** `course-storytelling` loaded.
2. Score each output against that scenario's `must_include` rubric: fraction of
   checkable points actually present.
3. **Pass bar:**
   - WITH the skill: **≥80% of rubric points covered.**
   - The WITH score must **clearly beat** WITHOUT (expect the baseline to skip the
     learner-grounding gate, invent proof, state the insight instead of building an
     epiphany, and end on a summary — all rubric misses).
   - Scenario 2 specifically checks the **hard STOP**: without the skill the agent
     will usually just answer; with it, it must refuse-and-interview first.

## Honesty notes

- Trials are stochastic — report the actual trial counts and pass rates, don't
  round a 2/5 up to "passes".
- A `should_not_trigger` that fires is as much a defect as a `should_trigger` that
  misses; both go in the report.
- If a case is wrong (ambiguous prompt, sibling overlap is genuinely 50/50), fix
  `cases.yaml` and say so — don't quietly grade around it.
- Capability grading is judgement, not grep. The `scripts/verify.sh` in the skill
  only covers the greppable subset (jargon/story/name flags); the rubric here is
  the real bar.
