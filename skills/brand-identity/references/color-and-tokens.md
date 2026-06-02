# Color system & design tokens

Depth offloaded from SKILL.md: the full role taxonomy, a worked palette in all four
channels, the contrast-pair matrix, the complete W3C `design-tokens.json` with light/dark,
the Tailwind v4 `@theme` mapping, and the dark-mode strategy.

## Role taxonomy (assign roles before values)

| Role | Count | Job | Example token |
| --- | --- | --- | --- |
| Primary | 2–3 | The brand's signature; the color people recall | `color.brand.primary` |
| Secondary | 2–3 | Support; section accents, illustration | `color.brand.secondary` |
| Neutral | a ramp (50→900) | Text, surfaces, borders, dividers | `color.neutral.*` |
| Accent | exactly 1 | CTAs, highlights, the "click here" color | `color.brand.accent` |
| Semantic | as needed | success / warning / danger / info states | `color.status.*` |

One accent only. The moment a palette has two "primary action" colors, every button
becomes a judgment call and the interface loses its one unambiguous next step.

## Worked palette — all four channels

A color is not in the system until it carries HEX (web), RGB (screen), CMYK (print),
and OKLCH (perceptual + wide-gamut). Author in OKLCH; let HEX be the fallback.

| Token | HEX | RGB | CMYK | OKLCH |
| --- | --- | --- | --- | --- |
| brand.primary | `#3b5bdb` | 59, 91, 219 | 73, 58, 0, 14 | `oklch(0.55 0.19 256)` |
| brand.accent | `#f08c00` | 240, 140, 0 | 0, 42, 100, 6 | `oklch(0.72 0.17 50)` |
| bg (light) | `#fcfcfc` | 252, 252, 252 | 0, 0, 0, 1 | `oklch(0.99 0 0)` |
| fg (light) | `#1f2430` | 31, 36, 48 | 35, 25, 0, 81 | `oklch(0.21 0.01 256)` |
| bg (dark) | `#15171c` | 21, 23, 28 | 25, 18, 0, 89 | `oklch(0.18 0.01 256)` |
| fg (dark) | `#e9ebf0` | 233, 235, 240 | 3, 2, 0, 6 | `oklch(0.93 0.005 256)` |

CMYK is approximate — final print values come from the press profile (e.g. coated vs
uncoated stock). Document the intent; let the printer's profile resolve the exact ink mix.

## Contrast-pair matrix (WCAG 2)

Thresholds: AA 4.5:1 normal / 3:1 large (≥18.66px bold or ≥24px); AAA 7:1 / 4.5:1.
Document every pair you ship as text-on-background.

| Foreground | Background | Ratio | Normal AA | Large AA | AAA |
| --- | --- | --- | --- | --- | --- |
| fg `#1f2430` | bg `#fcfcfc` | ~12.4:1 | ✓ | ✓ | ✓ |
| brand.primary `#3b5bdb` | bg `#fcfcfc` | ~5.0:1 | ✓ | ✓ | ✗ |
| white `#ffffff` | brand.primary `#3b5bdb` | ~4.9:1 | ✓ | ✓ | ✗ |
| brand.accent `#f08c00` | bg `#fcfcfc` | ~2.1:1 | ✗ | ✗ | ✗ |
| fg(dark) `#e9ebf0` | bg(dark) `#15171c` | ~13.6:1 | ✓ | ✓ | ✓ |

The accent on white fails — that is expected. An accent earns its saturation by being
*reserved*; use it as a fill behind white/dark text or as a non-text highlight, never as
body text on the page background. Verify each pair with a checker, not by eye.

**Logo-text caveat:** WCAG 1.4.3 exempts logos and brand-name graphics from these minimums.
A *typed* tagline or sub-brand that is plain text (not a graphical logo) is NOT exempt — hold
it to 4.5:1. Mark only logo tokens exempt.

## Complete `design-tokens.json` (W3C 2025.10, light/dark via group inheritance)

W3C Design Tokens reached first stable (2025.10) on 2025-10-28. The Color Module supports
CSS Color 4 spaces (OKLCH, Display P3). Themes share a base and override via group
inheritance / `$extends`.

```json
{
  "$schema": "https://tokens.designtokens.org/2025.10/schema.json",
  "$description": "Brand tokens — single source consumed by the design skill.",
  "color": {
    "$type": "color",
    "brand": {
      "primary":   { "$value": { "colorSpace": "oklch", "components": [0.55, 0.19, 256], "hex": "#3b5bdb" } },
      "secondary": { "$value": { "colorSpace": "oklch", "components": [0.62, 0.12, 200], "hex": "#1c8ab0" } },
      "accent":    { "$value": { "colorSpace": "oklch", "components": [0.72, 0.17, 50],  "hex": "#f08c00" } }
    },
    "neutral": {
      "50":  { "$value": { "colorSpace": "oklch", "components": [0.98, 0, 0],     "hex": "#f5f6f8" } },
      "500": { "$value": { "colorSpace": "oklch", "components": [0.55, 0.01, 256], "hex": "#6b7280" } },
      "900": { "$value": { "colorSpace": "oklch", "components": [0.21, 0.01, 256], "hex": "#1f2430" } }
    },
    "theme": {
      "light": {
        "bg": { "$value": { "colorSpace": "oklch", "components": [0.99, 0, 0],     "hex": "#fcfcfc" } },
        "fg": { "$value": { "colorSpace": "oklch", "components": [0.21, 0.01, 256], "hex": "#1f2430" } }
      },
      "dark": {
        "bg": { "$value": { "colorSpace": "oklch", "components": [0.18, 0.01, 256], "hex": "#15171c" } },
        "fg": { "$value": { "colorSpace": "oklch", "components": [0.93, 0.005, 256], "hex": "#e9ebf0" } }
      }
    }
  },
  "$extensions": {
    "com.risco.contrast": [
      { "fg": "#1f2430", "bg": "#fcfcfc", "use": "body",  "logo": false },
      { "fg": "#ffffff", "bg": "#3b5bdb", "use": "button", "logo": false },
      { "fg": "#e9ebf0", "bg": "#15171c", "use": "body-dark", "logo": false }
    ]
  }
}
```

The `$extensions["com.risco.contrast"]` array is what `scripts/verify.sh` reads to prove
each text/bg pair clears AA. `"logo": true` exempts a pair from the 4.5:1 floor.

## Tailwind v4 `@theme` + CSS custom-properties mapping

Generate these from the tokens file; never hand-edit them — the JSON is the source.

```css
@import "tailwindcss";

@theme {
  --color-brand-primary:   oklch(0.55 0.19 256);
  --color-brand-secondary: oklch(0.62 0.12 200);
  --color-brand-accent:    oklch(0.72 0.17 50);
  --color-neutral-50:      oklch(0.98 0 0);
  --color-neutral-500:     oklch(0.55 0.01 256);
  --color-neutral-900:     oklch(0.21 0.01 256);
  --color-bg:              oklch(0.99 0 0);
  --color-fg:              oklch(0.21 0.01 256);
}
```

## Dark-mode strategy

- Define `bg`/`fg` per theme; keep `brand.*` anchored across both (recognition is constant).
- Don't simply invert lightness — dark surfaces want slightly desaturated, slightly warmer
  neutrals to avoid the "pure black + pure white" vibration. Re-check contrast in dark too.
- Switch with a `prefers-color-scheme` media query or a `.dark` class that re-points the
  `--color-bg`/`--color-fg` vars at the `theme.dark` token group.
