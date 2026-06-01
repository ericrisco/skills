# Brand Grounding for Decks — Checklist, Question Script & Persistence

A deck is the brand on stage, so it grounds in the **same** brand study the `marketing` and `design` skills
use — it does not fork it. This file holds the **completeness checklist** (the shared brand dimensions plus the
**deck-specific** ones), the **question script** (how to interview, batched), and the **persistence format**
(how to write it into `02-DOCS` and link it from `CLAUDE.md`). The runtime hard-STOP that invokes this lives in
`SKILL.md` under "Brand grounding (read this first)".

## Where the brand study lives

Following the `harness` Karpathy-wiki convention (identical to `marketing`/`design`):

```text
02-DOCS/
├── raw/brand/         ← immutable: voice samples + raw inputs pasted verbatim by the user
└── wiki/brand/        ← compiled brand study, one article per dimension
    ├── index.md            ← positioning one-liner + links to every dimension article
    ├── audience.md         ← ICP, pains, desires (+ deck audience & setting, below)
    ├── value-proposition.md← value prop, differentiation
    ├── voice.md            ← tone, do/don't word lists, links to raw voice samples
    ├── proof.md            ← credibility, metrics, customers, guarantees
    ├── offers.md           ← offers + primary/secondary CTA (the deck's ASK)
    └── channels.md         ← channels (incl. how decks are delivered/presented)
```

Deck-specific facts (purpose, length, presenter-vs-leave-behind, must-include slides) are **per-deck**, not
brand-permanent — capture them at the start of each deck and record the *convention* in
`02-DOCS/wiki/stack/presentations.md` (see SKILL.md "Project grounding"). The brand-permanent dimensions are
shared with marketing/design and live in `wiki/brand/`.

## Completeness checklist

**COMPLETE** only when every dimension is filled with real, specific content. Any empty / placeholder / "TBD" =
**INCOMPLETE** = hard STOP, interview the user.

### Shared brand dimensions (same as marketing/design — reuse if already filled)

