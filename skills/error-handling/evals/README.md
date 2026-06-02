# Evals — error-handling

`cases.yaml` is read by the catalog eval runner. `should_trigger` and
`should_not_trigger` check routing precision: the model should select this skill
for the trigger prompts and route the negatives to the named sibling id instead
(`debug`, `observability`, `api-design`, `monitoring`, `testing-web`) — those ids
are the assertion, so they must be real catalog skills. `capability` is a rubric:
the model designs error handling for the scenario and is scored on whether its
answer covers every `must_include` bullet. To run locally, point the repo's eval
harness at this file (it discovers `skills/*/evals/cases.yaml`); with no harness
wired up, use the cases as a manual checklist — read each prompt cold, confirm the
routing decision, and grade a capability answer against the bullets.
