# Platform asset specs

Hard limits per surface. The character counts are not advice — overflow gets the
asset truncated or rejected, which drags the asset-group rating. Lint against these
with `scripts/verify.sh` before shipping.

*All counts/limits dated 2026-06-02. Sources: Google Ads Help answer/14528220 (PMax),
answer/13704860 (Demand Gen); digitalapplied.com PMax 2026 guide; groas.com Demand Gen
2026 guide; adligator.com / attnagency.com Advantage+ guides.*

## Google Performance Max (per asset group)

| Asset | Count | Limit |
|---|---|---|
| Headlines | up to 15 | 30 char each |
| Long headline | 1 | 90 char |
| Descriptions | up to 5 | 90 char each (one short ≤60 recommended) |
| Images | up to 20 | landscape 1.91:1, square 1:1, portrait 4:5 |
| Logos | up to 5 | 1:1 and 4:1 |
| Videos | up to 5 | ≥10s; add your own — Google auto-generates poor ones if you don't |
| Business name | 1 | 25 char |

- **Asset groups:** max **25 per campaign**; start with **1–2** and only split when a
  group has a distinct audience/theme and enough budget to feed it.
- **Asset rating:** Google labels each asset **Low / Good / Best**. Replace **Low**
  assets after **4–6 weeks** — a Low asset suppresses the whole group's reach.

## Google Demand Gen

| Asset | Count | Limit |
|---|---|---|
| Headlines | up to 5 | 40 char each |
| Descriptions | up to 5 | 90 char each |
| Images | per format | 1.91:1, 1:1, 4:5 |
| Videos | per format | landscape / square / vertical |

Demand Gen gives the control PMax withholds: **preview exact combinations**, **opt out
of optimized targeting**, and **report by placement / audience / asset**. Reach for it
when you need creative and audience control, not maximum automation.

## Google Search — Responsive Search Ads

| Asset | Count | Limit |
|---|---|---|
| Headlines | up to 15 | 30 char each |
| Descriptions | up to 4 | 90 char each |

Pin sparingly — pinning everything removes the algorithm's ability to test
combinations.

## Meta Advantage+ (Shopping / Sales)

- Feed **15–20+ creative variations** across mixed orientations (1:1, 4:5, 9:16) so
  the algorithm has material to compare; 3–5 creatives make it a manual campaign in
  disguise.
- Primary text, headline, and description fields exist per placement; Meta truncates
  primary text in-feed around ~125 char — front-load the hook.
- Set the **existing-customer budget cap at 20–30%**, or delivery drifts to cheap
  retargeting reconversions and acquisition stalls.

## Meta manual (ABO / CBO)

Use for tight audience control, small budgets, or isolating a segment the algorithm
would dilute. Same creative fields; you control the audience and budget split per
ad set.

## Google Ads API version note (for scripting)

If you script against the API rather than the UI: Google moved to a **monthly release
cadence in 2026**. Latest is **v24.1 (released 2026-05-13)**, preceded by v24
(2026-04-22) and v23 (2026-01-28). Pin a version explicitly and watch the deprecation
window. *Source: developers.google.com/google-ads/api/docs/release-notes — accessed
2026-06-02.*
