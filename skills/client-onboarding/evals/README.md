# Evals — client-onboarding

These cases are graded by an LLM against the rubric in `cases.yaml`, run through
the repo's eval harness. The `should_trigger` set (including the non-obvious
"deal is signed, what now" phrasing and the Spanish/Catalan prompts) checks that
the router selects `client-onboarding`. The `should_not_trigger` set checks the
near-miss boundaries route to the named real sibling instead — `customer-support`
for reactive tickets, `retention` for the post-gate lifecycle, `proposals` and
`sales-pipeline` for pre-close work. The single `capability` case grades a full
mid-market onboarding plan against the `must_include` rubric (motion choice,
handoff packet, defined activation event, kickoff + RACI, an owner/date/exit
30/60/90, metrics with a realistic band, and the explicit exit gate handed to
retention). There is no `verify.sh`: this is a judgment skill whose output is a
plan, so the capability rubric carries the rigor.
