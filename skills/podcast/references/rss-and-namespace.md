# RSS, iTunes, and the Podcasting 2.0 namespace

Deep reference for Phase 4 (Publish). All facts accessed 2026-06-02. Load this when hand-writing or auditing a feed; the SKILL body has the rules, this has the full shapes.

## Channel-level tags (the show, once per feed)

Required by Apple at the `<channel>` level:

- `<title>` — the show name.
- `<description>` — show description.
- `<itunes:image href="…"/>` — square JPG/PNG, RGB, **1400-3000 px** (same constraint as episode art).
- `<language>` — ISO 639 (e.g. `en`, `ca`, `es`).
- `<itunes:category text="…"/>` — at least one valid Apple category (nest a `<itunes:category>` child for a subcategory).
- `<itunes:explicit>` — `true` or `false`.
- `<link>` — the show's site URL.
- `<itunes:author>` and `<itunes:owner>` (`<itunes:name>` + `<itunes:email>`) — owner email is how Apple verifies the feed.

Recommended: `<itunes:type>` (`episodic` or `serial`), `<copyright>`, `<generator>`, `<atom:link rel="self" .../>`, and the Podcasting 2.0 `<podcast:guid>` (a feed-stable GUID that follows the show across hosts).

## Item-level tags (one per episode)

Required / strongly recommended:

```xml
<item>
  <title>Episode 12: How Marta scaled a solo SaaS to $40k MRR without ads</title>
  <itunes:title>How Marta scaled a solo SaaS to $40k MRR</itunes:title>
  <itunes:episode>12</itunes:episode>
  <itunes:season>2</itunes:season>
  <itunes:episodeType>full</itunes:episodeType>
  <pubDate>Mon, 02 Jun 2026 08:00:00 GMT</pubDate>
  <enclosure url="https://cdn.example.com/ep12.mp3" length="34185216" type="audio/mpeg"/>
  <guid isPermaLink="false">ep-2026-012-a1b2c3</guid>
  <itunes:duration>35:14</itunes:duration>
  <itunes:image href="https://cdn.example.com/ep12-cover.jpg"/>
  <itunes:explicit>false</itunes:explicit>
  <description><![CDATA[ ...blog-shaped show notes HTML... ]]></description>

  <!-- Podcasting 2.0 enrichments -->
  <podcast:transcript url="https://cdn.example.com/ep12.vtt" type="text/vtt"/>
  <podcast:transcript url="https://cdn.example.com/ep12.srt" type="application/srt"/>
  <podcast:chapters url="https://cdn.example.com/ep12.chapters.json"
                    type="application/json+chapters"/>
  <podcast:person role="host"  img="https://cdn.example.com/host.jpg">Alex Host</podcast:person>
  <podcast:person role="guest" img="https://cdn.example.com/marta.jpg">Marta Founder</podcast:person>
  <podcast:season name="Season 2">2</podcast:season>
  <podcast:episode>12</podcast:episode>
</item>
```

Tag notes that bite:

- **`<enclosure length>` is bytes**, not duration. Wrong value breaks the scrubber. Read the file's actual size.
- **`<guid>` is permanent.** Set it once; changing it makes every app treat the episode as new (duplicate). `isPermaLink="false"` when it is an opaque ID rather than a URL.
- **`<pubDate>` is RFC-822.** Future-dated items may be held until that date by some hosts.
- **`<itunes:episodeType>`** is `full`, `trailer`, or `bonus`.

## Podcasting 2.0 tags (namespace `xmlns:podcast="https://podcastindex.org/namespace/1.0"`)

| Tag | Key attributes | Purpose |
| --- | --- | --- |
| `podcast:transcript` | `url`, **`type` (required)** | links a transcript; `type` ∈ `text/vtt`, `application/srt`, `application/json`. Multiple allowed. |
| `podcast:chapters` | `url`, `type="application/json+chapters"` | links a hosted chapters JSON; editable after publish. |
| `podcast:person` | `role`, `group`, `img`, `href` | identifies host/guest with role + image. |
| `podcast:season` | `name` (text body = number) | names/numbers the season. |
| `podcast:episode` | `display` (text body = number) | episode number, separate from `<itunes:episode>`. |
| `podcast:funding` | `url` (text body = label) | a support/donate link shown in-app. |

Apple auto-generates transcripts (since 2024-03) and chapters (iOS 26.2). **Auto-chapters only fire when no `podcast:chapters` is supplied** — a manual file always wins, so ship one when titles/timing matter.

## chapters.json shape

```json
{
  "version": "1.2.0",
  "chapters": [
    { "startTime": 0,    "title": "Cold open" },
    { "startTime": 30,   "title": "Intro" },
    { "startTime": 252,  "title": "The first paying customer", "img": "https://cdn.example.com/ch3.jpg" },
    { "startTime": 1140, "title": "Why no paid ads" },
    { "startTime": 2050, "title": "What's next + CTA" }
  ]
}
```

Rules: `startTime` is **seconds** (number), titles present, and startTimes **monotonically non-decreasing**. Optional per-chapter `img`, `url`, `endTime`, `toc`. (Conforms to the Podcast Namespace JSON Chapters spec.)

## transcript.vtt snippet

```text
WEBVTT

00:00:00.000 --> 00:00:04.500
<v Alex>Welcome back to the show. Today, Marta.

00:00:04.500 --> 00:00:09.200
<v Marta>Thanks for having me — happy to get into it.
```

`WEBVTT` must be the first line. Speaker labels via `<v Name>` are optional but improve readability and accessibility.

## PodcastEpisode JSON-LD (show-notes page)

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "PodcastEpisode",
  "name": "How Marta scaled a solo SaaS to $40k MRR without ads",
  "datePublished": "2026-06-02",
  "duration": "PT35M14S",
  "url": "https://example.com/podcast/ep12",
  "associatedMedia": {
    "@type": "MediaObject",
    "contentUrl": "https://cdn.example.com/ep12.mp3"
  },
  "partOfSeries": {
    "@type": "PodcastSeries",
    "name": "The Solo SaaS Show",
    "url": "https://example.com/podcast"
  }
}
</script>
```

`duration` is ISO-8601 (`PT35M14S` = 35 min 14 s). This makes the episode page eligible for rich results and feeds AI engines a structured episode object.

## Sources

- RSS.com — Best Podcast Hosting Platforms / submission + artwork (2026).
- Apple Podcasters — Enhance episodes with chapters, links, and more; Apple Newsroom — transcripts (2024-03); Castopod/TechBuzz — iOS 26.2 auto-chapters.
- Podcasting 2.0 — Podcast Namespace docs (podcasting2.org / podcastindex.org).
- VNYL RSS guide; Spotify for Creators.
- SONE — Podcast Loudness Standards 2026; Descript — Podcast Loudness Standard; Podnews — LUFS/LKFS FAQ.

All accessed 2026-06-02.
