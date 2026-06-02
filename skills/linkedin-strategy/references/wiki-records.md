# Wiki records — `02-DOCS/wiki/linkedin/`

The read/write loop's storage. Everything is append-only markdown so future strategy sessions compound instead of restarting from generic advice.

## File layout

```text
02-DOCS/wiki/linkedin/
  positioning.md        # current POV, niche of authority, who-it's-for; updated in place when it shifts
  pillars.md            # the live 3-5 pillars + any KILLED pillars with the date and reason
  decisions/            # one append-only file per decision (preferred), dated filenames
    2026-06-02-distribution-to-founder.md
    2026-09-02-q3-review.md
  what-worked.md        # running log of what specific posts/pillars/formats earned dwell time + engagement
```

A running `decisions.md` log at the root is also accepted instead of `decisions/*.md` — pick one and stay consistent. `verify.sh` checks both shapes.

## Bootstrap (empty/absent dir)

When `02-DOCS/wiki/linkedin/` does not exist, create it with `positioning.md`, `pillars.md`, `decisions/`, and `what-worked.md` before you decide. Seed `positioning.md` with whatever the account already implies (title, current posts) so the first decision has a baseline to react to.

## Decision-record template

Every record carries: a dated heading, a context-read line (what you grounded in), a decision line, the single metric it bets on, and a review date. Missing the metric or the review date means it is not a checkable bet.

```markdown
# 2026-06-02 — <short decision title>

Context read: <what you pulled from the wiki — prior positioning, current pillars,
whether cadence held, top dwell-time performers, SSI trend, killed experiments>.

Decision: <the concrete choice — positioning / pillars / cadence / distribution /
social-selling rhythm, stated so the next session can act on it>.

Bets on metric: <the single steering metric + from -> to + window, e.g.
SSI 48 -> 65 within 90 days, or median dwell time +X%, or inbound DMs/week>.

Review date: <YYYY-MM-DD — when the next session checks whether the bet paid>.
```

## what-worked template

```markdown
## 2026-09-02 review

- Pillar "pipeline reliability" — RISING. 2 carousels in top-3 dwell time. Double down.
- Pillar "founder lessons" — FLAT. Text-only; try carousel format before sunsetting.
- Pillar "industry hot takes" — KILLED. Off-graph topic, suppressed reach. Slot reallocated to reliability.
- Format: carousels ~2.4x dwell vs text on this account. Weight calendar toward them.
- SSI: 48 -> 61 in 90 days. "Engage with insights" dimension moved most.
```

## What `scripts/verify.sh` checks

Read-only, network-free, pure bash + grep. Given `02-DOCS/wiki/linkedin/`:

1. The target directory exists.
2. At least one decision record exists (`decisions/*.md` or a root `decisions.md`).
3. Each record carries a date (`YYYY-MM-DD`), a `Decision:` line, and a named metric/bet field — a record missing the metric is a hard failure (a decision with no metric is an opinion).

A missing or empty target (a fresh presence with no wiki yet) is reported and exits 0 — no false failure. It enforces the compounding loop's integrity, not strategy quality (that is the capability eval).
