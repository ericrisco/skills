---
name: design
description: "Use when designing a modern UI, building a high-converting landing page, crafting marketing or value-prop copy, refreshing a hero, choosing type/color/spacing/motion, or making an interface feel premium instead of generic/AI-templated. Research-first: studies award-winning current work (Awwwards, Godly, Land-book, Refactoring UI, Linear/Stripe/Vercel-tier) before prescribing. Ships Tailwind v4 + Next.js 15 + React 19 patterns with WCAG 2.2 AA and Core Web Vitals (LCP/INP/CLS) as hard design constraints. Triggers: 'design a landing page', 'make this look premium', 'write the hero copy', 'pick a color palette', 'this UI feels generic', 'conversion copywriting', 'bento section', 'design review'."
origin: risco
---

# Design — Product UI, Landing Pages & Conversion Copy

*Research the best current work, then ship a premium, accessible, fast, high-converting interface.*

## When to use / When NOT to use

Use when:

- Building a new landing or marketing page.
- Doing a redesign or a polish pass on an existing surface.
- Writing hero, value-prop, pricing, or FAQ copy.
- Choosing a visual system: type, color, spacing, radius, shadow, motion.
- Rescuing a UI that "feels generic / AI-slop".
- Running pre-launch design QA.

Do NOT use when (delegate or decline):

- Pure backend/data/infra work with no UI surface → decline; there is nothing to design.
- Dense internal operational tooling used daily (not a sales page) → apply product-domain judgment and do NOT force a landing composition (`frontend-design-direction`).
- Native iOS/SwiftUI Liquid Glass material → `liquid-glass-design` (this skill ships the *web* glass approximation only).
- Deep motion code mechanics (springs, `AnimatePresence` internals, layout animations) → `motion-ui` / `motion-foundations` (this skill sets motion *intent + budget*).
- Deep keyword research or a technical SEO audit → `seo` (this skill only enforces SEO-aware *structure*).

**Tool vs. landing page:** A SaaS operations tool should be dense, quiet, and scannable — never paint a marketing skin on a tool that needs repeated daily use.

## The non-negotiables (read first)

These are constraints, not preferences. Violating any one is a defect, not a style choice.

1. **Research before you prescribe.** Run the research protocol; never ship from stale memory — your default taste skews AI-generic. (→ `references/research-method.md`)
2. **5-second value prop.** What it is, who it's for, and why it's better must be legible above the fold in 5 seconds.
3. **One `<h1>` per page;** semantic landmarks (`header`/`nav`/`main`/`section`/`footer`).
4. **Core Web Vitals are design constraints:** LCP < 2.5s, INP < 200ms, CLS < 0.1. (INP replaced FID in March 2024 — measure INP.)
5. **WCAG 2.2 AA:** 4.5:1 text contrast (3:1 large text / UI), visible focus, 44×44px targets, `prefers-reduced-motion` honored.
6. **Design tokens, never magic numbers.** Tailwind v4 `@theme` → CSS vars.
7. **Spacing on a 4/8px scale; type on a modular scale; color allocated 60-30-10.**
8. **Motion must guide attention, communicate state, or preserve continuity** — else delete it.
9. **Copy is benefit-led and specific.** No hype; the ban-list is enforced. (→ `references/copywriting-frameworks.md`)
10. **Match the product domain.** Density and composition follow the audience and the job, not a template.

## Decision rules (pick a direction first)

Fill the direction brief before you write a single line of markup:

```text
DIRECTION BRIEF (fill before coding)
1. Purpose .......... what job does this interface do, in one sentence?
2. Audience ......... who repeats this workflow; what do they scan first?
3. Tone ............. pick: utilitarian | editorial | playful | industrial | refined | technical | minimal | dense | calm
4. Memorable detail . the ONE idea that makes it feel intentional (not a gradient)
5. Constraints ...... framework, a11y, perf budget, existing design system/tokens
```

Then map the project type to composition, density, and motion budget:

| Project type | Composition | Density | Motion budget |
| --- | --- | --- | --- |
| SaaS marketing | Full landing stack, hero→CTA | Generous | Tasteful reveals, hover affordances |
| Dev tool | Show the product/CLI first, then proof | Medium | Subtle, fast (≤200ms) |
| Dashboard / internal tool | Data-first, no hero | Dense, scannable | State-only (loading, success) |
| Portfolio / editorial | Expressive, asymmetric | Airy | Expressive but reduced-motion-safe |
| E-commerce | Product grid, fast PDP | Medium | Micro-interactions on add-to-cart |
| Docs | Sidebar + reading column | Calm, 65ch measure | Near-zero |

## Research-first protocol

Trends churn quarterly and your built-in aesthetic prior is the median of every AI template ever scraped. Counter it with a loop:

1. Define 2–3 reference archetypes from the DIRECTION BRIEF (e.g. "Linear-grade dev tool, dark, type-led").
2. WebSearch award galleries and tier-1 product sites: `awwwards.com`, `godly.website`, `land-book.com`, `mobbin.com`, Refactoring UI, and the tier-1 sites (Linear, Stripe, Vercel, Cursor, Resend).
3. WebFetch 3–5 exemplars, prompting each for type, color, layout, motion, and copy voice — concrete details, not adjectives.
4. Extract a pattern table from what they share and where they differ.
5. Synthesize a one-paragraph DESIGN DIRECTION with citations (which URL contributed what).
6. Only THEN build; re-check the result against the references in QA.

