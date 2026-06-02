# Tools and runners (2026)

This skill is engine- and runner-neutral; this file is the lookup for *which* tool and *how* to make it
run the unsafe-by-default step safely. Versions are current as of 2026-06.

## Versioned vs declarative

- **Versioned** runners replay an ordered list of scripts (V1, V2, …). You write each step; the runner
  tracks which have run. Flyway, Liquibase, Alembic, golang-migrate, drizzle-kit.
- **Declarative** (schema-as-code) tools take your *target* schema and compute the diff to get there.
  Atlas is the main one. You review the planned diff; you do not hand-write each `ALTER`.

Declarative removes drift and hand-written DDL errors, but the *sequencing* in this skill still applies —
a planned diff that drops then re-adds a column, or adds `NOT NULL` in one shot, is still an outage. Read
the plan before you apply it.

## Stack → tool

| Stack / need | Tool | Version (2026-06) | Note |
|---|---|---|---|
| JVM, SQL-first, many DBs | Flyway | 12.6.x (12.6.1, May 2026) | Version-based, 50+ DBs. Redgate dropped the Teams tier in 2025, pushing to Enterprise / Native Connectors. |
| Max format flexibility | Liquibase | current | SQL/XML/YAML/JSON changelogs; most flexible, most verbose. |
| Python / SQLAlchemy | Alembic | 1.18.x (1.18.4, Feb 2026) | Requires Python ≥ 3.10; plugin system since 1.18.0. |
| Go | golang-migrate | current | The Go standard; up/down SQL files. |
| TypeScript / Drizzle | drizzle-kit | current | Runner mechanics in `../../drizzle-orm/SKILL.md`; safety sequence here. |
| Schema-as-code, planned diffs | Atlas | current | Declarative — give it the target, review the diff. |
| Vitess / PlanetScale | branch + deploy request | — | Online DDL built into the workflow; see `../../planetscale/SKILL.md`. |
| Big MySQL `ALTER`, native online DDL can't keep it online | gh-ost or pt-osc | — | See below. |

## Running a statement OUTSIDE the per-migration transaction

`CREATE INDEX CONCURRENTLY` (and `DROP INDEX CONCURRENTLY`, `ALTER TYPE ... ADD VALUE` on older PG)
**cannot run inside a transaction block**, but most runners wrap each migration in `BEGIN/COMMIT` by
default. Opt the offending migration out:

- **Flyway** — name the script with the `B`/`transactional=false` setting, or set
  `flyway.executeInTransaction=false` (per-script via a `-- flyway:` config callback / config file).
- **Alembic** — set `transaction_per_migration` appropriately and, for the autogenerate path, emit the
  statement with `op.execute(...)` after committing; the common pattern is
  `with op.get_context().autocommit_block(): op.execute("CREATE INDEX CONCURRENTLY ...")`.
- **Django** — add `atomic = False` to the `Migration` class (or use `AddIndexConcurrently` from
  `django.contrib.postgres.operations`).
- **Rails** — `disable_ddl_transaction!` in the migration, then `add_index ..., algorithm: :concurrently`.
- **golang-migrate** — split the concurrent statement into its own migration file; migrate runs each file
  without wrapping when the statement requires it (keep one statement per file).
- **drizzle-kit** — generate the SQL, then hand-edit the migration so the concurrent statement stands
  alone; details in `../../drizzle-orm/SKILL.md`.

## gh-ost vs pt-osc (big MySQL ALTER)

Both copy the table into a new shape and swap it in, so a large `ALTER` does not hold a long metadata
lock. They differ in *how* they capture concurrent writes:

| | gh-ost | pt-online-schema-change |
|---|---|---|
| Change capture | Triggerless — reads the binlog | Trigger-based — triggers on the original table |
| Consistency | Eventual (binlog replay) | Strict (synchronous triggers) |
| Write overhead | Lower; no triggers on the hot table | Higher; every write fires a trigger |
| Throttling | Throttles on replica lag; easy pause/resume | Throttles, but triggers can fail to get the metadata lock under heavy concurrency / long transactions |
| Cutover control | Fine-grained, can postpone | Less granular |

**Prefer gh-ost on a very busy master** — triggerless means no write amplification on the hot path, and
the lag-aware throttle plus postponable cutover are easier to operate. Reach for pt-osc when you need
strict synchronous consistency and the write volume is modest enough that trigger overhead and
metadata-lock contention are not a concern.

## CI gate — Squawk

**Squawk** is the standard static linter for Postgres migration SQL. Run it in CI so a bare
`CREATE INDEX`, a one-shot `NOT NULL`, a blocking constraint add, or a column drop fails the PR before
review.

```yaml
# .github/workflows/migrations.yml (excerpt)
- name: Lint migrations
  run: npx squawk@latest migrations/*.sql
```

```toml
# .squawk.toml — example: keep the dangerous rules on, silence ones you handle out of band
[lint]
excluded_rules = []   # start strict; add an id here only with a written reason
# e.g. "prefer-robust-stmts" enforces lock_timeout + CONCURRENTLY patterns
```

`scripts/verify.sh` in this skill runs the same class of static checks (no DB connection) against the
example migrations shipped in these references, so the skill stays self-consistent with what it tells you
to gate on.
