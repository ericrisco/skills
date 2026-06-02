# Metric catalog — candidate north stars and driver sets by business type

A lookup table, not a flow. Use it to seed candidates in Step 1 and Step 2, then narrow
to **one** north star and **3-5** inputs for the actual team. AARRR and HEART are
*candidate-generation lenses* — they help you find candidates, they are not the framework.
Adapt every line to the specific business; do not copy a row verbatim.

Every candidate north star below is a rate or ratio tied to delivered value, never a raw
count. Every input is leading, controllable, and stated as a concrete instrumentable event.

---

## SaaS (product-led)

- **Lens:** HEART (engagement + retention + adoption).
- **Candidate north star:** weekly active accounts completing a *core action* / active accounts.
  - Why a core action and not "logins": logins are presence, the core action is value delivered.
- **Inputs (leading):**
  - median time-to-first-core-action for new accounts
  - % of new accounts reaching the activation milestone in week 1
  - % of seats invited that activate within 7 days
  - feature-X adoption among accounts that retain (if X correlates with retention)
- **Guardrails:** support tickets per active account (must not rise); week-4 retention of newly-activated cohort (catches a loosened activation definition).

## Marketplace (two-sided)

- **Lens:** AARRR on both sides; liquidity is the real outcome.
- **Candidate north star:** % of listings/requests that result in a successful match within N days (matched supply-demand), or successful transactions / active buyer.
  - Why a match rate, not GMV: GMV grows with price inflation and one-off whales; match rate measures the marketplace actually clearing.
- **Inputs (leading):**
  - new supply with >=1 active listing in first 7 days
  - search-to-contact rate (demand side)
  - time-to-first-response from supply side
  - repeat-request rate within 30 days
- **Guardrails:** cancellation/dispute rate (catches forced or low-quality matches); supply churn (catches demand-side over-optimization that burns suppliers).

## Content / media

- **Lens:** HEART (engagement + happiness), explicitly *not* raw reach.
- **Candidate north star:** weekly returning readers/viewers who consume >=N pieces / weekly actives, or completion-weighted engaged time per returning user.
  - Why returning + depth, not page views: page views are the classic vanity metric — they spike on a viral fluke and predict nothing.
- **Inputs (leading):**
  - % of new visitors who return within 7 days
  - subscriptions/follows from engaged sessions (not popups)
  - content-completion rate per piece
  - saves / adds-to-list per active user
- **Guardrails:** unsubscribe + mute rate (catches notification spam); content-quality complaints (catches clickbait optimization).

## E-commerce

- **Lens:** AARRR (revenue + retention).
- **Candidate north star:** repeat-purchase rate within 90 days, or contribution-margin-positive orders per active customer.
  - Why repeat rate / margin, not revenue: top-line revenue hides discounting, returns, and one-time deal-chasers.
- **Inputs (leading):**
  - first-order-to-second-order conversion within 30 days
  - cart-to-checkout completion rate
  - email/SMS opt-in among purchasers
  - product-page-to-cart rate for in-stock items
- **Guardrails:** refund + return rate (catches aggressive upsell); CAC payback (hand economics to `../unit-economics/SKILL.md`).

## B2B sales-led

- **Lens:** AARRR adapted to a longer cycle; the outcome is qualified pipeline that closes.
- **Candidate north star:** SQL-to-closed-won rate, or net revenue retention of the existing book.
  - Why a conversion/retention rate, not "leads": lead count is vanity when leads don't convert; the win rate and NRR are where value lives.
- **Inputs (leading):**
  - MQL-to-SQL conversion rate
  - % of opportunities with a completed discovery/qualification step
  - time-in-stage for the slowest pipeline stage
  - product activation within the trial/POC window
- **Guardrails:** discount depth on closed-won (catches "win at any price"); 90-day post-sale churn (catches over-promising to close).

---

## How to use a row

1. Pick the lens that matches how your product creates value.
2. Take the candidate north star, rewrite it for your exact core action and denominator.
3. Steal 3-5 inputs, cut to the ones your team can actually ship against this quarter.
4. Take the guardrails as a starting countermetric set; add any harm specific to your push.
5. Move to Step 4 in `SKILL.md` to baseline and target each row.

If your business doesn't fit a row, build one: ask what single outcome predicts that next
year's customers stay, then ask which 3-5 plays the team controls that cause it.
