# 2026 UX/UI Trends — Dated Snapshot (re-verify per project)

This is a **point-in-time snapshot**, last verified **June 2026**. Trends churn quarterly and your built-in aesthetic prior is the AI-template median — so this file is a starting reference, not a substitute for live research. **Re-run WebSearch/WebFetch per project** (per `research-method.md`) and refresh this file when you do; cite sources with their dates. Treat anything here older than ~3 months as suspect.

## How to use this file

- When the brand study (`brand-grounding.md`) leaves a visual dimension with no user direction, or the user asks for "modern" / "2026" / "premium", pull current trends and fold the findings into the output **with citations + dates**.
- Extract *principles*, not pixels. "Bento for feature sections" is a principle; cloning a competitor's exact grid is theater.
- Cross-check every trend against the non-negotiables in `SKILL.md` — a trend that breaks contrast, CWV, or the 5s test is out, however current.

## Stack currency (verified June 2026)

| Tool | Current | Notes |
| --- | --- | --- |
| Tailwind CSS | v4.3 (2026-05-08) | OKLCH-native `@theme`, no `tailwind.config.js`; v4.2 added scrollbar/logical-property utilities and new palettes. |
| Next.js | 15 stable (16 released; this skill targets 15 + App Router) | Async request APIs, Turbopack stable, React 19 required for App Router. |
| React | 19.2.x (19.2.6, 2026-05-06) | Stable in Next.js 15.1+. |

Sources: [Tailwind v4.3 / v4.2 release notes](https://tailwindcss.com/blog), [InfoQ — Tailwind 4.2](https://www.infoq.com/news/2026/04/tailwind-css-4-2-webpack/), [Next.js 15 blog](https://nextjs.org/blog/next-15), [React versions](https://react.dev/versions). Re-verify before quoting a version.

## Typography (2026)

- **Type as the hero, not decoration.** Oversized headlines, expressive display faces, and variable fonts that respond to interaction/context. Serif and ledger-style numerals are back for editorial weight where the brand allows.
- **Kinetic typography** — headlines that animate on scroll — but only behind a purpose gate and reduced-motion guard (see `motion-and-interaction.md`); decorative letter-jelly is out.
- **Still true:** modular scale, ≤2 families, 45–75ch measure, `text-wrap: balance` on headings. Trends do not override the fundamentals in `visual-system.md`.

Source: [Figma — Web design trends](https://www.figma.com/resource-library/web-design-trends/) (2026), [Tubik — UI trends 2026](https://blog.tubikstudio.com/ui-design-trends-2026/) (2026).

## Color (2026)

- **Two poles this cycle:** (1) high-energy / "dopamine" — deep blacks layered with electric neon, sunset coral, holographic accents (Y2K-adjacent); (2) calm/adaptive — light "morning", low-contrast "focus", warm "evening" modes. Pick the pole the *brand* dictates; do not default to the loud one.
- **OKLCH is the production default** for ramps and dark-mode token swaps (perceptually even lightness, wider P3 gamut). Build ramps by holding hue+chroma and stepping L (see `visual-system.md`).
- **Adaptive / time-of-day theming** is emerging beyond binary light/dark — only worth it when the audience benefits; otherwise it is complexity for its own sake.
- **Still true:** 60-30-10 allocation, text ≥ 4.5:1, the brand color earns attention by being rare. Vivid palettes raise the contrast-failure risk — verify, never eyeball.

Source: [Envato — UX/UI trends 2026](https://elements.envato.com/learn/ux-ui-design-trends) (2026), [Figma](https://www.figma.com/resource-library/web-design-trends/) (2026).

## Layout (2026)

- **Bento** remains the standard for feature → benefit sections: asymmetric grid, one focal cell the eye lands on first.
- **Visible grids / wireframe logic as foreground** — exposed columns and structural lines used as decoration, not hidden scaffolding.
- **Experimental navigation** (radial menus, drawers, nonlinear journeys) and maximalist/collage layering — high-risk; only where the brand is expressive and it does not cost the 5s test or accessibility.
- **Container queries** (`@container`, core in Tailwind v4) for components that adapt to their slot, not just the viewport.
- **Still true:** clear focal point, max-width ~1024–1200px, body measure ~65ch.

Source: [Figma](https://www.figma.com/resource-library/web-design-trends/) (2026), [Index.dev — 12 UI/UX trends 2026](https://www.index.dev/blog/ui-ux-design-trends) (2026).

## Motion (2026)

- **Motion earns its keep by guiding, not flashing.** The cycle has moved away from bouncy micro-interactions toward *believable* motion: progress that reports real wait time, transitions that preserve continuity.
- **Native CSS scroll-driven animation** (`animation-timeline: view()/scroll()`) is the default engine — zero JS, no CLS — behind an `@supports` feature query and a `prefers-reduced-motion` guard (see `motion-and-interaction.md`). Safari support is still landing as of June 2026, so the feature query is load-bearing.
- **Still true:** purpose gate (guide / communicate / preserve), compositor-only properties (`transform`/`opacity`/`filter`), enter ~250ms / exit ~150ms, reduced-motion honored.

Source: [Tubik — UI trends 2026](https://blog.tubikstudio.com/ui-design-trends-2026/) (2026), [Envato](https://elements.envato.com/learn/ux-ui-design-trends) (2026).

## Tier-1 reference set (re-fetch live)

The benchmark for premium product/landing work this cycle — fetch the live sites in the research loop rather than trusting memory of them:

- **Linear** — radical restraint, dark near-monochrome, one accent, product-forward.
- **Stripe** — docs + marketing balance, gradients used as restrained seasoning.
- **Vercel** — type-led minimalism, dev-tool voice, product shown immediately.
- **Resend** — dev-tool voice in copy, clean bento, annual-default pricing.
- **Awwwards / Godly / Land-book / Mobbin** — galleries for direction, motion, and section order; weight by domain (skip the expressive entries for a dense dev tool).

## What now reads as dated / AI-generic (avoid)

- Purple→blue gradient on every surface; centered headline over an atmospheric mesh with the product hidden below the fold.
- Heavy glassmorphism / neumorphism everywhere; blob backgrounds.
- Cards-inside-cards; one hard `0 4px 8px #000` drop shadow on everything.
- Bouncy jelly micro-interactions with no informational purpose.

These are the AI-template median the research-first protocol exists to escape (`research-method.md`).

## See Also

- `research-method.md` — the live research loop that refreshes this snapshot.
- `brand-grounding.md` — offer these researched defaults when a brand dimension has no direction.
- `visual-system.md` — fundamentals these trends sit on top of (and never override).
- `motion-and-interaction.md` — the scroll-driven / reduced-motion implementation referenced above.
