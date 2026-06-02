# Evals — structured-extraction

These cases are read by a human or an LLM grader; nothing here runs a model automatically. To check the
skill, eyeball each `should_trigger` prompt against the SKILL.md `description` and confirm the routing
language would pull this skill in — the set deliberately includes a symptom-led, non-obvious case (the
"markdown fence / JSON.parse blows up" prompt, whose real fix is native structured outputs, not fence
stripping) and a Spanish/Catalan case. Then check each `should_not_trigger` prompt routes to the named
sibling instead (`document-processing` for raw text-out, `prompt-engineering` for schema-less prompt craft,
`llm-pipeline` for multi-node/batch, `agent-eval` for offline scoring, `rag` for retrieval, `data-cleaning`
for tabular cleanup) — those are the boundary lines the description must hold. The `capability` case is a
rubric: read it as "could an agent following SKILL.md produce an answer hitting every `must_include` bullet?"
If the body can't satisfy a bullet, fix the body, not the rubric. To statically lint the skill's own example
code (no network, no SDK calls), run `scripts/verify.sh`.
