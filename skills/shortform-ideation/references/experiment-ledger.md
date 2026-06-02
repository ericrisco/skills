# Reference — the experiment ledger

Phase 4 writes one file per advanced idea so the next ideation cycle learns from the
last instead of re-guessing. The ledger lives under
`02-DOCS/shortform/experiments/` and is read back in Phase 1.

## File layout

One markdown file per bet:

```text
02-DOCS/shortform/
  performance.md                      # the running perf log (Phase 1 reads)
  backlog.md                          # the ranked idea backlog (Phase 3 emits)
  experiments/
    2026-06-01-cafe-markup.md         # <YYYY-MM-DD>-<slug>.md, one per bet
    2026-06-03-grind-myth.md
```

## Hypothesis record schema

```markdown
# SF-007 — "The €4 latte lie" cost breakdown

- **id:** SF-007
- **date:** 2026-06-01
- **topic:** café pricing
- **format:** faceless voiceover
- **trend-signal:** voiceover-receipt format · TikTok→Reels early (<5k Reels) · first-seen 2026-06-01 · 7d↑
- **hook-line:** pour shot + on-screen "your café charges 900% markup"
- **target-length:** 18s
- **score:** 45

## Hypothesis
Trend `voiceover-receipt` + hook `"900% markup"` will lift **3s-hold above 60%**
for topic `café pricing` (vs our ~48% account baseline).

## Result  <!-- fill after it runs -->
- result: pending
- posted-url: __
- 3s-hold: __
- hook-rate: __
- shares: __
- saves: __
- watch-time/length: __
- verdict: __   <!-- confirmed | falsified | inconclusive -->
- learning: __  <!-- one line the next cycle inherits -->
```

**Rules:**

- The **hypothesis is one falsifiable sentence** with a named metric and threshold.
  "Will do well" is not a hypothesis; "will lift 3s-hold above 60%" is.
- **Result fields ship as `pending`,** never omitted — an absent result field is how
  a ledger silently rots. The structure must show the gap waiting to be filled.
- The **trend-signal carries its first-seen date,** copied from Phase 2.

## Worked before → after

**Before (the bet, 2026-06-01):**

> Hypothesis: `voiceover-receipt` + `"900% markup"` will lift 3s-hold above 60% for
> café pricing. Result: pending.

**After (filled 2026-06-05):**

> 3s-hold: 71% · hook-rate: 34% · shares: 220 · saves: 480 · watch-time/length: 0.82
> · verdict: **confirmed** · learning: *receipt/number hooks beat lifestyle hooks for
> this account; promote `number-reveal` to a winning hook pattern in performance.md.*

That `learning` line is the payload. In the next cycle's Phase 1, `number-reveal`
now scores higher on **Hook strength** and **On-account fit**, and the ledger has
done its only job: making the next batch smarter than the last.

## CSV alternative

If the account prefers one flat file over per-bet markdown, use
`02-DOCS/shortform/experiments.csv` with columns:

```text
id,date,topic,format,trend_signal,trend_first_seen,hook_line,target_len,score,result,three_s_hold,hook_rate,shares,saves,verdict,learning
```

Same fields, same rule: a row is created at bet-time with `result=pending` and the
result columns blank, then updated after the video runs.
