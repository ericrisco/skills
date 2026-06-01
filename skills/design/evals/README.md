# Eval harness — `design` skill

This is an **agent-run** eval, not a shell script. The cases in `cases.yaml` are fed to a
Claude Code agent and graded by inspection. There is no `pytest` to run; the "harness" is the
procedure below plus a human (or a judge agent) checking outputs against the rubrics.

## What's under test

1. **Triggering** — does the `design` skill activate on the right prompts and stay quiet on
   near-misses that belong to a sibling (`marketing`, `nextjs`, `flutter`) or to nothing in-repo?
2. **Capability** — when it does fire, does the guidance measurably beat an unguided answer?

## A. Triggering accuracy

For each prompt in `should_trigger` and `should_not_trigger`:

1. Start a fresh agent session with **only the `design` skill discoverable** (its `SKILL.md`
   description in the system prompt / skill index). Do not pre-load sibling skills.
2. Paste the prompt verbatim as the user's first message.
3. Observe whether the agent **invokes/loads the `design` skill** (announces it, reads
   `SKILL.md`, or applies its protocol) before answering.
4. Run **3–5 independent trials per prompt** (fresh session each) to average out sampling noise.

Scoring per prompt:
- `should_trigger` → PASS if the skill fires in the **majority** of trials.
- `should_not_trigger` → PASS if the skill **does not** fire in the majority of trials. Bonus:
  the agent routes to the `route_to` target (or correctly declines when `route_to: none`).

**Pass bar:** >= 90% trigger accuracy across all prompts (true-positives + true-negatives over
total). Any `should_not_trigger` that fires in a majority of trials is a hard fail to fix in the
`SKILL.md` description/When-NOT section, even if the aggregate clears 90%.

## B. Capability uplift (with vs without)

For each `capability` scenario:

1. **Without:** fresh session, skill NOT available, give the scenario prompt. Save the answer.
2. **With:** fresh session, `design` skill available and applied, same prompt. Save the answer.
3. Grade both against the scenario's `must_include` points — one point per item, mark
   covered / not covered. Use a second agent as judge or grade by hand.
4. Compute coverage = covered / total `must_include`, for each condition.

**Pass bar:** WITH the skill covers **>= 80%** of `must_include`; WITHOUT it covers materially
less (target a >= 30-point absolute gap). If the gap is small, the skill isn't earning its place —
fix the skill, not the rubric. The brand-grounding STOP and the research-first/CWV/WCAG points are
the high-signal items most likely to be missing without the skill; weight attention there.

## Notes / honesty

- Triggering is inherently stochastic; that's why we average trials and report a percentage, not a
  binary. Re-run if results straddle the bar.
- Keep grading faithful to `SKILL.md` — if a case drifts from the actual description, fix the case.
- These files document intent and a repeatable procedure; they are **not** wired into CI.
