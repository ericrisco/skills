# e2e-testing evals

`cases.yaml` holds three groups scored by an LLM judge, not a runtime test of Playwright itself.
`should_trigger` lists prompts where the skill must load (each with a `why`, including the non-obvious
flakiness and strict-mode cases and a Catalan phrasing); `should_not_trigger` lists near-misses that
must route to a real sibling (`route_to`) instead of loading here; `capability` is one end-to-end
scenario with a `must_include` rubric that the judge grades a skill-guided answer against. Run them
through the repo's eval harness, which loads the skill, replays each prompt, and checks routing plus
rubric coverage. Nothing here launches a browser or runs Playwright — that lives in the produced test
suite, which `scripts/verify.sh` statically lints.
