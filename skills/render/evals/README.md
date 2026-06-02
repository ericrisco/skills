# render evals

These cases are routing-and-capability fixtures, not an automated test runner. Feed
`cases.yaml` through the repo's eval harness, which uses an LLM judge. `should_trigger`
and `should_not_trigger` check that the SKILL.md `description` routes the right prompts in
(Render deploys, render.yaml authoring, the port/502/cron/free-tier traps) and the wrong
ones out to the named sibling (`fly-io`, `docker`, `deployment`, `postgresdb`,
`domains-dns`). The `capability` case is graded against its `must_include` rubric to confirm
the SKILL.md body actually produces a correct, trap-free `render.yaml` — right service
types, `0.0.0.0:$PORT` binding, referenced (not hardcoded) env vars, and the cron/Postgres
warnings. There is nothing to `npm test` here; the judge reads SKILL.md and scores the
output against the rubric.
