# Markdown Decks — Marp & Slidev, Themed from Design Tokens, Exported to PDF + PPTX

The design-led pipeline. Author the deck in Markdown, theme it with CSS driven by the project's design
tokens, export to **PDF (the hero)** and **PPTX (bonus, image-based)**. Two engines:

- **Marp** — simplest, most portable; one CSS theme; great default for most decks. Exports HTML/PDF/PPTX/PNG.
- **Slidev** — Vue-based, developer-grade; live code, Monaco, Mermaid, components, motion. Best for technical talks.

Pick Marp unless the deck needs live code / interactive components / Mermaid diagrams → then Slidev.
Both flatten to **images** on PPTX export — if the user needs *editable* PPTX text, use `pptx-python.md`.

> Versions verified 2026-06: `@marp-team/marp-cli` (Node 18+), `@slidev/cli` (Vue 3). Always confirm in the
> target project: `npx @marp-team/marp-cli@latest --version`, `npx slidev --version`. Pin versions in `package.json`.

---

## Marp

### Authoring

A Marp deck is one Markdown file. Front-matter sets directives; `---` separates slides.

```markdown
---
marp: true
theme: brand
paginate: true
size: 16:9
math: katex
---

<!-- _class: title -->

# Onboarding v2 cut churn 40%
## How we rebuilt the first-run experience

---

## TAM is $12B, growing 24%/yr

- Bottom-up: 40k target accounts × $30k ACV
- Reachable today via existing channel partners

<!-- Speaker note: this is the slide investors lean in for. Walk the assumptions, don't read them. -->

---

<!-- _class: lead -->

# One in three users never finished setup.
```

Key directives: `theme`, `paginate`, `size: 16:9`, `math`, `header`/`footer`, `backgroundImage`. Per-slide
overrides use HTML comments: `<!-- _class: title -->` (leading `_` = this slide only), `<!-- _backgroundColor:
... -->`. Speaker notes are any `<!-- comment -->` not starting with a directive; they export with `--pdf-notes`
and `--notes`, and into PPTX notes.

### Theme from design tokens (the part that makes it *flipa*)

Read the project's tokens from `02-DOCS/wiki/stack/design.md` / `design-tokens.json` (the `design` skill's
output: OKLCH palette, type pairing, type scale, spacing). A Marp theme is a CSS file with a `/* @theme name */`
banner; register it with `--theme ./theme.css` (or `--theme-set ./themes`). Map tokens → CSS custom properties
once, then style sections against the variables — never hand-pick hex per slide.

```css
/* @theme brand */
/* Marp theme generated from 02-DOCS/wiki/stack/design.md tokens. */
@import 'default'; /* inherit Marp's reset/layout, then override */

/* Web fonts: self-host or @import so they EMBED in the PDF (see exports). */
@import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@600;700&family=Inter:wght@400;500;600&display=swap');

:root {
  /* --- design tokens (OKLCH from the design skill) --- */
  --brand:      oklch(0.62 0.19 264);
  --brand-ink:  oklch(0.18 0.03 264);
  --surface:    oklch(0.98 0.005 264);
  --muted:      oklch(0.55 0.02 264);
  --accent:     oklch(0.74 0.17 52);

  /* --- type scale for PROJECTION (bigger than web; body >= 24pt-equiv) --- */
  --font-display: 'Fraunces', Georgia, serif;
  --font-body:    'Inter', system-ui, sans-serif;
  --step-display: 64px;
  --step-h1:      44px;
  --step-h2:      32px;
  --step-body:    26px;   /* legibility floor for a talk */
  --step-caption: 18px;

  /* --- spacing scale --- */
  --space-slide: 64px;    /* slide safe-area padding */
  --space-gap:   24px;
}

section {                 /* a Marp slide */
  background: var(--surface);
  color: var(--brand-ink);
  font-family: var(--font-body);
  font-size: var(--step-body);
  line-height: 1.4;
  padding: var(--space-slide);
}
h1 { font-family: var(--font-display); font-size: var(--step-h1); color: var(--brand-ink); }
h2 { font-family: var(--font-display); font-size: var(--step-h2); color: var(--brand); }
strong { color: var(--accent); }
section::after { color: var(--muted); font-size: var(--step-caption); } /* pagination */

/* Title slide: <!-- _class: title --> */
section.title { background: var(--brand-ink); color: var(--surface); justify-content: center; }
section.title h1 { font-size: var(--step-display); color: var(--surface); }
section.title h2 { color: var(--accent); }

/* Big statement slide: <!-- _class: lead --> */
section.lead { justify-content: center; text-align: center; }
section.lead h1 { font-size: var(--step-display); max-width: 22ch; }

/* Dark variant for dark rooms / big screens: <!-- _class: dark --> */
section.dark { background: var(--brand-ink); color: var(--surface); }
section.dark h2 { color: var(--accent); }
```

