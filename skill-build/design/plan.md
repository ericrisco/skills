# IMPLEMENTATION PLAN — skill `design`

This plan is the verbatim build order for an implementer subagent. Follow it
top-to-bottom. Make NO independent design decisions; every file, section, bullet,
table, and code block is specified here. The source of truth is
`/Volumes/EXTERN/DEV/skills/skill-build/design/spec.md`. This plan operationalizes
it and resolves all ambiguity.

Quality bar: match or exceed the ECC reference skills (`design-system`,
`frontend-design-direction`, `make-interfaces-feel-better`, `motion-ui`,
`motion-foundations`, `brand-voice`, `seo`, `content-engine`, `product-lens`,
`liquid-glass-design`). Be MORE current: Tailwind v4.1 (`@theme`/OKLCH-native, no
`tailwind.config.js`), Next.js 15 App Router + React 19, INP (not FID), native
`animation-timeline: view()` scroll-driven CSS, bento as a 2026 standard.

Audience of the skill: an LLM coding agent loading it while working in a real repo
(FastAPI/Python, Next.js 15, Go 1.22+, Flutter/Dart 3, PostgreSQL 16). Write FOR
that agent: directive, dense, copy-pasteable, research-first.

---

## 0. Global conventions (apply to EVERY file you write)

- One `# H1` per markdown file. All subsequent headings are `##`/`###`. No skipped
  levels.
- EVERY fenced code block has a language tag: `tsx`, `ts`, `css`, `html`, `bash`,
  `json`, `text`, `dart`, `python`. Never a bare ```` ``` ````.
- Good/Bad contrasts use comment markers inside the block: `/* Good — ... */`,
  `/* Bad — ... */`, `// Good`, `// Bad`, `<!-- Good -->`. When showing both,
  Bad first then Good, OR two adjacent labelled blocks.
- Tables use GitHub pipe syntax with a header separator row.
- No placeholders, no `TODO`, no `etc.`, no `...` hand-waving inside code. Every
  snippet must be correct and runnable in its stated context.
- Cross-file links are relative: from `SKILL.md` use `references/<file>.md` and
  `scripts/verify.sh`; from a reference file link siblings as `<file>.md`.
- Sibling-skill links in "See Also" point to `../<skill-id>/SKILL.md` for skills
  that live in this repo (`../nextjs/SKILL.md`, `../fastapi/SKILL.md`,
  `../flutter/SKILL.md`, `../go/SKILL.md`, `../postgresdb/SKILL.md`,
  `../secure-coding/SKILL.md`) and by bare name for ECC siblings not in this repo
  (`frontend-design-direction`, `make-interfaces-feel-better`, `motion-ui`,
  `motion-foundations`, `brand-voice`, `content-engine`, `seo`, `product-lens`,
  `liquid-glass-design`).
- Tone: imperative, second person to the agent ("Research before you prescribe",
  "Ship a Server Component hero"). No hedging, no "you might consider".
- US English. Hard numbers everywhere (px, ms, ratios, char counts).

---

## 1. File list (exact paths)

Create exactly these files under `/Volumes/EXTERN/DEV/skills/skills/design/`:

```text
skills/design/SKILL.md
skills/design/references/research-method.md
skills/design/references/visual-system.md
skills/design/references/landing-anatomy-and-cro.md
skills/design/references/copywriting-frameworks.md
skills/design/references/motion-and-interaction.md
skills/design/scripts/verify.sh
```

The directory `skills/design/` already exists. Create `references/` and `scripts/`
subdirectories as needed (e.g. `mkdir -p skills/design/references skills/design/scripts`).
Do NOT create any other files (no README, no examples/, no assets/).

Line budgets: `SKILL.md` 250–450 lines. Each `references/*.md` 200–500 lines
(targets per file below). `verify.sh` ~170–230 lines.

---

## 2. `SKILL.md` — full spec

### 2.1 Frontmatter (exact)

```yaml
---
name: design
description: "Use when designing a modern UI, building a high-converting landing page, crafting marketing or value-prop copy, refreshing a hero, choosing type/color/spacing/motion, or making an interface feel premium instead of generic/AI-templated. Research-first: studies award-winning current work (Awwwards, Godly, Land-book, Refactoring UI, Linear/Stripe/Vercel-tier) before prescribing. Ships Tailwind v4 + Next.js 15 + React 19 patterns with WCAG 2.2 AA and Core Web Vitals (LCP/INP/CLS) as hard design constraints. Triggers: 'design a landing page', 'make this look premium', 'write the hero copy', 'pick a color palette', 'this UI feels generic', 'conversion copywriting', 'bento section', 'design review'."
origin: risco
---
```

Frontmatter rules: keys exactly `name`, `description`, `origin`. `name: design`,
`origin: risco`. `description` is one quoted string starting with `Use when `.

### 2.2 Section order and content

Write these H2 sections in THIS order. Keep total file 250–450 lines by pushing
long material into `references/`. Every long bullet ends with an arrow pointer
`(→ references/<file>.md)`.

#### H1 + purpose line

```text
# Design — Product UI, Landing Pages & Conversion Copy
```

Immediately under it, one italic purpose line:
`*Research the best current work, then ship a premium, accessible, fast, high-converting interface.*`

