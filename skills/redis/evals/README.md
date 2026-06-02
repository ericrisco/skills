# redis — evals

`cases.yaml` holds the routing and capability checks for this skill. `should_trigger` are prompts
that must select `redis` (including the non-obvious lost-EXPIRE race and the `KEYS *` review trigger);
`should_not_trigger` are near-neighbours that must route to a named sibling (`postgresdb`, `vector-db`,
`fly-io`, `nextjs`, `clickhouse-analytics`) so the boundary is exercised, not just the centre. The
`capability` case is a three-bug scenario (stampede + lock + rate limiter) graded against the
`must_include` rubric. There is no automated runner here — feed each prompt to the skill-router under
test and confirm the selection, then judge the capability answer against its rubric by hand (or with an
LLM judge). Keep prompts phrased like a real developer would ask, not as keyword bait.
