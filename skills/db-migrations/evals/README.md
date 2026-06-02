# Evals — db-migrations

`cases.yaml` specifies routing and capability expectations, not live database runs. `should_trigger` /
`should_not_trigger` are prompt-routing checks: feed each prompt to the router and confirm db-migrations
fires (or that the named sibling — postgresdb, drizzle-orm, backups, sql, planetscale — wins instead).
The `capability` case is a rubric: ask the model to plan the column rename, then score the response
against the `must_include` bullets (each phase present, in order, with lock_timeout, batched/throttled
backfill, checksum verify, N/N-1, cooling period, forward-only). There is no database connection here;
the DDL-shape and self-consistency check lives in `../scripts/verify.sh`. Run these through the repo's
standard eval harness.
