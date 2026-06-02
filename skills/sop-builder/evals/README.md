# Evals — sop-builder

These cases are run by the catalog's eval harness (or read by hand) to check two
things. First, that the `description` triggers on real process-documentation asks
— including the non-obvious bus-factor symptom and the Spanish phrasing — while
routing meeting-decision, project-plan, help-doc, automation, and single-hire
onboarding asks to the correct sibling (`meeting-notes`, `project-ops`,
`technical-writing`, `automation-flows`, `people-ops`). Second, the `capability`
case is a rubric checked by human or model judgment, not an automated assertion:
feed the messy lead-triage transcript and confirm the produced SOP hits the right
altitude, names an owner and review date, writes the two branches and the
exception, uses active one-action-per-step phrasing, includes a change-log stub,
and does not invent steps the source never showed. There is no `verify.sh` — the
output is a written procedure, so rigor lives in this capability rubric.
