# Evals — testing-web

`cases.yaml` is the trigger-routing and capability spec for this skill. There is no automated runner
bundled here; run it the way you run the rest of the catalog's evals. Feed each `should_trigger` /
`should_not_trigger` prompt to the router and confirm `testing-web` is (or isn't) selected, checking that
declined prompts route to the named sibling. For `capability`, hand the scenario to the agent with this
skill loaded and grade the produced test file against the `must_include` rubric — every item should be
demonstrably present (awaited user-event, role/label queries, boundary-mocked network, async findBy,
real assertions, no internal-detail coupling). The rubric is pass/fail per line; a missing item is a
miss. `scripts/verify.sh` can statically lint the generated test file as a fast pre-check, but it
validates artifact shape, not whether the rubric's intent was met.
