# Slide Design — Communication Design, Visual System, Data Viz & Motion

How a slide *communicates*, *looks*, and *moves*. The brand's visual system from `../design/SKILL.md`,
re-tuned for the worst viewing conditions a deck faces: a projector, a bright room, the back row, a glance.
Defer the token *system* (OKLCH palette, type pairing, spacing scale, motion personality) to `design`; this
file is the deck-specific application. Good/Bad contrasts throughout.

The first half is the **communication layer** — assertion-evidence structure, cognitive load, and what you
*show* vs *say*. The second half is the **visual layer** — grid, type, color, data viz, motion. Get the
communication right first; a beautiful slide that says nothing still fails.

## Design first: audience, message, evidence

Before a grid or a color, answer six planning questions. The deck serves the *audience's* understanding,
not the presenter's comfort — that is the one principle every other rule descends from.

1. **Who, specifically, is the audience?** Their existing knowledge sets the floor and ceiling for what you can assume.
2. **What is the ONE main message?** One sentence they should remember a week later. If you can't write it, the deck has no spine.
3. **What 3–5 supporting points** carry that message, and in what order do they build?
4. **What evidence** (a number, a chart, a demo, an example) proves each point?
5. **What action** should the audience take — the single call-to-action the deck climbs toward?
6. **What is essential vs. expandable** under time pressure? Mark each point so a 30-minute deck collapses to 10 without losing the spine.

This maps onto the deck arc and slide skeleton in `storytelling-and-decks.md`: the one message is the
thesis, the supporting points are the act beats, the CTA is the closing ask. Plan here, storyboard there.

## Assertion-evidence: the headline IS the slide

The single highest-leverage structural move in the whole skill. **Each slide is one assertion (a complete
sentence stating the point) plus the visual evidence that proves it** — never a topic label over a bullet list.

- **Assertion** = the slide title, written as a full claim: *"User engagement rose 43% after the redesign"*, not *"Engagement"* or *"Key findings"*.
- **Evidence** = the visual that backs it: the chart, the diagram, the screenshot, the one number. The body proves the headline; it does not repeat it.
- If a slide's content is a bullet list, ask whether it should be a slide at all, or whether each bullet is really its own assertion-evidence slide.

> **Good:**
> ```text
> Title:  "User engagement rose 43% after the redesign"
> Body:   [line chart, pre→post, the post point highlighted]
> ```
> **Bad:**
> ```text
> Title:  "Key findings"
> Body:   • Data shows an increase
>         • Users engaged more
>         • Revenue improved
> ```

## Cognitive load: one concept per slide

Working memory is tiny and the audience is also listening to you. Every slide must pass one test: *"What
is the ONE thing I want them to take from this?"* If there are two answers, it is two slides.

- **One concept per slide.** A slide that needs two breaths to explain is two slides.
- **Progressive disclosure** when a concept genuinely has sequential parts: show the initial state, then add element one with context, then element two building on it. Build order *is* the explanation — the audience looks where you are, not three bullets ahead. (This is the legitimate use of motion; see the Motion section.)
- **Text density is a ceiling, not a target** (see the limits table below). Less on the slide means more attention on you.
- **Code on technical slides:** always syntax-highlight; highlight the one critical line; build complex examples up; strip boilerplate that isn't the point.

## Spoken vs. shown

The slide and your mouth are two channels, not one. Redundancy wastes both. Reading the slide verbatim is
the fastest way to lose a room — they read faster than you talk, finish, and tune out.

| Put on the slide | Say out loud |
| --- | --- |
| The assertion (headline) | The elaboration and nuance |
| The visual evidence | The context and the how |
| The critical number | Its interpretation — why it matters |
| The next step / CTA | The story that earns it |

> **Good:** slide shows a chart and one claim; you narrate the backstory, the caveat, and the implication.
> **Bad:** slide holds your full script in bullets; you read it aloud; the audience read it 20 seconds ago.

## The core constraint: legible from the back of the room

A web page is read at 50cm. A deck is read at 3–10 metres, often off a washed-out projector, sometimes for 5
seconds before you click. Design for the *worst* case.

