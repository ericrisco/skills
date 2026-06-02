---
name: linkedin-carousels
description: "Use when designing a LinkedIn carousel / document post — the swipeable multi-page PDF that is currently the highest-reach native LinkedIn format — and you need the slide-by-slide build: a scroll-stopping cover hook, a narrative arc that pulls swipe-to-swipe, one focused idea per slide with real visual hierarchy, a payoff + CTA closer, and a PDF export spec. Triggers: 'turn this into a LinkedIn carousel', 'design a swipeable PDF document post', 'my carousel cover gets no swipes fix the hook', 'how many slides and what goes on each', 'restructure one-idea-per-slide', 'what size to export so it isnt cropped on mobile', 'convierte este post en un carrusel de LinkedIn', 'dissenya'm un carrusel de LinkedIn amb portada i CTA'. NOT the account/format plan (that is linkedin-strategy), NOT a text or single-image feed post (that is linkedin-content), NOT a spoken-to talk deck (that is presentations)."
tags: [linkedin, carousel, document-post, slide-design, visual-hierarchy, hook, b2b, social-content]
recommends: [linkedin-content, linkedin-strategy, brand-identity, brand-voice, presentations, social-publisher]
origin: risco
---

# LinkedIn carousels

Design **one swipeable LinkedIn document post**: the cover hook, the narrative arc, one idea
per slide, and the PDF export spec. You hand back a slide-by-slide build ready to assemble in
Canva/Figma/Slides and a one-page design+export checklist.

You do not own the account plan (which formats, cadence, niche — that is
[`../linkedin-strategy/SKILL.md`](../linkedin-strategy/SKILL.md)), the words of a text or
single-image feed post ([`../linkedin-content/SKILL.md`](../linkedin-content/SKILL.md)), the
programmatic upload ([`../linkedin-api/SKILL.md`](../linkedin-api/SKILL.md)), or a spoken-to
16:9 talk deck ([`../presentations/SKILL.md`](../presentations/SKILL.md)). Your artifact is the
*slides of a phone-read PDF* — sequence and visual hierarchy are the product.

## What you produce

- **A cover slide spec** — the one slide that wins or loses the swipe to slide 2.
- **Interior slides** — each carrying a single focused idea, large type, a clear hierarchy.
- **A CTA closer** — the payoff slide plus one explicit ask.
- **A design + export spec** — canvas, safe area, type floor, PDF checklist (one page).
- **A one-line caption starter** — the first feed line; full caption tuning routes out.

Precondition: you need a topic, an angle, or a source (post/article). If the ask is the
account plan or a block of feed copy, you are in the wrong skill — see the handoffs table.

## Ground first

A carousel inherits an identity; it does not invent one. Before you design slides:

- **Read the brand kit** if it exists in `02-DOCS/` (colors, type, logo) —
  [`../brand-identity/SKILL.md`](../brand-identity/SKILL.md) owns it. Don't pick arbitrary fonts.
- **Read the voice** so the headlines sound like the account —
  [`../brand-voice/SKILL.md`](../brand-voice/SKILL.md) owns it.
- **Pull the angle** from any plan/post already produced by
  [`../linkedin-strategy/SKILL.md`](../linkedin-strategy/SKILL.md) or
  [`../linkedin-content/SKILL.md`](../linkedin-content/SKILL.md). Reuse the hook, don't reopen it.

If none exist, name your assumptions on slide 0 of the spec and proceed — don't stall.

## The swipe economics (why every rule below exists)

Document/carousel posts are the **highest-engagement native format on LinkedIn right now** —
they hit roughly 6.6% average engagement, ahead of every other format, and top-performing
pages post far more of them than median pages. The reason is **dwell time**: a swipeable deck
holds the thumb on screen, and dwell — not likes — is the algorithm's main distribution signal.

So the whole bet is the **cover slide and the swipe-to-slide-2 bounce**. If the cover doesn't
earn the first swipe, your slide count, your arc, and your CTA never get seen. Every swipe
after that extends dwell and signals quality, which is why each slide must *pull to the next*.
Design backwards from that: stop the thumb, then keep it moving.

## The cover slide

This slide is the entire campaign. Build it to one job: earn the swipe.

