# Evals — drizzle-orm

`cases.yaml` is a human/LLM-graded trigger and capability set, not an automated runner. To use it:
read each `should_trigger` prompt and confirm this skill is the right home (especially the
non-obvious "no author relation" and "push vs generate" cases and the Spanish/Catalan ones); read
each `should_not_trigger` prompt and confirm a reasonable router would send it to the named sibling
(`prisma-orm`, `db-migrations`, `postgresdb`, `neon`, `sql`) rather than here. For the `capability`
case, have a model answer the scenario and check it hits every item in `must_include` — relation
defined, `{ schema }`/`{ relations }` passed to `drizzle()`, `with` in the relational query,
`generate`+`migrate` (not `push`), and `$inferSelect`/`$inferInsert` types. The `scripts/verify.sh`
static lint can be run against any code the model produces to catch dialect mismatches, a missing
`{ schema }`/`{ relations }`, and Prisma-ism contamination.
