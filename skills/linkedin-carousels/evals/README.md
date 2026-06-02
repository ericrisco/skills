# Evals — linkedin-carousels

`cases.yaml` is a routing + capability spec, not an automated test suite. `should_trigger`
lists prompts whose description should route to this skill (including a non-obvious
cover-repair / export-size phrasing and a Spanish/Catalan one); `should_not_trigger` lists
near-miss prompts that must route to a real sibling (`linkedin-content`, `linkedin-strategy`,
`presentations`, `linkedin-api`, `brand-identity`) with the reason. `capability` is a rubric a
grader (human or LLM) applies to an actual produced carousel spec to confirm the skill changes
the output — not just that it loaded. There is no bundled runner: check routing by inspection
(does the description's "Use when" / Triggers / NOT boundary cover each prompt?), or feed the
file to the repo's eval tooling if one is present. To pressure-test capability, run the
scenario and score the result against `must_include`, then optionally lint the produced spec
with `../scripts/verify.sh path/to/spec.md`.