#### `## When to use / When NOT to use`

Two tight bullet lists. No code.

- "Use when" bullets (6): new landing/marketing page; redesign or polish pass;
  hero / value-prop / pricing / FAQ copy; choosing a visual system (type, color,
  spacing, radius, shadow, motion); "feels generic / AI-slop" rescue; pre-launch
  design QA.
- "Do NOT use when (delegate or decline)" bullets (5), each naming the delegate:
  pure backend/data/infra with no UI surface → decline; dense internal
  operational tooling used daily (not a sales page) → apply product-domain
  judgment, do NOT force a landing composition (`frontend-design-direction`);
  native iOS/SwiftUI Liquid Glass material → `liquid-glass-design` (this skill is
  the *web* glass approximation only); deep motion code mechanics (springs,
  `AnimatePresence` internals) → `motion-ui` / `motion-foundations` (this skill
  sets motion *intent + budget*); deep keyword research / technical SEO audit →
  `seo` (this skill only enforces SEO-aware *structure*).

Close the section with one bold line:
`**Tool vs. landing page:** A SaaS operations tool should be dense, quiet, and scannable — never paint a marketing skin on a tool that needs repeated daily use.`

#### `## The non-negotiables (read first)`

Intro line: `These are constraints, not preferences. Violating any one is a defect, not a style choice.`
Numbered list of 10 iron rules (bold lead-in each), no code:

1. **Research before you prescribe.** Run the research protocol; never ship from
   stale memory — your default taste skews AI-generic. (→ `references/research-method.md`)
2. **5-second value prop.** What it is, who it's for, and why it's better must be
   legible above the fold in 5 seconds.
3. **One `<h1>` per page;** semantic landmarks (`header`/`nav`/`main`/`section`/`footer`).
4. **Core Web Vitals are design constraints:** LCP < 2.5s, INP < 200ms, CLS < 0.1.
   (INP replaced FID in March 2024 — measure INP.)
5. **WCAG 2.2 AA:** 4.5:1 text contrast (3:1 large text / UI), visible focus,
   44×44px targets, `prefers-reduced-motion` honored.
6. **Design tokens, never magic numbers.** Tailwind v4 `@theme` → CSS vars.
7. **Spacing on a 4/8px scale; type on a modular scale; color allocated 60-30-10.**
8. **Motion must guide attention, communicate state, or preserve continuity** —
   else delete it.
9. **Copy is benefit-led and specific.** No hype; the ban-list is enforced.
   (→ `references/copywriting-frameworks.md`)
10. **Match the product domain.** Density and composition follow the audience and
    the job, not a template.

#### `## Decision rules (pick a direction first)`

- A 5-question direction brief, framed as fill-in (sharper than
  `frontend-design-direction`). Render as a fenced `text` block:

```text
DIRECTION BRIEF (fill before coding)
1. Purpose .......... what job does this interface do, in one sentence?
2. Audience ......... who repeats this workflow; what do they scan first?
3. Tone ............. pick: utilitarian | editorial | playful | industrial | refined | technical | minimal | dense | calm
4. Memorable detail . the ONE idea that makes it feel intentional (not a gradient)
5. Constraints ...... framework, a11y, perf budget, existing design system/tokens
```

- Then a decision table mapping project type → composition / density / motion
  budget:

| Project type | Composition | Density | Motion budget |
| --- | --- | --- | --- |
| SaaS marketing | Full landing stack, hero→CTA | Generous | Tasteful reveals, hover affordances |
| Dev tool | Show the product/CLI first, then proof | Medium | Subtle, fast (≤200ms) |
| Dashboard / internal tool | Data-first, no hero | Dense, scannable | State-only (loading, success) |
| Portfolio / editorial | Expressive, asymmetric | Airy | Expressive but reduced-motion-safe |
| E-commerce | Product grid, fast PDP | Medium | Micro-interactions on add-to-cart |
| Docs | Sidebar + reading column | Calm, 65ch measure | Near-zero |

No code beyond the brief block.

#### `## Research-first protocol`

~12 lines. The loop, numbered inline (1→6): define 2–3 reference archetypes →
WebSearch award galleries + tier-1 product sites → WebFetch 3–5 exemplars
(prompt for type, color, layout, motion, copy voice) → extract a pattern table →
synthesize a one-paragraph DESIGN DIRECTION with citations → only THEN build, and
re-check in QA. State the gallery URLs inline: `awwwards.com`, `godly.website`,
`land-book.com`, `mobbin.com`, Refactoring UI, and tier-1 sites (Linear, Stripe,
Vercel, Cursor, Resend). State "re-research per project — trends churn." End with
pointer `Full loop, source map, and synthesis template → references/research-method.md`.
No code here (worked example lives in the reference).

#### `## Visual system in 90 seconds`

Intro line: `Copy-pasteable foundation. Tokens once, consume everywhere.`
Bullets (one line each): Tailwind v4 `@theme` block (OKLCH, tokens become CSS vars
automatically — no `tailwind.config.js`); type scale via `next/font` (one display +
one text face) + fluid `clamp()`; spacing/radius/shadow as tokens; the Good/Bad rule
(arbitrary hex + random px = Bad; token refs = Good).

