# Reference — trend sources, the no-scrape rule, and freshness scoring

Per-source capture recipes for Phase 2. Every signal you capture here carries a
**first-seen date** before it is allowed into Phase 3 scoring. A signal with no
date does not exist.

## The hard rule: no scraping

**TikTok Creative Center exposes no public trends API, and automated harvesting of
it violates the ToS** — reinforced by the April 2026 rule updates. Do not write,
suggest, or bake a scraper into any emitted artifact (no `curl`/`wget`/headless
browser against `creativecenter` or `ads.tiktok.com`). Two sanctioned paths only:

1. **Manual / assisted capture** — the user browses the surface and pastes the view
   to you; you parse the pasted text.
2. **Sanctioned API** — TikTok Research API or Commercial Content API on
   `developers.tiktok.com`, with the user's own approved credentials.

*Why:* a scraper is both a legal liability and a brittle dependency — the page
structure changes, the loop breaks, and the account risks a ban.

## Lane 1 — TikTok Creative Center

- Trend Discovery (trending songs, hashtags, Top Ads) is browsable **in-app without
  login** by switching the region to **United States**.
- The data **refreshes every 24–48h** and lets you **compare 7-day vs 30-day
  movement.** Always read both windows.
- **Scoring rule:** a sound that moves only on the **30-day** view (flat or down on
  7-day) is likely **dying** — mark `freshness: stale` and down-weight it. A sound
  **rising on 7-day** is `peaking` or `early` — up-weight it.
- Capture line: `sound/hashtag | TikTok-CC US | first-seen YYYY-MM-DD | 7d:↑/→/↓ | 30d:↑/→/↓`.

## Lane 2 — Instagram trending audio

- The native **Trending Audio list is gated to US Professional accounts.** A
  trending sound shows an **upward-arrow indicator** next to its name in-app.
- Non-US / non-pro accounts cannot see that list. Fall back to: the **Explore**
  feed, **niche-creator repeat-use** (Lane 4), and **cross-platform origin tracking**
  (Lane 3) — find what is breaking on TikTok/Shorts and watch it arrive on Reels.
- Capture line: `audio | IG | first-seen YYYY-MM-DD | arrow:yes/no | source:explore/creator/cross-platform`.

## Lane 3 — TikTok → Reels lead window

- **Instagram Reels trends often lag TikTok by 3–7 days.** This lag is the
  opportunity.
- A sound **viral on TikTok** with **fewer than 5,000 Reels** using it on Instagram
  is a documented **head-start window**. Mark it `freshness: early` and prioritize —
  you arrive before saturation.
- Capture line: `audio | TikTok→Reels | first-seen YYYY-MM-DD | reels-count:<5k | freshness:early`.

## Lane 4 — Niche-creator repeat-use & templates

- When **3+ creators in the account's niche** reuse the same sound/format/CapCut
  template inside one week, treat it as **niche-validated** even before it shows on a
  global trending list — niche relevance often beats global volume for a small account.
- Scan CapCut "Trending" templates for the niche as a format (not just sound) signal.
- Capture line: `format/template | niche-creators | first-seen YYYY-MM-DD | reuse-count:N`.

## Freshness scoring summary

| freshness | meaning | scoring action |
|---|---|---|
| `early` | TikTok-viral, <5k Reels, or 7d-rising and pre-peak | top weight — biggest head-start |
| `peaking` | rising on both 7d and 30d, broadly visible | weight high but move fast |
| `stale` | 30d-only movement, or first-seen >10 days ago | down-weight or drop; likely dying |

A signal's freshness is recomputed each cycle from its **first-seen date** against
today. Because Creative Center refreshes every 24–48h, a signal older than ~10 days
with no fresh confirmation defaults to `stale`.
