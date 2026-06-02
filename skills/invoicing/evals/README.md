# Evals — invoicing

`cases.yaml` holds the routing and capability checks for this skill. There is no automated runner bundled here: load `cases.yaml` and judge each case with an LLM (or by hand). For `should_trigger`, confirm a router given the prompt would reach for `invoicing`; for `should_not_trigger`, confirm it routes to the named sibling instead (each `route_to` is a real catalog id). For the `capability` case, have the agent produce the artifact and score it against every line in `must_include` — all items must be present to pass.

To check the artifact-validation side, run `scripts/verify.sh` against an invoice JSON payload (it ships with a clean sample fixture and a deliberately broken one); see that file's header for usage. It lints the mandatory-field set and the number sequence and is read-only.
