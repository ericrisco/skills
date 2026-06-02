# Evals — sales-pipeline

`cases.yaml` is run by the rsc eval harness. The `should_trigger` and
`should_not_trigger` prompts test the description router: each should-trigger
prompt must load this skill, and each should-not-trigger prompt must route to
the named real sibling (`forecasting`, `lead-gen`, `cold-outreach`,
`proposals`, `client-onboarding`) instead. The single `capability` case is
graded by a judge against its `must_include` rubric — feed the scenario's 6-row
deal CSV to the skill and check the output hits every rubric line (required-field
gate, stage-owned probabilities, 14d/30d stale decay, weighted forecast,
coverage-vs-quota verdict at the current ~18% win rate, and a lint-able artifact).
No external API or network access is required; everything is local to the model
and the harness.
