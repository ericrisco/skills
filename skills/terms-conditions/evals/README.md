# Evals — terms-conditions

`cases.yaml` is run by the repo's skill-eval harness. The `should_trigger` and
`should_not_trigger` prompts test the frontmatter `description`: each trigger
should select this skill, and each near-miss should route to the named real
sibling (`contracts`, `gdpr-privacy`, `e-signature`, `ip-trademark`,
`compliance`) instead. The `capability` case is graded against the SKILL.md body
— a model given the scenario should produce a draft hitting every `must_include`
rubric item. No network, fixtures, or credentials are needed; point the harness
at this directory and read the pass/fail per case.

To smoke-test the drafting lint separately, run `scripts/verify.sh <path>`
against a generated document — it flags archaic legalese and, for a full ToS,
missing governing-law / liability / attorney-review sections.
