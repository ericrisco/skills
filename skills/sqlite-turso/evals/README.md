# Eval harness — `sqlite-turso`

Two things get checked: **triggering** (does the skill fire on real SQLite/Turso situations and stay
quiet on near-misses that belong to a sibling?) and **capability** (does loading it measurably
improve the answer?). Cases live in `cases.yaml`. These run through an agent harness, not a pure
shell script — a human or driver agent feeds each prompt and grades the output.

**Triggering.** For each prompt, start a fresh session with only `sqlite-turso` discoverable, paste
the prompt verbatim, run 3–5 trials (the decision is stochastic). `should_trigger` passes if the
skill fires in the majority of trials; `should_not_trigger` passes if it does not fire — and when a
`route_to` is named (drizzle-orm, db-migrations, postgresdb, neon, vector-db), sanity-check the agent
would plausibly route there. Pass bar: ~90% accuracy across all trigger cases.

**Capability.** Run the scenario twice — once WITHOUT the skill, once WITH — and grade each
transcript against the `must_include` checklist, one point per bullet genuinely covered (not just
name-dropped). Pass bar: WITH the skill covers ≥80% of bullets and clearly beats WITHOUT.

**verify.sh spot-check (separate, deterministic).** `scripts/verify.sh` is a static, read-only,
no-network gate for generated connection files. Sanity-check it by hand: a file with `createClient` +
`syncUrl` + a local `file:` url + an env-var token should pass; flip the token to a string literal,
drop the `file:` url, or call `sync()` patterns on a remote-only client and confirm it FAILs. Running
it against an empty directory must print nothing actionable and exit 0.

Record trial counts and per-bullet verdicts so a reviewer can audit; don't report a bare pass/fail.
