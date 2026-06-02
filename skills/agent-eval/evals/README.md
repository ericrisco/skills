# Evals for agent-eval

`cases.yaml` is the trigger and capability spec for this skill. It is read by the catalog's
skill-eval harness, not by a standalone runner here. `should_trigger` lists prompts the skill
must claim (including non-obvious and Spanish phrasings); `should_not_trigger` lists prompts
that must route to a named sibling instead; `capability` is a rubric a graded run must satisfy.

To check by hand: read each `should_trigger` prompt and confirm the description in `SKILL.md`
would plausibly fire on it; read each `should_not_trigger` prompt and confirm the `route_to`
sibling is the better home and is a real catalog id. For the `capability` case, draft the
skill's answer and confirm every `must_include` bullet is covered. If your harness scores these
automatically, point it at this file with `skill: agent-eval` as the key.
