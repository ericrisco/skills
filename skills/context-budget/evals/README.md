# Evals: context-budget

`cases.yaml` is read by the repo's eval runner. The `should_trigger` and `should_not_trigger`
sets check routing: each `should_trigger` prompt should select this skill, and each
`should_not_trigger` near-miss should route to the named sibling (`route_to`) instead — those
boundaries against `cost-tracking`, `rag`, `parallel`, and `prompt-engineering` are the ones
that actually get confused. The single `capability` case is a rubric-graded scenario: an agent
facing an ~85%-full window must pick the right moves (offload + compact early), write a resumable
handoff, and isolate the read-heavy step to a subagent; grade its response against `must_include`
with an LLM judge or a human. This is a process skill, so there is no `verify.sh` to run — the
rigor lives in the capability rubric, not a script.
