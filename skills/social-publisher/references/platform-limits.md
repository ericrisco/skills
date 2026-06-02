# Platform limits & API reality (2026)

Every number below carries its source and was **accessed 2026-06-02**. These move
fast — re-check before promising programmatic publishing. Treat caps as ceilings,
not targets; treat best-time slots (in SKILL.md) as hypotheses to validate against
the account's own analytics.

## Per-platform table

| Platform | Char cap | Media spec (headline) | API content-publishing limit | Rate limit | OAuth / approval gate | 2026 cost note |
| --- | --- | --- | --- | --- | --- | --- |
| **X (Twitter)** | 280 / post (longer on paid) | image ≤5MB; video ≤512MB, ≤2:20 (longer on paid) | legacy Free ~500 posts/month, no new signups | tier-dependent | OAuth 2.0; new apps default to pay-per-use | **Pay-per-use default for new devs** ~$0.01/post; URL posts cost more |
| **LinkedIn** | ~3,000 chars; "see more" cutoff ~210 | image ≤5MB; video ≤200MB, 3s–10min | UGC/Share API ~100 calls/day/member | member-level | free OAuth = Sign-In + basic profile only; posting needs approval | Marketing/advanced partner tier from **~$699+/mo** |
| **Instagram** | 2,200 caption; 30 hashtags max (use 3–5) | image 1080px; Reel ≤90s typical; carousel ≤20 | **~25–50 published posts / rolling 24h** (varies 25/50/100 by trust) | ~200 requests/hour/account | Graph API; Business/Creator account + app review | free; rolling-24h window, not calendar-day |
| **Threads** | 500 chars | image + short video | via Threads API (limited) | low | OAuth via Meta | free; light-hashtag culture |
| **Bluesky** | 300 chars | image + short video | AT Protocol create-record | **~5,000 points/hour** | **OAuth** (App Passwords deprecated for new projects; `transition:email` scope shipped 2025-06-12) | free |
| **TikTok** | 2,200 caption | vertical 9:16; video to several min | Content Posting API; **forces `SELF_ONLY` until audited** | per-app | separate **audit** required before public posts | free; audit gate |
| **Facebook** | ~63k (keep short) | native video > shared link | Graph API publish | per-app | Page access token + app review | free |
| **YouTube** | title 100, desc 5,000 | Shorts ≤60s; long-form to hours | Data API upload quota (cost in quota units) | daily quota | Google OAuth + app verification | free within quota; quota-limited |

Sources for the rows above: Meta Instagram Platform docs "Content Publishing Limit";
InstantDM 2026 IG API rate-limit guide; Zernio / Postproxy / Blotato X API pricing 2026;
Phyllo / SociaVault LinkedIn API 2026; Bluesky / AT Protocol docs (OAuth announced
2024-09-25, `transition:email` 2025-06-12); Blotato / PostPeer 2026 platform guides
(TikTok audit / `SELF_ONLY`). All accessed 2026-06-02.

## The 2026 gotchas, restated

- **Instagram window is rolling.** The ~25–50 cap is measured over the last 24 hours
  continuously, not reset at midnight. A launch that fires 40 posts at 9am can be
  throttled at 9am the next day even though it is a "new day".
- **X now costs money for new apps.** New developers default to pay-per-use; do not
  promise free programmatic posting on X for a fresh app.
- **LinkedIn posting is gated.** Free OAuth does not let you post. Posting needs
  approval, runs ~100 calls/day/member, and the advanced tier is **~$699+/mo**.
- **TikTok forces private until audited.** Your API posts are `SELF_ONLY` (only the
  poster can see them) until TikTok approves the app via audit.
- **Bluesky is OAuth + points-budget.** App Passwords are deprecated for new
  projects; the ~5,000 points/hour cap is generous but real.

## Execution layer — what actually publishes the calendar

This skill produces the plan; one of these consumes it.

| Option | What it is | When to pick it |
| --- | --- | --- |
| **Hosted scheduler** (Buffer, Hootsuite) | SaaS calendar + queue; import CSV | few channels, no infra, manual-ish |
| **Mixpost** | Laravel, **self-hosted**, one-time license; drag-drop calendar, first-comment, dynamic variables | you want to own data + a paid self-host |
| **Postiz** | **Apache-2.0, free**, 15+ platforms, self-hostable | open-source self-host, no license fee |
| **Unified API** (Blotato-style) | one API across many platforms | programmatic posting without per-platform auth pain |

(Mixpost.app; Postiz blog "Open Source Social Media Scheduler 2025" / GitHub
inovector/mixpost — accessed 2026-06-02.)

The skill's job ends at a calendar these tools can import. Deploying Mixpost/Postiz
or wiring a unified API is infrastructure work, not part of this skill.