Then ONE `css` Good block (the canonical compact `@theme`):

```css
/* Good — Tailwind v4 @theme: OKLCH palette, tokens become CSS vars + utilities */
@import "tailwindcss";
@theme {
  --color-bg:        oklch(0.99 0 0);
  --color-fg:        oklch(0.21 0.01 256);
  --color-muted:     oklch(0.55 0.01 256);
  --color-brand-500: oklch(0.62 0.19 256);
  --color-brand-600: oklch(0.55 0.19 256);
  --font-display:    "Geist", ui-sans-serif, system-ui, sans-serif;
  --font-text:       "Inter", ui-sans-serif, system-ui, sans-serif;
  --radius-card:     0.875rem;
  --shadow-card:     0 1px 2px oklch(0 0 0 / 0.06), 0 8px 24px oklch(0 0 0 / 0.08);
  --ease-out:        cubic-bezier(0.22, 1, 0.36, 1);
}
```

Then one short Bad/Good contrast in `html`:

```html
<!-- Bad — magic hex + arbitrary px, no system -->
<div style="background:#5b54ff;border-radius:13px;padding:17px">…</div>
<!-- Good — token-driven utilities -->
<div class="bg-brand-500 rounded-card p-4">…</div>
```

End: `Full token system, type scale, OKLCH ramp, bento, glass → references/visual-system.md`.

#### `## Landing page build recipe ("the brutal landing")`

Intro: `Each section has ONE job. Cut any section that has none.`
Ordered section stack as a numbered list, each with its job in one clause:
Hero (value prop, 5s) → social-proof strip → problem/agitation → solution →
features→benefits (bento) → objection handling → pricing → FAQ → final CTA → footer.

Then ONE copy-pasteable Next.js 15 / React 19 LCP-safe hero (Server Component,
`next/image` `priority`, semantic, a11y, no CLS):

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
          Concrete benefit, who it is for, and why now — no hype.
        </p>
        <a
          href="#start"
          className="mt-8 inline-flex min-h-11 items-center rounded-card bg-brand-500 px-6 font-medium text-white transition-colors hover:bg-brand-600"
        >
          Start free
        </a>
        <Image
          src="/hero.avif"
          alt="Product dashboard showing a one-click deploy"
          width={1200}
          height={720}
          priority
          className="mt-16 rounded-card shadow-card"
        />
      </section>
    </main>
  );
}
```

End: `Full section-by-section anatomy, CTA cadence, pricing psychology, JSON-LD → references/landing-anatomy-and-cro.md`.

#### `## Conversion copy in one pass`

Bullets: the 5s value-prop test; headline formula slots (outcome + timeframe; "X
without Y"; JTBD); framework picker one line each (PAS = pain-aware cold traffic;
AIDA = broad/top-of-funnel; FAB/JTBD = feature→benefit); CTA value-on-the-button.

One Good/Bad headline contrast in `text`:

```text
Bad  — "Revolutionize your workflow with our seamless platform"
Good — "Deploy a fix in 4 minutes — no YAML, no on-call page"
```

Then the ban-list as an inline code list:
`Ban: revolutionary · game-changer · cutting-edge · "In today's landscape" · unlock · seamless · elevate · supercharge · bait questions · "not X, just Y" · forced lowercase · "Excited to share".`
End: `Frameworks, value-prop canvas, Bad→Good rewrites, VOICE block → references/copywriting-frameworks.md`.

#### `## Motion & interaction budget`

Bullets (intent + budget, mechanics deferred): purposeful-only rule; timing
defaults (enter 200–350ms, exit ~150ms, press `scale(0.97)`); never
`transition: all`; compositor-only props (`transform`/`opacity`/`filter`);
`prefers-reduced-motion` required; scroll-driven via native CSS
`animation-timeline: view()` FIRST (no JS, no CLS) before any JS lib.

One Good CSS scroll-reveal + reduced-motion guard:

```css
/* Good — native scroll-driven reveal, zero JS, respects reduced motion */
@media (prefers-reduced-motion: no-preference) {
  .reveal {
    animation: reveal linear both;
    animation-timeline: view();
    animation-range: entry 0% cover 30%;
  }
}
@keyframes reveal {
  from { opacity: 0; translate: 0 16px; }
  to   { opacity: 1; translate: 0 0; }
}
```

End: `Timing tokens, micro-interactions, scroll/parallax, when to escalate to motion/react → references/motion-and-interaction.md`.

#### `## Premium details that compound`

Intro: `Small things, applied consistently, are what reads as "designed".`
A compact Good/Bad table (denser/more current than ECC `make-interfaces-feel-better`):

| Detail | Bad | Good |
| --- | --- | --- |
| Nested radius | Same radius parent + child | `outer = inner + padding` (concentric) |
| Shadows | One hard `0 4px 8px #000` | Layered transparent OKLCH shadows |
| Separation | Heavy drop shadow everywhere | Hairline 1px border first, shadow only for lift |
| Headings | Ragged wrap | `text-wrap: balance` |
| Body / captions | Orphan last word | `text-wrap: pretty` |
| Numbers/prices | Width jitters | `font-variant-numeric: tabular-nums` |
| Images | Edge blurs into bg | 1px neutral `outline`, `outline-offset: -1px` |
| Glass | `backdrop-blur` on everything | Blur + 1px hairline + subtle noise, sparingly |