For a **dark deck** default, swap the `section` background/color and provide a light `.handout` class for the
printed leave-behind. Keep contrast ≥ 4.5:1 in both. Two-column layouts: use a small utility, e.g.
`section.split { display: grid; grid-template-columns: 1fr 1fr; gap: var(--space-gap); }` and a `<!-- _class:
split -->` plus raw HTML columns, or Marp's CSS-grid recipes.

### Export — Marp

```bash
# PDF — the hero. Vector text, fonts embedded (if @imported/installed). 16:9 from `size:`.
npx @marp-team/marp-cli@latest deck.md --theme ./theme.css --pdf

# PDF with clickable outline (from headings) + presenter notes attached
npx @marp-team/marp-cli@latest deck.md --theme ./theme.css --pdf --pdf-outlines --pdf-notes

# PPTX — one IMAGE per slide (text NOT selectable). Speaker notes carry over.
npx @marp-team/marp-cli@latest deck.md --theme ./theme.css --pptx

# PPTX, experimental editable mode — needs LibreOffice (`soffice`) on PATH
npx @marp-team/marp-cli@latest deck.md --pptx --pptx-editable

# Speaker notes as a text file
npx @marp-team/marp-cli@latest deck.md --notes notes.txt

# PNG/JPEG of each slide (thumbnails, social) — also --images png|jpeg
npx @marp-team/marp-cli@latest deck.md --images png

# Self-contained HTML (no server) for browser presenting
npx @marp-team/marp-cli@latest deck.md --theme ./theme.css --html -o deck.html
```

PDF/PPTX/image export drive a **Chromium-family browser** (Chrome/Edge, or Firefox) under the hood — install
one or set `CHROME_PATH`. CI without a browser → use the official `marpteam/marp-cli` Docker image. Allow remote
CSS/fonts with `--allow-local-files` for local assets. A `marp.config.js` / `marp.config.mjs` can fix
`theme`/`pdf`/`html` so you don't repeat flags.

---

## Slidev

For developer-grade / technical talks: live-editable code blocks, Monaco editor, Mermaid/PlantUML diagrams,
Vue components on slides, click-driven `v-click` builds, and animation via `@vueuse/motion`.

### Scaffold & author

```bash
npm init slidev@latest        # scaffolds slides.md + Vite project
cd <project>
npx slidev                    # dev server at http://localhost:3030 (live reload)
```

`slides.md` — front-matter headmatter + `---` between slides; per-slide front-matter blocks set `layout`,
`class`, `background`, `transition`:

````markdown
---
theme: ./theme            # local theme, or an npm theme like 'seriph'
title: Onboarding v2
transition: fade
fonts:
  sans: Inter
  serif: Fraunces
---

# Onboarding v2 cut churn 40%

How we rebuilt the first-run experience

---
layout: two-cols
class: text-2xl
---

## What changed

- Single-screen setup
- Defaults that work

::right::

```ts {2|4|all}
// builds revealed click-by-click with v-click ranges
const churn = before * 0.6   // -40%
```

<!--
Speaker note: this exports to PDF presenter notes and PPTX notes.
-->
````

