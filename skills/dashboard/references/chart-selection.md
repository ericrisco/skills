# Chart selection — full matrix and edge cases

Pick the chart from the **shape of the question the metric answers**, not from novelty. The body table covers the common cases; this is the full matrix plus the situations where the obvious choice is wrong.

## Full metric-shape → chart matrix

| Metric shape | Primary chart | Acceptable alternative | Avoid |
| --- | --- | --- | --- |
| One headline number, "where are we now" | Big-number tile + delta | Big number + sparkline | Gauge, dial |
| Value over time, "which way is it going" | Line | Area (only if part-to-whole over time) | Many overlapping lines (>4) |
| Compare a category across items | Sorted horizontal bar | Dot plot | Pie, vertical bars with long labels |
| Actual vs a single target | Bullet chart | Bar with a target reference line | Gauge, dial, donut |
| Part-to-whole, ≤5 parts | Stacked bar | Treemap, pie (3-5 slices only) | Pie >5, nested donuts |
| Part-to-whole over time | 100% stacked area/bar | Small multiples of stacked bars | 3D area |
| Relationship between two measures | Scatter | Bubble (adds a 3rd measure via size) | Dual-axis line |
| Distribution of a measure | Histogram | Box plot | Single average number alone |
| Progress toward a deadline/goal | Bullet or progress bar | Burn-up line | Gauge |
| Geographic spread | Choropleth map | Sorted bar by region | 3D map, bubble-on-map clutter |

## Edge cases where the obvious chart is wrong

- **Sparkline inside a tile.** A north-star big number reads better with a tiny inline trend than with a separate chart tile. Use a sparkline when the *value* is the message and the *trend* is supporting context.
- **Small multiples beat one busy chart.** Comparing the same trend across 6 segments? Don't stack 6 lines on one axis — render 6 small identical line charts in a grid. The eye compares shapes faster than it untangles a spaghetti chart.
- **When a plain table beats every chart.** If the reader needs to look up exact values, compare more than ~3 precise numbers per row, or the data is inherently tabular (a ranked leaderboard with several columns), a clean table with right-aligned numbers and inline RYG cells wins. A chart that forces the reader back to a tooltip for the real number has failed.
- **Log scale.** Use only when values span orders of magnitude (e.g. error counts from 1 to 100,000) AND the audience understands log axes. For an exec dashboard, prefer splitting the metric or using a different view — a log axis silently understates big swings to a non-technical reader.
- **Annotating inflection points.** A trend line earns a one-line annotation at the moment something changed ("v2 launch", "price increase"). Why: the reader's first question at any bend is "what happened here"; answer it on the chart, not in a footnote.
- **Sorted bars for "who missed target".** When the question is accountability ("which regions are below plan"), sort bars by gap-to-target and color the misses. Don't sort alphabetically — sorting *is* the answer.
- **Dual axis: almost never.** Two y-axes on one chart invent correlations by letting you scale each line to "look related". If two metrics must be compared, normalize both to an index (base 100) and plot on one axis, or use two stacked charts.

## Color discipline

- Reserve red/yellow/green strictly for **status**. If everything is colored, nothing signals.
- Use a single neutral hue for non-status series; differentiate by position and labels, not by a rainbow.
- Ensure status is not encoded by color alone — pair RYG with an icon or shape so the screen stays readable for color-blind viewers (visual polish lives in [design](../../design/SKILL.md)).
