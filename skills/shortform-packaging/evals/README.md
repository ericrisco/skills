# Evals — shortform-packaging

These are routing and capability checks, not an automated harness. Run them by hand:
read each `should_trigger` prompt and confirm the skill's Use-when/Triggers fire on it
(including the non-obvious "nobody shares my shorts" and the Spanish/Catalan prompt);
read each `should_not_trigger` prompt and confirm the description's NOT-boundary sends
it to the named `route_to` sibling instead. For the `capability` case, draft a real
package against the scenario and check it hits every `must_include` rubric line — then
run `scripts/verify.sh` on that draft to confirm the structural lint passes. No network,
no fixtures.
