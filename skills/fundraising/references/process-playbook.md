# The sprint playbook, the instrument decision, and the term-sheet cheat sheet

The SKILL.md gives the rules; this gives the week-by-week sequence, the SAFE-vs-priced detail, and the term-by-term read. Defer all real cap-table math to `../financial-model/SKILL.md`.

## The 6–8 week sprint, week by week

A raise is won by **simultaneity**. The default target is ~6–8 weeks; the 2025 market stretched cold-start cycles to 12–18 months when momentum was absent, so the whole point of the sprint is to never give the market time to cool.

```text
Pre-launch (1–2 weeks before)
  · Finalize deck (pitch-deck), model (financial-model), data room (investor-materials)
  · Build the tiered list and confirm intro paths (funnel-math.md)
  · Pre-warm connectors: line up the intros so they fire in a batch on day 1
  · DO NOT take real meetings yet — a leaked early "no" with no momentum hurts

Weeks 1–2  ·  The meeting burst
  · 30–50 first meetings IN PARALLEL — this density is what creates competition
  · Same week for all of Tier A; investors talk, and a busy calendar signals a hot deal
  · Tight, repeatable first-meeting narrative; capture every follow-up ask same day

Weeks 3–4  ·  Partner meetings & diligence
  · Convert first meetings → partner/2nd meetings (~50% target)
  · Feed diligence fast (data room ready = days saved); slow responses read as disorganized
  · Drive explicitly toward the FIRST term sheet — it is the unlock

Close
  · First term sheet in hand → use it to compress everyone else's timeline
  · Run a short, honest "we're moving to decisions this week" to the live pipeline
  · Compare offers (never sign the only one), negotiate the compounding terms, sign
```

## Honest momentum / FOMO mechanics

FOMO is real and worth manufacturing — but only from true signals. The asymmetry: a fabricated competing offer wins you nothing investors can't unravel, and unravels the whole round when two partners compare notes.

```text
Legitimate momentum levers          Forbidden (round-killers)
· A visibly busy meeting calendar    · "We have a term sheet" when you don't
· A real first term sheet            · Invented deadlines / fake closing dates
· Parallel timelines ("decisions     · Naming a competing fund that isn't in
   this week"), stated honestly         · Inflating the round size or interest
· Letting investors infer demand     · Any claim you couldn't defend if called
   from the cadence, not from claims
```

The rule: every signal you project must survive an investor calling another investor. If it wouldn't, don't say it.

## SAFE vs priced — the full decision table

| Dimension | Post-money SAFE | Priced equity round |
| --- | --- | --- |
| Typical size | < ~$4M | ≥ ~$4M |
| Lead required | no (works as a party round) | usually yes (lead sets terms) |
| Legal cost | ~$0–$2,000 (YC template) | ~$15,000–$25,000 attorney fees |
| Speed | days | weeks |
| Instrument | converts later, no stock issued now | preferred stock issued now |
| Governance | founder keeps full control | board seat / protective provisions likely |
| Cap-table impact | deferred to conversion (watch the pile-up) | priced & on the cap table immediately |
| Best when | small/early, no lead, simple cap table, need speed | larger, lead present, complex cap table, governance expected |

Market reality: ~90% of pre-seed rounds on Carta in Q1 2025 used a SAFE; ~92% of all pre-priced rounds as of Q3 2025. Below ~$4M, SAFE is the default; above it (or with a lead wanting control), price it.

## Post-money SAFE pile-up — worked example

A post-money SAFE fixes the holder's ownership **after all SAFE money but before the priced round**. Founders read each SAFE in isolation and are shocked at conversion when several stack. Model the whole stack *before* signing the next one.

```text
Illustrative pile-up (directional — run the real math in financial-model):
  SAFE 1:  $500K  @ $5M post-money cap   →  holder fixed at ~10% post-conversion
  SAFE 2:  $500K  @ $7M post-money cap   →  holder fixed at ~7.1%
  SAFE 3:  $500K  @ $8M post-money cap   →  holder fixed at ~6.25%

  Founders read each as "small." Combined, the SAFE holders are pre-committed to
  ~23%+ of the post-priced cap table BEFORE the new-money priced round and the
  option-pool top-up dilute founders further. The stack compounds; the pieces hide it.
```

Most post-money SAFEs are **cap-only (no discount)** — add a discount only with a specific reason (e.g. very early, no cap agreeable). The instant a SAFE stack gets non-trivial, push the exact combined-dilution table to `../financial-model/SKILL.md`.

## Term-sheet basics cheat sheet (2025 bands + what to push on)

Negotiate the terms that **compound**, not the headline valuation alone. Bands are Q2 2025 market standard at seed.

| Term | Standard band | Read / what to push on |
| --- | --- | --- |
| **Liquidation preference** | ~98% **1x**; ~95% **non-participating** | 1x non-participating is founder-friendly and market. Anything **>1x** or **participating** is off-market — push hard or walk. |
| **Valuation cap / pre-money** | sets your dilution | Translate cap → implied dilution; reject anything outside your Step-1 band. Median seed lead ownership ~12.6%. |
| **ESOP / option pool** | carved **pre-money** | The hidden dilution lever. A big "for hiring" pool inflates the lead's effective ownership at your expense. Size it to the real 12–18mo hiring plan. |
| **Board composition** | common post-seed **2 founder / 1 investor** | Keep founder majority at seed. A 2/1 investor-majority board at seed is a red flag. |
| **Pro-rata rights** | common | Generally fine to grant; know who reserves follow-on so the next round isn't a surprise. |
| **Protective provisions / vetoes** | in **>90%** of rounds | Standard major-decision vetoes are normal. Push back on scope creep into ordinary operating decisions. |
| **Anti-dilution** | broad-based weighted-average is standard | Reject full-ratchet — it's punitive and off-market at seed. |

Two hard rules:

1. **Never sign the first term sheet without a comparison.** A single offer with no comp gives away all your leverage. The first term sheet's real value is the urgency it creates across the rest of the pipeline.
2. **The term sheet is mostly non-binding; the SAFE / SPA / side letter is binding.** You read and negotiate the term sheet here. The binding instrument goes to `../contracts/SKILL.md` and a real startup lawyer — do not draft or redline the binding doc from this skill.
