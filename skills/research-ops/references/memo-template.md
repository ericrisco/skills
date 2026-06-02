# Memo template — skeleton + provenance grammar

This is the contract `scripts/verify.sh` checks against. Keep the section headings and the
provenance line shape, and the gate passes.

## Provenance line grammar

Every finding line carries one of these shapes:

```text
<CLAIM> — [Source title](https://url), pub 2026-04-12 / accessed 2026-06-02 · confidence: high
<CLAIM> — corroborated by [A](https://a, 2026-03-01) and [B](https://b, 2026-05-10) · confidence: high
<CLAIM> — [Source](https://url), pub n/a / accessed 2026-06-02 · confidence: low
```

Rules:

- A **citation token** is required on every finding: a Markdown link or an explicit URL.
- A **date** is required: `pub YYYY-MM-DD`, `accessed YYYY-MM-DD`, or both. If the source
  has no publication date, write `pub n/a` and keep the access date — don't drop the date
  field entirely.
- A **confidence tier** token is required: `high`, `med`/`medium`, or `low`.
- Triangulated claims name ≥2 independent sources, each with its own date.

## Memo skeleton

```markdown
# Research memo — <question, scoped>

_As of: 2026-06-02 · researcher: <name/agent> · budget: <N searches, M sources read>_

## Answer
<The direct answer, 2–4 sentences. Bottom line up front. If the honest answer is
"it depends", state on what.>

## Findings
- <claim> — [Source title](https://url), pub 2026-04-12 / accessed 2026-06-02 · confidence: high
- <claim, triangulated> — corroborated by [A](https://a, 2026-03-01) and [B](https://b, 2026-05-10) · confidence: high
- <weaker claim> — [Blog](https://url), pub n/a / accessed 2026-06-02 · confidence: low

## Disagreements
- <where sources conflicted; what each said; which you weight higher and why>
- (If none: "No source-level disagreement found across the N sources read.")

## Open questions / could not verify
- <what you could not source>
- <what remains an assumption, flagged as such>
- <what would settle it if someone spent more budget>

## Sources
1. [Source title](https://url) — pub 2026-04-12, accessed 2026-06-02 — <one-line what it is / why trusted>
2. ...
```

## What "good" looks like

- The **Answer** stands alone — a reader who stops there still got the bottom line.
- Every **Findings** line is independently checkable: click the link, see the date, see
  the tier.
- **Disagreements** is never empty silently — either it lists conflicts or it states none
  were found.
- **Open questions** is present even on a confident memo; it's the boundary of the
  evidence, not an admission of failure.
