# Carousel patterns

Offloaded depth for `linkedin-carousels`. SKILL.md points here from the cover, narrative-arc,
and export sections. Everything here is a build aid — the SKILL.md rules still govern.

## Slide-by-slide spec template

Produce one block per slide. Fill every field; "—" if a field genuinely doesn't apply.

```text
SLIDE 0 — CONTEXT (not exported; for the build)
  Topic / angle:
  Source (post/article/idea):
  Brand kit ref (02-DOCS or assumption):
  Voice ref (02-DOCS or assumption):
  Chosen arc:
  Slide count:

SLIDE 1 — COVER
  Headline (dominant, reads first):
  Supporting line (smaller):
  Dominant visual / treatment:
  Swipe cue (arrow / "Swipe →" / 1/N counter):

SLIDE n — INTERIOR  (repeat per slide)
  Single idea (one sentence):
  Headline line (large):
  Supporting line (one, optional):
  Dominant visual / number:
  Open-loop close (cliff line into the next slide):

SLIDE N — CTA CLOSER
  Payoff restatement (the satisfying landing):
  One explicit ask (save / comment / share / visit):
```

## Cover-hook pattern library

Each shape, with a Bad (label) → Good (stake/payoff) rewrite. Pick the one that fits the angle.

```text
1. NUMBER
   Bad   "Things to improve onboarding"
   Good  "5 onboarding mistakes that cost you 60% of new users"

2. CONTRARIAN
   Bad   "Onboarding best practices"
   Good  "Your onboarding checklist is why users churn. Delete half of it."

3. MISTAKE
   Bad   "Onboarding tips"
   Good  "The week-one mistake almost every SaaS makes (and how to spot it)"

4. OUTCOME
   Bad   "How onboarding works"
   Good  "How we cut week-one churn from 60% to 18% — the exact flow"

5. QUESTION
   Bad   "About user retention"
   Good  "Why do 60% of your signups never come back? It's not the product."

6. NOBODY-TELLS-YOU
   Bad   "Onboarding guide"
   Good  "Nobody tells you that onboarding fails before the user even logs in"

7. STAKES / COST
   Bad   "User drop-off"
   Good  "Every extra signup field drops completion ~7%. Here's the math."
```

Rule across all of them: the headline names a payoff or a stake, one line dominates, and a
swipe cue tells the reader the format is a deck.

## Narrative-arc blueprints

Each arc expanded to a full slide map for an ~8-slide deck. Adjust count to fit the content —
length follows the arc, not a quota.

```text
ARC A — PROBLEM → TENSION → REVEAL → PAYOFF   (persuasive / insight)
  1 Cover: the stake (curiosity/benefit headline + swipe cue)
  2 The problem: name the pain the reader feels
  3 The tension: why the obvious fix doesn't work
  4 The reveal: the actual cause / the shift in thinking
  5 The mechanism: how the fix works
  6 The proof: a number, result, or example
  7 The payoff: what changes once they apply it
  8 CTA: restate payoff + one ask (save/comment)

ARC B — NUMBERED STEPS / LISTICLE   (how-to, framework)
  1 Cover: "N steps to <outcome>" + swipe cue
  2..7 One step per slide (one idea, large type, open-loop close)
  8 Recap or the one step that matters most + CTA ask

ARC C — MYTH → TRUTH   (contrarian)
  1 Cover: the contrarian claim + swipe cue
  2 The myth: what most people believe
  3 Why it's wrong: the flaw in the belief
  4 The truth: the better model
  5 Proof: evidence the truth holds
  6 So-what: what to do differently
  7 CTA: restate the truth + one ask

ARC D — BEFORE → AFTER   (transformation / case)
  1 Cover: the transformation ("from X to Y") + swipe cue
  2 Before: the starting state and its cost
  3 The turning point: what changed
  4 After: the new state
  5 How: the steps that got there
  6 Lesson: what's transferable
  7 CTA: restate result + one ask

ARC E — DATA REVEAL   (stat-led)
  1 Cover: tease the number, don't reveal it ("60% of users do THIS")
  2 Setup: why the number matters / how it was measured
  3 The number: reveal it as the dominant element
  4 Why it happens: the cause
  5 So-what: the implication for the reader
  6 Action: what to change
  7 CTA: restate the insight + one ask
```