One short `css` snippet for the highest-leverage trio (font smoothing + image
outline + tabular nums):

```css
html { -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; }
img  { outline: 1px solid oklch(0 0 0 / 0.1); outline-offset: -1px; }
.price { font-variant-numeric: tabular-nums; }
```

End: `Depth recipes, glass, noise, concentric math → references/visual-system.md`.

#### `## Anti-patterns / rationalizations → STOP`

Two-column table (Rationalization → Reality / Fix), 9 rows:

| Rationalization | Reality / Fix |
| --- | --- |
| "Purple→blue gradient on everything looks modern" | It reads AI-generic. Pick a domain-true palette; gradients are seasoning. |
| "Centered text over an atmospheric gradient is a hero" | Show the product. Vague hero fails the 5s test. |
| "Cards inside cards add structure" | They add noise. Flatten; use spacing + one border. |
| "I know good design, I'll skip research" | Taste ≠ current trend. Re-research every project. |
| "The image sells it, copy can be vague" | Copy carries the value prop. Pass the 5s test. |
| "Animate everything on scroll" | CLS + INP cost. Reveal sparingly, transform/opacity only. |
| "Ship now, check contrast later" | Contrast is a constraint, not polish. 4.5:1 or it ships broken. |
| "Glass everywhere looks premium" | Glass on everything looks cheap. Reserve for floating surfaces. |
| "`transition: all` is convenient" | It animates layout props → jank. List exact properties. |

#### `## Quick reference`

One scannable table: Lever → Default → Token / where:

| Lever | Default | Token / where |
| --- | --- | --- |
| Type scale ratio | 1.25 | modular scale |
| Body size | 16–18px | `--font-text` |
| Line-height | 1.5 body / 1.1 display | per element |
| Spacing base | 4 / 8px | Tailwind spacing |
| Color allocation | 60-30-10 | bg / fg / brand |
| Text contrast | ≥ 4.5:1 (3:1 large) | verify with checker |
| Card radius | 0.875rem | `--radius-card` |
| Touch target | ≥ 44×44px | `min-h-11` |
| Enter / exit motion | 250ms / 150ms | `--ease-out` |
| LCP | < 2.5s | `next/image priority` |
| INP | < 200ms | compositor-only motion |
| CLS | < 0.1 | reserved space, `next/font` |
| Hero | passes 5s test | value prop above fold |

#### `## Design-review QA checklist`

Intro: `Run before claiming done. Same checks scripts/verify.sh falls back to.`
14 binary checks as a `- [ ]` list: value prop legible in 5s; text contrast ≥
4.5:1; visible focus on all interactives; targets ≥ 44px; `prefers-reduced-motion`
honored; exactly one `<h1>`; semantic landmarks present; LCP image has `priority`;
fonts use `next/font` (no CLS / FOUT swap shift); no `transition: all` /
`transition-all`; tokens used (no magic hex/px); ban-list words absent from copy;
text fits at 360px and desktop without overflow; empty / loading / hover / error
states designed. End: `Automate → scripts/verify.sh (runs Lighthouse if a dev server is up, else static grep checks + this list).`

#### `## See Also`

Bullet list:

- `../nextjs/SKILL.md` — App Router / React 19 stack implementation.
- `frontend-design-direction` — product-domain design direction.
- `make-interfaces-feel-better` — polish-pass details.
- `motion-ui`, `motion-foundations` — motion code mechanics (springs, `AnimatePresence`).
- `brand-voice`, `content-engine` — voice profile and multi-platform distribution.
- `seo` — deep technical SEO + keyword work.
- `product-lens` — validate the "why" before you build.
- `liquid-glass-design` — native iOS 26 Liquid Glass (this skill = web glass only).
- References: `references/research-method.md`, `references/visual-system.md`,
  `references/landing-anatomy-and-cro.md`, `references/copywriting-frameworks.md`,
  `references/motion-and-interaction.md`.

---

## 3. `references/research-method.md` (target 200–260 lines)

H1: `# Research-First Design Method`. One-line intro: the engine that keeps output
current and non-generic.

Ordered sub-sections:

1. `## Why re-research every project` — 4 bullets: trends churn quarterly; model
   taste skews to AI-template median; competitors moved; the domain dictates the
   reference set. State plainly: "Your built-in aesthetic prior is the problem this
   protocol fixes."
2. `## The loop` — numbered 1→7: (1) define 2–3 reference archetypes from the
   DIRECTION BRIEF; (2) WebSearch award galleries + tier-1 product sites; (3)
   WebFetch 3–5 exemplars, prompting each for type / color / layout / motion /
   copy voice; (4) extract a pattern table; (5) synthesize a one-paragraph DESIGN
   DIRECTION with citations; (6) build; (7) re-check against references in QA.
   Include a `text` block with the exact WebSearch/WebFetch prompt sketches:

