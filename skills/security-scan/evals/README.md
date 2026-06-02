# Evals — security-scan

`cases.yaml` holds two kinds of checks, run by the skill eval harness — no live
scanners are invoked. `should_trigger` / `should_not_trigger` are routing cases:
each prompt asserts whether this skill should fire, and every negative names the
real sibling it belongs to (`secure-coding`, `code-review`, `review`, `verify`).
The `capability` case is a rubric: given the monorepo scenario, the agent's plan
is graded against the `must_include` list (correct tool per ecosystem, history
secret scan, SARIF merge + dedupe, exploitability ranking, the
`security-scan-report.json` artifact, scanner pinning, rotate-then-scrub, and
read-only default). Score the routing cases as pass/fail on the trigger decision
and the capability case by how many rubric items the plan covers. The
`scripts/verify.sh` gate is exercised separately by pointing it at a sample
`security-scan-report.json`.