Momentum rule applies to every arc: end each interior slide on a small open loop (a cliff
line, a "but…", a half-answered question) so the reader swipes to resolve it.

## Design + export checklist (in words)

- **Canvas.** Use 1080×1350 px (4:5 portrait) — it claims the most vertical feed space, which
  raises dwell and scroll-stop chance. 1080×1080 (1:1 square) is the safe fallback. Never
  landscape for the feed — it reads as a talk deck and takes minimal space.
- **Safe area.** Keep every headline and key visual inside a central ~880×880 region, ~80 px
  padding on all sides. LinkedIn's in-feed viewer and mobile cropping can shave the edges.
- **Type floor.** Body text ≥ 28 px; headlines far larger so hierarchy reads at a glance. It
  is consumed one-handed on a phone — anything smaller forces a pinch-zoom, which is a stop.
- **Export format.** PDF only — it preserves fonts and layout across devices. LinkedIn also
  accepts PPTX/DOCX, but only PDF renders consistently. One slide = one PDF page.
- **File size.** Reported ceilings range ~100-300 MB / 300 pages depending on source (LinkedIn's
  own Help page states 100 MB / 300 pages); keep it under ~10 MB so it loads fast in-feed.
  Compress images if needed.
- **Font substitution.** On free Canva, custom fonts can be swapped at PDF export with no
  warning. Open the exported PDF and confirm the fonts before upload.
- **Bleed / crop marks.** If accidentally enabled, they add black bars around every slide.
  Disable them in export settings.
- **Phone preview.** Open the final PDF on an actual phone before posting — the desktop preview
  hides crops and bars that only show on mobile.

## Worked example — full 8-slide deck (Arc A)

Topic: "Why most onboarding flows lose users in week one." Arc A (problem → reveal → payoff).

```text
SLIDE 1 — COVER
  Headline:     "60% of new users quit in week one."
  Supporting:   "It's almost never the product. Here's where they fall off."
  Dominant:     the "60%" set large; headline reads first
  Swipe cue:    "Swipe →"  (1/8)

SLIDE 2 — THE PROBLEM
  Idea:         users churn before they reach value
  Headline:     "They never hit the 'aha' moment."
  Supporting:   "Most leave before doing the one thing that makes the product click."
  Open loop:    "And the usual fix makes it worse →"

SLIDE 3 — THE TENSION
  Idea:         adding more onboarding steps backfires
  Headline:     "More onboarding ≠ better onboarding."
  Supporting:   "Every extra setup screen is another exit."
  Open loop:    "So what actually keeps them? →"

SLIDE 4 — THE REVEAL
  Idea:         time-to-value is the real metric
  Headline:     "Cut the time to first value."
  Supporting:   "Get them to one real win fast — defer everything else."
  Open loop:    "Here's how, step by step →"

SLIDE 5 — THE MECHANISM
  Idea:         shorten the signup form
  Headline:     "Step 1: 3 fields, not 9."
  Supporting:   "Every extra field drops completion ~7%."
  Open loop:    "Then remove the empty state →"

SLIDE 6 — THE MECHANISM (cont.)
  Idea:         seed the first win
  Headline:     "Step 2: pre-load a sample so they see value in 30 seconds."
  Supporting:   "Don't make day one a blank screen."
  Open loop:    "The result? →"

SLIDE 7 — THE PAYOFF
  Idea:         the outcome of the changes
  Headline:     "Week-one churn: 60% → 18%."
  Supporting:   "Same product. Faster path to the 'aha'."
  Open loop:    "Want the checklist? →"

SLIDE 8 — CTA CLOSER
  Payoff:       "Faster time-to-value is the whole game in week one."
  Ask:          "Save this for your next onboarding review. Which step are you missing? Comment below."

CAPTION STARTER (hand to linkedin-content for tuning):
  "60% of new users quit in week one — and it's almost never the product. 👇"
```
