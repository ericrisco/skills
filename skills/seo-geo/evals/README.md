# Evals — seo-geo

`cases.yaml` drives two kinds of check. The `should_trigger` / `should_not_trigger`
prompts are routing assertions: run them through the repo's eval harness against this
skill's `description` + triggers and confirm the router selects `seo-geo` for the trigger
set (including the non-obvious GPTBot/robots and dead-FAQ-schema cases and the
Spanish/Catalan prompts) and prefers the named sibling for each near-miss
(`content-engine`, `article-writing`, `performance`, `nextjs`, `accessibility`). The
`capability` case is graded manually or by an LLM judge against its `must_include` rubric:
feed the scenario to an agent loaded with this skill and check the produced audit hits
every rubric line (length-bounded title/meta, answer-first note, valid Article JSON-LD
with no dead type, ≥2 Princeton GEO levers, CWV stated at p75 with a performance handoff,
the AI-bot/robots note, and an explicit handoff statement). There is no automated scorer
in this folder; routing is harness-run, capability is rubric-judged.
