# Tricky transactions — the lines careless judgment gets wrong

The basic mechanics (debits=credits, normal balances) are not where books go wrong. They go wrong on a recurring set of transactions that *look* like a simple expense or revenue and are not. For each: the situation, the **wrong** entry that gets posted by default, and the **right** one. Run Rule 4.5's decision procedure to land on these; this file is the lookup of the answers.

Convention: `DR` = debit (left), `CR` = credit (right). Every entry below ties.

---

## 1. Transfer between your own accounts (not income/expense)

You move $5,000 from operating checking to a savings/reserve account.

- **Wrong:** `DR Cash–Savings 5000 / CR Service Revenue 5000` — invents revenue. (Or booked as an expense out of operating.)
- **Right:**
  ```text
  DR  1010 Cash–Savings        5000
      CR  1000 Cash–Operating       5000
  ```
- Net worth unchanged → no P&L account is touched. Same logic for: owner topping up the business (that leg is `CR Owner Capital`, equity), and paying the company credit card from operating cash (that is `DR Credit Card Payable / CR Cash`, two balance-sheet accounts).

## 2. Refund of an expense (reverse the cost, don't book revenue)

A $200 software charge is refunded to your card.

- **Wrong:** `DR Cash 200 / CR Revenue 200` — overstates income and leaves the original expense overstated too.
- **Right:**
  ```text
  DR  1000 Cash                 200
      CR  5200 Software Subscriptions  200
  ```
- A refund **credits the original expense account**, netting the cost to its true value. A *customer* refund (you returning money to a buyer) is the mirror: `DR Sales Returns & Allowances (contra-revenue) / CR Cash`.

## 3. Collecting an invoice already booked (clear AR, don't re-book revenue)

You earned $3,000 last month (booked `DR AR / CR Revenue`). The customer now pays.

- **Wrong:** `DR Cash 3000 / CR Revenue 3000` — double-counts the sale; revenue is now $6,000 for one $3,000 job.
- **Right:**
  ```text
  DR  1000 Cash                3000
      CR  1100 Accounts Receivable  3000
  ```
- The revenue was recognized when earned. Cash collection only **clears the receivable**. Mirror for paying a supplier bill already in AP: `DR Accounts Payable / CR Cash` — the expense was booked when incurred.

## 4. Partial payment / overpayment

Customer owes $1,000, pays $600.

- **Right:** `DR Cash 600 / CR AR 600`. AR carries the remaining $400 — do not write it off or call it discount unless agreed.

Customer overpays: owes $1,000, sends $1,100.

- **Right:**
  ```text
  DR  1000 Cash               1100
      CR  1100 Accounts Receivable  1000
      CR  2400 Unearned Revenue       100   (or Customer Credit liability)
  ```
- The extra $100 is a liability (you owe it back or owe future work), **never** revenue.

## 5. Loan payment — split principal from interest

A $600 monthly loan payment of which $520 is principal and $80 is interest.

- **Wrong:** `DR Loan Expense 600 / CR Cash 600` — there is no "loan expense"; this double-counts cost (the borrowed cash was never income) and never reduces the liability.
- **Right:**
  ```text
  DR  2700 Loan Payable         520
  DR  5xxx Interest Expense      80
      CR  1000 Cash                  600
  ```
- Only the **interest** is an expense. Principal repays the liability. Receiving the loan originally was `DR Cash / CR Loan Payable` — also not revenue.

## 6. Buying an asset on finance / capital purchase

A $3,000 laptop+equipment purchase, useful life > 1 year, above your capitalization threshold.

- **Wrong:** `DR Equipment Expense 3000 / CR Cash 3000` — expensing a capital asset overstates this period's cost and understates assets.
- **Right (capitalize):**
  ```text
  DR  1500 Equipment           3000
      CR  1000 Cash                  3000
  ```
  then each month: `DR 5600 Depreciation Expense / CR 1510 Accumulated Depreciation`.
- Set a capitalization threshold (e.g. $2,500). Below it → expense now. Above it → capitalize and depreciate. A $40 keyboard is an expense; a $3,000 workstation is an asset.

## 7. Payroll — three pieces, not one

Gross wages $5,000; $1,000 employee tax/withholding; employer payroll tax $400.

- **Wrong:** `DR Wages 5000 / CR Cash 5000` — ignores the withholding you hold in trust and the employer's own tax.
- **Right (run):**
  ```text
  DR  5300 Payroll & Wages      5000      (gross)
  DR  5350 Employer Payroll Tax  400
      CR  1000 Cash                  4000  (net paid to employee)
      CR  2300 Payroll Liabilities   1400  (withholding 1000 + employer tax 400)
  ```
  then on remittance: `DR 2300 Payroll Liabilities 1400 / CR Cash 1400`.