- [ ] **1. Brand name & one-line positioning** — "[Brand] helps [audience] [outcome] by [mechanism]." No jargon.
- [ ] **2. ICP / audience, pains & desires** — who exactly; top 2–3 pains in their words; top 2–3 desires; today's alternatives.
- [ ] **3. Value proposition & differentiation** — core benefit in one sentence; what's different; the one thing only this brand can say.
- [ ] **4. Tone & voice** — 3–5 tone adjectives; a **do-words** and **don't-words** list; **3–5 voice samples pasted from the user's real writing** (mandatory — never infer a voice).
- [ ] **5. Proof & credibility** — real metrics, named customers/logos, quantified testimonials, certifications, guarantees, traction. Mark aspirational items `[[NEEDS PROOF]]`.
- [ ] **6. Offers & primary CTA** — what the audience is asked to do; the primary CTA verb; any secondary CTA; pricing if relevant. (This is the deck's **ask**.)
- [ ] **7. Channels** — where the brand publishes / how decks are delivered (in-person, sent PDF, webinar).

### Deck-specific dimensions (capture per deck, before building)

- [ ] **8. Deck purpose & type** — pitch / sales / product launch / keynote / investor / board-QBR / training / internal. What single outcome must this deck achieve?
- [ ] **9. Audience & setting** — who's in the room (role, knowledge level, skepticism); the setting (live on stage / Zoom screen-share / sent as a PDF to read alone); the time slot (5-min pitch vs 45-min talk).
- [ ] **10. Length** — target slide count / time. (5–10 short, 10–20 medium, 20+ long; keynotes time-boxed.)
- [ ] **11. Presenter vs leave-behind** — are you narrating it live (sparse slides + speaker notes) or is it read unattended (self-contained), or **both** (build presenter, derive leave-behind)?
- [ ] **12. Must-include & must-avoid** — mandatory slides/sections (a specific metric, a partner logo, a legal disclaimer, a required template), and anything that must NOT appear.
- [ ] **13. Visual & format constraints** — pipeline preference if any (Marp/Slidev/editable-PPTX); a corporate template (`.potx`) to honor; dark vs light; aspect ratio (default 16:9); the deck theme must reconcile with the design tokens in `02-DOCS/wiki/stack/design.md`.

## Question script (ask in batches, never all at once)

Send a batch, wait, persist, send the next. **Skip questions the located study already answers** — only fill
gaps. Stop the moment every dimension is complete.

### Batch A — purpose, audience, format (deck-specific, ask first)

```text
1. What kind of deck is this (pitch / sales / product launch / keynote / investor / board-QBR /
   training / internal), and in one sentence: what's the ONE outcome it must achieve?
2. Who's the audience and what's the setting — live on stage, a Zoom screen-share, or a PDF they
   read alone? How skeptical/knowledgeable are they, and how long is your slot?
3. Roughly how many slides / minutes?
4. Will you narrate it live (sparse slides, I write your talk track into speaker notes), is it sent
   to read unattended (self-contained), or both?
5. Any must-include slides or sections (a specific metric, a partner logo, a required template),
   and anything that must NOT appear?
6. Any format constraints — a corporate template (.potx) to match, dark vs light, do you need an
   EDITABLE PowerPoint at the end or is a polished PDF enough?
```

### Batch B — brand identity & audience (skip if `wiki/brand/` already has it)

```text
7. Brand/product name, and in one sentence: who is it for and what outcome does it deliver?
8. Describe the ideal customer/decision-maker precisely — role, context, sophistication.
9. In THEIR words, the top 2–3 pains that make them look for something like you?
10. The top 2–3 things they actually want? And what do they use today instead of you?
```

### Batch C — value & proof (skip if already filled)

```text
11. In one sentence, the core benefit — no feature list, no jargon?
12. What makes you genuinely different from those alternatives, and what's the one thing only YOU
    can credibly claim?
13. What proof can you stand behind RIGHT NOW (metrics, named customers, quantified testimonials,
    certifications)? If something's aspirational, say so — I'll mark it [[NEEDS PROOF]], not state it as fact.
```

### Batch D — voice & the ask (voice samples mandatory; skip if already filled)

```text
14. 3–5 adjectives for how the deck should sound, plus a DO list and a DON'T list of words/phrases.
15. Paste 3–5 samples of your REAL writing (posts, emails, prior decks/copy) so I match your voice
    instead of inventing a generic one — I'll save them verbatim under 02-DOCS/raw/brand/.
16. What's the single action you want the audience to take by the last slide (the ask)? Any
    secondary action?
```

If the user can't answer a dimension, it stays INCOMPLETE — note the gap, keep the STOP for that dimension,
and offer to draft a hypothesis they confirm rather than fabricating. Voice samples are non-negotiable: no
samples → no voice → don't write the headlines.

## Persistence format

When a dimension is newly answered, write it as a wiki article under `02-DOCS/wiki/brand/` (shared dimensions)
and record deck conventions under `02-DOCS/wiki/stack/presentations.md`. Save any pasted raw text verbatim under
`02-DOCS/raw/brand/` and link it from the article's `> Raw:` line. Article format:

```markdown
# Voice

> Updated: 2026-06-01 · Source: user interview + raw/brand/voice-sample-1.md

Tone: direct, dry, concrete. ...

## Do words
ship, mechanism, receipts, ...

## Don't words
revolutionary, seamless, game-changer, supercharge, ...

> Raw: see [raw/brand/voice-sample-1.md](../../raw/brand/voice-sample-1.md)
```

Then add/refresh the link in the root `CLAUDE.md` (additive — never delete existing sections). Insert (or
update) under a `## Brand & voice` heading:

```markdown
## Brand & voice

Brand study (source of truth for all marketing, design, and deck copy):
`02-DOCS/wiki/brand/` — see `index.md` for positioning and links to every dimension.
Raw voice samples & inputs: `02-DOCS/raw/brand/`.
```

And ensure the deck conventions are indexed from the `## Knowledge map` section (create if absent):

```markdown
## Knowledge map

- Deck conventions: `02-DOCS/wiki/stack/presentations.md`
- Design tokens: `02-DOCS/wiki/stack/design.md`
```

Update `wiki/index.md` and `wiki/log.md` per the harness convention. Create any missing directories/files
(`CLAUDE.md` included) — additive only.

## Why this gate exists

Generic decks are the failure mode. A deck with no brand behind it defaults to the AI-median look and voice —
the exact "another AI deck" the audience tunes out. Grounding every headline in the voice samples and every
visual in the design tokens is what makes a deck unmistakably *this* brand. Cite the articles you used in the
deliverable (e.g. "narrative grounded in `value-proposition.md`, voice in `voice.md`, palette in
`stack/design.md`") so the user can trace every choice back to the study.
