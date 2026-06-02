# Weekly status report — template + worked example

A status report is a **view** of the milestone file, not a second copy. It surfaces what changed since last week, what is at risk, and what needs a decision. Scannable in under 2 minutes; written in under 15.

## Fill-in template

```markdown
## Status — <project> — week of <YYYY-MM-DD>
**Overall: <GREEN|AMBER|RED>** — <one line: the single most important fact, lead with any slip>

### Hit this week
- <Mn milestone name> (<@owner>) — done, <what proves it>
- ...

### Next steps
- <Mn milestone name> — <@owner> — due <YYYY-MM-DD> [<+N days if changed>]
- ...

### Blockers / escalations
- <Mn>: <what is blocking> (<risk|issue|dependency>). Mitigation: <action>. <Decision needed? who/by when, or "none">
- ...

### RAID changes
- New <RISK|ASSUMPTION|ISSUE|DEPENDENCY>: <desc> (owner <@x>, review <date>)
- Moved <RISK → ISSUE>: <what materialized>
- Closed: <item> — <why>
```

## Honesty rule (audited by verify.sh)

Every report names **at least one non-green item with a mitigation**, OR states **"all green"** explicitly. A report with no non-green item and no explicit all-green claim is treated as untracked. If a milestone slipped, the overall line leads with it and the recovery plan — never bury a slip under accomplishments.

## Worked Good example

```markdown
## Status — Pricing launch — week of 2026-06-02
**Overall: AMBER** — M2 (page build) slipped 3 days; recovery in place, end date 2026-06-24 holds.

### Hit this week
- M1 Pricing copy approved (@ana) — done, final copy signed off in the shared doc.

### Next steps
- M2 Pricing page built — @ben — due 2026-06-18 (was 06-15; +3 days)
- M3 Page live in prod — @ben — due 2026-06-24

### Blockers / escalations
- M2: design assets landed 2 days late (dependency on the design team). Mitigation: @ben ships a reduced v1 hero, full hero in a fast-follow. Decision needed: none.

### RAID changes
- New RISK: analytics tag may not fire behind the prod CDN — likelihood med, impact high (no launch data). Owner @ben, review 2026-06-16.
- Moved RISK → ISSUE: staging deploy is flaky and now blocks M2 testing — owner @ben, action today.
```

## Artifact column contract

The milestone file `verify.sh` lints (markdown table or CSV with this header):

```
id | milestone | owner | target | status | done_test | depends_on
```

- `id` — unique, stable (e.g. `M1`, `M2`).
- `milestone` — the checkpoint name.
- `owner` — exactly one `@handle`.
- `target` — ISO date `YYYY-MM-DD`.
- `status` — one of `green | amber | red | done`.
- `done_test` — non-empty, binary/verifiable.
- `depends_on` — comma-separated ids that exist in this file (or empty).
