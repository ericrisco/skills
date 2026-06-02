# Evals — investor-materials

`cases.yaml` is read by the repo's skill-eval harness. `should_trigger` and
`should_not_trigger` measure routing precision: each `should_trigger` prompt must load
`investor-materials`, and each `should_not_trigger` prompt must instead route to the named
sibling (`pitch-deck`, `financial-model`, `fundraising`, `cold-outreach`, `unit-economics`) —
they encode the boundaries between packaging documents and building the story, the numbers, or
the round. The `capability` case is a scenario scored by a judge model against its `must_include`
rubric: it feeds the prompt, lets the skill generate the data-room index / one-pager / update
bundle, and checks the rubric points are met (8 numbered categories, the dated/versioned naming
example, the 7 one-pager blocks with a specific ask, the 6 update sections with a metrics table
and named asks, and correct routing of deck/model work to siblings). Run it through the
repository's standard eval command (see the repo root). The structural lint in
`../scripts/verify.sh` is complementary — it checks the generated artifacts mechanically; the
capability eval judges framing and metric selection, which the script deliberately does not.
