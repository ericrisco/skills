# Hiring evals

`cases.yaml` holds the trigger / near-miss / capability cases for the `hiring`
skill. There is no automated runner here — score by judgment. For each
`should_trigger` prompt, confirm a router would reach for `hiring`; for each
`should_not_trigger`, confirm it routes to the named sibling instead (the test is
that the boundary holds, not just that hiring is skipped). For the `capability`
case, give the scenario to an agent loaded with `SKILL.md` and check the output
against every `must_include` line — a pass means it produced a split must/nice
post with inclusive language and a 3–6-competency anchored scorecard with an
evidence field and an overall recommendation, stated the independent-scoring
rule, and stayed out of onboarding/payroll. This is a process skill, so the
capability rubric is the rigor; there is no `verify.sh`.
