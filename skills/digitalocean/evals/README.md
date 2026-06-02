# Evals — digitalocean

`cases.yaml` is a routing + capability fixture, not an auto-runner. To use it: feed each
`should_trigger` prompt to the skill router and confirm `digitalocean` fires; feed each
`should_not_trigger` prompt and confirm it does NOT fire but defers to the named `route_to`
sibling. For the `capability` case, run the scenario through the agent and judge the
resulting transcript against the `must_include` rubric — every item should be present and
correct (doctl auth, an app spec with a service + envs, the DB wired via `${db.*}`/VPC, the
validate→create/update flow, logs + spec-revert rollback, and a cost note). Score it by hand
or with an LLM judge; there is no pass/fail script here.
