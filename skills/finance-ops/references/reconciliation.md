# Reconciliation — matching tiers, thresholds, report schema

The detail behind the reconciliation section of `SKILL.md`. Goal: every bank line classified, zero orphans, exceptions surfaced early.

## The matching algorithm

Run the tiers in order. A bank line stops at the first tier that produces a confident match; otherwise it falls through to the next.

### Tier 1 — exact
Match on `amount + date + reference` (or amount + date when no reference). This is the cheap, certain tier and clears the bulk of clean transactions. Auto-matches ~60–70% of volume on its own.

### Tier 2 — fuzzy
For lines exact-match missed, score candidate book entries by string similarity on description/reference, with amount inside a small tolerance.

- Use a normalized similarity (e.g. Levenshtein-ratio or token-set ratio) scaled 0–100.
- **Auto-clear threshold ≈ 85–90.** Why this band: below ~85 you start auto-pairing genuinely different vendors ("ACME LLC" vs "ACME LTD" can be different entities); above ~90 you reject legitimate fee/rounding/description drift ("STRIPE PAYOUT" vs "Stripe payout #4821"). 85–90 is the empirical sweet spot.
- Amount tolerance handles bank fees and FX rounding: allow a few cents or a known fee delta, not arbitrary slack.
- A fuzzy hit **at or above** threshold → matched. **Below** threshold but plausible → needs-review, never silently matched.

### Tier 3 — one-to-many / many-to-one
Handles split payments: one invoice paid in several transfers, or one bank deposit covering several invoices.

- Search for subsets of book entries whose sum equals the bank line (and vice versa) within tolerance.
- A clean sum match can auto-clear; an ambiguous combination → needs-review with the candidate set attached.

Exact + fuzzy + many-to-many together push auto-clear toward ~90%. The remaining ~10% is where a human earns their keep — that's the needs-review pile.

## The four classic gaps

When the bank balance and book balance disagree, the cause is almost always one of these. Resolve them before declaring a discrepancy a real error:

| Gap | Symptom | Resolution |
|---|---|---|
| Outstanding checks | Book shows payment, bank doesn't | Leave as timing diff; clears when check is cashed |
| Deposits in transit | Book shows deposit, bank doesn't yet | Leave as timing diff; clears next statement |
| Bank charges / fees | Bank debit not in books | Route a fee entry to `bookkeeping`; classify line as unmatched-needs-entry |
| Interest earned | Bank credit not in books | Route an interest entry to `bookkeeping` |

## Exception decision table

| Situation | Bucket | Next action |
|---|---|---|
| Exact or fuzzy ≥ threshold | matched | none |
| Clean one-to-many sum | matched | none |
| Fuzzy below threshold, single plausible candidate | needs-review | human confirm/reject |
| No candidate at all, but is a known fee/interest | unmatched | route posting to `bookkeeping` |
| No candidate, unrecognized counterparty | unmatched | investigate before close |
| Duplicate bank line (double charge) | needs-review | dispute / flag to bank |
| Ambiguous split (multiple subsets sum) | needs-review | human pick the right set |

## Report schema

The artifact `verify.sh` checks. Every bank line appears exactly once with a `status` of `matched`, `unmatched`, or `needs-review` — no line may be absent or carry any other status.

```csv
bank_line_id,date,amount,description,status,match_ref,note
B0012,2026-05-03,-1200.00,STRIPE PAYOUT 4821,matched,INV-204,exact
B0013,2026-05-04,-15.00,MONTHLY SERVICE FEE,unmatched,,fee-needs-entry
B0014,2026-05-06,-980.00,ACME,needs-review,INV-198?,fuzzy-72-below-threshold
```

Rules:
- `status` is one of `matched | unmatched | needs-review` — `verify.sh` rejects anything else and rejects a missing status.
- `matched` rows should carry a `match_ref`; the others may leave it blank.
- The three buckets must partition the full bank statement — count of rows in the report equals count of lines on the statement.
