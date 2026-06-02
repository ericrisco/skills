# RTL & bidi reference

Full depth for right-to-left (Arabic, Hebrew, Persian, Urdu) and bidirectional text. The core rule lives in SKILL.md: set `dir` on `<html>`, write layout with CSS logical properties. This file is the complete mapping plus the judgment calls.

## Physical → logical property mapping

Replace physical properties so one stylesheet flips automatically with `dir`/`writing-mode`.

| Physical | Logical |
| --- | --- |
| `margin-left` / `margin-right` | `margin-inline-start` / `margin-inline-end` |
| `padding-left` / `padding-right` | `padding-inline-start` / `padding-inline-end` |
| `left` / `right` | `inset-inline-start` / `inset-inline-end` |
| `border-left` / `border-right` | `border-inline-start` / `border-inline-end` |
| `text-align: left` / `right` | `text-align: start` / `end` |
| `border-top-left-radius` | `border-start-start-radius` |
| `width` / `height` | `inline-size` / `block-size` |
| `float: left` | `float: inline-start` |

Flexbox/grid: `flex-start`/`flex-end` and `start`/`end` already follow direction — prefer them over `left`/`right`. Use `justify-content: flex-start`, not absolute positioning, where possible.

## Bidi isolation for interpolated content

User-supplied or locale-foreign text embedded in a sentence can reorder surrounding characters (the "bidi spillover" bug: a Hebrew name pushes an LTR punctuation mark to the wrong side).

- HTML: wrap the interpolated value in `<bdi>` — it isolates the embedded run's direction.
- CSS: `unicode-bidi: isolate` on the wrapper achieves the same.
- `dir="auto"` on an input/element lets the browser infer direction from the first strong character — useful for user-generated content fields whose language you don't know.

```html
<span>@<bdi>{{username}}</bdi> mentioned you</span>
```

## Mirror vs. don't mirror

When `dir="rtl"`, layout flips — but not every graphic should.

**Mirror** (directional meaning): back/forward arrows, breadcrumb chevrons, progress that advances, list bullets/indentation, send/reply arrows, undo/redo.

**Do NOT mirror** (physical/absolute meaning): media play button (always points to time-forward, conventionally right), clocks, musical notation, checkmarks, logos and brand marks, photos, phone/email/numbers that read LTR even in RTL context, charts with a real x-axis.

Implement icon mirroring with a logical transform scoped to RTL:

```css
[dir="rtl"] .icon-directional { transform: scaleX(-1); }
```

Keep a single explicit class for mirrored icons rather than flipping all of them.

## Numbers, dates, and embedded LTR

Numbers and Latin product names stay LTR even inside RTL text — the bidi algorithm handles this if you don't fight it. Don't force `direction` on number spans; let `Intl.NumberFormat` with the locale render digits (Arabic-Indic vs. Western) and let bidi place them.

## Testing RTL

1. **Pseudo-RTL locale.** Add a fake locale that forces `dir="rtl"` plus pseudolocalized strings to smoke-test layout flip without real translations.
2. **Snapshot one real RTL locale** (ar) in visual regression.
3. **Tab order + focus**: verify keyboard navigation follows visual order after the flip.
4. **Check truncation/ellipsis**: `text-overflow` and gradient fades must sit on the logical end, not a hardcoded right edge.
5. **Mixed content**: render an LTR username/number inside an RTL sentence and confirm no spillover.