```text
WebSearch: "best <domain> landing page 2026 site:awwwards.com OR site:godly.website"
WebSearch: "<competitor> pricing page design"
WebFetch(url, "Extract: typeface pairing, color palette (approx OKLCH/hex),
  layout system (grid/bento/asymmetry), motion (what animates, on what trigger),
  hero copy voice. List concrete details, not adjectives.")
```

3. `## Source map` — table:

| Source | Mine for |
| --- | --- |
| awwwards.com | Bold direction, motion, art direction |
| godly.website | Current premium web aesthetics |
| land-book.com | Landing-page structure + section order |
| mobbin.com | Real app UI flows and patterns |
| Refactoring UI | Spacing, hierarchy, color rules |
| Linear | Restraint, dark UI, dense product surfaces |
| Stripe | Docs + marketing balance, gradients done right |
| Vercel | Type-led minimalism, dev-tool voice |
| Cursor / Resend | Dev-tool landing conventions |

4. `## Synthesis template` — a fill-in DESIGN DIRECTION block as `text`:

```text
DESIGN DIRECTION
Archetype ...... <e.g. "Linear-grade dev tool, dark, type-led">
Type pairing ... display=<face> / text=<face>, scale ratio <1.25>
Palette ........ bg/fg/brand/accent in OKLCH (list values)
Layout ......... <12-col | bento | asymmetric editorial>, max-width <px>, measure <ch>
Motion budget .. <reveals on entry only | none | expressive>, timings
Copy voice ..... <direct/compressed | warm | technical>; one-line value prop
Citations ...... <url 1>, <url 2>, <url 3>  (what each contributed)
```

5. `## Worked example` — a complete developer-tool landing brief produced
   end-to-end: 3 cited references (use plausible real URLs from the source map),
   the extracted pattern table, and the resulting filled DESIGN DIRECTION block
   with concrete OKLCH token values that match the `@theme` block in
   `visual-system.md`. Make it specific (a fictional "deploy CLI" product).
6. `## Anti-pattern` — copying a reference pixel-for-pixel vs. extracting
   principles; one Bad/Good `text` contrast.

End with `See Also` line → `visual-system.md`, `../nextjs/SKILL.md`,
`frontend-design-direction`.

---

## 4. `references/visual-system.md` (target 320–460 lines)

H1: `# Visual System — Tokens, Type, Color, Layout, Depth`.

Ordered sub-sections, each with real code:

1. `## Spacing scale` — explain 4/8 base; show the full ramp as a table (0,1,2,3,4,
   6,8,12,16,24 → rem values); one line on when to break it (optical, not
   mathematical, alignment).
2. `## Typographic scale` — modular ratios table (1.2 / 1.25 / 1.333 with the
   resulting px ladder from 16px base); a fluid `clamp()` generator snippet in
   `css`; line-height + measure rules (45–75ch); pairing strategy (one display +
   one text, or one superfamily). Include `next/font` setup killing CLS:

```tsx
// app/fonts.ts — next/font, self-hosted, no layout shift
import { Geist, Inter } from "next/font/google";
export const display = Geist({ subsets: ["latin"], variable: "--font-display", display: "swap" });
export const text = Inter({ subsets: ["latin"], variable: "--font-text", display: "swap" });
```

   plus the `clamp()` fluid heading:

```css
.h1 { font-size: clamp(2.25rem, 1.5rem + 3vw, 3.75rem); line-height: 1.05; text-wrap: balance; }
```

3. `## Color theory (OKLCH)` — explain OKLCH (perceptual lightness, P3 gamut, hue
   stable across lightness); build a ramp by holding hue+chroma and stepping L;
   60-30-10 allocation; semantic tokens (`bg/fg/muted/brand/accent/destructive`);
   accessible contrast (compute + verify 4.5:1, name the tool: APCA-aware checker /
   browser devtools); dark mode via token swap (not per-component overrides);
   gradients/mesh done tastefully + when NOT to. Include the OKLCH ramp:

```css
/* Brand ramp — hold hue 256 + chroma, step lightness */
@theme {
  --color-brand-50:  oklch(0.97 0.02 256);
  --color-brand-100: oklch(0.93 0.05 256);
  --color-brand-300: oklch(0.78 0.13 256);
  --color-brand-500: oklch(0.62 0.19 256);
  --color-brand-700: oklch(0.48 0.17 256);
  --color-brand-900: oklch(0.32 0.10 256);
}
```

   and dark mode via swap:

```css
:root { --color-bg: oklch(0.99 0 0); --color-fg: oklch(0.21 0.01 256); }
@media (prefers-color-scheme: dark) {
  :root { --color-bg: oklch(0.17 0.01 256); --color-fg: oklch(0.96 0.01 256); }
}
```

4. `## Grid & layout` — 12-col vs container queries (Tailwind v4 core `@container`);
   bento recipe (asymmetric `grid-template-areas`, one focal cell, why it scans);
   asymmetry/optical balance; max-width + measure. Include a bento grid in `html`
   (Tailwind utilities) with a focal cell spanning 2 columns/rows. Make it correct
   and responsive (`grid-cols-1 md:grid-cols-3`).
5. `## Depth` — layered transparent shadow recipe (`css`); radius scale + concentric
   rule (`outer = inner + padding`, with a worked number); hairline borders; tasteful
   glass card (`backdrop-blur` + 1px hairline + SVG noise); film-grain via inline SVG
   `data:` background; "when depth becomes slop" line. Include the glass card:

