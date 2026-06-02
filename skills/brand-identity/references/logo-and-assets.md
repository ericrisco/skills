# Logo brief & asset export

Depth offloaded from SKILL.md: the variation grid with when-to-use each, clear-space and
min-size formulas, the full export matrix with DPI, the favicon set with HTML markup and a
`prefers-color-scheme` SVG snippet, and the file-naming convention.

## Variation grid

A logo is a system of variations, each earning its place by the context it survives.

| Variation | Form | When to use |
| --- | --- | --- |
| Primary | Horizontal lockup (mark + wordmark) | Default — headers, docs, most digital |
| Stacked | Vertical (mark over wordmark) | Square/tight slots, social avatars, merch |
| Mark-only | The symbol alone | Favicons, app icons, watermarks, ≤32px |
| Monochrome | Single ink (black, or white knockout) | One-color print, dark/photo backgrounds, embossing |

Build and test the **monochrome** version first. If the mark dies in one ink — needs its
gradient or two colors to read — it is too fragile and must be simplified before color work.

## Clear-space formula

Define clear space relative to the mark so it scales with the logo instead of breaking at
small sizes:

```text
clear space = cap-height of the wordmark (or x-height of the mark), on all four sides
```

Nothing — text, other logos, page edges — intrudes inside that margin. Expressing it as a
ratio (not a fixed px) means it stays correct from favicon to billboard.

## Minimum sizes

Below these, detail collapses and the mark stops reading:

| Variation | Digital min | Print min |
| --- | --- | --- |
| Primary lockup | 24px wide | 10mm wide |
| Stacked | 32px wide | 12mm wide |
| Mark-only | 16px wide (favicon territory) | 6mm wide |

## Export matrix

Ship vector first; raster for the cases vector can't cover. 72 DPI digital, 300 DPI print.

| Asset | Format | DPI | Notes |
| --- | --- | --- | --- |
| Logo, digital primary | SVG | n/a (vector) | Scales infinitely, smallest file |
| Logo, raster transparency | PNG @1x/@2x | 72 | Transparent background |
| Logo, print | PDF or JPEG | 300 | CMYK color, embed fonts/outline |
| Mark, app icon | PNG | 72 | Square, safe-zone padded |

## Favicon set (2025 baseline)

Modern baseline: an SVG primary that can carry a `prefers-color-scheme` dark variant, with
PNG/ICO fallbacks for engines that don't render SVG favicons (notably older Safari).

| File | Size | Purpose |
| --- | --- | --- |
| `favicon.svg` | vector, <1KB | Primary; can embed dark-mode CSS |
| `favicon.ico` | 16/32 multi | Legacy root fallback |
| `favicon-16.png`, `favicon-32.png` | 16, 32 | Tab/bookmark raster |
| `apple-touch-icon.png` | 180×180 | iOS home screen |
| `android-chrome-192.png`, `-512.png` | 192, 512 | Android / PWA |
| `site.webmanifest` | — | Declares the icon set + theme color |

### HTML markup

```html
<link rel="icon" href="/favicon.ico" sizes="32x32">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
```

### Dark-mode favicon (SVG with `prefers-color-scheme`)

An SVG favicon can flip its fill in dark UI chrome — one file, no extra requests:

```html
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <style>
    path { fill: #1f2430; }
    @media (prefers-color-scheme: dark) { path { fill: #e9ebf0; } }
  </style>
  <path d="M6 6 H26 V26 H6 Z" />
</svg>
```

## File-naming convention

Predictable names keep the asset folder usable years later:

```text
brand/
  logo-primary.svg        logo-primary@2x.png
  logo-stacked.svg        logo-stacked@2x.png
  logo-mark.svg           logo-mark@2x.png
  logo-mono-black.svg     logo-mono-white.svg
  logo-print.pdf
  favicon.svg  favicon.ico  favicon-16.png  favicon-32.png
  apple-touch-icon.png  android-chrome-192.png  android-chrome-512.png
  site.webmanifest
```

Pattern: `logo-<variation>[-<modifier>][@<scale>].<ext>`. Lowercase, hyphenated, no spaces.

## Misuse rules (do / don't)

- DON'T stretch, squash, or rotate the mark — scale uniformly only.
- DON'T recolor the logo off-palette or apply gradients/shadows not in the brief.
- DON'T place the color logo on a busy/low-contrast background — switch to the mono knockout.
- DON'T violate clear space or drop below the minimum size.
- DON'T recreate the lockup by hand-typing the wordmark — use the supplied files.
- DO use the variation that fits the slot (stacked for square, mark-only for ≤32px).
- DO keep the accent reserved; the logo is not a place to introduce new colors.
