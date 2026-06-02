# Evals — replicate

`cases.yaml` is a trigger/routing and capability rubric, not an executable test of the Replicate API.
`should_trigger` lists prompts (with a non-obvious symptom and a Spanish one) that must route here;
`should_not_trigger` lists near-miss prompts that must route to a named sibling (`replicate-images`,
`modal`, `runpod`, `webhooks`, `cost-tracking`) so the boundary stays sharp. The `capability` case is
a scored rubric: feed the scenario to an agent loaded with this skill and check the response covers
every `must_include` item. Run it through whatever eval harness scores the skills repo; no Replicate
token, GPU, or network call is required to grade these.
