# Evals — technical-writing

`cases.yaml` is read by the repo's skill-eval harness. The `should_trigger` and
`should_not_trigger` blocks gauge routing: each `should_trigger` prompt must load
this skill, and each `should_not_trigger` prompt must route to the named sibling
instead — these catch over- and under-triggering against article-writing,
content-engine, translation-l10n, course-storytelling, and brand-voice. The
`capability` block is graded by a model judge against its `must_include` rubric:
the agent is handed the mixed-page scenario and its output is checked for the
Diátaxis split, the rewritten reference table, the removed weasel words, runnable
samples, and the Vale/CI recommendation. Run it with the repo's eval runner over
this directory; there is no separate setup beyond a checkout of the skill.
