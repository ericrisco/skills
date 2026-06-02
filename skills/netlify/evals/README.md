# Evals — netlify

`cases.yaml` holds three groups. `should_trigger` are prompts where this skill must fire
(including non-obvious symptom phrasings like SPA-refresh 404s and secrets-scan build failures,
plus a Catalan case). `should_not_trigger` are nearby prompts that belong to a sibling, each
tagged with the `route_to` id that should win instead. `capability` is an end-to-end scenario
with a `must_include` rubric.

There is no automated runner here. To evaluate: feed each `should_trigger` / `should_not_trigger`
prompt to the router and confirm the skill fires (or yields to the named sibling). For the
`capability` case, have the agent produce the artifact and check the output covers every
`must_include` bullet. The structural correctness of an emitted `netlify.toml` is separately
checkable with `../scripts/verify.sh`.
