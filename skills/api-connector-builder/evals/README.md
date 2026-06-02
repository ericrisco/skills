# Evals — api-connector-builder

These cases are a hand-run rubric, not an automated test harness; no scoring
script ships. To run them: paste a `should_trigger` prompt into a fresh agent
session and confirm `api-connector-builder` is the skill that fires (and not a
sibling). Paste a `should_not_trigger` prompt and confirm the agent routes to the
named sibling instead. For the `capability` scenario, have the agent build the
connector, then grade the result against the `must_include` list — every bullet
should be satisfied by the code it produces. A connector that hardcodes the token,
retries all 4xx, or stops after one page fails the rubric regardless of how clean
it looks.
