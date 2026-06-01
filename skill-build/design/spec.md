# DESIGN SPEC — skill `design`

Title: World-class product design, landing pages & conversion copywriting
Skill id: `design` · origin: `risco`
Audience: an LLM coding agent loading this skill while working in a real repo
(FastAPI/Python, Next.js 15 App Router, Go 1.22+, Flutter/Dart 3, PostgreSQL 16).
Write FOR that agent: directive, dense, copy-pasteable, research-first.

Calibration floor: ECC `design-system`, `frontend-design-direction`,
`make-interfaces-feel-better`, `motion-ui`, `motion-foundations`, `brand-voice`,
`seo`, `content-engine`, `product-lens`, `liquid-glass-design`. This skill must
match or exceed their density and be MORE current (Tailwind v4.1 / OKLCH-native,
Next.js 15 + React 19, INP not FID, bento-as-standard, scroll-driven CSS).

---

## 1. Purpose & precise trigger

**Purpose (one line):** Research current best-in-class work first, then ship a
modern, premium, high-converting UI / landing page / marketing copy that passes
WCAG and Core Web Vitals as hard constraints.

**Frontmatter `description` (trigger-rich, starts with "Use when"):**
> Use when designing a modern UI, building a high-converting landing page,
> crafting marketing or value-prop copy, refreshing a hero, choosing
> type/color/spacing/motion, or making an interface feel premium instead of
> generic/AI-templated. Research-first: studies award-winning current work
> (Awwwards, Godly, Land-book, Refactoring UI, Linear/Stripe/Vercel-tier) before
> prescribing. Ships Tailwind v4 + Next.js 15 patterns with WCAG and Core Web
> Vitals (LCP/INP/CLS) as design constraints. Triggers: "design a landing page",
> "make this look premium", "write the hero copy", "pick a color palette", "this
> UI feels generic", "conversion copywriting", "bento section", "design review".

**When to use:** new landing/marketing page; redesign or polish pass; hero /
value-prop / pricing / FAQ copy; choosing a visual system (type, color, spacing,
radius, shadow, motion); "feels generic / AI-slop" rescue; pre-launch design QA.

**When NOT to use (delegate / decline):**
- Pure backend/data/infra work with no UI surface → no.
- Dense internal operational tooling that needs daily repeated use, not a sales
  page → use product-domain judgment from `frontend-design-direction`, do not
  force a landing-page composition (call this out explicitly in SKILL.md).
- iOS/SwiftUI Liquid Glass native material → defer to ECC `liquid-glass-design`;
  this skill covers the *web* glass approximation only.
- Implementing the motion *code mechanics* in depth (springs, AnimatePresence
  internals) → this skill sets motion *intent + budget*; point to the repo's
  motion skill / `motion-and-interaction.md` for mechanics.
- Deep keyword research / technical SEO audit → defer to ECC `seo`; this skill
  only enforces SEO-aware structure (one H1, semantic landmarks, metadata,
  JSON-LD presence) as a design constraint.

---

## 2. SKILL.md outline (every H2/H3 + delivery note + examples)

Target length ~250–450 lines. One H1. Progressive disclosure: anything long goes
to `references/`. Every code block has a language tag. Good/Bad contrasts
throughout.

### H1: `# Design — Product UI, Landing Pages & Conversion Copy`

One-line purpose immediately under H1: "Research the best current work, then ship
a premium, accessible, fast, high-converting interface."

### H2: `## When to use / When NOT to use`
Two tight bullet lists mirroring §1. Includes the "tool vs. landing page"
caveat and the delegate-to-siblings table. No code.

### H2: `## The non-negotiables (read first)`
A dense rules block — the spine of the skill. Delivers ~10 iron rules:
1. **Research before you prescribe.** Run the research protocol; never ship from
   stale memory. (-> `references/research-method.md`)
2. Value prop legible in **5 seconds** above the fold.
3. **One H1 per page**; semantic landmarks (`header/nav/main/section/footer`).
4. Core Web Vitals are design constraints, not afterthoughts: **LCP < 2.5s,
   INP < 200ms, CLS < 0.1**. (Note: INP replaced FID in 2024 — current.)
