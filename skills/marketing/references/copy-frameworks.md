# Copy Frameworks — Value Prop, PAS/AIDA/FAB/BAB/JTBD, Headlines, Microcopy & CTAs

The copy engine. The value proposition and voice come from the brand study (`brand-grounding.md`); this file turns them into headlines, section copy, microcopy, and CTAs. Every example pairs a `Bad` (generic / hype / vague) line with a `Good` (specific / benefit-led / human) rewrite — that contrast is the lesson.

## The 5s value-prop test

A stranger reads the hero and, within 5 seconds, can answer: **what is it, who is it for, why is it better?** If any answer is missing, the copy fails — rewrite the words before touching layout. The product image is `design`'s job; the answer must survive in text alone.

## Value-proposition canvas

Map the customer side, then your side, then compress the strongest match into a headline. Pull jobs/pains/gains straight from the brand study's audience article.

```text
VALUE-PROP CANVAS — Driftway (preview-environment CLI)
Customer jobs ...... ship a branch for review without breaking shared staging
Customer pains ..... staging is a shared queue; manual env setup eats an afternoon
Customer gains ..... reviewers click a link and see the real change, not a diff
Pain relievers ..... one CLI command spins an isolated env; auto-teardown on merge
Gain creators ...... every PR gets a live preview URL automatically
Headline ........... "Preview every branch — no staging queue"
Subhead ............ "One command gives every pull request a live URL. For platform
                      teams done babysitting staging."
```

The subhead's three jobs: state **who** it's for, **how** it works in one clause, and **proof** if you have it.

## Frameworks with a picker

Pick by traffic temperature and funnel position.

| Framework | Use when | Shape |
| --- | --- | --- |
| **PAS** (Problem-Agitate-Solution) | pain-aware cold traffic that already feels the problem | name pain → twist the knife → resolve |
| **AIDA** (Attention-Interest-Desire-Action) | broad / top-of-funnel; must earn attention first | hook → relevance → want → act |
| **FAB** (Feature-Advantage-Benefit) | feature sections; translate capability into outcome | what it is → what it does → why you care |
| **BAB** (Before-After-Bridge) | transformation stories, case studies | today's pain → the better world → the product as bridge |
| **JTBD** (Jobs To Be Done) | frame the product as the tool that finishes a job | when [trigger], [product] [gets job done] |

```text
PAS rewrite
Bad  — "Our platform streamlines environment management."
Good — "Staging is a queue. Every merge waits behind someone else's broken branch.
        Driftway gives each PR its own environment — no queue, no waiting."
```

```text
AIDA rewrite
Bad  — "Sign up for our developer tool today."
Good — "See your branch live in 30 seconds (Attention). It runs as one CLI step in your
        existing pipeline (Interest). Reviewers click a real URL, not a screenshot
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
Good — "Before: reviewers guess from a diff. After: they click a live URL and test the
        real thing. Driftway builds that URL on every push (Bridge)."
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
| Specificity | replace an adjective with a number | "Cut review setup from 20 min to 30 sec" |
| Negation of the cliché | name the thing they expect, then deny it | "No YAML. No on-call page. Just a deploy." |

Specificity beats cleverness — a clear claim outconverts a clever pun every time. Run every headline through the ban-list in `SKILL.md` plus the brand study's don't-words.

```text
Bad  — "Revolutionize your workflow with our seamless platform"
Good — "Ship a fix in 4 minutes — no YAML, no on-call page"
```

## Benefit-led specificity (the feature → benefit → proof ladder)

Climb feature → benefit → proof. Stop at the rung the visitor cares about (the benefit), and back it with proof.

```text
Feature ... "Isolated per-branch environments."
Benefit ... "Reviewers test the real change, not a screenshot."
Proof ..... "Northwind cut review setup from 20 min to 30 sec across 40 engineers."
```

The 2026 Feature-Benefit Transformation pattern, applied:

```text
Bad  — "Our platform has advanced encryption."
Good — "Encrypt customer data with AES-256, so your security team signs off in days,
        not months."
```

Numbers and receipts outperform adjectives. "Fast" is a claim; "30 seconds" is evidence. If you have no number, mark `[[NEEDS PROOF]]` and ask the user — never invent one.

## Microcopy & CTA copy

Buttons carry value verbs; reassurance sits under them; form labels are explicit; states stay human. (Pairing a CTA with a one-line reassurance — "No credit card required" — measurably lifts conversion.)

| Context | Bad | Good |
| --- | --- | --- |
| Primary CTA | "Submit" / "Learn more" | "Start free" / "Get my estimate" |
| Secondary CTA | "Click here" | "See a 2-min demo" |
| CTA reassurance | (none) | "No credit card required · Cancel anytime" |
| Form label | "Email" placeholder only | "Work email" with a persistent visible label |
| Field hint | (silence) | "We'll send the export here — no marketing." |
| Empty state | "No data" | "No previews yet — push a branch to create one." |
| Loading | "Loading…" | "Spinning up your environment…" |
| Success | "Success" | "Live. Your preview URL is ready below." |
| Error | "Something went wrong" | "Couldn't reach the API. Retry, or check status.acme.example." |
| Disabled CTA | (no reason) | "Add a work email to continue" (say why it's blocked) |

CTA rules:

- **Value on the button**, never the mechanic ("Start free", not "Submit").
- **One primary action per viewport.** A secondary ghost link may accompany it; never two equal-weight primaries.
- **Match the funnel stage** — cold traffic gets "See how it works", warm traffic gets "Start free".
- **Reassurance under the button** removes the last hesitation (risk, price, lock-in).

## Voice/tone application

The brand study's `voice.md` is the source of truth. Consume it; do not re-derive a voice here. A quick application checklist while drafting:

```text
APPLY VOICE (from 02-DOCS/wiki/brand/voice.md)
[ ] Tone descriptors honored (e.g. direct, dry, technical).
[ ] Do-words present where natural; don't-words absent.
[ ] Sentence rhythm matches the samples (compression vs. expansion).
[ ] Claims are made as sharply as the samples make them — no softer, no harder.
[ ] Reads like the same author wrote the samples AND this copy.
```

If a line would be out of character for the brand's samples, rewrite it — matching the voice is non-negotiable.

## SEO-aware copy structure

A structural constraint on the words, not a keyword strategy — defer depth to `seo`.

- Put the primary keyword in the `<h1>` naturally, not stuffed.
- `<h2>`/`<h3>` subheads double as answers to likely search queries.
- Front-load the benefit in the first ~160 characters so the search snippet reads well.
- Title 50–60 characters; meta description 120–160 characters (one honest sentence + the value).

## See Also

- `brand-grounding.md` — where the value prop, voice, and proof come from.
- `landing-copy.md` — where each piece of copy lands on the page.
- `campaigns-and-channels.md` — the copy beyond the page (email, launch, channels).
- `../../design/SKILL.md` — the visual treatment of every section.
- `seo` — keyword research and technical SEO.
