# Platform limits cheatsheet (2026)

Dated numbers live here so SKILL.md stays evergreen. Design against the *metering model*, not these exact figures — re-verify before quoting a price to anyone.

## Bubble — metered by Workload Units (WU)

Every DB query, workflow run, and API call burns WU. Cost is a function of usage, not seats.

| Tier | Price (web) | WU/month |
| --- | --- | --- |
| Free | $0 | ~50K (dev/trial) |
| Starter | $29/mo | 175K |
| Growth | $119/mo | 250K |
| Team | $349/mo | 500K |
| Enterprise | custom | custom |

- The allotments are small and the steps between tiers are small — Growth's 250K is only **~1.43x** Starter's 175K. A widely-repeated older claim put Growth at **1M WU** (a 4x jump); that figure is stale and unsupported by any current source — do not design around it. Plan around the metering, not the tier names.
- Prices shift with billing choice: the figures above are **web-only, annual billing**. Web+mobile and monthly billing run higher (e.g. Starter up to ~$59, Team up to ~$549); the WU allotments per tier stay 175K / 250K / 500K across those variants.
- Overage: extra WU is sold in packs (≈ $0.30 per 1,000 WU as a rough run rate) beyond the tier allotment — verify the current pack pricing before quoting.
- Warning emails at **75%** and **100%** of allotment — wire these to a human.
- Source: goodspeed.studio "Bubble.io Pricing 2026" (last updated 2026-05-29, verified against the official pricing page), adalo.com/posts/bubble-pricing, lowcode.agency Bubble pricing, manual.bubble.io pricing-plans, bubble.io/pricing (re-verified 2026-06-02). Three independent write-ups plus the Bubble docs agree on 175K / 250K / 500K WU.

## Glide — metered by "updates" (data writes)

Billed on writes, not seats. Cost is unpredictable as write volume grows.

| Tier | Price | Notes |
| --- | --- | --- |
| Free | $0 | Draft apps; up to 25K rows |
| Maker | $25/mo | personal/community apps, more features than Free |
| Team | $99/mo | unlimited apps, 20 users, 5K updates/mo, Glide Basic API |
| Business | $249/mo | unlimited apps, 30 users, 5K updates/mo, rows capped: ~25K with an external/standard source, ~100K with Glide (Big) Tables |

- The Business row cap is real and load-bearing: a standard/external data source tops out around **25K rows**; you only reach **~100K rows** on Glide's own (Big) Tables. Pick the data source with that ceiling in mind.
- Update overage beyond the monthly allotment is charged per extra update — confirm the current per-update rate before quoting.
- Source: glideapps.com/pricing, adalo.com/posts/glide-pricing, costbench.com Glide 2026, Glide community "Data rows in business plan? 25000 or 100000?" (verified 2026-06-02).

## Softr — flat-rate per workspace (not metered)

No per-write metering; no charge for internal editors → the most predictable scaling of the three.

| Tier | Price | Notes |
| --- | --- | --- |
| Basic | ~$49/mo (annual) | 3 apps, 20 app users, **10,000 records/base** (50,000 records/workspace) for the Softr DB; custom code, payments |
| Professional | ~$139/mo | 50,000 records/base (500,000/workspace) |
| Business | ~$269/mo | 200,000 records/base (1,000,000/workspace) |

- The Basic per-base cap is **10,000 records**, *not* 50K. The 50K figure is the **per-workspace** total across bases — easy to mistake for the per-base limit, which is the one a single dataset actually hits. Size against the 10K-per-base number early.
- External/advanced data sources (SQL, BigQuery, Xano, Supabase) get much higher per-app limits (Basic ~500K), so the 10K cap bites hardest on the native Softr DB.
- Source: softr.io/pricing (re-verified 2026-06-02 — Basic 10,000/base, 50,000/workspace), docs.softr.io pricing-and-plans, Softr community "Database Limits for Basic Plan", adalo.com/posts/softr-pricing.

## Backend comparison

| | Airtable | Xano |
| --- | --- | --- |
| What | Relational DB with a spreadsheet UI | Full backend: PostgreSQL + visual API builder |
| Record cap | ~50K records/base on the common Team tier (Free 1K, Business 125K) — cumulative across the base's tables | Scales (real DB) |
| API speed | Slow | <200ms typical |
| Best for | Simple read/create, admin data entry | Complex logic, performance, security, scale |

Note the Airtable per-base cap (~50K on Team) is a *different* number from Softr's Basic per-base cap (10K) — don't conflate them. The Airtable limit counts all records across all tables in one base.

Hybrid pattern: **Airtable for human data entry/admin, Xano for API logic + perf + security.**

Source: airtable.com/pricing (Team ~50K/base, Business 125K — re-verified 2026-06-02), xano.com/versus/xano-vs-airtable, minimum-code.com, adalo.com.

## Cost-estimation worked examples

**Bubble (WU):** estimate WU per user action ≈ (DB queries + workflow steps + API calls) it triggers. Multiply by expected actions/month.

```text
1 booking action ≈ 3 queries + 4 workflow steps + 1 payment API call ≈ ~8 WU
2,000 bookings/mo  => ~16K WU just for bookings (comfortably under Starter's 175K)
add page loads, searches, dashboards, scheduled jobs => easily 100K-300K WU/mo
=> the overhead, not the bookings, is what eats the budget: 100K-300K WU lands you
   on the edge of Starter (175K) and quickly past it — Growth only buys 250K, so a
   single feature that loops an API call per row pushes you to overage, not just a
   tier bump. Budget against total WU, not the headline booking count.
```

**Glide (updates):** count data writes per user per month.

```text
Each user: ~10 writes/visit x 8 visits/mo = ~80 updates/user/mo
500 users => ~40K updates/mo, on top of tier allotment, overage ~$0.02 each.
```

**Softr (flat):** the same workloads cost the tier price regardless of write volume — this is why it is the predictable choice for portals.

## Migrate-off trigger list

Stop adding features and start the migration plan when **two or more** fire:

1. **Logic outgrows the canvas** — many-branch conditionals, custom algorithms that fight the visual builder.
2. **Performance wall** — the app crawls at real row counts (snappy at 100, slow at 10,000; load-test at 10x early).
3. **Cost crossover** — the metered bill exceeds what a real backend + hosting would cost.

Context: ~25-30% of no-code projects get rewritten when they outgrow the tool; rebuild cost **$50K-$250K**; ~68% of platforms offer **no code export** (verify data export on day 1).

Source: weweb.io code-export buyer's guide, nocodefinder.com vendor lock-in, designrevision.com platform comparison (accessed 2026-06-02).
