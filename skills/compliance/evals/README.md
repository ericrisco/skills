# Evals — compliance

These cases are graded by judgment, not by an automated runner. Feed each
`should_trigger` and `should_not_trigger` prompt to the skill router and confirm
the routing matches: triggers should land on `compliance`, and each
`should_not_trigger` prompt should route to the named sibling (`route_to`). For
the `capability` case, run the scenario through the skill and check the response
covers every item in `must_include` — especially the date-sensitive ones (EU AI
Act 2 Aug 2026 as active vs the not-yet-adopted Omnibus deferral; HIPAA NPRM as
forthcoming-not-law) and the structural ones (a register with owner/evidence/
cadence columns, the 60-70% overlap, a weekly control-health review). The
separate `scripts/verify.sh` mechanically lints a finished control register; run
it against a generated register to confirm no control is missing an owner,
evidence, or cadence.
