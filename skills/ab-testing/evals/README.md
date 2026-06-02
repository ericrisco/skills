# Evals — ab-testing

These cases are routing and capability checks for the catalog harness, not an automated test runner.
`should_trigger` and `should_not_trigger` are judged by feeding each prompt to the router and confirming
it lands on `ab-testing` (or, for the negatives, on the named sibling such as `analytics` or
`forecasting`). The single `capability` case is graded by hand or with the catalog's eval script: run the
scenario through the skill and check the produced design/analysis against every line in `must_include` —
a pass needs all of them present, not just most. There is no `pytest` here; the rubric is the spec.
