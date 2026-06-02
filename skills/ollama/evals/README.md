# Evals for the `ollama` skill

`cases.yaml` is a routing + capability fixture, not an automated test harness. Run it by hand (or feed
it to whatever router you use to dispatch skills): for each `should_trigger` prompt, confirm the router
selects `ollama`; for each `should_not_trigger` prompt, confirm it routes to the named sibling
(`runpod`, `modal`, `huggingface`, `rag`, `prompt-engineering`) and not here. For the `capability`
case, have the skill answer the scenario and check the response covers every bullet in `must_include`.
No models, GPUs, or external services are required — this is purely about whether the skill fires in
the right situations and produces a complete, correct local-Ollama answer.
