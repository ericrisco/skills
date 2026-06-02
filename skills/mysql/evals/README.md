# Evals — mysql

These cases are routing and capability specs, not an automated test suite. There is no in-repo
trigger harness. To run them, have a human or an LLM judge read `cases.yaml` and check three things:
that each `should_trigger` prompt would plausibly load this skill, that each `should_not_trigger`
prompt routes to the named sibling instead (`sql`, `postgresdb`, `planetscale`, `db-migrations`,
`drizzle-orm` — all real skills), and that an answer to the `capability` scenario hits every bullet
in its `must_include` rubric. The rubric is the bar: a passing answer reads EXPLAIN, fixes the
non-sargable predicate, designs the composite/covering index with correct column order, reasons
about the InnoDB clustered index, and verifies the new plan — without drifting into ORM or platform
workflow that belongs to a sibling. `scripts/verify.sh` is separate: it lints emitted `*.sql` /
`*.cnf` artifacts for the foot-guns in SKILL.md and never connects to a database.