```html
<div class="rounded-card border border-white/10 bg-white/5 shadow-card backdrop-blur-xl">
  <!-- floating surface only — never the whole page -->
</div>
```

   and a layered shadow:

```css
--shadow-card:
  0 1px 2px oklch(0 0 0 / 0.06),
  0 8px 24px oklch(0 0 0 / 0.08),
  0 16px 48px oklch(0 0 0 / 0.06);
```

6. `## Design tokens end-to-end` — the canonical full Tailwind v4 `@theme` block
   (colors + type + spacing + radius + shadow + easing), consumed as utilities AND
   raw `var()`; plus a `tokens.json` mirror for cross-tool / Flutter parity. Include
   a Flutter `ThemeData` snippet that mirrors the same brand color in `dart` so the
   parity claim is concrete:

```dart
// lib/theme.dart — Flutter mirror of the brand token (Dart 3 / Flutter stable)
final brand = const Color(0xFF5B54FF); // ≈ oklch(0.62 0.19 256)
final theme = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: brand));
```

Good/Bad pairs throughout (magic hex vs token; same-radius nesting vs concentric;
glass everywhere vs floating-only). End with `See Also` →
`motion-and-interaction.md`, `landing-anatomy-and-cro.md`, `../flutter/SKILL.md`.

---

## 5. `references/landing-anatomy-and-cro.md` (target 320–460 lines)

H1: `# Landing Anatomy & Conversion (CRO)`.

Ordered sub-sections:

1. `## Above the fold` — the 5s test; F vs Z scan patterns; what must be visible
   (value prop, primary CTA, proof, the product itself).
2. `## Section-by-section anatomy` — for EACH section give: job · copy framework ·
   a11y note · the conversion principle it serves. Sections: Hero · logo/social-proof
   strip · problem/agitation · solution · features→benefits (bento) · how-it-works ·
   testimonials/case studies · objection handling · pricing · FAQ · final CTA · footer.
   Render as a table with columns `Section | Job | Copy framework | Conversion principle`.
3. `## Full landing skeleton` — one complete Next.js 15 `tsx` page: semantic
   `<main>` with each `<section>` as a landmark, exactly one `<h1>`, the Metadata
   API export, and a JSON-LD `<script type="application/ld+json">` (Organization +
   FAQPage only if FAQ content matches). Must be correct and copy-pasteable:

```tsx
// app/page.tsx — semantic landing skeleton (Next.js 15 App Router)
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Deploy in minutes — Acme",            // 50–60 chars
  description: "Ship a fix in 4 minutes with no YAML and no on-call page. Free to start.", // 120–160
};

export default function Page() {
  return (
    <main>
      <section aria-labelledby="hero-h">{/* hero */}</section>
      <section aria-label="Trusted by">{/* logo strip */}</section>
      <section aria-labelledby="pricing-h">{/* pricing */}</section>
      <section aria-labelledby="faq-h">{/* FAQ */}</section>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify({
          "@context": "https://schema.org",
          "@type": "Organization",
          name: "Acme",
          url: "https://acme.example",
        }) }}
      />
    </main>
  );
}
```

4. `## CTA strategy` — primary/secondary hierarchy; placement cadence (above fold +
   after value + after pricing + sticky on mobile); one primary action per viewport;
   microcopy. Include the sticky-mobile-CTA pattern in `tsx`/`css`.
5. `## Pricing psychology` — anchoring; 3-tier with highlighted middle; annual
   default; value framing not feature dumps; decoy effect; money-back risk reversal.
   Include a 3-tier pricing `html` (Tailwind) with the middle tier highlighted
   (`ring-2 ring-brand-500`), correct semantics.
6. `## Social proof` — logos, quantified testimonials, metrics, trust badges, where
   to place each. One Bad/Good (vague quote vs quantified).
7. `## Objection handling + FAQ` — surface real objections; `FAQPage` JSON-LD only
   when content matches. Include a correct `FAQPage` JSON-LD `json` block.
8. `## A/B mindset + instrumentation` — one hypothesis at a time; what to measure
   (CVR, scroll depth, INP at CTA); event-hook sketch.
9. `## SEO-aware structure constraint` — one H1, landmarks, Metadata, breadcrumb /
   Article / Product JSON-LD presence; defer depth to `seo`.

Good/Bad throughout. End `See Also` → `copywriting-frameworks.md`, `seo`,
`../nextjs/SKILL.md`.

---

## 6. `references/copywriting-frameworks.md` (target 300–440 lines)

H1: `# Conversion Copywriting Frameworks`.

Ordered sub-sections:

1. `## The 5s value-prop test` + value-proposition canvas (jobs/pains/gains →
   pain-relievers/gain-creators → headline). Include a filled canvas as `text`.
2. `## Frameworks with picker` — PAS, AIDA, FAB, BAB, JTBD: one line on when each
   wins, then one worked Bad→Good rewrite each (5 total). Render each rewrite as a
   labelled `text` block.
