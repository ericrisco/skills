# Content calendar artifact — the contract

The calendar is the deliverable. It must be machine-readable enough for a scheduler
to import and human-readable enough to review. CSV, JSON array, or a Markdown table
all work — pick what the downstream tool ingests. `scripts/verify.sh` lints both
CSV and JSON.

## Columns

| Column | Required | Meaning |
| --- | --- | --- |
| `date` | yes | publish date, `YYYY-MM-DD` |
| `time` | yes | publish time, `HH:MM` (24h) |
| `timezone` | yes | IANA tz, e.g. `Europe/Madrid` — never ambiguous "9am" |
| `platform` | yes | one of `x`, `linkedin`, `instagram`, `threads`, `bluesky`, `tiktok`, `facebook`, `youtube` |
| `format` | yes | `post`, `thread`, `carousel`, `reel`, `short`, `story`, `video` |
| `source_asset_id` | yes | ties all rows derived from one source (the repurposing link) |
| `hook` | yes | the first line / scroll-stopper |
| `body` | yes | the post body — must respect the platform char cap |
| `media_ref` | no | path/URL/id of attached media, or null |
| `link` | no | destination URL (goes to first comment on LinkedIn/IG/FB) |
| `hashtags` | no | array/CSV of tags, per-platform convention |
| `status` | yes | `draft` → `scheduled` → `posted` |

## Status lifecycle

```text
draft       being written / not yet timed
scheduled   has a future date+time and is queued (verify.sh requires a future datetime)
posted      already live (date+time in the past)
```

A `scheduled` row with a past or malformed datetime is a hard error — fix the time
or move it to `draft`/`posted`.

## The repurposing link

`source_asset_id` is the glue. One blog post `blog-cloud-001` becomes many rows; all
of them carry `blog-cloud-001`. This lets you (and `verify.sh`) confirm that one
source produced *native variants*, not the same string pasted across platforms.

## CSV example

```csv
date,time,timezone,platform,format,source_asset_id,hook,body,media_ref,link,hashtags,status
2026-06-09,11:30,Europe/Madrid,linkedin,post,blog-cloud-001,We cut our cloud bill 38%,"We cut our cloud bill 38% last quarter. The boring one that mattered most: rightsizing before reserving. Here's the order we did it in.",,https://ex.co/cloud,#cloud,scheduled
2026-06-09,21:00,Europe/Madrid,x,thread,blog-cloud-001,5 ways we cut cloud cost,"5 ways we cut our cloud bill 38% in a quarter. A thread.",,,#cloud,scheduled
2026-06-10,11:00,Europe/Madrid,instagram,carousel,blog-cloud-001,38% off our cloud bill,"Swipe for the 6 moves. Save this one. Link in bio.",carousel-cloud.png,,#cloud #devops #finops,draft
```

## JSON example

```json
[
  {
    "date": "2026-06-09",
    "time": "11:30",
    "timezone": "Europe/Madrid",
    "platform": "linkedin",
    "format": "post",
    "source_asset_id": "blog-cloud-001",
    "hook": "We cut our cloud bill 38%",
    "body": "We cut our cloud bill 38% last quarter. The boring one that mattered most: rightsizing before reserving. Here's the order we did it in.",
    "media_ref": null,
    "link": "https://ex.co/cloud",
    "hashtags": ["#cloud"],
    "status": "scheduled"
  },
  {
    "date": "2026-06-09",
    "time": "21:00",
    "timezone": "Europe/Madrid",
    "platform": "x",
    "format": "thread",
    "source_asset_id": "blog-cloud-001",
    "hook": "5 ways we cut cloud cost",
    "body": "5 ways we cut our cloud bill 38% in a quarter. A thread.",
    "media_ref": null,
    "link": null,
    "hashtags": ["#cloud"],
    "status": "scheduled"
  }
]
```

## Importing into a scheduler

- **Buffer / Hootsuite:** import the CSV; map `date`+`time`+`timezone` to the scheduled
  slot and `body` to the post text. Hashtags and link usually go inline or to a
  first-comment field where supported.
- **Mixpost:** create posts per row; use its first-comment + dynamic-variable features
  for the `link` and per-platform variants.
- **Postiz:** map rows to its calendar; one `source_asset_id` group = one campaign.

Keep one row per platform per post — never one row meant to fan out to all channels.
The whole point is per-platform native shaping, and the verifier flags byte-identical
bodies across platforms for exactly this reason.
