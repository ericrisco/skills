# Publish call bodies + the metric catalog split by API

Copy-paste request shapes for the full publish flow and the exact field split between
Display (counters) and Business (rich insights).

## Publish — FILE_UPLOAD init

```json
POST https://open.tiktokapis.com/v2/post/publish/video/init/
Authorization: Bearer <access_token>
Content-Type: application/json; charset=UTF-8

{
  "post_info": {
    "title": "caption text #fyp",
    "privacy_level": "SELF_ONLY",
    "disable_comment": false,
    "disable_duet": false,
    "disable_stitch": false
  },
  "source_info": {
    "source": "FILE_UPLOAD",
    "video_size": 10485760,
    "chunk_size": 10485760,
    "total_chunk_count": 1
  }
}
```

Response `data` carries `publish_id` and `upload_url`.

### Chunk math (the part people get wrong)

- Chunk size **min 5 MB, max 64 MB**; the **final** chunk may run up to **128 MB**.
- **1–1000 chunks** total, uploaded **sequentially**.
- A file **under 5 MB is a single chunk** whose `chunk_size` equals the file size and
  `total_chunk_count` is 1.
- Each `PUT` to `upload_url` carries `Content-Range: bytes {first}-{last}/{total}` and
  returns **206** (more to send) or **201** (final chunk accepted).

```python
# the PUT loop, expanded
with open(path, "rb") as f:
    for i in range(total_chunk_count):
        first = i * chunk_size
        blob = f.read(chunk_size)
        last = first + len(blob) - 1
        r = requests.put(upload_url, data=blob, headers={
            "Content-Type": "video/mp4",
            "Content-Range": f"bytes {first}-{last}/{video_size}",
        })
        assert r.status_code in (206, 201), (r.status_code, r.text)
```

## Publish — PULL_FROM_URL init

Requires a **verified** domain/URL-prefix (see oauth-setup.md §6), HTTPS, no redirects.

```json
POST https://open.tiktokapis.com/v2/post/publish/video/init/

{
  "post_info": { "title": "caption #fyp", "privacy_level": "SELF_ONLY" },
  "source_info": {
    "source": "PULL_FROM_URL",
    "video_url": "https://verified.example.com/clips/clip.mp4"
  }
}
```

No chunk PUT needed — TikTok fetches the file itself. Then poll status as usual.

## Upload to draft (inbox)

For "let the user finish/post it in-app," swap the endpoint to
`https://open.tiktokapis.com/v2/post/publish/inbox/video/init/` with scope
`video.upload`. Same `source_info`/chunk rules; the video lands in the user's drafts.

## Status poll

```json
POST https://open.tiktokapis.com/v2/post/publish/status/fetch/
{ "publish_id": "<publish_id>" }
```

`data.status` walks through `PROCESSING_UPLOAD` / `SEND_TO_USER_INBOX` →
`PUBLISH_COMPLETE` or `FAILED`. Poll on a sleep, never a tight loop —
**6 requests/minute per user token** or you hit `rate_limit_exceeded`.

## Metric catalog — which API returns what

### Display API — `POST /v2/video/query/` (counters only)

Pass `fields` as a query param; filter by `video_ids` (**≤20 per request**). Scope
`video.list`. Returns ONLY:

| Field | Meaning |
| --- | --- |
| `id` | Video id |
| `title` | Caption/title |
| `view_count` | Total views |
| `like_count` | Likes |
| `comment_count` | Comments |
| `share_count` | Shares |
| `duration` | Video length (s) |
| `create_time` | Post timestamp |

There is **no watch-time, completion, or impression-source field here.** Asking for one
returns nothing — that is the wrong-API assumption `verify.sh` flags.

### Business Account API — video list + insights (the rich metrics)

The engagement signal lives only here:

| Field | Meaning |
| --- | --- |
| `average_time_watched` | Mean seconds watched per view |
| `total_time_watched` | Aggregate watch time |
| `full_video_watched_rate` | Completion rate (watched to the end) |
| `impression_sources` | Traffic breakdown: For You / Following / personal profile / search / sound |
| `audience_countries` | Top viewer geographies |

### Lag caveat

Business insight metrics **lag 24–48h** and can differ from the in-app numbers. A pull
within ~2 days of posting is **provisional** — log it, then watch it settle across
later pulls (this is exactly why the wiki log appends instead of overwriting).