Builds: wrap content in `<v-click>` or use `{2|4|all}` line-highlight ranges in code blocks — reveal one idea at
a time (restraint!). Diagrams: ` ```mermaid ` fences render natively.

### Theme from design tokens — Slidev

Slidev styles with **UnoCSS/Tailwind utilities + CSS**. Drive it from the same design tokens. Put global CSS in
`./style.css` (auto-imported) or a local theme folder:

```css
/* style.css — Slidev global, from 02-DOCS/wiki/stack/design.md tokens */
:root {
  --brand:     oklch(0.62 0.19 264);
  --brand-ink: oklch(0.18 0.03 264);
  --surface:   oklch(0.98 0.005 264);
  --accent:    oklch(0.74 0.17 52);
}
.slidev-layout            { background: var(--surface); color: var(--brand-ink); font-family: Inter, sans-serif; }
.slidev-layout h1         { font-family: Fraunces, serif; color: var(--brand-ink); font-size: 2.75rem; }
.slidev-layout h2         { color: var(--brand); }
.slidev-layout strong     { color: var(--accent); }
.slidev-layout.cover      { background: var(--brand-ink); color: var(--surface); }
```

Expose tokens to Tailwind/UnoCSS via `uno.config.ts` `theme.colors` so utility classes (`text-brand`, `bg-ink`)
map to the same OKLCH values — single source of truth. Layouts (`cover`, `center`, `two-cols`, `image-right`,
`fact`, `quote`, `section`) cover most slide types; build custom ones in `layouts/`.

### Export — Slidev

Export uses **Playwright-Chromium** rendering — install it once in the project.

```bash
npx playwright install chromium          # one-time (or: npm i -D playwright-chromium)
npx slidev export                        # PDF (default), vector where possible, notes included
npx slidev export --format pptx          # PPTX — image-per-slide; notes per slide carry over
npx slidev export --format png           # one PNG per slide
npx slidev export --with-clicks          # one page per CLICK step (every build state)
npx slidev export --dark                 # force dark theme on export
npx slidev export --output deck.pdf      # explicit output path
npx slidev build                         # static SPA (deploy the deck as a website)
```

Like Marp, Slidev **PPTX = images, not editable text** — notes do carry over. Slidev's PDF keeps text selectable
for HTML-rendered text (better than image-PPTX) but complex components may rasterize.

---

## Export gotchas (both engines, and the fallback)

- **Fonts must embed in the PDF.** Self-host or `@import` web fonts so the renderer has them at export time; otherwise the PDF falls back to system fonts on other machines and the type drifts. Verify with `pdffonts deck.pdf` — every font should show `emb yes`. Subset fonts to shrink the file.
- **PPTX from Marp/Slidev is image-based** — text is not selectable/editable, search/accessibility suffer, and file size balloons with full-bleed images. If the user must edit text in PowerPoint, switch to `pptx-python.md`. Use Marp's experimental `--pptx-editable` (needs `soffice`) only as a best-effort.
- **16:9** — set `size: 16:9` (Marp) / default aspect (Slidev). Don't let a 4:3 default ship.
- **File size** — compress images before embedding (`sips`/`squoosh`/`pngquant`); prefer SVG for logos/diagrams; subset fonts. A 100MB deck won't email.
- **Browser dependency** — PDF/PPTX/PNG export needs Chromium (Marp) / Playwright-Chromium (Slidev). On headless CI install it explicitly or use the Marp Docker image; otherwise export silently skips.
- **Local assets** — Marp needs `--allow-local-files` to embed local images into PDF/PPTX.
- **Reduced motion** — HTML/presenting mode should honor `prefers-reduced-motion`; transitions are for the live talk, irrelevant in the static PDF.

### Fallback: any HTML deck → PDF (decktape / Playwright)

For reveal.js or a hand-rolled HTML deck with no native exporter:

```bash
# decktape drives a headless browser across the deck and writes a vector-ish PDF
npx decktape reveal http://localhost:8000 deck.pdf
npx decktape generic --slides 20 http://localhost:8000 deck.pdf   # generic mode for custom decks

# Or a minimal Playwright print-to-PDF
npx playwright pdf http://localhost:8000 deck.pdf
```

## When to choose which engine

| Need | Engine |
| --- | --- |
| Fastest path, max portability, one CSS theme | **Marp** |
| Mostly text/charts/images, PDF is the deliverable | **Marp** |
| Live code, Monaco, line-highlight builds, Mermaid | **Slidev** |
| Vue components / interactive widgets on slides | **Slidev** |
| Deploy the deck as a website too | **Slidev** (`slidev build`) |
| Recipient must EDIT the slides in PowerPoint | neither → `pptx-python.md` |
