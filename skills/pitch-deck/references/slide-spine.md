# The slide spine — full template

The canonical investor-deck spine is **10 core slides + the ask**, read in risk-evaluation order. Keep the
whole deck under ~15 (DocSend: 11–20 raises better; past that it hurts). For each slide below: its one job, the
investor question it answers, what content goes on it, an example line, and the trap.

Read this top-to-bottom: the deck is built in this order because that is the order an investor evaluates risk.

---

## 1 — Title / purpose

- **Job:** say what you do in one declarative line.
- **Investor question:** "What is this, in a sentence?"
- **On it:** company name, a one-line "we do X for Y" positioning, stage/round (optional), one clean visual.
- **Example:** *"Acme — the books-close autopilot for Series-A finance teams."*
- **Trap:** a vague tagline ("reimagining work") that could describe a hundred companies. Be concrete.

## 2 — Problem

- **Job:** make a real pain ache, for a specific who.
- **Investor question:** "Is this a real, urgent problem — and for whom?"
- **On it:** who has the pain, what it costs them today, why current workarounds fail. One number that sizes
  the pain.
- **Example:** *"A 200-person SaaS company spends ~12 finance-days a month closing the books in spreadsheets."*
- **Trap:** a problem no one pays to solve, or a problem stated so broadly it has no owner.

## 3 — Solution

- **Job:** show the insight that solves the problem.
- **Investor question:** "Does their thing actually solve it — and why is it the right shape?"
- **On it:** your approach in one sentence, the non-obvious insight behind it, the before→after for the user.
- **Example:** *"We ingest the ledger and auto-reconcile — close drops from 12 days to 2."*
- **Trap:** a feature list. Lead with the insight; features are slide 6.

## 4 — Why now

- **Job:** name the shift that makes this the moment.
- **Investor question:** "Why hasn't this been done — and why is now the time?"
- **On it:** the recent change (tech, regulation, behavior, cost curve) that just made this viable or urgent.
- **Example:** *"Ledger APIs went universal in 2024; what needed a 6-month integration is now a 1-day connect."*
- **Trap:** no answer, or a hand-wave ("AI is hot"). If there is no real shift, the timing thesis is weak.

## 5 — Market

- **Job:** show the prize is big and reachable.
- **Investor question:** "Is the outcome big enough to return the fund?"
- **On it:** TAM / SAM / SOM, **bottom-up first**, every number sourced. (Full method below.)
- **Example:** *"120K target SMBs × $4.8K ACV = $576M SAM (source: [registry]); 3-yr SOM 3,000 = $14.4M ARR."*
- **Trap:** "$X trillion, we just need 1%." Top-down hand-wave; a credibility tell.

## 6 — Product

- **Job:** one concrete proof the thing is real.
- **Investor question:** "Is this a working product or a slide?"
- **On it:** one screenshot / flow / demo frame that shows the core loop. Not 17 features — the one that matters.
- **Example:** *"[screenshot of the auto-reconcile run completing in 90 seconds]."*
- **Trap:** a feature carousel. One visual that proves the core insight from slide 3 actually ships.

## 7 — Business model

- **Job:** show how a dollar in becomes more dollars out.
- **Investor question:** "How does this make money, and is the unit profitable?"
- **On it:** pricing, who pays, ACV, and the unit economics signal (gross margin, LTV:CAC if you have it).
- **Example:** *"$400/mo per finance seat; ACV $4.8K; 82% gross margin; LTV:CAC 4:1."*
- **Trap:** "we'll figure out monetization later" at seed, or a model with no margin logic.

## 8 — Traction (the center of gravity)

- **Job:** show it is working AND accelerating — the SHAPE, not just a point.
- **Investor question:** "Is it working, and is it speeding up?"
- **On it:** MRR/ARR + MoM trend (the curve), retention/NRR, key logos, the LTV:CAC band. Few numbers, each
  with a unit and a trend.
