# Monitoring config: the runnable stack

The default you can actually run is **`changedetection.io`** — open-source, self-hosted, no
vendor lock-in. It does text/visual, **XPath/CSS-selector**, and **JSON-API (JSONPath / jq)**
change detection; checks as often as ~1 minute; notifies via Slack/Discord/Telegram/email/API;
and ships AI change summaries like "Price dropped from \$89.99 to \$67.00"
(github.com/dgtlmoon/changedetection.io, accessed 2026-06-02).

## Self-host: docker-compose

```yaml
# docker-compose.yml — changedetection.io + a Playwright fetcher for JS-heavy pages
services:
  changedetection:
    image: ghcr.io/dgtlmoon/changedetection.io
    container_name: changedetection
    ports:
      - "5000:5000"
    volumes:
      - ./datastore:/datastore
    environment:
      - PLAYWRIGHT_DRIVER_URL=ws://playwright-chrome:3000
      - BASE_URL=https://watch.internal.example.com
    restart: unless-stopped
  playwright-chrome:
    image: dgtlmoon/sockpuppetbrowser:latest
    container_name: playwright-chrome
    restart: unless-stopped
```

Bring it up with `docker compose up -d`, open `http://localhost:5000`, and add one watch per
watched URL from the competitor profile.

## Per-axis watch definitions

Each watch = URL + selector + cadence. Map straight from the watch-list table in `SKILL.md`.

```text
# Pricing (time-sensitive → 5–15 min)
URL:       https://acme.com/pricing
Filter:    css:.price-amount          # CSS selector for the price node only
Cadence:   00:10:00                   # 10 minutes
Notify:    tgram://<token>/<chat_id>  # Telegram on change

# Features / changelog (daily)
URL:       https://acme.com/changelog
Filter:    css:.changelog li:nth-child(-n+5)   # first 5 release items
Cadence:   1 day

# Positioning / homepage (weekly)
URL:       https://acme.com
Filter:    css:h1.hero-title, css:.hero-subtitle
Cadence:   7 days
```

### JSON-API pricing (when price comes from an endpoint, not HTML)

If the pricing page hydrates from an API, watch the API and pin the exact field with JSONPath
— far more stable than scraping rendered HTML.

```text
URL:       https://acme.com/api/v2/plans
Filter:    json:$.plans[?(@.id=='pro')].monthly_price
Cadence:   00:10:00
```

### AI change summary (optional)

changedetection.io can attach an LLM that turns a raw diff into one line ("Pro monthly went
from \$49 to \$59"). Enable it per-watch when the page is noisy and you want the classification
pre-chewed — but you still own the axis + materiality call; the summary is an input, not the log.

## Notification wiring

Point the notify URL at where your team already lives. Common targets:

```text
tgram://<bot_token>/<chat_id>          # Telegram
slack://<token_a>/<token_b>/<token_c>  # Slack
discord://<webhook_id>/<webhook_token> # Discord
post://watch.internal.example.com/hook # your own webhook → automation-flows
```

The *scheduling and downstream routing* of those webhooks (cron, retries, fan-out into a
tracker write) is automation wiring → `../automation-flows/SKILL.md`. This skill defines the
watches; that skill makes them run reliably on a schedule.

## Wayback Machine — historical reconstruction ONLY

The Wayback Machine is a **passive archive, not a monitor**. It captures *some* snapshots (a
pricing page may be archived once in months, or never) and **does not tell you when something
changed**. Use it to reconstruct what a rival's page said in the past — never as the live
alerting layer.

Its "Changes" diff compares two existing captures (added = blue, deleted = yellow):

```text
# Compare two captured timestamps of the same URL
https://web.archive.org/web/diff/<TS1>/<TS2>/https://acme.com/pricing
# e.g. TS = 20260101000000 (YYYYMMDDhhmmss)
https://web.archive.org/web/diff/20260101000000/20260501000000/https://acme.com/pricing
```

(archive.org "Compare two versions", accessed 2026-06-02.) Good for "how did their positioning
read 6 months ago"; useless for "alert me when it changes."

## Self-host vs paid SaaS — when each is the right call

| Option | Price (accessed 2026-06-02) | Right call when |
|---|---|---|
| **changedetection.io** (self-host) | free / infra cost only | Default. You want a config you run, full selector control, no vendor. |
| Visualping | from ~\$10/mo | A few pages, want zero ops, visual diffs. |
| ChangeTower | from ~\$9/mo | Same — lightweight page monitor, hosted. |
| Kompyte | ~\$20K avg ARR (entry ~\$300/yr, 1–2wk setup) | You need site+social+filings 24/7 and a dedicated CI owner. |
| Crayon | median ≈\$28.7K/yr (~\$12K–\$47K, 7–8wk setup) | Many rivals, auto-updated battlecards, priced by # competitors. |
| Klue | ~\$16K–\$42.7K/yr (Basic/Standard/Premium, by seats) | Large CI team splitting "curators" vs "consumers." |

(vendr.com/marketplace/crayon, autobound.ai "Top 15 CI tools 2026", kompyte.com comparison,
visualping.io — accessed 2026-06-02.)

The paid suites also auto-update **battlecards** — but the battlecard itself is a sales
artifact owned by `../sales-pipeline/SKILL.md`, not this skill. A self-host config covers most
teams; reach for a suite only when breadth (many rivals, many surfaces, 24/7) outgrows what one
config + one owner can maintain.
