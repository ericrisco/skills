# Composition & specs reference

Depth for the hard constraints and composition rules in SKILL.md. All facts dated
2026-06-02.

## Full constraint table

| Property | Value | Notes |
|---|---|---|
| Recommended resolution | 1280 x 720 px | Anything smaller upscales soft |
| Aspect ratio | 16:9 | Fills player, feed, end screens, embeds |
| Minimum width | 640 px | Below this, upload may be rejected |
| File size (standard) | under 2 MB | Hard cap |
| File size (podcast) | under 10 MB | Only the podcast surface allows this |
| Accepted formats | JPG, PNG, GIF, BMP | Ship JPG or PNG |
| Feed render scale | ~320 x 180 px | Where most discovery happens |
| Duration-stamp zone | bottom-right corner | Reserved overlay — keep critical content out |

## The 30% contrast rule (luminance, not hue)

Make the main subject roughly 30% brighter or darker than the background. This is
about *luminance* separation, not color difference. Quick way to judge it: desaturate
the image to grayscale — if the subject still clearly separates from the background
in gray, it will separate in the feed. If the subject and background turn the same
shade of gray, add an outline, drop shadow, or glow until they don't.

Text/background contrast: aim for about 4.5:1. This is a borrowed usability
heuristic (the WCAG AA ratio for normal text), not a YouTube-enforced rule — use it
as a floor, not a target.

## Legibility test protocol (the squint test)

1. Export the candidate at 1280x720.
2. Scale a copy to 320x180.
3. Glance for under one second. Can you name the subject and read the text?
4. If not, the thumbnail fails the feed and no editor-canvas polish saves it.

Equivalent without resizing: step ~2 meters back from the monitor, or view it as a
phone-sized thumbnail in an actual feed mock.

## Render contexts to check

A thumbnail does not live in one place. Verify it in:

- **Mobile feed (light + dark mode)** — the dominant surface; dark mode changes how
  a dark background reads against the app chrome.
- **Desktop sidebar (small)** — even smaller than the mobile feed in some layouts.
- **Watch-page suggested column** — appears next to a playing video, competing for
  attention.
- **Search results grid** — sits among rival thumbnails; relative contrast matters.

## Export workflow (PNG -> JPG under 2MB)

1. Design and master in PNG (lossless) at 1280x720.
2. Export final as JPG at quality 85-90%. This almost always lands well under 2 MB
   while keeping text edges crisp.
3. If a PNG with flat color/text must stay PNG and exceeds 2 MB, reduce the palette
   or flatten layers before re-exporting.
4. Re-run `scripts/verify.sh path/to/thumb.jpg` to confirm dimensions, ratio, size,
   and format before upload.

## Sources

- socialrails.com — 1280x720 specs guide (accessed 2026-06-02)
- thumbnailtest.com — size/format guide (accessed 2026-06-02)
- thumbmagic.co / socialrails.com — 320x180 safe-zone guides (accessed 2026-06-02)
- usevisuals.com, deliveredsocial.com — duration-stamp safe zone (accessed 2026-06-02)
- nearstream.us, clickyapps.com — face/emotion and custom-vs-auto CTR (accessed 2026-06-02)
- usevisuals.com, ampifire.com — color count and 30% contrast guidance (accessed 2026-06-02)
