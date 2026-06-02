# reporting — evals

These cases are run by the skill-eval harness, not by a bundled scorer here. `should_trigger` and
`should_not_trigger` check routing: each `should_trigger` prompt should select this skill (read the
`why` to see what makes it reporting, including the non-obvious "stale Monday email" case and the
Spanish/Catalan phrasings), and each `should_not_trigger` prompt should route to the named real
sibling (`route_to`) instead of being absorbed here — the boundaries against dashboard, kpi-framework,
analytics, forecasting, data-cleaning, and automation-flows are the whole point. The single
`capability` case is rubric-scored by a judge: a passing answer must hit every item in `must_include`
(report contract, template/params separation, pinned render stack, narrative layer, schedule,
freshness + failure gate, and correct routing of out-of-scope asks). There is no automated pass/fail
script — read each `why`/`route_to` and the rubric to grade by hand or feed them to the harness.
