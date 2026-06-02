# Eval harness — `firebase`

`cases.yaml` is a human/LLM-graded trigger-and-capability set; there is no automated runner in this
folder. To run it, feed each prompt to the routing model with only the `firebase` skill discoverable
and check that `should_trigger` prompts fire it (run 3–5 trials each, since the decision is
stochastic) while `should_not_trigger` prompts stay quiet and would plausibly route to the named
sibling. For each `capability` scenario, run the prompt with and without the skill loaded and grade
the answer against its `must_include` rubric — one point per bullet that is specifically and
correctly covered, not merely name-dropped. The skill passes when triggering is right on the large
majority of cases and the capability answer covers the rubric (and clearly beats the no-skill
baseline). Grade by hand or via the repo's shared eval harness; record trial counts and per-bullet
verdicts so a reviewer can audit.