5. WCAG 2.2 AA: **4.5:1** text contrast (3:1 large/UI), visible focus, 44px
   targets, `prefers-reduced-motion` honored.
6. Use **design tokens** (Tailwind v4 `@theme` → CSS vars), never magic numbers.
7. Spacing on a **4/8px scale**; type on a modular scale; **60-30-10** color.
8. Motion must guide attention, communicate state, or preserve continuity — else
   delete it (inherits the motion skills' rule, stated once).
9. Copy is **benefit-led and specific**; no hype/fluff; ban-list enforced.
10. Match the **product domain** — don't paint a marketing skin on a dense tool.
No code; this is the contract.

### H2: `## Decision rules (pick a direction first)`
Delivers a 5-question direction brief (Purpose / Audience / Tone / one memorable
detail / Constraints) — sharper than `frontend-design-direction`, framed as fill-in.
Then a **decision table**: project type → composition + density + motion budget
(SaaS marketing / dev tool / dashboard / portfolio / e-commerce / docs). No code.

### H2: `## Research-first protocol`
~10 lines: the loop (define references → WebSearch award galleries + tier-1
sites → WebFetch 3–5 exemplars → extract type/color/layout/motion patterns with
citations → synthesize a one-paragraph direction → only THEN build). States the
gallery URLs (Awwwards, Godly.website, Land-book, Refactoring UI, Mobbin) and
"re-research per project." Pointer to `references/research-method.md`. No code
(the worked example lives in the reference).

### H2: `## Visual system in 90 seconds`
Condensed, copy-pasteable foundation. Delivers:
- **Tailwind v4 `@theme` token block** (current syntax: tokens in CSS, OKLCH
  palette, no `tailwind.config.js` needed) — Good example.
- **Type scale + pairing** snippet (`next/font` with one display + one text face,
  fluid `clamp()` scale).
- **Spacing/radius/shadow tokens** one-liners.
- Good/Bad contrast: arbitrary hex + random px **(Bad)** vs token refs **(Good)**.
Deep dive → `references/visual-system.md`.

```css
/* Good — Tailwind v4 @theme, OKLCH, tokens become CSS vars automatically */
@import "tailwindcss";
@theme {
  --color-brand-500: oklch(0.62 0.19 256);
  --color-bg:        oklch(0.99 0 0);
  --color-fg:        oklch(0.21 0.01 256);
  --font-display:    "Geist", ui-sans-serif, system-ui, sans-serif;
  --radius-card:     0.875rem;
  --shadow-card:     0 1px 2px oklch(0 0 0 / 0.06), 0 8px 24px oklch(0 0 0 / 0.08);
}
```

### H2: `## Landing page build recipe ("the brutal landing")`
The actionable centerpiece. Delivers an ordered section stack with the *job* of
each section and copy framework attached:
Hero (value prop, 5s) → social proof strip → problem/agitation → solution →
features→benefits (bento) → objection handling → pricing → FAQ → final CTA.
Includes ONE compact, correct **Next.js 15 + React 19 + Tailwind v4 hero**
(Server Component, `next/image` `priority` on LCP, `next/font`, semantic, a11y,
no CLS) as a copy-pasteable Good block. Full anatomy → `references/landing-anatomy-and-cro.md`;
copy → `references/copywriting-frameworks.md`.

```tsx
// app/page.tsx — Server Component, LCP-safe hero (Next.js 15 / React 19)
import Image from "next/image";
export default function Page() {
  return (
    <main>
      <section className="mx-auto max-w-5xl px-6 pt-24 text-center">
        <h1 className="text-balance text-5xl font-semibold tracking-tight md:text-6xl">
          Ship the change in an afternoon, not a sprint
        </h1>
        <p className="mx-auto mt-5 max-w-xl text-pretty text-lg text-fg/70">
          Concrete benefit + who it is for + why now. No hype.
        </p>
        <a href="#start" className="mt-8 inline-flex min-h-11 items-center rounded-card bg-brand-500 px-6 font-medium text-white">
          Start free
        </a>
        <Image src="/hero.avif" alt="Product dashboard" width={1200} height={720} priority className="mt-16 rounded-card shadow-card" />
      </section>
    </main>
  );
}
```

### H2: `## Conversion copy in one pass`
Delivers: the 5s value-prop test; headline formula slots; PAS/AIDA picker (one
line each: PAS for pain-aware cold traffic, AIDA for broad, FAB/JTBD for
feature→benefit); CTA microcopy Good/Bad; the **ban-list** (no "revolutionary /
game-changer / cutting-edge / In today's landscape / unlock / seamless / elevate /
supercharge", no bait questions — aligned with ECC `brand-voice`/`content-engine`).
Good/Bad headline contrast. Deep dive → `references/copywriting-frameworks.md`.

### H2: `## Motion & interaction budget`
Delivers the *intent + budget* layer (mechanics deferred): purposeful-only rule;
timing defaults (enter 200–350ms, exit ~150ms, press `scale(0.97)`); never
`transition: all`; compositor-only props (transform/opacity/filter);
`prefers-reduced-motion` required; scroll-driven via **CSS `animation-timeline:
view()`** first (no JS, no CLS) before reaching for a JS lib. One Good CSS
scroll-reveal snippet + the reduced-motion guard. Deep dive →
`references/motion-and-interaction.md`.

```css
/* Good — native scroll-driven reveal, zero JS, respects reduced motion */
@media (prefers-reduced-motion: no-preference) {
  .reveal { animation: reveal linear both; animation-timeline: view(); animation-range: entry 0% cover 30%; }
}
@keyframes reveal { from { opacity: 0; translate: 0 16px; } to { opacity: 1; translate: 0 0; } }
```

### H2: `## Premium details that compound`
The "feels-better" layer, denser/more current than ECC `make-interfaces-feel-better`:
concentric radius (`outer = inner + padding`), optical alignment, layered
transparent shadows, `text-wrap: balance/pretty`, `tabular-nums`, font-smoothing,
neutral image outlines, **tasteful glass** (backdrop-blur + 1px hairline border +
subtle noise — never on everything), borders > heavy shadows for separation. A
compact Good/Bad table of each detail. Short snippets only; rest →
`references/visual-system.md`.

### H2: `## Anti-patterns / rationalizations -> STOP`
Two-column table (Rationalization → Reality/Fix), calibrated to beat ECC. Rows
e.g.: "purple→blue gradient on everything" → pick a domain-true palette;
"centered text over stock atmospheric gradient" → show the product; "cards inside
cards"; "I'll skip research, I know good design" → re-research, taste ≠ current
trend; "hero copy can be vague, the image sells it" → fail the 5s test; "animate
everything on scroll" → CLS + INP cost; "ship now, check contrast later" → it's a
constraint, not polish; "glass everywhere"; "`transition: all`".

### H2: `## Quick reference`
One scannable table: lever → default → token/where.
(Type scale `1.25` ratio · Body 16–18px · Line-height 1.5 body / 1.1 display ·
Spacing 4/8 · Color 60-30-10 · Contrast 4.5:1 · Radius card `0.875rem` · Target
44px · Enter 250ms / Exit 150ms · LCP<2.5s · INP<200ms · CLS<0.1 · Hero=5s test.)

### H2: `## Design-review QA checklist`
~14 binary checks (the same list `verify.sh` falls back to) covering value-prop
5s, contrast, focus, targets, reduced-motion, one-H1, semantic landmarks, LCP
image `priority`, font CLS, no `transition: all`, tokens-not-magic-numbers,
ban-list clean, responsive text fit, empty/loading/hover states. Pointer to
`scripts/verify.sh`.

### H2: `## See Also`
Links: `frontend-design-direction` (domain direction), `make-interfaces-feel-better`
(polish), `motion-ui` / `motion-foundations` (motion mechanics), `brand-voice` +
`content-engine` (voice/distribution), `seo` (technical SEO), `product-lens`
(validate the why first), `liquid-glass-design` (native iOS glass), and the repo's
nextjs skill for stack implementation. Plus the five `references/` files.

---

## 3. references/ files — outline + key code

### `references/research-method.md` (~200–260 lines)
The research-first engine. Outline:
- **Why re-research every project** (trends churn; memory is stale; the agent's
  default taste skews AI-generic).
- **The loop** (numbered): define 2–3 reference archetypes → WebSearch galleries
  + tier-1 product sites → WebFetch 3–5 exemplars (prompt them for type, color,
  layout, motion, copy voice) → extract a pattern table → synthesize a one-para
  direction with citations → build → re-check against references in QA.
- **Source map** table: Awwwards / Godly.website / Land-book / Mobbin / Refactoring
  UI / Linear / Stripe / Vercel / Cursor / Resend — what to mine from each.
- **Synthesis template**: a fill-in "DESIGN DIRECTION" block (archetype, type
  pairing, palette in OKLCH, layout system, motion budget, copy voice, citations).
- **Worked example**: a developer-tool landing brief produced end-to-end with 3
  cited references and the resulting token decisions.
- **Anti-pattern**: copying a reference pixel-for-pixel vs. extracting principles.
Code/example: the filled DESIGN DIRECTION block + a `WebSearch`/`WebFetch` call
sketch (as fenced `text`/`ts` pseudo-calls) showing the prompts to use.

### `references/visual-system.md` (~320–460 lines)
The full design-token + aesthetics system. Outline:
- **Spacing scale** (4/8 base, full ramp) + when to break it.
- **Typographic scale**: modular ratios (1.2 / 1.25 / 1.333), fluid `clamp()`
  generator, line-height/measure (45–75ch) rules, pairing strategy (one display +
  one text, or one superfamily), `next/font` setup with `display: "swap"` and
  fallback metrics to kill CLS.
- **Color theory**: OKLCH explained (perceptual lightness, P3 gamut), building a
  ramp by holding hue/chroma and stepping L, 60-30-10 allocation, semantic tokens
  (`bg/fg/muted/brand/accent/destructive`), **accessible contrast** (compute &
  verify 4.5:1), dark mode via token swap (not per-component overrides),
  gradients & mesh done tastefully, when NOT to gradient.
- **Grid & layout**: 12-col vs container queries (Tailwind v4 core), **bento**
  recipe (asymmetric `grid-template-areas`, focal cell, why it scans better — now
  an industry standard), asymmetry/optical balance, max-width + reading measure.
- **Depth**: layered transparent shadows recipe, radius scale + concentric rule,
  hairline borders, **tasteful glass** (`backdrop-blur` + border + noise),
  film-grain/noise via SVG, when depth becomes slop.
- **Design tokens end-to-end**: the canonical Tailwind v4 `@theme` block (colors,
  type, spacing, radius, shadow, easing) → consumed as utilities AND raw CSS vars;
  light/dark; a `tokens.json` mirror for cross-tool/Flutter parity.
Key code: full `@theme` token file; `next/font` config; OKLCH ramp; bento grid
Tailwind markup; glass card; contrast-check note. Good/Bad pairs throughout.

### `references/landing-anatomy-and-cro.md` (~320–460 lines)
The CRO playbook. Outline:
- **Above the fold**: the 5s test, F vs Z scan patterns, what must be visible.
- **Section-by-section anatomy** (job + copy framework + a11y + the conversion
  principle each serves): Hero · logo/social-proof strip · problem/agitation ·
  solution · features→benefits (bento) · how-it-works · testimonials/case studies
  · objection handling · pricing · FAQ · final CTA · footer.
- **CTA strategy**: primary/secondary hierarchy, placement cadence (above fold +
  after value + after price + sticky on mobile), one primary action per viewport,
  microcopy.
- **Pricing psychology**: anchoring, 3-tier with highlighted middle, annual
  default, value framing not feature dumps, decoy effect, money-back risk reversal.
- **Social proof**: logos, quantified testimonials, metrics, trust badges, where.
- **Objection handling + FAQ**: surface real objections, `FAQPage` JSON-LD only
  when content matches (aligns with ECC `seo`).
- **A/B mindset + instrumentation**: one hypothesis at a time, what to measure
  (CVR, scroll depth, INP at CTA), event hooks.
- **SEO-aware structure constraint**: one H1, semantic landmarks, metadata,
  breadcrumb/Article/Product JSON-LD presence (defer depth to `seo`).
Key code: full Next.js 15 landing skeleton (semantic sections + Metadata API +
JSON-LD) ; sticky-mobile-CTA pattern; 3-tier pricing Tailwind markup.

### `references/copywriting-frameworks.md` (~300–440 lines)
The marketing-copy engine. Outline:
- **The 5s value-prop test** + value-proposition canvas (jobs/pains/gains →
  pain-relievers/gain-creators → headline).
- **Frameworks with picker**: PAS, AIDA, FAB, BAB, JTBD — when each wins, one
  worked rewrite each (Bad generic → Good specific).
- **Headline formulas**: outcome+timeframe, "X without Y", JTBD, specificity over
  cleverness; subhead job (who + how + proof).
- **Benefit-led specificity**: feature→benefit→proof ladder; numbers/receipts >
  adjectives (aligns with `brand-voice`).
- **Microcopy & CTA copy**: button verbs, value-on-the-button, form labels, error
  states, empty states, loading copy.
- **Voice/tone system**: a small reusable VOICE block (consumes `brand-voice` if
  present), tone sliders, do/don't.
- **The ban-list** (hype words, bait questions, "not X, just Y", forced
  lowercase, "Excited to share") — shared with ECC content skills, stated once.
- **SEO-aware copy**: title 50–60 chars, meta 120–160, keyword-in-H1 naturally,
  scannable subheads — constraint only, depth → `seo`.
Key code: filled value-prop canvas; 4–5 Bad→Good copy rewrites; a CTA microcopy
table; a reusable VOICE block.

### `references/motion-and-interaction.md` (~280–420 lines)
Motion intent + mechanics, current-first. Outline:
- **Purpose gate** (guide/communicate/preserve — else delete), inherited once.
- **Timing & easing tokens**: durations (instant 80 / fast 180 / normal 280 /
  slow 600ms), easings (`cubic-bezier(0.22,1,0.36,1)` standard, sharp, bounce),
  enter vs exit asymmetry, press `scale(0.97)`.
- **Micro-interactions**: hover/active/focus, button press, icon cross-fade,
  optimistic state, toast, skeleton.
- **Scroll-driven, CSS-first**: native `animation-timeline: view()` /
  `scroll()` (baseline-ish 2024+, no JS, no CLS) as the default; parallax via
  scroll timeline; **only** reach for `motion/react` when you need
  orchestration/layout/exit — then defer mechanics to the repo motion skill.
- **Performance budget**: transform/opacity/filter only; never animate
  width/height/top/left; `will-change` sparingly; INP cost of scroll handlers;
  content-visibility for offscreen.
- **Accessibility**: `prefers-reduced-motion` (CSS + JS), no motion-only meaning,
  pause controls for loops, vestibular safety (cut large translate/parallax).
Key code: scroll-driven CSS reveal + parallax (no JS); reduced-motion guards
(CSS + a JS `matchMedia` snippet); button press transition with explicit
`transition-property`; one minimal `motion/react` example flagged as "only when
CSS can't express it, see motion skill."

---

## 4. verify.sh contract

Path: `skills/design/scripts/verify.sh`. Executable, idempotent, END-USER runs it
inside THEIR project. Do NOT run it in this repo.

- Shebang `#!/usr/bin/env bash`; `set -euo pipefail`; top usage comment block
  (what it does, how to run, that missing tools are skipped not failed).
- **Never fail hard on tooling absence.** Helper `warn()` prints a yellow
  `[skip]` line; helper `ok()`/`fail()` for real results. Exit non-zero ONLY on a
  genuine design/perf failure that the user asked to gate on; default exit 0 with
  a summary.
- **Tool detection order** (each guarded by `command -v`, skip+warn if missing):
  1. Parse args: optional `--url <url>` (default `http://localhost:3000`),
     `--strict` (turns soft warnings into a non-zero exit).
  2. **lighthouse** (or `npx --no-install lighthouse`): if present AND a URL is
     reachable (`curl -sf --max-time 3`), run a categories=performance,accessibility
     run to JSON in a temp dir; extract LCP, CLS, INP/TBT proxy, a11y score with
     `node -e`/`jq` (prefer `jq`, fall back to `node`); print PASS/FAIL vs
     thresholds (LCP<2.5s, CLS<0.1, a11y≥0.9). If no URL reachable → skip with
     guidance to start the dev server.
  3. **Static design-review checks** (always run; pure grep/ripgrep, no network):
     - more than one `<h1` in a page/route file → warn.
     - `transition: all` / `transition-all` present → warn.
     - hardcoded hex colors in component files when a token system exists → warn
       (heuristic, low-confidence → soft).
     - `<img` without `alt=` / `next/image` without `alt` → warn.
     - missing `prefers-reduced-motion` block when keyframes/animations exist →
       warn.
     - ban-list marketing words in page copy (`revolutionary|game-?changer|
       cutting-edge|supercharge|seamless|unlock`) → warn.
     Each check prints file:line evidence; uses `rg` if available else `grep -rn`.
  4. **Embedded checklist fallback**: if neither lighthouse nor a reachable URL,
     print the 14-point design-review checklist (same as SKILL.md) for the human
     to self-verify, exit 0.
- Summary line at the end: counts of `ok / skip / warn / fail`. Exit non-zero
  only if `fail>0`, or if `--strict` and `warn>0`.
- After writing: `chmod +x`. Markdown/code lint clean. No placeholders.

---

## 5. Quality differentiators (why this beats the ECC equivalents)

1. **Research-first is enforced, not assumed.** A real WebSearch/WebFetch loop
   with a citation-bearing synthesis template — ECC `design-system` only mentions
   "research 3 competitors via browser MCP" in passing. This is the spine.
2. **Current by construction.** Tailwind **v4.1 `@theme`/OKLCH-native** (no
   `tailwind.config.js`), **Next.js 15 + React 19** Server Component hero, **INP
   (not FID)**, native **`animation-timeline: view()`** scroll-driven CSS, bento
   treated as a 2026 standard — the ECC motion/design skills predate all of this.
3. **One skill spans design + CRO + copy + motion + a11y + CWV**, cross-linked
   instead of ten siblings that each cover a slice. The agent gets a hero that is
   simultaneously beautiful, accessible, fast, and persuasive in one pass.
4. **Performance & accessibility are stated as design *constraints* with hard
   numbers** (LCP<2.5s, INP<200ms, CLS<0.1, 4.5:1, 44px) wired into both the
   non-negotiables and an executable `verify.sh` — ECC treats them as review-time
   afterthoughts.
5. **CSS-first motion.** Defaults to zero-JS scroll-driven animation (no CLS, no
   INP hit) and only escalates to `motion/react` when CSS can't express it —
   stronger performance posture than `motion-ui`/`motion-foundations`, which jump
   straight to the JS library.
6. **Concrete, runnable artifacts**: a full "brutal landing" section recipe, a
   copy-pasteable LCP-safe hero, a bento grid, 3-tier pricing, a value-prop
   canvas, and Bad→Good copy rewrites — vs. ECC's mode-list/bullet abstraction.
7. **Domain-honesty guardrail.** Explicit "tool vs. landing page" rule and a
   project-type→composition decision table prevent the #1 AI failure (slapping a
   marketing skin on a dense internal tool) — sharper than `frontend-design-direction`.
8. **Anti-slop is operational, not vibes.** A rationalizations→STOP table plus a
   grep-driven slop detector in `verify.sh` (purple gradients, `transition: all`,
   hype ban-list, cards-in-cards, missing reduced-motion) make "don't be generic"
   checkable.
