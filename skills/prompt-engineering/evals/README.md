# Evals for prompt-engineering

These cases are illustrative routing and capability checks, not an automated pass/fail
gate. To run them, read `cases.yaml` and judge by hand: for each `should_trigger` prompt,
ask whether this skill's description and body would plausibly fire; for each
`should_not_trigger` prompt, confirm it routes to the named sibling instead. For the
`capability` scenario, draft a real answer and check it hits every `must_include` rubric
item (ordered skeleton, explicit output contract with the strict-vs-JSON-mode note, three
deliberately different few-shot examples, ≥5 inline cases incl. an adversarial one, the
iterate-one-variable note, no banned hedges, and the building-agents pointer). If an
answer misses an item, the skill body — not the case — is what needs fixing.
