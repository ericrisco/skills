# Evals: api-design

These cases are run by the repository's eval harness against the skill router. `should_trigger` asserts that for each prompt the router selects `api-design`; `should_not_trigger` asserts the named sibling wins instead (each `route_to` is a real catalog id); `capability` is a rubric-graded generation check — the model is asked the scenario and its output is scored against the `must_include` list. Run them with the repo's eval runner pointed at `cases.yaml`; no network or live API is needed.