3. `## Headline formulas` — outcome + timeframe; "X without Y"; JTBD; specificity
   over cleverness; subhead job (who + how + proof). Table of formula → example.
4. `## Benefit-led specificity` — feature→benefit→proof ladder; numbers/receipts >
   adjectives. One ladder example as `text`.
5. `## Microcopy & CTA copy` — button verbs, value-on-the-button, form labels,
   error states, empty states, loading copy. Include a CTA microcopy table
   (`Context | Bad | Good`).
6. `## Voice/tone system` — a small reusable VOICE block (consumes `brand-voice` if
   present) as `text`; tone sliders; do/don't.
7. `## The ban-list` — hype words, bait questions, "not X, just Y", forced
   lowercase, "Excited to share". State once, as a list. Cross-reference
   `brand-voice` / `content-engine` as canonical.
8. `## SEO-aware copy` — title 50–60 chars, meta 120–160, keyword-in-H1 naturally,
   scannable subheads; constraint only, depth → `seo`.

Key code: filled value-prop canvas; 5 Bad→Good rewrites; CTA microcopy table;
reusable VOICE block. End `See Also` → `landing-anatomy-and-cro.md`, `brand-voice`,
`content-engine`, `seo`.

---

## 7. `references/motion-and-interaction.md` (target 280–420 lines)

H1: `# Motion & Interaction`.

Ordered sub-sections:

1. `## Purpose gate` — guide / communicate / preserve, else delete. State once.
2. `## Timing & easing tokens` — durations (instant 80 / fast 180 / normal 280 /
   slow 600ms); easings (`cubic-bezier(0.22,1,0.36,1)` standard, sharp `(0.4,0,0.2,1)`,
   bounce `(0.34,1.56,0.64,1)`); enter vs exit asymmetry; press `scale(0.97)`.
   Include a `css` token block + a button press with explicit `transition-property`:

```css
.button {
  transition-property: transform, background-color, box-shadow;
  transition-duration: 150ms;
  transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
}
.button:active { transform: scale(0.97); }
```

3. `## Micro-interactions` — hover/active/focus, button press, icon cross-fade,
   optimistic state, toast, skeleton. Short snippets, CSS-first.
4. `## Scroll-driven, CSS-first` — native `animation-timeline: view()` / `scroll()`
   as the DEFAULT (no JS, no CLS); parallax via scroll timeline; only reach for
   `motion/react` when you need orchestration / layout / exit. Include the
   scroll-reveal + a CSS parallax via `scroll()` timeline.
5. `## Performance budget` — transform/opacity/filter only; never width/height/top/
   left; `will-change` sparingly; INP cost of scroll handlers; `content-visibility`
   for offscreen.
6. `## Accessibility` — `prefers-reduced-motion` (CSS + JS `matchMedia`); no
   motion-only meaning; pause controls for loops; vestibular safety (cut large
   translate/parallax). Include both CSS guard and JS:

```ts
const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
```

7. `## When to escalate to motion/react` — one minimal `motion/react` example
   flagged "only when CSS can't express it — orchestration, layout, exit"; then
   defer mechanics to `motion-ui` / `motion-foundations`. Include the `tsx`:

```tsx
"use client";
import { motion, AnimatePresence } from "motion/react";
// Use only for orchestration/exit that CSS can't express. Tokens + springs: motion-foundations.
```

End `See Also` → `visual-system.md`, `motion-ui`, `motion-foundations`,
`../nextjs/SKILL.md`.

---

## 8. `scripts/verify.sh` — exact contract

Path: `skills/design/scripts/verify.sh`. END-USER runs it inside THEIR project.
Do NOT execute it in this repo. After writing, `chmod +x` it.

### 8.1 Header + bootstrap (exact)

- Line 1: `#!/usr/bin/env bash`
- Then a comment usage block: what it does (Lighthouse perf/a11y if a dev server
  is reachable + static design-review grep checks); how to run
  (`./verify.sh [--url <url>] [--strict]`); that missing tools are SKIPPED (yellow)
  not failed; default exit 0, exit non-zero only on real `fail` (or `--strict` with
  any `warn`).
- `set -euo pipefail`
- Color helpers + counters: define `RED GREEN YELLOW NC` (guard with
  `[ -t 1 ]` so non-TTY output has no escape codes); counters `ok=0 skip=0 warn=0 fail=0`.
- Functions: `ok() { ... ((ok++)); }`, `warn() { ... ((warn++)); }` (yellow `[skip]`
  or `[warn]`), `fail() { ... ((fail++)); }`. Each prints the message.
- Arg parse loop: `--url <url>` (default `URL="http://localhost:3000"`), `--strict`
  (sets `STRICT=1`, default 0). Unknown arg → print usage, exit 2.
- `have() { command -v "$1" >/dev/null 2>&1; }` helper.
- `SEARCH`: pick `rg` if `have rg`, else `grep -rn` equivalent. Define a wrapper
  `search() { if have rg; then rg -n "$@"; else grep -rnE "$@"; fi; }` (note: align
  flags so the same call works; document the chosen behavior).

### 8.2 Lighthouse step (guarded)

