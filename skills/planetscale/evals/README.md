# Evals — planetscale

`cases.yaml` holds prompt-routing checks and capability rubrics for the repo's eval harness. The
`should_trigger` / `should_not_trigger` entries assert routing: an LLM grader decides whether each
prompt would invoke the planetscale skill, and the `should_not_trigger` cases name the real sibling it
should go to instead (mysql, postgresdb, neon, db-migrations, prisma-orm). The `capability` entry is a
scenario graded against its `must_include` rubric — the model's answer must hit each bullet (dev
branch, branch-scoped DDL, `pscale deploy-request create`/`diff`, Online DDL shadow-copy/cutover,
auto-apply vs manual apply, the ~30-minute revert window and its carve-outs, and a no-FK table design).
No live PlanetScale account, `pscale` CLI, or database is needed — everything is graded from the model's
text. Run it through the repo's standard eval runner against this directory.