- Withheld tax is **money you hold for the government** — a liability — not your cash and not an expense.

## 8. Prepaid expense (asset first, expense over time)

You pay $1,200 for 12 months of insurance up front.

- **Wrong:** `DR Insurance Expense 1200 / CR Cash 1200` in month one — overstates one month, understates the next eleven.
- **Right:**
  ```text
  DR  1200 Prepaid Expenses    1200
      CR  1000 Cash                 1200
  ```
  then monthly: `DR Insurance Expense 100 / CR Prepaid Expenses 100`.
- Annual SaaS, prepaid rent, prepaid insurance — all prepaid **assets** amortized over the term (under accrual). Cash basis may expense at payment; accrual amortizes.

## 9. Unearned revenue / deferred income (mirror of prepaid)

Customer prepays $1,200 for 12 months of service.

- **Right at receipt:** `DR Cash 1200 / CR Unearned Revenue 1200` (liability — you owe the work).
- **Each month as earned:** `DR Unearned Revenue 100 / CR Service Revenue 100`.
- Recognize revenue **as delivered**, not when cash lands. Booking the whole $1,200 as revenue on day one is the classic income-inflation error.

## 10. Accrued expense (incurred before paid)

December electricity used but the bill arrives in January.

- **Right (Dec, accrual):**
  ```text
  DR  5xxx Utilities Expense    150
      CR  2xxx Accrued Liabilities   150
  ```
  then when paid in Jan: `DR Accrued Liabilities 150 / CR Cash 150`.
- The cost belongs to the period it was **incurred**, matching expense to the revenue it helped produce. Skipping the accrual misstates both months' profit.

## 11. Sales tax / VAT collected (liability, not your revenue)

You sell $1,000 of services + $80 collected sales tax/VAT.

- **Wrong:** `DR Cash 1080 / CR Revenue 1080` — inflates revenue by tax you must remit.
- **Right:**
  ```text
  DR  1000 Cash               1080
      CR  4000 Service Revenue      1000
      CR  2200 Sales Tax / VAT Payable  80
  ```
- Tax collected is **money held for the authority** — a liability cleared on remittance (`DR 2200 / CR Cash`). Your revenue is the pre-tax amount. (Spain IVA repercutido works identically; the deductible IVA soportado on purchases is the asset/receivable mirror.)

## 12. Merchant-processor settlement — record gross, expense the fee (the Stripe/PayPal trap)

A $100 sale settles as a **$97.10 net** deposit; the processor kept a $2.90 fee.

- **Wrong:** `DR Cash 97.10 / CR Revenue 97.10` — understates revenue and hides the fee expense entirely (so true gross margin is invisible).
- **Right:**
  ```text
  DR  1000 Cash                97.10
  DR  5500 Bank & Payment Fees  2.90
      CR  4000 Service Revenue        100.00
  ```
- Always book **gross revenue** and the **fee as its own expense**. Reconcile the bank deposit (net) to the gross sale minus fees. This is the most common Stripe/PayPal/Square bookkeeping error and it quietly distorts every margin metric finance-ops reads downstream.

## 13. Bad debt write-off

A $500 receivable is confirmed uncollectible.

- **Right (allowance method):** `DR Allowance for Doubtful Accounts 500 / CR Accounts Receivable 500`. (Direct write-off: `DR Bad Debt Expense / CR AR`.)
- Removing AR you never collected; do **not** reverse it against Revenue of the current period unless it's the same period as the sale.

## 14. Foreign-currency payment

You pay a €1,000 invoice; at payment the bank charges $1,080 (rate moved since the bill was booked at $1,050).

- **Right:**
  ```text
  DR  2000 Accounts Payable    1050
  DR  5xxx FX Loss               30
      CR  1000 Cash                 1080
  ```
- The difference between booked and settled rate is a realized **FX gain/loss**, not an adjustment to the original expense.

## 15. Personal / mixed-use spend

Owner buys $300 of groceries on the business card.

- **Right:** `DR 3100 Owner Draws 300 / CR Cash 300` — personal spend is an **equity draw**, never an expense, and never on the P&L.

A genuinely mixed charge (e.g. a phone bill 70% business): split it — `DR Phone Expense (70%) / DR Owner Draws (30%) / CR Cash`. Only the business portion is deductible.

---

## When none of these fit

If a line survives Rule 4.5 and matches no case here, **post it to a Suspense/Holding account (e.g. 1999) and flag it for follow-up** — then resolve it against the source document before period close. A flagged suspense balance is visible and gets cleared; a confident guess buried in "Misc" is invisible and never does. Suspense must be **zero at close**, exactly like Uncategorized.
