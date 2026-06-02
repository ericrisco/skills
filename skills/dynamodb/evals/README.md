# Evals — dynamodb

These cases are graded by judgment, not an automated harness. Feed each `should_trigger` and
`should_not_trigger` prompt to the skill router and confirm it routes to `dynamodb` (or, for the negatives,
to the named `route_to` sibling). For the `capability` case, give the scenario to the skill and check the
answer hits every item in `must_include` — most importantly that it enumerates access patterns before keys,
serves every lookup with a key or GSI (never a Scan), and never falls back to relational joins. The
separate `scripts/verify.sh` mechanically checks a key-design artifact; this YAML checks reasoning.
