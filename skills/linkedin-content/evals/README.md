# Evals — linkedin-content

These cases are read by the catalog's routing harness (or by hand); there is no
bundled automated scorer. `should_trigger` asserts the SKILL.md description and body
are specific enough that each listed prompt would load `linkedin-content`;
`should_not_trigger` asserts a near-miss prompt routes to the named real sibling
instead (every `route_to` id must exist in the catalog); and `capability` is a
rubric — feed the scenario to an agent with this skill loaded and grade the generated
post against every `must_include` bullet as pass/fail. To sanity-check a *generated*
draft against the mechanical rules separately, run `../scripts/verify.sh path/to/draft.md`
— it is read-only and flags an over-long hook line, an http(s) body link, banned dead
CTAs, and wall-of-text blocks. Judgment (does the hook pull? is the CTA answerable?)
stays with the capability rubric; verify.sh only catches mechanical reach-killers.
