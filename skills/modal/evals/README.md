# Eval harness — `modal` skill

These cases are run by an **agent harness** (an LLM agent with the skill catalog available for
routing), not a plain shell script. `cases.yaml` is the fixture; this file is the procedure.
No Modal account or credentials are needed — every check is about *routing* and the *generated
code rubric*, not live execution against Modal.

## 1. Triggering accuracy

Load only the skill descriptions (this `modal` one plus the bare names of routing siblings:
replicate, runpod, fastapi, docker, python, llm-pipeline), not the bodies. For each prompt in
`should_trigger` / `should_not_trigger`, ask which skill the agent would invoke, running 3–5
trials per prompt. `should_trigger` passes if `modal` wins the majority; `should_not_trigger`
passes if `modal` does **not** fire (bonus if it routes to the named `route_to` sibling). Pass
bar: ≥90% of prompts, and no near-miss may fire `modal` in a majority of its trials. The
Catalan/Spanish and the `gpu=modal.gpu.A100()` prompts are the ones to watch for flakiness.

## 2. Capability uplift (with vs without)

For each `capability` scenario, run the agent twice — once with no `modal` skill loaded, once
with it fully loaded — and grade each output against the scenario's `must_include` checklist
(a point counts only if genuinely correct, not merely mentioned). Pass bar: WITH-skill
coverage ≥80% of the rubric, and WITH must clearly beat WITHOUT. The load-bearing points are
the string GPU form, `Volume.from_name(create_if_missing=True)` with commit/reload, correct
web-decorator stack order under `@app.function`, and `modal deploy` (not `run`) for anything
persistent. Any rubric point the skill never produces is a gap to fix in `SKILL.md`.

This is judgment-based, not byte-exact; record trial counts and the judge (human or model)
alongside results for reproducibility.