Re-research per project — trends churn, competitors moved, and the domain dictates the reference set. Full loop, source map, and synthesis template → `references/research-method.md`.

## Visual system in 90 seconds

Copy-pasteable foundation. Tokens once, consume everywhere.

- Tailwind v4 `@theme` block (OKLCH): tokens become CSS vars and utilities automatically — no `tailwind.config.js`.
- Type scale via `next/font` (one display + one text face) plus a fluid `clamp()` ladder.
- Spacing, radius, and shadow are tokens too, never inline numbers.
- The rule: arbitrary hex + random px = Bad; token references = Good.

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

```html
<!-- Bad — magic hex + arbitrary px, no system -->
<div style="background:#5b54ff;border-radius:13px;padding:17px">…</div>
<!-- Good — token-driven utilities -->
<div class="bg-brand-500 rounded-card p-4">…</div>
```

Full token system, type scale, OKLCH ramp, bento, glass → `references/visual-system.md`.

## Landing page build recipe ("the brutal landing")

Each section has ONE job. Cut any section that has none.

1. **Hero** — state the value prop; pass the 5s test.
2. **Social-proof strip** — borrow credibility immediately (logos, a hard metric).
3. **Problem / agitation** — name the pain in the reader's words.
4. **Solution** — show the product doing the job.
5. **Features → benefits (bento)** — translate each capability into an outcome.
6. **Objection handling** — preempt the top reason they won't buy.
7. **Pricing** — anchor, highlight one tier, default to annual.
8. **FAQ** — answer the real blockers, not filler.
9. **Final CTA** — one clear action, value on the button.
10. **Footer** — navigation, legal, trust signals.

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

Full section-by-section anatomy, CTA cadence, pricing psychology, JSON-LD → `references/landing-anatomy-and-cro.md`.

## Conversion copy in one pass

- The 5s value-prop test: a stranger reads the hero and can say what it is, who it's for, why it's better.
- Headline formula slots: outcome + timeframe; "X without Y"; the job-to-be-done.
- Framework picker: PAS for pain-aware cold traffic; AIDA for broad / top-of-funnel; FAB/JTBD for feature → benefit translation.
- CTA: put the value on the button ("Start free", "Get my estimate"), never "Submit".

```text
Bad  — "Revolutionize your workflow with our seamless platform"
Good — "Deploy a fix in 4 minutes — no YAML, no on-call page"
```

Ban: `revolutionary` · `game-changer` · `cutting-edge` · "In today's landscape" · `unlock` · `seamless` · `elevate` · `supercharge` · bait questions · "not X, just Y" · forced lowercase · "Excited to share".

Frameworks, value-prop canvas, Bad→Good rewrites, VOICE block → `references/copywriting-frameworks.md`.

## Motion & interaction budget

- Purposeful-only: motion must guide attention, communicate state, or preserve continuity.
- Timing defaults: enter 200–350ms, exit ~150ms, press `scale(0.97)`.
- Never `transition: all` — it animates layout props and janks.
- Compositor-only properties: `transform`, `opacity`, `filter`.
- `prefers-reduced-motion` is required, not optional.
- Scroll-driven via native CSS `animation-timeline: view()` FIRST (no JS, no CLS) before any JS library.

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

Timing tokens, micro-interactions, scroll/parallax, when to escalate to motion/react → `references/motion-and-interaction.md`.

## Premium details that compound

Small things, applied consistently, are what reads as "designed".

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

```css
html { -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; }
img  { outline: 1px solid oklch(0 0 0 / 0.1); outline-offset: -1px; }
.price { font-variant-numeric: tabular-nums; }
```

Depth recipes, glass, noise, concentric math → `references/visual-system.md`.

## Anti-patterns / rationalizations → STOP

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

## Quick reference

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

## Design-review QA checklist

Run before claiming done. Same checks `scripts/verify.sh` falls back to.

- [ ] Value prop legible in 5 seconds above the fold.
- [ ] Text contrast ≥ 4.5:1 (3:1 for large text / UI).
- [ ] Visible focus state on all interactive elements.
- [ ] Touch targets ≥ 44×44px.
- [ ] `prefers-reduced-motion` honored.
- [ ] Exactly one `<h1>` on the page.
- [ ] Semantic landmarks present (`header`/`nav`/`main`/`section`/`footer`).
- [ ] LCP image has `priority`.
- [ ] Fonts use `next/font` (no CLS / FOUT swap shift).
- [ ] No `transition: all` / `transition-all`.
- [ ] Tokens used (no magic hex / px).
- [ ] Ban-list words absent from copy.
- [ ] Text fits at 360px and desktop without overflow.
- [ ] Empty / loading / hover / error states designed.

Automate → `scripts/verify.sh` (runs Lighthouse if a dev server is up, else static grep checks + this list).

## See Also

- `../nextjs/SKILL.md` — App Router / React 19 stack implementation.
- `frontend-design-direction` — product-domain design direction.
- `make-interfaces-feel-better` — polish-pass details.
- `motion-ui`, `motion-foundations` — motion code mechanics (springs, `AnimatePresence`).
- `brand-voice`, `content-engine` — voice profile and multi-platform distribution.
- `seo` — deep technical SEO + keyword work.
- `product-lens` — validate the "why" before you build.
- `liquid-glass-design` — native iOS 26 Liquid Glass (this skill = web glass only).
- References: `references/research-method.md`, `references/visual-system.md`, `references/landing-anatomy-and-cro.md`, `references/copywriting-frameworks.md`, `references/motion-and-interaction.md`.