- **Lead with a curiosity or benefit headline** — promise a payoff, not a topic label. Why: a
  label ("Onboarding tips") gives no reason to swipe; a stake ("Why 60% of users quit in week
  one") does.
- **One dominant element** — the headline reads first, before anything else. Why: a cover with
  three competing focal points reads as zero.
- **Intentional white space** — let the headline breathe. Why: a dense cover looks like work,
  and the thumb keeps scrolling.
- **An explicit swipe cue** — an arrow, "Swipe →", or a 1/8 counter. Why: tell people the
  format is a deck so they know there's more.

The test: **would this stop *my own* thumb mid-scroll on a crowded feed?** If you hesitate,
the cover is too quiet.

```text
Bad  (topic label, no stake, no swipe reason)
  ┌──────────────────────────┐
  │  Tips for better          │
  │  user onboarding          │
  │                           │
  └──────────────────────────┘

Good (stake + payoff + swipe cue, one dominant line)
  ┌──────────────────────────┐
  │  60% of new users quit    │   ← largest element, reads first
  │  in week one.             │
  │                           │
  │  Here's where they fall   │   ← supporting line, smaller
  │  off — and the fix.       │
  │                  Swipe →  │   ← explicit cue
  └──────────────────────────┘
```

More cover-hook shapes (number / contrarian / mistake / outcome / question) with Bad→Good
rewrites are in [`references/carousel-patterns.md`](references/carousel-patterns.md).

## The narrative arc

A carousel is not a list — it is a sequence engineered so each slide creates a reason to see
the next. Pick **one** arc and map slides to it. Branch on the angle:

| Arc | Use when | Slide shape |
|---|---|---|
| Problem → tension → reveal → payoff | persuasive / insight post | cover, stakes, the wrong way, the shift, the payoff, CTA |
| Numbered steps / listicle | how-to, framework | cover, step 1..n, recap, CTA |
| Myth → truth | contrarian take | cover, the myth, why it's wrong, the truth, proof, CTA |
| Before → after | transformation / case study | cover, before, turning point, after, how, CTA |
| Data reveal | stat-led post | cover, setup, the number, why it matters, so-what, CTA |

**Momentum rule:** end each interior slide on a small open loop — a cliff line, a "but here's
the catch", a half-finished list — so the thumb keeps swiping. Why: a slide that fully resolves
gives permission to stop. Each arc expanded to a full slide map is in
[`references/carousel-patterns.md`](references/carousel-patterns.md).

## One idea per slide + hierarchy

The line between a finished deck and one abandoned at slide 3 is **one idea per slide**.

- **One point per slide** — if a slide has two ideas, split it. Why: cramming dilutes the
  message and stalls momentum; a single point is swiped through fast and remembered.
- **Type floor ≥ 28 px** — it is read on a phone, one-handed. Why: body text below ~28 px
  forces a pinch-zoom, which is a stop.
- **One dominant element per slide** — a headline, a number, or a visual that reads first.
- **Generous white space + a consistent grid** — same margins, same headline position across
  slides. Why: a stable frame lets the eye land instantly and the deck feels designed.

```text
Bad  — crammed, four competing points, tiny text
  ┌──────────────────────────┐
  │ Onboarding fixes:         │
  │ • Shorten the signup form │
  │ • Add a progress bar      │
  │ • Send a day-1 email      │
  │ • Show a sample dataset   │
  └──────────────────────────┘

Good — one idea, one dominant element, breathing room
  ┌──────────────────────────┐
  │  Step 1                   │
  │                           │
  │  Cut the signup form to   │   ← single point, large
  │  3 fields.                │
  │                           │
  │  Every extra field drops  │   ← one supporting line
  │  completion ~7%.          │
  └──────────────────────────┘
```

## Slide count

Aim for the **6–12 band, ~8 as the sweet spot** (cover + ~6 content + CTA). Reported peaks
cluster around 7–8 slides; 8–12 is where the highest dwell/save/share rates show up. Fewer
than 5 underdelivers (not worth the swipe); more than ~15 loses people before the payoff.

Treat the band as a guide, not a law: **length follows the arc, not a quota.** If the arc
resolves in 7 slides, ship 7 — don't pad to hit a number.

## The CTA closer

The last slide is the payoff landing plus **one explicit ask**.

- **State the payoff first**, then ask. Why: people act after value, not before it.
- **One ask, tied to the payoff** — "Save this for your next onboarding review", "Comment your
  worst week-one drop-off". Why: a bare "Follow for more" is generic and ignorable; an ask
  hooked to what they just read converts.

```text
Bad   →  "Follow me for more content."     (generic, no reason)
Good  →  "Save this for your next onboarding review.
          Which step are you missing? Comment below."   (tied to payoff, one action)
```

## Design + export spec

```text
Canvas:    1080×1350 (4:5 portrait, recommended) or 1080×1080 (1:1 fallback). No landscape.
Safe area: keep headline + key visual inside ~880×880; ~80 px padding on all sides.
Type:      body ≥ 28 px (it is read on a phone).
Export:    PDF only (1 slide = 1 page). Cap ~100-300 MB / 300 pp depending on source; keep < ~10 MB.
Gotchas:   open the exported PDF and verify fonts — free Canva silently substitutes them;
           disable bleed / crop marks — they add black bars to every slide;
           preview on a PHONE before posting — the desktop view hides mobile crops.
```

Portrait 4:5 takes the most vertical space in a mobile feed, which raises dwell and the chance
of a scroll-stop. PDF is the only export that preserves fonts and layout reliably across
devices — exporting slides as images loses crispness and breaks selectable text. The full
checklist in prose is in [`references/carousel-patterns.md`](references/carousel-patterns.md).

## The feed caption handoff

A document post still has a **text caption above it**, and its first 1–2 lines (before the
"…more" fold) must restate the cover hook — that line is what people read before deciding to
expand and swipe. Give a one-line starter that echoes the cover, then route full feed-copy
length/tone tuning to [`../linkedin-content/SKILL.md`](../linkedin-content/SKILL.md). You own
the slides; that sibling owns the caption.

## Handoffs

| When you actually want… | Go to |
|---|---|
| The account/format plan, cadence, niche, who to target | [`../linkedin-strategy/SKILL.md`](../linkedin-strategy/SKILL.md) |
| A text or single-image feed post (just the copy) | [`../linkedin-content/SKILL.md`](../linkedin-content/SKILL.md) |
| 1:1 DMs / connection-request outreach sequences | `linkedin-outreach` |
| To publish/schedule the deck via the LinkedIn API | [`../linkedin-api/SKILL.md`](../linkedin-api/SKILL.md) |
| A spoken-to 16:9 talk deck (speaker support) | [`../presentations/SKILL.md`](../presentations/SKILL.md) |
| The color / type / logo brand kit the deck is styled in | [`../brand-identity/SKILL.md`](../brand-identity/SKILL.md) |
| The reusable tone of voice the words are written in | [`../brand-voice/SKILL.md`](../brand-voice/SKILL.md) |
| A long-form article (the prose, not slides) | [`../article-writing/SKILL.md`](../article-writing/SKILL.md) |
| To cross-post / schedule the finished asset elsewhere | [`../social-publisher/SKILL.md`](../social-publisher/SKILL.md) |

## Anti-patterns

| Anti-pattern | Why it fails | Do instead |
|---|---|---|
| Cover is a title slide / table of contents | No stake, no swipe reason — the deck dies at slide 1 | Lead with a curiosity/benefit headline that promises a payoff |
| Multiple ideas crammed on one slide | Dilutes the message, stalls momentum, forces tiny text | One focused idea per slide; split the rest into more slides |
| Body text under 28 px | Forces a pinch-zoom on mobile — that's a stop | Keep body ≥ 28 px; headlines far larger |
| Landscape (16:9) canvas | Takes minimal feed space, low dwell, looks like a talk deck | Portrait 1080×1350 (4:5), or 1080×1080 square fallback |
| A flat list with no arc | Nothing pulls the reader forward; they abandon early | Pick one arc; end each slide on a small open loop |
| 20+ slides | Loses people before the payoff | Stay in the 6–12 band (~8); let the arc set the length |
| Bare "Follow me for more" CTA | Generic, no reason to act | One explicit ask tied to the payoff (save/comment) |
| Exporting slides as images, not a PDF | Loses crispness, breaks the document-post format | Export one PDF, 1 slide = 1 page, < 10 MB |
| Trusting Canva's PDF fonts | Free Canva silently substitutes custom fonts | Open the exported PDF and verify fonts before upload |
| Never previewing on a phone | Desktop view hides mobile crops and bleed bars | Open the final PDF on a phone before posting |

## Verify

If you wrote the spec to a file, lint it before handing off:

```bash
scripts/verify.sh path/to/carousel-spec.md
```

It checks (read-only) for a labeled cover slide, a slide count in 5–15 (warns outside 6–12), a
CTA slide with an explicit ask, a portrait/square canvas, a ≥28 px type floor, "PDF" as the
export target, and warns on any crammed (3+ bullet) interior slide. An empty or clean target
passes. The deeper rigor is the capability eval in `evals/`.
