# Conversion Copywriting Frameworks

The marketing-copy engine. Copy carries the value prop — the prettiest hero fails if the words are vague. Write benefit-led, specific, and human. The `marketing` skill is the canonical owner of the WORDS (voice, full landing copy, launch, channel adaptation) and grounds them in the same `02-DOCS/wiki/brand/` study; this file is the design-side quick reference that makes on-page copy convert and keeps it in sync with the design. For anything beyond the hero/section copy, hand off to `marketing`.

## The 5s value-prop test

A stranger reads the hero and, within 5 seconds, can answer: **what is it, who is it for, why is it better?** If any answer is missing, the copy fails — rewrite before you touch the layout.

Build the value prop from a value-proposition canvas: map the customer's jobs/pains/gains, then your pain-relievers/gain-creators, then compress the strongest match into a headline.

```text
VALUE-PROP CANVAS — Driftway (preview-environment CLI)
Customer jobs ...... ship a branch for review without breaking staging
Customer pains ..... staging is a shared queue; manual env setup eats an afternoon
Customer gains ..... reviewers click a link and see the real change
Pain relievers ..... one CLI command spins an isolated env; auto-teardown
Gain creators ...... every PR gets a live preview URL automatically
Headline ........... "Preview every branch — no staging queue"
Subhead ............ "One command gives every pull request a live URL. For platform teams who are done babysitting staging."
```

## Frameworks with picker

Pick the framework by traffic temperature and funnel position.

- **PAS (Problem-Agitate-Solution)** — pain-aware cold traffic that already feels the problem.
- **AIDA (Attention-Interest-Desire-Action)** — broad / top-of-funnel where you must earn attention first.
- **FAB (Feature-Advantage-Benefit)** — feature sections; translate capability into outcome.
- **BAB (Before-After-Bridge)** — show the transformation; strong for case studies.
- **JTBD (Jobs To Be Done)** — frame the product as the tool that gets a specific job done.

```text
PAS rewrite
Bad  — "Our platform streamlines environment management."
Good — "Staging is a queue. Every merge waits behind someone else's broken branch.
        Driftway gives each PR its own environment — no queue, no waiting."
```

```text
AIDA rewrite
Bad  — "Sign up for our developer tool today."
Good — "See your branch live in 30 seconds (Attention). It runs as one CLI step in
        your existing pipeline (Interest). Reviewers click a real URL, not a screenshot
        (Desire). Start free — no credit card (Action)."
```

```text
FAB rewrite
Bad  — "Includes automatic environment teardown."
Good — "Environments tear down automatically when the PR merges (Feature → Advantage),
        so you never pay for idle infra or clean up by hand (Benefit)."
```

```text
BAB rewrite
Bad  — "Improve your review workflow."
Good — "Before: reviewers guess from a diff (Before). After: they click a live URL and
        test the real thing (After). Driftway builds that URL on every push (Bridge)."
```

```text
JTBD rewrite
Bad  — "A powerful preview platform for modern teams."
Good — "When a teammate opens a PR, you want to test the actual change in seconds —
        Driftway gives that PR a live environment automatically."
```

## Headline formulas

| Formula | Pattern | Example |
| --- | --- | --- |
| Outcome + timeframe | `<Outcome> in <time>` | "Preview every branch in 30 seconds" |
| X without Y | `<Gain> without <pain>` | "Live previews without a staging queue" |
| JTBD | `When <trigger>, <product> <gets job done>` | "When you open a PR, get a live URL automatically" |
| Specificity | Replace adjectives with numbers | "Cut review setup from 20 min to 30 sec" |

The subhead's job: state **who** it's for, **how** it works in one clause, and **proof** if you have it. Specificity beats cleverness — a clear claim outconverts a clever pun every time.

## Benefit-led specificity

Climb the ladder feature → benefit → proof. Stop at the rung the visitor cares about (the benefit), and back it with the proof rung.

```text
Feature ... "Isolated per-branch environments."
Benefit ... "Reviewers test the real change, not a screenshot."
Proof ..... "Northwind cut review setup from 20 min to 30 sec across 40 engineers."
```

Numbers and receipts outperform adjectives. "Fast" is a claim; "30 seconds" is evidence.

## Microcopy & CTA copy

Buttons use value verbs; forms label clearly; states stay human.

| Context | Bad | Good |
| --- | --- | --- |
| Primary CTA | "Submit" | "Start free" |
| Secondary CTA | "Learn more" | "See a 2-min demo" |
| Form label | "Email" placeholder only | "Work email" with persistent label |
| Empty state | "No data" | "No previews yet — push a branch to create one" |
| Loading | "Loading..." | "Spinning up your environment…" |
| Error | "Something went wrong" | "Couldn't reach the API. Retry, or check status.acme.example." |

## Voice/tone system

Define a reusable VOICE block once and apply it everywhere. If a brand study exists under `02-DOCS/wiki/brand/voice.md` (owned by `marketing`), consume its profile verbatim; otherwise fill this and persist it back to the brand study:

```text
VOICE
Persona ...... a senior engineer who respects your time
Tone sliders . formal ⟵───●──── casual | serious ●──────── playful | dense ───●───── airy
Do ........... lead with the outcome; use concrete numbers; short sentences; active voice
Don't ........ hype words; bait questions; em-dash-stacked run-ons; forced lowercase
Reading level  8th–10th grade; one idea per sentence
```

## The ban-list

State once, enforce everywhere. These signal AI-template copy and erode trust:

`revolutionary` · `game-changer` · `cutting-edge` · "In today's landscape" · `unlock` · `seamless` · `elevate` · `supercharge` · bait questions ("Tired of slow deploys?") · "not X, just Y" · forced lowercase as a style · "Excited to share".

The `marketing` skill is the canonical owner of voice and distribution; this ban-list is the on-page enforcement of its rules.

## SEO-aware copy

A structural constraint, not a keyword strategy — defer depth to `seo`.

- Title 50–60 characters; meta description 120–160.
- Put the primary keyword in the `<h1>` naturally, not stuffed.
- Use scannable `<h2>`/`<h3>` subheads that double as answers to likely queries.
- Front-load the benefit in the first 160 characters so search snippets read well.

## See Also

- `landing-anatomy-and-cro.md` — where each piece of copy lands on the page.
- `brand-grounding.md` — where the voice/positioning that drives this copy is captured and persisted.
- `marketing` — canonical owner of voice, full landing copy, launch and channel adaptation.
- `seo` — keyword research and technical SEO.
