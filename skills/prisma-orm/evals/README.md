# Evals — prisma-orm

These cases are graded by an LLM against `cases.yaml`, run through the repo's standard eval
harness (point it at this skill id). `should_trigger` and `should_not_trigger` check routing —
that Prisma-specific prompts land here and that Drizzle, cross-cutting migration strategy,
Postgres-server tuning, raw-SQL authoring, and managed-DB platform prompts route to the named
sibling instead. The `capability` case is scored against its `must_include` rubric: a correct
answer must produce a v7-correct setup (the `prisma-client` generator with `output`, a driver
adapter on the constructor, connection in `prisma.config.ts`) and an N+1-safe, bounded query
(`select` + `take` + `relationLoadStrategy: "join"`, FK indexed) plus the right dev/CI migrate
commands. There is no DB connection in any case; `scripts/verify.sh` covers the static-artifact
checks separately.
