# Eval harness — `spreadsheet-ops`

Two things are graded: **triggering** (does the skill fire on real spreadsheet work and stay quiet on
near-misses that belong to a sibling?) and **capability** (does loading the skill make the produced
script measurably better?). Cases are in `cases.yaml`. They are graded by a human or a driver agent
feeding prompts to a fresh session — not an automated runner. The executable check is
`scripts/verify.sh`, which smoke-tests that generated artifacts actually compile/open and that formulas
use comma arguments; the eval cases here grade judgment, not code.

## Triggering

For each prompt, start a fresh agent with only `spreadsheet-ops` discoverable, paste the prompt
verbatim, and observe whether the agent reaches for this skill. Run 3–5 trials (the decision is
stochastic). `should_trigger` passes if the skill fires in the majority of trials. `should_not_trigger`
passes if it does **not** fire; each names a `route_to` sibling (`data-cleaning`, `data-scraper`,
`automation-flows`, `google-workspace`, `reporting`) — sanity-check the agent would plausibly route
there, though any not-this-skill route still passes the gate. Some routed siblings may not be built in
this collection yet; the routing intent is what's graded. Pass bar: ≥ 90% trigger accuracy across cases.

## Capability

Run the scenario twice — WITHOUT the skill (clean agent) and WITH it — and grade each transcript against
the `must_include` checklist, one point per bullet that is specifically and correctly covered (not just
name-dropped). WITH the skill should cover ≥ 80% of bullets and clearly beat WITHOUT (target ≥ +30
points or crossing fail→pass). If the script the WITH-skill agent emits is real, run it through
`scripts/verify.sh` to confirm the comma-args and compile bullets objectively.

## Notes

Prompts are deliberately varied: several never say "spreadsheet" (the #VALUE! SUMIFS repair, the blank
openpyxl cell, the service-account PermissionError), and one is in Spanish — these test intent over
keywords. Record trial counts and per-bullet verdicts so a reviewer can audit; don't report a bare
pass/fail.
