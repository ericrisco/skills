# Voice Guide — Tend

*Tend is a B2B fintech: cash-flow and treasury tooling for the finance teams of small and mid-size companies. The brand has to be trusted with someone's payroll and runway, and it has to read like a person — not a bank, not a bot.*

This is the durable definition of how Tend sounds. Write it once; every landing page, email, support reply, and AI-generated draft writes against it. This guide is the source of truth — not a deck, not someone's instinct.

---

## Voice vs. tone

**Voice is constant. Tone flexes by context.** Tend sounds the same whether it's welcoming a new team or flagging a failed transfer — that fixed personality is the voice. What moves is the tone: a finance lead staring at a declined payment doesn't want warmth-by-default, and a "books closed" screen shouldn't read like a security disclosure. Same voice, different dial. (Nielsen Norman Group, "The Four Dimensions of Tone of Voice," pub. 2016-07-17, updated 2023-08-16.)

Author the voice once (Steps 1–4). Tabulate the tone per context (Step 5). Never let the channel rewrite the voice.

---

## 1. Traits

Three traits. Each is testable — a rival could deny the opposite, so none is filler.

```text
Straight with you
  this means:         we name the trade-off, the fee, and the limit up front; we say what we don't know
  this does NOT mean: blunt, cold, or hiding behind "subject to terms"

Plain-spoken
  this means:         short Anglo-Saxon words; one idea per sentence; we explain the why, not just the what
  this does NOT mean: dumbing down the finance — a real number keeps its real precision

Steady
  this means:         calm and the same every time; no hype, no panic, no manufactured urgency
  this does NOT mean: flat or robotic — we still write to a person who has a hard job
```

Why these and not the usual brand-neutral adjectives: a competitor would happily claim being forward-thinking, dependable, or customer-first, so those exclude nothing. "Straight with you," "plain-spoken," and "steady" are choices a hype-driven fintech would actively reject.

---

## 2. Rules (per trait, with a Bad→Good)

Levers: person · sentence-length ceiling · active/passive · contractions · jargon policy.

```text
Trait: Straight with you
  R1  Every number carries a source and a date inline. No floating stats.
  R2  Name the fee, the limit, or the cutoff before the benefit — never bury it.
  R3  No hedging to dodge a claim ("may", "could", "potentially"). State it or cut it.
  Bad : "Transfers may potentially clear faster with our optimized rails."
  Good: "Domestic transfers clear same day if you send before 4pm ET. After that, next morning."

Trait: Plain-spoken
  R1  Sentence ceiling ~20 words; break anything longer.
  R2  Active voice — the subject does the verb.
  R3  Jargon only when you define it inline on first use.
  Bad : "It is advised that liquidity positions be reconciled on a monthly cadence."
  Good: "Check your cash position against the bank once a month. We'll remind you."

Trait: Steady
  R1  Second person ("you"), contractions ("you'll", "we've", "here's").
  R2  Zero exclamation marks; the facts carry the weight, not the punctuation.
  R3  No urgency theater — no "act now", no countdowns on anything involving money.
  Bad : "Don't miss out — upgrade NOW to unlock premium treasury tools!!"
  Good: "When you're ready for multi-entity treasury, it's one click. No rush."
```

---

## 3. Four dimensions (ratios)

A position on each scale, as a ratio — not "somewhere in the middle." Each ratio is pulled from a trait, not from taste.

| Dimension | Position (ratio) | Why this brand sits here |
|---|---|---|
| Formal ↔ Casual | 55 / 45 casual | Payroll and runway demand credibility; contractions and "you" keep it human. Leans formal of center on purpose. |
| Serious ↔ Funny | 90 / 10 serious | We hold people's cash. Humor lives only in low-stakes onboarding microcopy, nowhere near money movement. |
| Respectful ↔ Irreverent | 80 / 20 respectful | We challenge legacy-bank opacity and jargon — never the reader, who is already under pressure. |
| Matter-of-fact ↔ Enthusiastic | 80 / 20 matter-of-fact | "Steady" trait, direct: a sourced number beats an adjective. Energy goes in verbs, not exclamation marks. |

