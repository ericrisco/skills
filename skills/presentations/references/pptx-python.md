# Native Editable PPTX — python-pptx Recipes

The editable pipeline. Use **python-pptx** when the deliverable is a `.pptx` that non-technical people will
open and edit in PowerPoint, Keynote, or Google Slides — or when you need **native, editable charts** that live
inside the file. python-pptx is pure Python: it writes Office Open XML directly, **no PowerPoint/LibreOffice
required to build** (only to render to PDF afterward).

> Version verified 2026-06: `python-pptx` current major `1.x` (e.g. `1.0.x`). Confirm in the target env:
> `python -c "import pptx; print(pptx.__version__)"`. Install: `pip install python-pptx`.

## Mental model

- A `Presentation` has `slide_masters` → each master has `slide_layouts` → each `slide` is *built from* a layout.
- A layout's **placeholders** (title, body, picture, etc.) are the editable scaffolding PowerPoint users expect. **Add content via placeholders/layouts**, not only free-floating textboxes, so the result behaves like a "real" template deck (outline view, reflow, theme-aware).
- **Theme** (colors + fonts) lives on the master. python-pptx can set per-shape colors and fonts directly, and can start from a corporate template (`.potx`/`.pptx`) to inherit a real theme.
- EMU is the internal unit. Always use helpers: `Inches`, `Pt`, `Emu`. 16:9 at 13.333"×7.5".

## Skeleton: a themed deck from design tokens

Map the project's design tokens (`02-DOCS/wiki/stack/design.md`) into PPTX theme values. PPTX is **sRGB**, so
convert OKLCH tokens to hex first (the `design` skill's `design-tokens.json` should carry sRGB/hex fallbacks;
if only OKLCH exists, convert via the design pipeline — do not eyeball it).

```python
"""build_deck.py — native editable 16:9 deck from design tokens.

Run: python build_deck.py  (writes deck.pptx; no Office needed)
"""
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR

# --- design tokens -> sRGB hex (from 02-DOCS/wiki/stack/design.md) ----------
BRAND      = RGBColor(0x4F, 0x46, 0xE5)   # oklch(0.62 0.19 264) -> #4F46E5
BRAND_INK  = RGBColor(0x1E, 0x1B, 0x2E)
SURFACE    = RGBColor(0xFA, 0xFA, 0xFC)
ACCENT     = RGBColor(0xF5, 0x9E, 0x0B)
MUTED      = RGBColor(0x6B, 0x70, 0x80)
FONT_DISPLAY = "Fraunces"
FONT_BODY    = "Inter"

# --- 16:9 canvas ------------------------------------------------------------
prs = Presentation()
prs.slide_width  = Inches(13.333)
prs.slide_height = Inches(7.5)

EMU_W, EMU_H = prs.slide_width, prs.slide_height
MARGIN = Inches(0.9)   # safe-area; nothing important outside this

def fill(slide, color):
    """Solid background fill for a slide."""
    bg = slide.background
    bg.fill.solid()
    bg.fill.fore_color.rgb = color

def textbox(slide, left, top, width, height, anchor=MSO_ANCHOR.TOP):
    tb = slide.shapes.add_textbox(left, top, width, height)
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    return tf

def run(paragraph, text, size, color, font=FONT_BODY, bold=False, align=PP_ALIGN.LEFT):
    paragraph.alignment = align
    r = paragraph.add_run(); r.text = text
    f = r.font
    f.size = Pt(size); f.bold = bold; f.name = font
    f.color.rgb = color
    return r

BLANK = prs.slide_layouts[6]   # 6 = blank layout in the default template

# --- Title slide ------------------------------------------------------------
s = prs.slides.add_slide(BLANK)
fill(s, BRAND_INK)
tf = textbox(s, MARGIN, Inches(2.6), EMU_W - 2*MARGIN, Inches(2.4))
run(tf.paragraphs[0], "Onboarding v2 cut churn 40%", 54, SURFACE, FONT_DISPLAY, bold=True)
p = tf.add_paragraph()
run(p, "How we rebuilt the first-run experience", 26, ACCENT, FONT_BODY)

# --- Assertion-headline content slide ---------------------------------------
s = prs.slides.add_slide(BLANK)
fill(s, SURFACE)
tf = textbox(s, MARGIN, MARGIN, EMU_W - 2*MARGIN, Inches(1.4))
run(tf.paragraphs[0], "TAM is $12B, growing 24%/yr", 38, BRAND_INK, FONT_DISPLAY, bold=True)
body = textbox(s, MARGIN, Inches(2.6), EMU_W - 2*MARGIN, Inches(3.5))
for i, line in enumerate([
    "Bottom-up: 40k target accounts x $30k ACV",
    "Reachable today via existing channel partners",
]):
    p = body.paragraphs[0] if i == 0 else body.add_paragraph()
    run(p, "•  " + line, 26, BRAND_INK)
    p.space_after = Pt(12)

# Speaker notes (native, editable pane)
s.notes_slide.notes_text_frame.text = (
    "This is the slide investors lean in for. Walk the assumptions, don't read them."
)

prs.save("deck.pptx")
print("wrote deck.pptx")
```

