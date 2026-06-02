# Eval harness — `sql`

These cases are hand-graded prompts, not an automated test suite. Run them through an agent harness and grade honestly.

**Triggering.** For each prompt in `cases.yaml`, start a fresh agent session with only the `sql` skill discoverable, paste the prompt verbatim, and run 3–5 trials (the decision is stochastic). A `should_trigger` case passes if the skill fires in the majority of trials; a `should_not_trigger` case passes if it stays quiet and the agent would plausibly route to the named `route_to` sibling (or `none`). Aim for ≥ 90% trigger accuracy across all cases — the near-misses (indexing, MySQL config, ORM builder, migrations, ClickHouse) deliberately share vocabulary with this skill, so they test intent, not keywords.

**Capability.** Run each `capability` scenario twice — once WITHOUT the skill (clean agent) and once WITH it loaded — and score each transcript against its `must_include` rubric, one point per bullet that is specifically and correctly covered (not merely name-dropped). The skill passes if WITH-coverage reaches ≥ 80% of the bullets and clearly beats WITHOUT (target ≥ +30 points or fail→pass). If a baseline agent already nails the rubric, tighten it.

**Artifact check.** `scripts/verify.sh` lints emitted `.sql` files heuristically (read-only, no DB connection); it complements the capability eval but does not replace it. Record trial counts and per-bullet verdicts so a reviewer can audit.
