# Month-close — the 5-day sequenced checklist

The detail behind the close section of `SKILL.md`. Close is a sequence, not an event. Target: ≤5 days for a small business. Reconcile early so day-5 surprises have nowhere to hide.

## Day-by-day gates with done-criteria

Each gate has a concrete "done when" — the close artifact marks each one `done` or `blocked` (with a reason). A silently-missing gate is a failure, not a pass.

### Day 1–2 — Transaction cleanup + bank/card reconciliation
- Pull all bank and card statements for the period.
- Run the reconciliation tiers (see `reconciliation.md`).
- **Done when:** every account reconciled and the reconciliation report has **zero orphans** (every line matched / unmatched / needs-review). Any unmatched line has an owner and a next action.

### Day 3 — Payroll & journal entries
- Confirm payroll for the period is run and the payroll journal is posted.
- Confirm recurring journals (accruals, prepaids, depreciation) are posted.
- **These postings belong to `bookkeeping`** — finance-ops *verifies* they landed; it does not create them.
- **Done when:** payroll + all recurring journals confirmed posted; any missing one is `blocked` with the owner named.

### Day 4 — AR/AP review + expense categorization
- Review AR aging (from `invoicing`): who's overdue, what's collectible, what to write off.
- Review AP: what's due, what to delay (feed this into the forecast).
- Categorize the period's spend against tax-return lines.
- **Done when:** aging reviewed, no spend left in "Other expenses", contractors crossing the 1099-NEC ≥$600 threshold flagged.

### Day 5 — Reporting + final close
- Assemble the close package (below).
- Lock the period so no back-dated entries land silently.
- **Done when:** package assembled and reviewed, period locked, next month's forecast rolled forward one week.

## The close package contents

What "closed" produces — hand this to whoever needs the monthly read:

1. **Reconciliation report** for every bank/card account (matched / unmatched / needs-review, zero orphans).
2. **The refreshed 13-week forecast** with the just-closed week's actuals folded in and a new week 13 added.
3. **Burn and runway** for the closed month, computed from actual cash.
4. **Expense summary by tax-return category** (no "Other" junk drawer).
5. **AR/AP snapshot** — overdue collections, upcoming payables, anything to write off.
6. **The close checklist itself** — every gate marked `done` or `blocked` with reasons.

## Close checklist artifact shape

`verify.sh` checks the checklist has every required gate present and marked. Minimal shape:

```csv
gate,day,status,note
transaction_cleanup,1,done,
bank_reconciliation,2,done,zero orphans
payroll_journals,3,done,posted by bookkeeping
recurring_journals,3,blocked,depreciation entry pending
ar_ap_review,4,done,
expense_categorization,4,done,no Other
reporting_final_close,5,done,period locked
```

Rules:
- Every required gate row is present — a missing gate is treated as a failure, not an implicit pass.
- `status` is `done` or `blocked`; a `blocked` gate must carry a `note` saying why and who owns it.
