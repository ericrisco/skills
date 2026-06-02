# Reference — the composite scoring model + scored-list schema

The full 100-point rubric the SKILL summarizes, plus the CSV schema that `scripts/verify.sh` lints.

## The 100-point split

Single-signal scoring fails; layer three signal families. *(houseofmartech.com / theinsightcollective.com intent-scoring guides, accessed 2026-06-02.)*

| Family | Weight | What it measures |
|---|---|---|
| Fit | ~30 | Match to the ICP firmographics/technographics |
| Engagement | ~50 | Observed behavior (the strongest predictor) |
| Intent | ~20 | Third-party surge on your category |

### Fit (0–30) — example allocation

| Signal | Points |
|---|---|
| Headcount in ICP band | 8 |
| Revenue/funding in ICP band | 6 |
| Region/country in target | 4 |
| Industry/vertical match | 6 |
| Required tech in stack | 6 |

### Engagement (0–50) — example allocation

| Signal | Points |
|---|---|
| Replied to a prior touch | 18 |
| Booked/attended a demo or event | 14 |
| Repeat site visits (pricing/product pages) | 10 |
| Content download / form fill | 8 |

### Intent (0–20) — example allocation

| Signal | Points |
|---|---|
| Third-party intent surge on your category | 12 |
| Active job posting matching the trigger | 5 |
| Recent funding/expansion event | 3 |

## Negative scoring (subtract, do not skip)

Negative signals keep junk out of the A tier. Apply after the positive total.

| Signal | Points |
|---|---|
| Matches a `disqualify if…` ICP rule | −100 (force to bottom / drop) |
| Competitor, current customer, or partner | −100 |
| Personal/free-mail domain only (no business email) | −15 |
| Headcount below the floor | −20 |

## Score decay

Engagement and intent are time-sensitive. Decay them so a 6-month-old signal does not inflate a cold account:

- Engagement/intent signals older than **30 days** → multiply that family's contribution by 0.5.
- Older than **90 days** → contribution = 0 (the signal is stale, re-source the trigger).
- Fit does not decay (firmographics are stable).

## The "intent without fit is noise" gate

Apply this hard rule before tiering: **if Fit < 15 (half of max), cap the total at 74 (tier C) regardless of intent/engagement.** A 10-person company surging on "enterprise CRM" must not reach the A tier on intent alone.

## Tier → SLA map

| Tier | Total | Action | SLA |
|---|---|---|---|
| A | 90–100 | Route to a rep now | First contact within 24h |
| B | 75–89 | Queue for outreach | Within 48h |
| C | 60–74 | Nurture only | No rep time; revisit on new signal |
| (below 60) | <60 | Suppress | Not handed off |

## Scored-list CSV schema (the artifact verify.sh checks)

Every produced list must carry exactly these columns. Header row is required.

```csv
account,contact,source,fit,intent,engagement,total,tier,opt_out
Acme Corp,Dana Lee <dana@acme.com>,apollo:bulk_match 2026-06-02,26,14,46,86,B,source-disclosed
Globex,Sam Ortiz <sam@globex.io>,zoominfo 2026-06-01,29,18,48,95,A,source-disclosed
```

Column rules `verify.sh` enforces:

- `account`, `contact` — non-empty.
- `source` — non-empty provenance string (provider + date, or the export origin).
- `fit`, `intent`, `engagement` — integers ≥ 0; their sum equals `total`.
- `total` — integer 0–100.
- `tier` — `A` (90–100), `B` (75–89), `C` (60–74); the label must match the band.
- `opt_out` — non-empty compliance flag (e.g. `source-disclosed`, `opt-out-ready`); proves the compliance gate ran.

A list missing any of these columns, or with a tier that does not match its score band, or with an empty provenance/compliance cell, is not shippable.
