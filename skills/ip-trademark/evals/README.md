# Evals — ip-trademark

These cases are routing and coverage checks, not a graded automated harness.
To run them, prompt the model with each `should_trigger` prompt and confirm
`ip-trademark` fires (and produces triage, not a drafted clause); prompt it with
each `should_not_trigger` prompt and confirm it declines and routes to the named
sibling (`contracts`, `brand-identity`, `terms-conditions`, `gdpr-privacy`,
`compliance`). For the `capability` scenario, run it once and score the answer
by hand against the `must_include` rubric — every bullet should be present. No
score is stored; this is a manual sanity pass on triage quality and boundaries.
