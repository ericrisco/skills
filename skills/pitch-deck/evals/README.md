# Evals — pitch-deck

These cases check two things: that the skill's description/triggers ROUTE correctly, and that the SKILL.md
content contract actually holds. Run them with the repo's eval harness if one is wired up, or read-and-judge
manually. `should_trigger` prompts must select `pitch-deck` (they include non-obvious cases — a narrative
diagnosis, a story-tightening, a market-slide judgment call — plus a Spanish trigger). `should_not_trigger`
prompts must route to the named real sibling instead (`presentations` for rendering/sales decks,
`financial-model` for the projection spreadsheet, `investor-materials` for the one-pager/data room,
`unit-economics` for the CAC/LTV health check, `fundraising` for the raise process). The `capability` cases are
graded against their `must_include` rubric: a correct response produces a ~10-slide + ask outline in
risk-evaluation order, shows the growth SHAPE on traction, names amount + use-of-funds + milestone on the ask,
sizes the market bottom-up, respects the stage, defers rendering and modeling to the right siblings, and stays
within the ~15-slide discipline. The mechanical slide-structure subset (required slides, count, ask + traction
numbers, buzzwords) is enforced by `../scripts/verify.sh` against a deck outline; narrative quality is judged
here, not by grep.