## Native, editable charts (the python-pptx superpower)

Unlike Marp/Slidev (which flatten charts to images), python-pptx writes **live PowerPoint charts** the user can
restyle and re-data. One chart = one point named in the slide headline (see `slide-design.md`).

```python
from pptx.chart.data import CategoryChartData
from pptx.enum.chart import XL_CHART_TYPE, XL_LEGEND_POSITION, XL_TICK_MARK

s = prs.slides.add_slide(BLANK); fill(s, SURFACE)
tf = textbox(s, MARGIN, MARGIN, EMU_W - 2*MARGIN, Inches(1.2))
run(tf.paragraphs[0], "Revenue 3x'd in four quarters", 38, BRAND_INK, FONT_DISPLAY, bold=True)

data = CategoryChartData()
data.categories = ["Q1", "Q2", "Q3", "Q4"]
data.add_series("ARR ($k)", (220, 360, 540, 680))

gframe = s.shapes.add_chart(
    XL_CHART_TYPE.COLUMN_CLUSTERED,
    MARGIN, Inches(2.4), EMU_W - 2*MARGIN, Inches(4.2), data,
)
chart = gframe.chart
chart.has_legend = False           # one series -> no legend needed
chart.has_title = False            # the SLIDE headline is the title

# De-clutter + brand the plot
plot = chart.plots[0]
plot.gap_width = 60
series = plot.series[0]
series.format.fill.solid()
series.format.fill.fore_color.rgb = BRAND   # one brand color, not a rainbow
# emphasize the final (latest) point in accent — pre-attentive highlight
series.points[-1].format.fill.solid()
series.points[-1].format.fill.fore_color.rgb = ACCENT

cat_axis = chart.category_axis
cat_axis.major_tick_mark = XL_TICK_MARK.NONE
cat_axis.tick_labels.font.size = Pt(16)
val_axis = chart.value_axis
val_axis.has_major_gridlines = False         # remove gridline clutter
val_axis.tick_labels.font.size = Pt(16)
val_axis.visible = False                     # direct-label instead if useful
```

Chart types: `COLUMN_CLUSTERED`, `BAR_CLUSTERED`, `LINE`, `LINE_MARKERS`, `PIE`, `DOUGHNUT`, `XY_SCATTER`,
`AREA`. Avoid `*_3D` types (banned by the design rules). Add a data point's value as a label via
`plot.has_data_labels = True` and `plot.data_labels.number_format = '$#,##0'`.

## Tables (native, editable)

```python
rows, cols = 4, 3
gframe = s.shapes.add_table(rows, cols, MARGIN, Inches(2.4),
                            EMU_W - 2*MARGIN, Inches(3.5))
table = gframe.table
headers = ["Plan", "Price", "Seats"]
for c, h in enumerate(headers):
    cell = table.cell(0, c)
    cell.text = h
    cell.fill.solid(); cell.fill.fore_color.rgb = BRAND
    para = cell.text_frame.paragraphs[0]
    para.runs[0].font.color.rgb = SURFACE
    para.runs[0].font.bold = True
    para.runs[0].font.size = Pt(20)
# ... fill body rows; set cell.text and per-run font for each
table.columns[0].width = Inches(5.0)
```

