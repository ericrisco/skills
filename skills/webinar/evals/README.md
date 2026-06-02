# Evals — webinar

These cases are run by the catalog's eval harness, not a standalone script. The
`should_trigger` and `should_not_trigger` prompts validate that the description routes
correctly — webinar should fire on offer-first planning, show-up/no-sale diagnosis, the
reminder cadence, and the permission-transition question (incl. the Spanish phrasing),
and should hand off cleanly to presentations (slide visuals), landing-copy (page words),
newsletter (recurring program), lead-gen (list sourcing), and sales-pipeline (working
deals). The single `capability` case checks the body actually produces a complete
offer-first funnel plan: offer-before-tactics, registrant-anchored math, the 4-week
promotion + reminder + SMS levers, a run-of-show with the permission transition, the
segmented 0–72h follow-up, a platform pick sized to the audience, and the hand-offs.
Run it through whatever harness loads `cases.yaml`; there is no checkable artifact, so
there is no `verify.sh` — webinar is a process skill and its rigor is the capability rubric.