- **Example:** *"$50K MRR, +22% MoM for 5 months (curve); NRR 118%; 40 paying logos; LTV:CAC 4:1."*
- **Trap:** vanity metrics (registered users with no activation), a single flat number, or no unit/trend.
- **Why it's the highest-stakes slide:** investors spend ~3× longer here, and 76% of "no" decisions cite weak
  traction. This is where the deck is won or lost.

## 9 — Competition

- **Job:** an honest landscape + your specific wedge.
- **Investor question:** "Why won't incumbents just crush them?"
- **On it:** the real alternatives (incl. "status quo / spreadsheets"), and the one axis where you win.
- **Example:** *"Incumbents bolt reconciliation onto an ERP; we are the close-native layer — 10× faster setup."*
- **Trap:** "we have no competition." Reads as naive or as "no market." Status quo is always a competitor.

## 10 — Team

- **Job:** why *this* team wins *this*.
- **Investor question:** "Can these specific people pull it off?"
- **On it:** founders, the earned insight / unfair advantage, relevant prior wins. Key hires/advisors if they
  de-risk.
- **Example:** *"Ex-Stripe finance-infra lead + ex-Big4 controller — we lived this close for 6 years."*
- **Trap:** a logo wall of past employers with no link to *why it makes you win this problem*.

## 11 — The ask

- **Job:** amount → use-of-funds → the milestone it buys.
- **Investor question:** "What do you need, and what does my money de-risk?"
- **On it:** raise amount + instrument, the use-of-funds split, and the specific milestone the runway reaches.
- **Example:**

  ```text
  Raising $1.5M (SAFE).
  Use of funds:  60% engineering · 25% go-to-market · 15% ops
  Buys:          18 months runway to $100K MRR — Series-A ready.
  ```

- **Trap:** an ask with no number, or a burn statement with no milestone ("$1.5M for 18 months"). The
  milestone turns a burn rate into an investment thesis.

---

## The market-sizing method (bottom-up, sourced)

Investors scrutinize the market slide and the ask hardest for realism. Build the number, do not assert it.

1. **SOM (bottom-up, the honest one):** reachable accounts in 3 years × your price. Start here.
2. **SAM:** total accounts you could serve × price — the segment you actually address.
3. **TAM:** the whole category, top-down — used only as a sanity ceiling.
4. **Source every figure** (registry, analyst report, census). The big number should be the *result* of the
   unit math, never the premise.

```text
SOM (3-yr reachable):  3,000 accounts  × $4.8K ACV = $14.4M ARR
SAM (addressable):     120,000 accounts × $4.8K   = $576M
TAM (category ceiling): $X.XB  (top-down sanity check, sourced)
```

## Stage deltas — what each slide may claim

| Slide | Pre-seed (sells team + insight) | Seed (sells early traction shape) | Series A (sells repeatable engine) |
| --- | --- | --- | --- |
| Problem | Sharp, lived, specific | Same, now validated by users | Same, with paying-customer proof |
| Solution | The insight + a prototype | A shipped product | A product with depth/moat |
| Why now | The timing thesis | Same, with early signal | Same, proven by adoption |
| Market | Bottom-up estimate | Bottom-up, refined by real ACV | Real ACV + expansion math |
| Traction | Waitlist / LOIs / design partners | MRR + MoM trend + early retention | Predictable growth + NRR + payback |
| Business model | Hypothesis, with margin logic | Early pricing validated | Proven unit economics (LTV:CAC, payback) |
| Team | The whole bet | Team + early execution proof | Team scaled, key hires in place |
| Ask | Small (to reach traction) | Medium (to reach the engine) | Larger (to pour fuel on a proven engine) |

Claiming above your stage (Series-A "engine" language on a pre-seed deck with no data) reads as naive.
Claiming below it (a seed deck hiding real traction behind a vision) wastes your strongest card.

---

Hand off: once this spine is locked, `presentations` renders + themes + exports it; `financial-model` produces
the numbers behind slides 5/7/8/11; `investor-materials` builds the one-pager, memo, and data room around it.