If a ratio fought a trait, the trait wins and the ratio gets fixed. These don't.

---

## 4. Word bank

**Power words (16)** — derived from the traits, not a thesaurus dump:

`clear · cleared · cash · runway · on time · same day · sourced · accurate · secure · plain · simple · steady · fix · done · trusted · holds`

Read cold, that list could only be a cash/treasury brand that values plainness — not a generic fintech.

**Ban list** — the drift killer. Universal corporate-filler and AI tells first, then Tend-specific bans:

`leverage · seamless · elevate · delve · robust · unlock · game-changer · revolutionize · synergy · best-in-class · cutting-edge · world-class · "in today's fast-paced world" · "it's important to note" · "embark on a journey"`

Tend-specific bans:

```text
"financial journey"   -> name the actual task (close the month, send payroll)
"thrilled" / "excited" -> manufactured emotion; we're steady, not breathless
"users"               -> say "your team" or "finance teams"
"!"                   -> banned outright; the voice is steady, punctuation can't fake energy
"act now" / "hurry"   -> no urgency theater around money, ever
```

---

## 5. Tone-by-context matrix

The voice column never changes — that's the proof voice is constant. Only the tone column moves.

| Context | Voice (constant) | Tone shift | Example line |
|---|---|---|---|
| Onboarding | straight, plain, steady | warm, lightly welcoming | "You're in. Let's connect your first bank account — takes about two minutes." |
| Error / failure | straight, plain, steady | plain, reassuring, zero humor | "That transfer didn't go through. No money left your account — here's why, and how to retry." |
| Success | straight, plain, steady | quiet warmth, no hype | "Payroll's sent. Everyone gets paid Friday." |
| Billing / account | straight, plain, steady | precise, calm, no jokes | "Your plan renews June 30 at $240. Cancel anytime — no fee, no notice period." |
| Legal / security | straight, plain, steady | formal, exact, literal | "Your cash is held in FDIC-insured accounts at partner banks. Details in our deposit terms." |

A frustrated finance lead at an error screen gets reassurance, not a joke. The celebration line stays warm but never breathless. Same voice throughout.

---

## 6. AI voice-DNA block

Paste this into a system prompt so any LLM or writer reproduces Tend.

```text
VOICE DNA — Tend
Traits: straight with you, plain-spoken, steady.
Rules: active voice; sentences <=20 words; use contractions; second person "you";
  no exclamation marks; every number gets a source + date; name the fee/limit before
  the benefit; no hedging to dodge a claim; no urgency theater around money.
Dimensions: 55/45 casual, 90/10 serious, 80/20 respectful, 80/20 matter-of-fact.
Use: clear, cleared, cash, runway, on time, same day, sourced, accurate, secure,
  plain, simple, steady, fix, done, trusted, holds.
Never use: leverage, seamless, elevate, delve, robust, unlock, game-changer,
  revolutionize, synergy, best-in-class, cutting-edge, world-class, "financial journey",
  "thrilled", "excited", "act now", "in today's fast-paced world".
Tone by context: onboarding=warm+light; error=plain+reassuring,no humor;
  success=quiet warmth,no hype; billing=precise+calm; legal=formal+exact.
```

---

## Auditing a sample for drift

Three passes against any copy claiming to be Tend:

1. **Ban scan** — any banned word is one drift point. Start here; it catches the AI-tells and corporate filler fastest.
2. **Rule check** — count passive voice, sentences over ~20 words, exclamation marks, undefined jargon, floating numbers with no source/date, urgency language around money.
3. **Trait test** — read it cold. Does it land as "straight + plain + steady"? If it reads as "hypey + vague + breathless," it's off-brand no matter the word count. The fix is a rewrite toward a rule, never "make it pop."
