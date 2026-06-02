# Analytics API v2 — metric/dimension catalog + copy-paste queries

Every report is the same shape:

```text
GET https://youtubeanalytics.googleapis.com/v2/reports
  ?ids=channel==MINE
  &startDate=YYYY-MM-DD
  &endDate=YYYY-MM-DD
  &metrics=<comma list>
  &dimensions=<comma list>     (optional)
  &filters=<key==value;...>    (optional)
  &sort=<metric>               (optional)
  &maxResults=<n>              (optional)
```

`ids=channel==MINE` reports on the authenticated user's channel.

## Core metrics

| Metric | Meaning |
| --- | --- |
| `views` | view count |
| `estimatedMinutesWatched` | total watch time (minutes) |
| `averageViewDuration` | mean seconds watched per view |
| `averageViewPercentage` | mean % of the video watched |
| `subscribersGained` / `subscribersLost` | net subs movement |
| `likes`, `comments`, `shares` | engagement |
| `audienceWatchRatio` | absolute retention at a playback position |
| `relativeRetentionPerformance` | retention vs similar videos |
| `impressions`, `impressionClickThroughRate` | **content-owner-report metrics** — see CTR note |
| `estimatedRevenue` | needs `yt-analytics-monetary.readonly` scope |

## Useful dimensions

| Dimension | Use |
| --- | --- |
| `day` / `month` | time series |
| `video` | per-video breakdown |
| `elapsedVideoTimeRatio` | retention curve x-axis (0.0–1.0) |
| `insightTrafficSourceType` | where views come from |
| `country` | geography |
| `deviceType` | mobile/desktop/TV/tablet |
| `subscribedStatus` | `SUBSCRIBED` vs `UNSUBSCRIBED` |
| `ageGroup`, `gender` | demographics |

## Copy-paste query bodies (Python `yta.reports().query(...)`)

```python
# Daily time series for the month
dict(ids="channel==MINE", startDate="2026-05-01", endDate="2026-05-31",
     metrics="views,estimatedMinutesWatched,averageViewPercentage", dimensions="day")

# Top videos by views
dict(ids="channel==MINE", startDate="2026-05-01", endDate="2026-05-31",
     metrics="views,estimatedMinutesWatched,averageViewPercentage",
     dimensions="video", sort="-views", maxResults=10)

# Retention curve for one video
dict(ids="channel==MINE", startDate="2026-05-01", endDate="2026-05-31",
     metrics="audienceWatchRatio,relativeRetentionPerformance",
     dimensions="elapsedVideoTimeRatio", filters="video==VIDEO_ID")

# Traffic sources
dict(ids="channel==MINE", startDate="2026-05-01", endDate="2026-05-31",
     metrics="views,estimatedMinutesWatched", dimensions="insightTrafficSourceType")

# Geography
dict(ids="channel==MINE", startDate="2026-05-01", endDate="2026-05-31",
     metrics="views,estimatedMinutesWatched", dimensions="country", sort="-views")

# Device + subscribed status
dict(ids="channel==MINE", startDate="2026-05-01", endDate="2026-05-31",
     metrics="views", dimensions="deviceType")
dict(ids="channel==MINE", startDate="2026-05-01", endDate="2026-05-31",
     metrics="views,averageViewPercentage", dimensions="subscribedStatus")
```

## `insightTrafficSourceType` values

`YT_SEARCH` (search), `SUGGESTED` (suggested videos), `BROWSE` (home/subscriptions feed), `EXT_URL` (external sites), `NOTIFICATION`, `PLAYLIST`, `END_SCREEN`, `NO_LINK_EMBEDDED`, `NO_LINK_OTHER`, `CHANNEL`, `SUBSCRIBER`.

## CTR / impressions: content-owner vs channel reports

`impressions` and `impressionClickThroughRate` are surfaced through **content-owner reports**, not reliably through a plain `channel==MINE` query. If a channel query returns empty for them, that is expected — do not treat it as an error and do not block the pull. Read the CTR value from YouTube Studio for the wiki entry instead. Everything else (views, watch time, retention, traffic) is available on the channel query.

## Valid combinations

Not every metric pairs with every dimension. `audienceWatchRatio` requires the `elapsedVideoTimeRatio` dimension and a single-`video` filter. Demographic dimensions (`ageGroup`, `gender`) only return percentage-style metrics (`viewerPercentage`), not raw `views`. When a combination is invalid the API returns a `400` naming the offending field — fix by aligning metric and dimension from the tables above.
