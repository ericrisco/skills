# Chart of accounts — a worked example

The COA is the index of your ledger. Keep it small, numbered by range, and named by what each account *is*. Below is a starter COA for a typical small service business — about 25 accounts. Add to it only when a reporting question forces a split.

## Example numbered COA

### 1000–1999 Assets (normal balance: debit)

| Code | Account |
| --- | --- |
| 1000 | Cash — Operating |
| 1010 | Cash — Savings / Reserve |
| 1100 | Accounts Receivable |
| 1200 | Prepaid Expenses |
| 1500 | Equipment |
| 1510 | Accumulated Depreciation — Equipment (contra) |

### 2000–2999 Liabilities (normal balance: credit)

| Code | Account |
| --- | --- |
| 2000 | Accounts Payable |
| 2100 | Credit Card Payable |
| 2200 | Sales Tax / VAT Payable |
| 2300 | Payroll Liabilities |
| 2400 | Unearned Revenue (customer prepayments) |
| 2700 | Loan Payable |

### 3000–3999 Equity (normal balance: credit)

| Code | Account |
| --- | --- |
| 3000 | Owner Capital |
| 3100 | Owner Draws (contra-equity) |
| 3900 | Retained Earnings |

### 4000–4999 Revenue (normal balance: credit)

| Code | Account |
| --- | --- |
| 4000 | Service Revenue |
| 4100 | Product Sales |
| 4900 | Sales Returns & Allowances (contra-revenue) |

### 5000–5999 Expenses (normal balance: debit)

| Code | Account |
| --- | --- |
| 5000 | Cost of Goods Sold |
| 5100 | Rent |
| 5200 | Software Subscriptions |
| 5300 | Payroll & Wages |
| 5400 | Professional Fees |
| 5500 | Bank & Payment Fees |
| 5600 | Depreciation Expense |

## Contra accounts

A contra account carries the *opposite* normal balance of its parent and reduces it on reports. The three you will actually meet:

- **Accumulated Depreciation (1510)** — contra-asset; credit balance; reduces Equipment to book value. Paired with Depreciation Expense (5600).
- **Allowance for Doubtful Accounts** — contra-asset against Accounts Receivable; credit balance; estimates AR you do not expect to collect.
- **Owner Draws (3100)** — contra-equity; debit balance; reduces owner equity when the owner takes money out. It is **not** an expense — it never touches the P&L.

## When to add vs merge an account

**Add** an account only when a real reporting or tax question requires the split:

- You must report "Software" separately from "Rent" on a return or to a lender.
- A category has grown large enough that one line hides decisions you need to see.
- A regulator/jurisdiction requires it (e.g., VAT-bearing vs VAT-exempt expenses).

**Merge** (or never split) when:

- You hesitate about which of two accounts a transaction belongs in — that hesitation guarantees inconsistent history.
- An account collects fewer than a handful of entries a year and answers no reporting question.
- Two accounts are always read together anyway.

## The over-splitting failure mode

A 200-account COA feels precise and produces the opposite. Symptoms:

- The same recurring charge lands in a different account each month because the splits are too fine to choose between consistently.
- Reports have dozens of near-zero lines and the signal drowns.
- New transactions stall because classification is a research task, so they pile up in Uncategorized.

The fix is almost always to **merge down**, not split further. A COA you can hold in your head is a COA you classify correctly. Twenty-five accounts that are always right beat two hundred that are usually wrong.
