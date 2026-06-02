# Idea ledger + hypothesis/outcome log — templates and a worked example

Two artifacts, both Markdown, both in `02-DOCS/`. The ledger is rewritten each run (it is
the current shortlist). The log is **append-only** — it is the audit trail and must never
be overwritten.

## Artifact 1 — the idea ledger

Header records the baseline so "outlier signal" and every later hypothesis are anchored.

```markdown
# Idea ledger — <channel> — <YYYY-MM-DD>
Baseline: <N> avg views (from <M> videos, computed YYYY-MM-DD via youtube-api log)

| # | Idea (one sentence) | Fit | Demand | Outlier | Pkg | Ret | Orig | Money | /35 | Verdict | Evidence | AI-flag |
|---|---------------------|-----|--------|---------|-----|-----|------|-------|-----|---------|----------|---------|
```

- Each dimension cell is an integer 1–5.
- `/35` is the sum; `Verdict` is one of `produce` / `improve` / `gray` / `abandon` and must
  match the band (30–35 produce, 24–29 improve, 18–23 gray, <18 abandon).
- `Evidence` carries the outlier links + a search number — never blank for a non-zero demand
  score.
- `AI-flag` = `yes` if the idea leans on AI-generated media (disclosure-label risk), else `-`.

## Artifact 2 — the append-only hypothesis/outcome log

```markdown
# Hypothesis/outcome log — <channel> (APPEND ONLY — never edit a past row)

## <YYYY-MM-DD> — <idea>
- predicted: <X>x baseline
- why: <the mechanism — what makes this beat baseline>
- judge-by: <metric> vs <baseline metric>
- status: pending
```

After publish, **append** below the same entry (do not edit the lines above):

```markdown
### outcome <YYYY-MM-DD>
- actual: <X>x baseline   (views <V> vs baseline <N>)
- CTR: <c>% (channel median <m>%)   retention: <r>% (baseline <b>%)
- verdict: validated | killed | inconclusive
- lesson: <what this changes in the next scoring pass>
```

## Fully worked example

### Ledger (run of 2026-06-02)

```markdown
# Idea ledger — buildwithcode — 2026-06-02
Baseline: 6,250 avg views (from 18 videos, computed 2026-06-02 via youtube-api log)

| # | Idea | Fit | Demand | Outlier | Pkg | Ret | Orig | Money | /35 | Verdict | Evidence | AI-flag |
|---|------|-----|--------|---------|-----|-----|------|-------|-----|---------|----------|---------|
| 1 | I rebuilt my SaaS the way senior devs do | 5 | 4 | 5 | 5 | 4 | 4 | 4 | 31 | produce | 6 outliers 3.4–7.1x; "rebuild" autocomplete + Trends 28d rising | - |
| 2 | My honest thoughts on the new framework | 4 | 2 | 2 | 2 | 3 | 3 | 3 | 19 | gray | 1 outlier 2.1x; flat Trends | - |
| 3 | AI wrote my entire backend — does it work | 4 | 3 | 4 | 4 | 3 | 3 | 2 | 23 | gray | 4 outliers 3.0–5.2x; AI media heavy | yes |
```

Idea 1 clears 30 → promote with a hypothesis. Ideas 2 and 3 sit in the gray band:
re-angle, don't produce as-is. Idea 3 also carries an AI-flag (disclosure-label risk).

### Log entry at promotion

```markdown
## 2026-06-02 — I rebuilt my SaaS the way senior devs do
- predicted: 2.5x baseline
- why: 6 niche outliers all open on the same "I did it wrong for years" stakes in 8s,
  and we own a real refactor with before/after numbers none of them have.
- judge-by: 28-day views vs trailing-10 average (6,250) AND CTR vs channel median (4.1%)
- status: pending
```

### Outcome appended after publish

```markdown
### outcome 2026-07-05
- actual: 3.1x baseline   (views 19,400 vs baseline 6,250)
- CTR: 5.8% (channel median 4.1%)   retention: 47% (baseline 39%)
- verdict: validated
- lesson: the "I did it wrong for years" cold-open beat our usual intro on retention —
  bump Retention-potential weight for ideas that can open on a personal-mistake stake.
```

That lesson is what makes the next run's scoring smarter than this one's. The original
prediction lines are untouched — that is the whole point of append-only.
