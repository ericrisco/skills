# Evals — kpi-framework

These are LLM-graded prompts, not an automated test suite; no scorer ships with the skill.
Run them through the repo's eval harness, or paste each prompt into a fresh agent with this
skill available. For `should_trigger`, confirm the agent loads `kpi-framework`; for
`should_not_trigger`, confirm it routes to the named sibling skill instead of loading this
one. For the `capability` case, run the scenario and read the produced metric definition doc
against every `must_include` bullet — a pass hits all of them (one rate-based north star,
3-5 concrete leading inputs, a named guardrail, a baselined target with date + owner, an
explicit vanity-metric rejection, and the analytics/dashboard handoff). Grading is by
inspection against that rubric.
