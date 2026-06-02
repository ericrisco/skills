# Evals — railway

`cases.yaml` holds three buckets. `should_trigger` lists prompts (with a `why`) where an agent
should reach for this skill, including non-obvious symptom phrasings (a 502 that never says
"bind") and Spanish phrasings. `should_not_trigger` lists nearby prompts that must route to a
real sibling (`render`, `fly-io`, `db-migrations`, `domains-dns`, `coolify`) with the routing
reason. `capability` is an end-to-end scenario with a `must_include` rubric.

There is no automated runner here. Evaluate by judgment or with your harness: feed each
`should_trigger` / `should_not_trigger` prompt to a router and check the selection matches; for
`capability`, have the agent produce a plan and check every `must_include` bullet is satisfied
(uses the real CLI flow, references `${{Postgres.DATABASE_URL}}`, binds `0.0.0.0:$PORT`, sets
`healthcheckPath`, and invents no fake commands). To sanity-check the emitted config artifact,
run `bash ../scripts/verify.sh` from a dir containing a `railway.json`.