- If `have lighthouse || have npx`; and `curl -sf --max-time 3 "$URL" >/dev/null`:
  run Lighthouse to JSON in a temp dir
  (`tmp=$(mktemp -d)`; `lighthouse "$URL" --quiet --chrome-flags="--headless=new" --only-categories=performance,accessibility --output=json --output-path="$tmp/lh.json"`,
  or `npx --no-install lighthouse ...` when only npx is present).
- Extract metrics preferring `jq`, falling back to `node -e`:
  - LCP = `audits["largest-contentful-paint"].numericValue` (ms) → PASS if < 2500.
  - CLS = `audits["cumulative-layout-shift"].numericValue` → PASS if < 0.1.
  - INP proxy: use TBT `audits["total-blocking-time"].numericValue` → PASS if < 200
    (label it "INP proxy (TBT)").
  - a11y score = `categories.accessibility.score` → PASS if ≥ 0.9.
  - Each → `ok`/`fail` with the measured value printed.
- If Lighthouse absent → `warn "lighthouse not found — skipping perf/a11y run"`.
- If URL unreachable → `warn "no dev server at $URL — start it (e.g. npm run dev) to run Lighthouse"`.
- `rm -rf "$tmp"` afterwards.

### 8.3 Static design-review checks (always run, no network)

For each, print `file:line` evidence via `search`; classify as `warn` (soft,
heuristic) unless noted:

1. More than one `<h1` in any page/route file (`grep -c` per file; >1 → warn).
2. `transition: all` OR `transition-all` present → warn.
3. Hardcoded hex colors (`#[0-9a-fA-F]{3,8}`) in component files (`*.tsx *.jsx
   *.css`) when a token system exists (heuristic: `@theme` or `--color-` found
   anywhere) → warn (low-confidence).
4. `<img` without `alt=` OR `next/image` `<Image` without `alt` → warn.
5. Keyframes/animations present (`@keyframes` or `animation:`/`animate-`) but NO
   `prefers-reduced-motion` block anywhere → warn.
6. Ban-list marketing words in page copy
   (`revolutionary|game-?changer|cutting-edge|supercharge|seamless|unlock`,
   case-insensitive) → warn.

Wrap each check so a missing match is silent (not an error under `set -e`): use
`if search ... ; then warn ...; fi` and ensure non-match returns 0 (e.g. append
`|| true` where needed so `set -e` does not abort).

### 8.4 Fallback checklist + summary

- If Lighthouse did NOT run (absent or URL unreachable): print the 14-point
  design-review checklist (identical wording to `SKILL.md` §QA) for the human.
- Summary line: `echo "ok=$ok skip=$skip warn=$warn fail=$fail"`.
- Exit logic: `if (( fail > 0 )); then exit 1; fi`;
  `if (( STRICT == 1 && warn > 0 )); then exit 1; fi`; else `exit 0`.

### 8.5 After writing

Run `chmod +x /Volumes/EXTERN/DEV/skills/skills/design/scripts/verify.sh`. Do NOT
run the script. Sanity-check syntax only with `bash -n` (parse, no execution).

---

## 9. Acceptance checks (implementer must self-verify before finishing)

Run/verify ALL of these; do not report done until each passes:

1. All 7 files exist at the exact paths in §1. Confirm with `ls`/`find`.
2. `SKILL.md` is 250–450 lines (`wc -l`); each `references/*.md` is 200–500 lines.
3. Frontmatter: `name: design`, `origin: risco`, `description` starts with
   `Use when ` and is a single quoted string.
4. Exactly one `# H1` per file; no skipped heading levels; section order in
   `SKILL.md` matches §2.2 exactly.
5. Every fenced code block has a language tag (no bare ```` ``` ````). Verify by
   scanning for ```` ``` ```` lines with no trailing word.
6. No placeholders / `TODO` / literal `etc.` / `...` inside code blocks. Every
   `tsx`/`ts`/`css`/`dart`/`json` snippet is syntactically correct in context
   (Server vs Client component correct; `"use client"` present on `motion/react`
   files; `@theme`/OKLCH valid; JSON-LD valid JSON).
7. Good/Bad contrasts present where §2.2 / references require them.
8. `scripts/verify.sh` starts with `#!/usr/bin/env bash`, has `set -euo pipefail`,
   the usage comment, detect-or-skip for `lighthouse`/`npx`/`curl`/`rg`, exits
   non-zero only on real `fail` (or `--strict`+warn). `bash -n` passes. The file is
   executable (`test -x` true after `chmod +x`).
9. Cross-links resolve: `SKILL.md` references all 5 `references/*.md` and
   `scripts/verify.sh`; each reference links at least one sibling; "See Also" links
   the in-repo skills via `../<id>/SKILL.md` and ECC skills by bare name.
10. Currency: Tailwind v4 `@theme`/OKLCH (no `tailwind.config.js`), Next.js 15 +
    React 19 Server Component hero, INP (not FID), native `animation-timeline:
    view()` present. No outdated `framer-motion` default (use `motion/react`).
11. The QA checklist in `SKILL.md` and the fallback checklist in `verify.sh` are
    the same 14 items, same wording.
12. Markdown lints clean-ish: consistent pipe tables, fenced blocks closed, one H1.

When all pass, report: files created, line counts, and that `verify.sh` is
executable and `bash -n`-clean.
