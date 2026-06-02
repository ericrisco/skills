# RAID buckets, the RAG decision table, and RACI on milestones

## RAID log

Create at project initiation; review at least **weekly and at every phase transition** — phase boundaries are where hidden risks surface and old assumptions break. Keep the four buckets distinct.

| Bucket | Definition | When it moves |
|--------|------------|---------------|
| **Risk** | Might happen; plan a mitigation ahead of time | Becomes an **Issue** when it materializes |
| **Assumption** | Believed true but unverified; a milestone rests on it | Becomes an **Issue** (or new Risk) when it breaks |
| **Issue** | Already happening, needs action now | Closes when resolved |
| **Dependency** | A handoff/relationship that can bottleneck | Often the cross-team `depends_on` edges; closes when the handoff completes |

Each item carries: **description, likelihood, impact/severity, owner, review date.**

### Example rows

```markdown
| type | description | likelihood | impact | owner | review |
|------|-------------|------------|--------|-------|--------|
| RISK | Analytics tag may not fire behind prod CDN | med | high | @ben | 2026-06-16 |
| ASSUMPTION | Design team delivers hero assets by 06-12 | — | high | @ana | 2026-06-12 |
| ISSUE | Staging deploy flaky, blocks M2 testing | — | high | @ben | today |
| DEPENDENCY | Legal sign-off on pricing copy before launch | med | high | @ana | 2026-06-09 |
```

Risk vs Issue is the distinction people get wrong: a **risk is conditional and future** ("the CDN *might* drop the tag"); an **issue is happening now** ("staging *is* broken"). When a risk materializes, move it to Issue rather than leaving a stale risk row.

## RAG + early-warning decision table

Set status by condition, not by feel. Write the reason next to any non-green item.

| Condition | Status | Note |
|-----------|--------|------|
| On or ahead of target; dependencies met; visible progress | `green` | The default only when earned |
| Days of slip accumulating (target shifting later) | `amber` | Trending late — act now |
| A blocking `depends_on` milestone has shifted its date | `amber` | Inherited slip |
| Past ~halfway to target with little visible progress | `amber` | Burn-rate warning |
| Target date missed | `red` | Late, full stop |
| Critically late with no credible recovery plan | `red` | Needs immediate intervention |
| Hard blocker, no owner-driven mitigation | `red` | Escalate |
| `done_test` satisfied and verified | `done` | Stop tracking it |

Two operating rules:
- **Amber fires before the due date**, not on it. The whole value is course-correcting while time remains.
- **All-green is a smell** — on a real project at least one item is usually amber. If everything is truly green, state it explicitly so it is a claim, not a default.

### Worked slippage example

M2 has `target 2026-06-15`. On 2026-06-08 its blocking dependency (design assets) shifts from 06-10 to 06-12. M2 was already at the halfway mark with the page not started → trip **amber** on 06-08, target revised to 06-18 (+3 days). Because M2 sits on the critical path (M1 → M2 → M3 sets the finish date), the project overall goes amber too, and the recovery (reduced v1 hero) protects the 06-24 end date. Had you waited until 06-15 to notice, the only status available would have been red with no time to recover.

## Critical path

The critical path is the **longest chain of `depends_on` edges** — it sets the finish date and has zero buffer. Re-confirm it at every update; the path moves as dates change. Watch **near-critical** chains, since a small slip can promote them onto the critical path. Mark critical milestones in the file (e.g. a `*` after the id or a note) so a reader sees instantly where a slip is fatal.

## RACI on milestones (for teams that want it)

Keep roles unambiguous: each milestone or decision has **exactly one Accountable** and **at least one Responsible**. On a small team one person can be both R and A — that is fine. The failure mode is spreading **A** across people. Set roles during planning and review them at phase transitions. Do not clutter the matrix with admin items like recurring status meetings; RACI is for deliverables, not calendar events.
