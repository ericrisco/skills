# people-ops evals

Run these through the repo's eval harness, which feeds each prompt to the skill
router and grades the result with an LLM. `should_trigger` checks that the listed
prompts route into `people-ops` (including the non-obvious "the offer's signed,
now what?" and the Spanish "plan de onboarding ... para el nuevo fichaje" cases);
`should_not_trigger` checks that adjacent requests route to the named real sibling
instead (`hiring`, `sop-builder`, `contracts`, `gdpr-privacy`) rather than being
swallowed here. The single `capability` case is graded against its `must_include`
rubric — the model must produce an onboarding plan plus a remote-work policy that
keeps paperwork in preboarding, names the manager's moves, carries the
at-will/not-a-contract disclaimer, flags the US-only I-9 clock, and defers the
employment contract to `contracts`. There is no `verify.sh`: this is a
judgment skill, so its rigor lives in this capability eval, not a script.
