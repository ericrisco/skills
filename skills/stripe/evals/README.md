# Evals — stripe

`cases.yaml` holds three groups scored by an LLM judge against the rendered
skill. `should_trigger` and `should_not_trigger` check routing: each prompt is
classified and we confirm Stripe owns it (or that it correctly defers to the
named sibling — `route_to` ids are real skills). `capability` checks that the
SKILL.md plus `references/` actually contain enough to satisfy the `must_include`
rubric for a subscription-paywall build. Run these through the repo's eval runner
(it discovers `evals/cases.yaml` under each skill); there is no standalone
harness here. Treat a judge miss as a prompt to sharpen the description's
triggers/boundary or to fill a gap in the body, not as noise.
