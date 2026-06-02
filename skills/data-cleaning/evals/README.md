# Eval harness — `data-cleaning`

`cases.yaml` is a human/LLM-graded rubric, not an automated runner. It grades two things: **triggering**
(does the skill fire on real messy-data asks and stay quiet on near-misses that belong to a sibling?) and
**capability** (does loading the skill produce a measurably better cleaning pipeline?). The mechanical
check — that the documented validation gate actually rejects a bad row — lives separately in
`scripts/verify.sh`, which these cases do not duplicate.

To run triggering: start a fresh agent with only `data-cleaning` discoverable, paste each `should_trigger`
prompt verbatim, and confirm it reaches for this skill (3–5 trials each, since the decision is stochastic;
pass if it fires in the majority). For each `should_not_trigger`, confirm it does **not** fire and would
plausibly route to the named `route_to` sibling (some siblings may not be built yet — the routing intent is
what's graded). To run capability: give the scenario to a clean agent WITHOUT the skill and again WITH it,
then grade each transcript against the `must_include` list, one point per bullet that is specifically and
correctly covered (not merely name-dropped). WITH should clearly beat WITHOUT. Record trial counts and
per-bullet verdicts so a reviewer can audit; don't report a bare pass/fail.
