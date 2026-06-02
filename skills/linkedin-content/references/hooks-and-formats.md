# Hooks, format templates, and the 02-DOCS post log

Depth offloaded from `SKILL.md`. Use this when you need the full hook library, a
fill-in template for any of the three formats, or the schema for logging posts and
reading outcomes back. Every char budget and engagement figure traces to the keyed
sources `[S1]`–`[S4]` listed in `SKILL.md` ("Sources" section, all accessed
2026-06-02); the multipliers there are flagged as directional, not confirmed.

## Hook pattern library

The hook lives in the first ~150 characters — the visible zone before *see more*.
Pick the pattern that fits the idea; each one front-loads tension or specificity so
the eye keeps moving.

| # | Pattern | Shape | Bad | Good |
|---|---|---|---|---|
| 1 | Number-lead | A surprising metric first | "We grew a lot last year." | "We added $1.2M ARR with zero paid ads. Here's the only channel that worked." |
| 2 | False-start | Admit the thing people won't | "Some lessons on hiring." | "I hired for culture fit for 5 years. It was the most expensive mistake I made." |
| 3 | Contrarian | Reject the consensus | "Networking is important." | "Networking events are a waste of time. I closed our biggest deal in a DM." |
| 4 | Open-loop | Promise an answer, withhold it | "Here's how we handle churn." | "One churned customer's exit interview changed our whole roadmap. I almost deleted the email." |
| 5 | Named-stakes | Put a real cost on the line | "Thoughts on pricing." | "We raised prices 40% expecting churn. We lost 2 customers and gained $300k." |
| 6 | Before→after | Two states, sharp delta | "Onboarding improved." | "Onboarding took 3 weeks. Now it takes 3 days. The change was one deleted step." |
| 7 | Confession | A mistake you own | "Mistakes were made." | "I ghosted a candidate for 6 weeks. He's now a competitor's VP. Here's what I'd do differently." |
| 8 | Pattern-callout | Name a thing everyone does | "Meetings can be inefficient." | "Every 'quick sync' on your calendar is a decision someone was afraid to make alone." |
| 9 | Question-trap | A question the reader can't not answer | "Do you struggle with focus?" | "When did 'busy' become the answer to 'how are you?' I want to opt out." |
| 10 | Receipt | Lead with proof | "Our product helps teams." | "47 support tickets in one week, all the same complaint. We rebuilt the feature in a sprint." |

Rule across all ten: the first line must be readable and complete on its own line on
mobile — do not let a thought run past the truncation point mid-clause.

## Text post template (1,300–1,900 chars)

```text
[HOOK — ~150 chars, one of the 10 patterns. First line readable alone.]
[Second line escalates the hook.]

[TURN — ~300–400 chars. The pivot: the non-obvious thing.
1–2 sentence paragraphs, blank line between blocks.]

[PAYOFF — ~600–900 chars. The story/lesson/proof the hook promised.
One idea per line. Use → or ▸ as occasional bullets, not confetti.
Unicode emphasis on at most one or two phrases.]

[CTA — ~100–200 chars. A question only the reader can answer.
Never "thoughts?".]

[No link. No "link in comments". If a link is unavoidable, decide knowingly.]
```

## Document / PDF post template (3–10 slides)

```text
COVER (slide 1):
  [Hook line, large, thumbnail-readable — does the see-more job here too.]

SLIDES 2–N (3–10 total):
  Slide 2: [One idea. Ends pulling the swipe.]
  Slide 3: [One idea.]
  ...
  Slide N: [Payoff + the single takeaway.]

CAPTION (100–200 words):
  [Frame the deck in the text-post arc, miniaturized.]
  [End on a comment-earning CTA.]
```

Hand the slide *text* to `../linkedin-carousels/SKILL.md` for layout, visual system,
and PDF export. You write words; that skill renders pixels.

## Native-video template (30–90s)

```text
SCRIPT BEATS:
  0–3s   HOOK (visual + spoken; most viewers are muted, so the on-screen
         text must carry it alone).
  3–15s  TURN — the non-obvious pivot.
  15–75s PAYOFF — story/proof, escalating.
  last   SPOKEN CTA — one answerable question.

CAPTION (text-post arc in miniature):
  [Hook line + 2–4 short lines + comment-CTA. No body link.]
```

Sub-60s short-form gets ~53% more engagement than longer; 30–90s is the band. For a
cross-platform vertical short (Reels/TikTok/Shorts), route to `../video-shorts/SKILL.md`.

## The 02-DOCS post log

Log every published post so the next draft can learn. One markdown file per post (or
a single appended log), front-matter first:

```yaml
---
date: 2026-06-02        # publish date
format: text            # text | document | video
hook: "We almost shut the product down in March."
hook_pattern: confession # one of the 10 patterns above
cta_type: experience-ask # experience-ask | disagreement-ask | number-ask
char_count: 1640
# --- filled in later, once metrics land ---
impressions: 0
dwell_s: 0              # avg dwell in seconds (the currency)
comments: 0
saves: 0
---
[the full post body, for reference]
```

**Reading it back to bias drafts:** before writing, scan the log and sort by
`dwell_s` and `comments` (the weighted signals), not impressions. Note which
`hook_pattern`, `format`, and `cta_type` recur among the top performers *for this
account*, and lean the new draft toward them. A pattern that wins generically but
flops for this audience loses to one that wins here. After publishing, append the new
row; fill metrics in when they stabilize (~48–72h).