## Images (full-bleed + safe sizing)

```python
# Full-bleed background image, then a scrim + text on top (see slide-design.md)
pic = s.shapes.add_picture("hero.jpg", 0, 0, width=EMU_W, height=EMU_H)
s.shapes._spTree.remove(pic._element)        # send to back
s.shapes._spTree.insert(2, pic._element)
# scrim rectangle for legibility
from pptx.enum.shapes import MSO_SHAPE
scrim = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, EMU_W, EMU_H)
scrim.fill.solid(); scrim.fill.fore_color.rgb = BRAND_INK
scrim.fill.transparency = 0  # python-pptx has no direct alpha API; see note
scrim.line.fill.background()
```

Note: python-pptx has no first-class alpha/transparency API for fills — for a true semi-transparent scrim,
either pre-render a translucent PNG and `add_picture` it, or set transparency by editing the shape's XML
(`fill.fore_color` + an `<a:alpha>` element via `lxml`). Keep image files compressed *before* embedding to
control file size (PPTX embeds the original bytes).

## Starting from a corporate template (inherit a real theme)

The cleanest way to honor a company's brand is to open their `.potx`/`.pptx` and add slides using **its**
layouts — you inherit theme colors, fonts, masters, and logos for free.

```python
prs = Presentation("corporate-template.potx")   # or a .pptx
# Inspect what layouts exist so you pick the right scaffolding:
for i, layout in enumerate(prs.slide_layouts):
    print(i, layout.name)
title_layout = prs.slide_layouts[0]
s = prs.slides.add_slide(title_layout)
s.placeholders[0].text = "Onboarding v2 cut churn 40%"   # title placeholder
s.placeholders[1].text = "How we rebuilt the first-run experience"  # subtitle
```

Prefer placeholders here (`s.placeholders[idx].text`) so content lands in the template's themed, reflowing
slots rather than as off-theme floating boxes. List `slide.placeholders` to discover indices/types.

## Speaker notes

```python
notes = slide.notes_slide.notes_text_frame
notes.text = "Talk track for this slide. Exports to the PowerPoint notes pane and notes/handout pages."
```

## Render to PDF (python-pptx can't; convert)

python-pptx only writes `.pptx`. To get a PDF (vector, fonts embedded), convert with LibreOffice headless or
open in Office and export:

```bash
soffice --headless --convert-to pdf --outdir out deck.pptx     # LibreOffice
# verify fonts embedded:
pdffonts out/deck.pdf            # every font should read 'emb yes'
```

If LibreOffice substitutes fonts, install the brand fonts on the converting machine first, or embed fonts in
the `.pptx` via PowerPoint (File → Options → Save → "Embed fonts in the file") before converting.

## python-pptx gotchas

- **No PDF/render engine** — convert via LibreOffice/Office; verify font embedding afterward (`pdffonts`).
- **No fill transparency API** — pre-render translucent PNGs or edit XML for scrims/overlays.
- **EMU everywhere** — always wrap measurements in `Inches`/`Pt`/`Emu`; raw ints are EMU and easy to get wrong.
- **Fonts** — setting `font.name` references the font by name; the viewing machine must have it (or the deck must embed it). Stick to the brand fonts the design tokens specify; provide a safe fallback.
- **Default template = 4:3 historically** — always set `slide_width/height` to 13.333"×7.5" for 16:9.
- **Placeholders vs textboxes** — for a deck people will *edit*, prefer layout placeholders so outline view and reflow work; reserve free textboxes for bespoke layouts.
- **File size** — PPTX embeds original image bytes; compress images before `add_picture`.
- **SmartArt / advanced animations** — not supported by python-pptx; build those in PowerPoint, or keep motion to the simple build order you control.
