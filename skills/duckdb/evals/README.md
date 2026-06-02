# Eval harness — `duckdb`

This checks two things: **triggering** (does the skill fire on real DuckDB situations and stay quiet on
near-misses that belong to a sibling?) and **capability** (does loading the skill measurably improve the
answer?). Cases live in `cases.yaml`. These are graded by a human or a driver agent feeding prompts to a
fresh session — not an automated runner. The executable check is `scripts/verify.sh`, which smoke-tests
that the documented DuckDB commands actually run; the eval cases here grade judgment, not code.

## Triggering

For each prompt: start a fresh agent with only the `duckdb` skill discoverable, paste the prompt verbatim,
and observe whether the agent reaches for DuckDB. Run 3–5 trials (the decision is stochastic).
`should_trigger` passes if DuckDB fires in the majority of trials. `should_not_trigger` passes if it does
**not** fire; each such case names a `route_to` sibling (`clickhouse-analytics`, `postgresdb`, `sql`,
`sqlite-turso`, `vector-db`) — sanity-check the agent would plausibly route there, but any not-duckdb route
still passes this skill's gate. Some routed siblings may not be built in this collection yet; the routing
intent is what's graded. Pass bar: ≥ 90% trigger accuracy across all cases.

## Capability

Run the scenario twice — WITHOUT the skill (clean agent) and WITH it — and grade each transcript against
the `must_include` checklist, one point per bullet that is specifically and correctly covered (not just
name-dropped). WITH the skill should cover ≥ 80% of bullets and clearly beat WITHOUT (target ≥ +30 points
or crossing fail→pass). If a baseline agent already nails it, tighten the rubric.

## Notes

Prompts are deliberately varied: some never say "DuckDB" (slow pandas groupby, out-of-core join,
analyze-a-CSV-without-a-server), and one is in Spanish — these test intent recognition, not keyword
matching. Record trial counts and per-bullet verdicts so a reviewer can audit; don't report a bare
pass/fail.
