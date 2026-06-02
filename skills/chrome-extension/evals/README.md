# Evals: chrome-extension

`cases.yaml` holds two things. The `should_trigger` / `should_not_trigger`
prompts are routing checks: read each prompt cold and judge whether this skill
(versus the named sibling) should fire — run them by hand or feed them to an
LLM judge against the skill's description. The `capability` case is graded by
handing the scenario to an agent loaded with the skill and checking the output
against every item in `must_include` (a rubric, not a string match). There is no
automated test runner here. The one mechanical check is `scripts/verify.sh
<dir>`, which lint-checks any `manifest.json` the skill produces against the MV3
invariants; it exits 0 when the target has no manifest, so it is safe to run on
an empty directory.