- **Body text ≥ 24pt; ≥ 28–32pt for a conference talk.** Title 40–60pt. Caption ≥ 18pt. Never shrink text to fit — split the slide.
- **~6 words per line, ~6 lines per slide** as a *ceiling*. Less is more. A keynote slide is often one line.
- **Contrast ≥ 4.5:1** for text (the WCAG AA floor), higher is better on a projector. Check both your dark and light themes.
- **One focal point per slide.** The eye should land in one place. If everything is bold, nothing is.
- **Negative space is not wasted space** — it's what makes the one thing readable. Crowded slides read as filler.

> **Good:** `OnboardingChurn-40%` in 54pt over a clean field, one supporting chart.
> **Bad:** a 14pt 9-bullet slide the presenter reads aloud while the back row squints.

## Layout grid for 16:9

- **12-column grid**, consistent gutters, generous outer margin (~7% / ~0.9"). Define a **safe area**; keep all important content inside it so nothing clips on a projector or in PPTX export.
- **One layout family**, reused: title, section divider, statement, content (headline + one visual), two-column (text|visual), full-bleed image, big-number, chart, quote, agenda/closing. Consistency reads as polish.
- **Align to the grid.** Ragged left edges and floating boxes read as amateur. Snap to columns.
- **Headline anchored top-left** (or centered for statements); visual occupies the focal zone; caption/source small and quiet at the bottom.

## Type for projection

- **Two type roles max:** a display face for headlines (personality) + a clean sans for body (legibility). Pull the exact pairing from the design tokens; don't introduce new fonts per deck.
- **A real type scale** (e.g. display 60 / h1 44 / h2 32 / body 26 / caption 18) — steps, not arbitrary sizes. One scale across the whole deck.
- **Weight for hierarchy**, not just size: bold the assertion, regular the support. Avoid all-caps for long strings (hard to read at distance); reserve it for short labels.
- **Numbers are the message** in data decks — set big numbers in display size; the label small beside them.

> **Good:** one display font for headlines, one sans for body, four sizes total.
> **Bad:** four fonts, random sizes, italic + underline + color all at once.

## Color: dark vs light decks, allocated for a room

- **Dark deck** (dark surface, light text): better for dark rooms, big LED/LCD screens, on-stage; reduces glare; feels premium. Default for keynotes/launches.
- **Light deck** (light surface, dark text): better for **printed handouts**, bright rooms, documents that double as leave-behinds, and projectors that wash out darks. Default for board/QBR leave-behinds.
- **Build both from the same tokens** (a `.dark` / `.handout` class in Marp/Slidev; two masters in PPTX). Keep contrast ≥ 4.5:1 in each.
- **60-30-10 allocation:** ~60% surface, ~30% ink/text, ~10% one accent for emphasis. The accent marks the *one* thing that matters per slide.
- **Never encode meaning by color alone** (color-blind audiences, washed-out projectors): pair color with label, position, or shape.

> **Good:** dark navy deck, off-white text, a single amber accent on the one number that matters.
> **Bad:** five competing brand colors per slide, a gradient behind every headline, low-contrast gray-on-gray.

## Data visualization: one chart, one point

The single biggest credibility lever in a data deck. **Every chart makes exactly one point, and that point is
the slide's headline.** If the chart needs a legend decoder ring, it's failing.

- **Name the takeaway in the headline** ("Revenue 3×'d in four quarters"), then let the chart prove it.
- **Pre-attentive emphasis:** gray out everything, highlight the **one** bar/line/point in the accent color. The eye goes there first.
- **Strip the clutter:** no gridlines (or one faint baseline), no chart border, no redundant legend for a single series, minimal axis ticks. Maximize data-ink.
- **Direct-label** lines/bars instead of forcing a legend lookup. Put the value at the end of the line.
- **Honest axes:** start bars at zero; don't truncate to exaggerate; one axis, not dual axes; consistent scales across comparable slides.
- **Pick the right chart:** trend over time → line; comparison across categories → bar; part-of-whole (≤ 4 parts) → a single bar or simple pie; correlation → scatter. **Never a 3-D chart, never a rainbow palette, never a pie with 8 slices.**
- **Big-number slide** for a single hero metric: the number in display size, one line of context, source in the caption. Often more powerful than any chart.

> **Good:** one line chart, four labeled points, the final point in accent, no gridlines, headline states the result.
> **Bad:** a 3-D stacked bar with 7 series, a rainbow legend, dual y-axes, and a title that just says "Metrics".

In Marp/Slidev, draw charts as SVG/chart-lib/images; in python-pptx use **native editable charts** (see
`pptx-python.md`) so the data lives in the file.

## Imagery

- **Full-bleed and intentional**, not decorative stock. One strong image > three small clip-art ones.
- **Always put a legibility scrim** (a dark/light gradient or solid overlay) behind text on a photo, or the text disappears against busy areas.
- **Resolution matters at 4K** — use images large enough not to pixelate on a big projector; prefer SVG for logos, icons, and diagrams (infinite scale, tiny file).
- **Consistent treatment** — one duotone/filter/crop style across the deck, from the brand imagery mood in the design tokens. Mixed photo styles read as a collage, not a brand.
- **Diagrams over screenshots** when explaining a system; a labeled, simplified diagram beats a dense UI capture nobody can read from row 10.

> **Good:** one full-bleed product shot, dark gradient scrim bottom-left, white headline over it.
> **Bad:** three pixelated stock photos of "teamwork", logos at random sizes, a screenshot too small to read.

## Motion & transitions — with restraint (a deck is not a video)

Motion clarifies sequence and state change; it does not fill time. Applies to HTML pipelines (Marp/Slidev
presenting) and to the build order you control in PPTX.

- **One transition family** for the whole deck (e.g. a quick `fade` or a subtle slide), ≤ 300ms. Mixing transition types per slide is noise.
- **Builds reveal one idea at a time.** Use `v-click` (Slidev) / fragment reveals to show bullets or chart series sequentially when sequence *is* the point — so the audience looks where you're talking, not ahead. Don't animate for the sake of it.
- **Animate to explain, not to decorate:** a value changing, a step being added, an old→new comparison. If the motion doesn't carry meaning, cut it.
- **Honor `prefers-reduced-motion`** in HTML decks — disable non-essential animation. (Irrelevant in the static PDF, which is why PDF is the safe leave-behind.)
- **Pacing:** statement slides reset attention after a heavy data slide; don't run ten dense slides in a row.

Borrowed-from-motion-tools ideas, applied to slides (NOT to turn this into a video):
- **Progressive reveal** of a diagram (show the current state, then the optimized state) — clarifies a transformation.
- **One highlighted element** entering/emphasizing — directs the eye, the slide equivalent of pre-attentive color.
- **Spring/ease on the single transition** for a premium feel — subtle, fast, consistent.

> **Good:** one fade transition deck-wide; a 3-step diagram builds one step per click; reduced-motion honored.
> **Bad:** spin/zoom/bounce transitions varying per slide, every bullet flying in from a different edge, 1.5s animations that make the audience wait.

## Content density limits (ceilings, not targets)

| Slide type | Limit |
| --- | --- |
| Title | 1 headline + 1 subtitle (+ optional tagline) |
| Statement | 1 line, big |
| Content | 1 assertion headline + ≤ 3 support points / 1 visual |
| Two-column | headline + text (≤ 4 points) \| one visual |
| Big number | 1 metric (display size) + 1 line context + source |
| Chart | 1 chart, 1 takeaway (named in headline), source caption |
| Quote | 1 quote + attribution |
| Image | 1 full-bleed image + scrim + ≤ 1 line of text |

## Diagnostic rubric (score 1–5, aim ≥ 4 each)

Use this to *evaluate* a deck — your own draft or one you're asked to review. Score each criterion 1
(failing) to 5 (exemplary); anything below 4 is a fix before shipping. The four axes match the QA gate
the `verify.sh` checklist points back to.

**1. Audience-centered design** — *does every choice serve the audience?*

| Criterion | 1–5 |
| --- | --- |
| Content matches the audience's knowledge level | |
| One clear main message + a value proposition for *them* | |
| Adaptable to time constraints (essential vs. expandable marked) | |
| Structure/order aids understanding rather than the presenter's notes | |

Red flags: presenter-focused not audience-focused; no read on existing knowledge.

**2. Visual clarity** — *does the eye land on the point?*

| Criterion | 1–5 |
| --- | --- |
| Assertion-evidence structure (claim + visual), not topic + bullets | |
| Visual elements balance text; one focal point per slide | |
| Visual hierarchy guides attention (weight, size, accent) | |
| Consistent layouts/treatment; deliberate whitespace | |

Red flags: bullet-point overuse; text-heavy slides; cluttered layouts.

**3. Cognitive load** — *can working memory keep up while listening?*

| Criterion | 1–5 |
| --- | --- |
| One key concept per slide | |
| Text density under the ceiling; slide ≠ script | |
| Animation judicious (disclosure/emphasis only) | |
| Code formatted; critical line highlighted (if applicable) | |
| Supporting detail accessible (appendix/notes), not crowding the slide | |

Red flags: multiple complex concepts per slide; text competing with speech; animation overuse.

**4. Accessibility** — *does it work for everyone, on any screen?*

| Criterion | 1–5 |
| --- | --- |
| Works across display sizes; reads from the back row | |
| Color contrast ≥ 4.5:1; meaning never color-only | |
| Inclusive imagery and language | |
| Font sizes appropriate (body ≥ 24pt; ≥ 28–32 for a talk) | |

Red flags: poor contrast; too-small fonts; non-inclusive content.

**Prioritize fixes:** (1) critical — blocks understanding, accessibility failure, message unclear;
(2) important — cognitive load, visual inconsistency, structure; (3) polish — animation, custom styling.

## Implementation checklist (build pass)

- **Structure:** main message clear in the first 2 minutes; supporting points in logical order; essential-vs-expandable marked; structure aids understanding.
- **Content:** assertion-evidence throughout; visual evidence backs each assertion; one concept per slide; code formatted and highlighted.
- **Visual:** consistent palette (3–5 colors); typography hierarchy (2–3 roles); deliberate whitespace; everything aligned to the grid.
- **Accessibility:** contrast verified; font sizes appropriate; alt text for key images; works across display sizes.

## Communication anti-patterns

These sit alongside the visual anti-patterns in `SKILL.md`; they fail at the *message* layer, before pixels.

| Anti-pattern | Why it fails | Fix |
| --- | --- | --- |
| **Data dump** — every slide raw data/charts, no interpretation | Audiences can't analyze in real time; without a stated conclusion they're doing your job; most is forgotten | One insight per slide; state the conclusion, show the proof; they grasp the point before the data |
| **Script reader** — slides hold the full spoken script as "bullets" | Audiences read faster than you talk, read ahead, then tune out | Slides show what you can't say; you say what you can't show |
| **Template trap** — content poured into a generic template | Design should serve comprehension, not just look professional; generic template → generic communication | Start from the communication need: what structure helps *this* audience understand *this* content? |
| **Animation circus** — transitions/builds/effects everywhere | Animation is attention; when everything animates, nothing stands out | Animate only for progressive disclosure or emphasis; default to none |
| **Bullet-point disease** — list after list as the default | Bullets are for documents; equal weight for unequal ideas; passive reading not active viewing | Assertion-evidence; if you truly need a list, question whether it earns a slide |

## Slide-design QA (the visual subset)

- [ ] Body ≥ 24pt (≥ 28–32 for a talk); reads at 3 metres; contrast ≥ 4.5:1.
- [ ] One focal point per slide; ≤ ~6 lines; generous negative space.
- [ ] Aligned to the grid; consistent safe-area; nothing clips on export.
- [ ] Two type roles, one scale, weight-for-hierarchy; no font soup.
- [ ] Colors from tokens, 60-30-10, one accent marks the one thing; meaning never color-only.
- [ ] Each chart makes one point named in the headline; decluttered; honest axes; no 3-D/rainbow.
- [ ] Imagery full-bleed + scrim, high-res, consistent treatment; SVG for logos/diagrams.
- [ ] One transition family ≤ 300ms; builds reveal meaning; reduced-motion honored (HTML).
- [ ] Dark/light variant chosen for the room (dark = stage, light = print/handout).
