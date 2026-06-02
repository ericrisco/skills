# Ledger schema

The touch/outcome ledger is the artifact `scripts/verify.sh` checks. One file:
`02-DOCS/linkedin-outreach/touches.csv`.

## Header (verbatim — verify.sh asserts this exact row)

```csv
date,name,profile_url,channel,trigger,action,stage,outcome,next_touch
```

## Columns

| Column | Type | Notes |
| --- | --- | --- |
| `date` | ISO date `YYYY-MM-DD` | The day of the touch. |
| `name` | text | The person. |
| `profile_url` | URL | LinkedIn profile (de-dupe key). |
| `channel` | enum | `connect` \| `inmail` \| `dm` \| `comment` \| `view`. |
| `trigger` | text | The reason you touched: `job_change`, `funding`, `post:<topic>`, `viewed_me`, `referral`. |
| `action` | text | What you did this touch (e.g. `commented on launch post`, `sent request no-note`). |
| `stage` | text | Free-text loop stage: `warm`, `requested`, `in_thread`, `handed_off`. |
| `outcome` | enum (no blanks) | `requested` \| `accepted` \| `replied` \| `conversation` \| `call_booked` \| `dead`. |
| `next_touch` | ISO date or empty | When to follow up; empty allowed only for terminal outcomes (`call_booked`, `dead`). |

No cell may contain a literal merge token or placeholder (`{first_name}`, `[company]`, `XXXX`, `TODO`) — verify.sh fails on it.

## Filled example

```csv
date,name,profile_url,channel,trigger,action,stage,outcome,next_touch
2026-05-26,Marta Ruiz,https://linkedin.com/in/martaruiz,comment,post:attribution,liked + commented on her attribution post,warm,replied,2026-05-28
2026-05-28,Marta Ruiz,https://linkedin.com/in/martaruiz,connect,post:attribution,sent request no-note,requested,accepted,2026-05-30
2026-05-30,Marta Ruiz,https://linkedin.com/in/martaruiz,dm,post:attribution,referenced post asked how she splits paid vs organic,in_thread,conversation,2026-06-02
2026-05-27,Tom Lai,https://linkedin.com/in/tomlai,inmail,job_change,InMail congratulating new RevOps role,requested,accepted,2026-05-30
2026-06-01,Tom Lai,https://linkedin.com/in/tomlai,dm,job_change,he asked for pricing — booked 20-min call,handed_off,call_booked,
```

## Weekly-review formulas

Compute over the rows for the period:

- **Acceptance %** = `count(outcome in {accepted,replied,conversation,call_booked}) / count(outcome in {requested,...})` — i.e. accepted-or-better ÷ all requests sent.
- **Post-accept reply %** = `count(replied|conversation|call_booked) / count(accepted-or-better)`.
- **Conversations → calls %** = `count(call_booked) / count(conversation|call_booked)`.
- **Touches/week** = rows whose `date` falls in the week.

Thresholds to act on: acceptance < ~30% → warm harder (phase 2). Reply < ~10% → weak hooks, write a better brief for cold-outreach. Touches/week ≈ 0 → the loop stopped, the real failure.
