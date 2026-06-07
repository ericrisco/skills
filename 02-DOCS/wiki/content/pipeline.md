# Production Pipeline of Record — Tend (4-person team)

*The how-it-moves machine. Every calendar slot (`q3-2026-calendar.csv`) travels these
stages. Output stays consistent regardless of who writes it.*

`idea → brief → draft → edit → atomize → publish-ready`

## Stage gates

| Stage | Entry gate | Exit gate | WIP |
|---|---|---|---|
| `idea` | slot exists in calendar with pillar + cluster assigned | brief written + owner set | backlog (unbounded) |
| `brief` | brief written in `briefs/<slug>.md` | all required fields present; `target_keyword` filled by seo-geo (not invented); `voice_ref` linked | small |
| `draft` | brief complete | a draft exists, hits the brief's format + angle | cap 3–4 in flight (whole team) |
| `edit` | draft exists | edited against the brief AND `voice-guide.md` (ban-scan, rule-check, trait-test) | within the same 3–4 cap |
| `atomize` | flagship passed edit (non-flagships skip straight to publish-ready) | atomization plan filled, ≥10 derivatives, each with owner + destination | 1–2 |
| `publish-ready` | all derivatives planned + routed | every asset has an owner + a destination | — |

**Hard rules enforced by the gates:**
- A slot **cannot leave `idea` without a brief** (blocks output drift).
- A **flagship cannot leave `edit` without an atomization plan of ≥10 derivatives** (no 1:10 leverage left on the floor).
- Editing is **always** a pass against `voice-guide.md` — the three-pass drift audit (ban scan → rule check → trait test). AI may draft; a human owns angle and "good."

**WIP discipline (small-team row):** cap **3–4 slots in flight** across draft+edit. Finish
before you pull a new idea. Exceeding the cap is how the calendar becomes a graveyard.

## Owners (4 people)

| Owner | Role | Owns in the pipeline |
|---|---|---|
| `ana` | Content lead | flagship briefs, LinkedIn posts, calendar of record, gate decisions |
| `leo` | Writer | drafts, X threads, newsletter issues, article updates |
| `mara` | Designer / video | carousels, video-shorts, quote graphics, infographics |
| `tom` | Founder / SME | proof interviews, case studies, founder-POV posts, expert review |

## Who fills each station — route, do not write

| Station | Routed to |
|---|---|
| Long-form flagship + case-study draft/edit | `article-writing` |
| Newsletter issue copy | `newsletter` |
| Short-form video script/storyboard | `video-shorts` |
| Keyword research + clusters + `target_keyword` (the open gate) | `seo-geo` |
| The act of publishing/scheduling to platforms | `social-publisher` |
| Landing/launch page copy | `marketing` |
| Automating publish/atomize as a cron/webhook flow | `automation-flows` |

`content-engine` owns the slot and its stage. It does not write the words and does not ship them.

## Atomization plans (1 flagship → ≥10 derivatives)

Each Q3 flagship's plan is in its brief (`atomization_intent`). The derivative menu and
per-channel native Bad→Good rewrites live in `references/atomization.md`. Reformat every
derivative to its channel; never copy-paste across platforms. Route each derivative to its
specialist station above; route the act of shipping to `social-publisher`.

- **Jul — Cash-flow forecast guide** → see `briefs/cash-flow-forecast-guide.md`
- **Aug — Treasury for small teams** → see `briefs/treasury-small-teams-guide.md`
- **Sep — Month-end close** → see `briefs/month-end-close-guide.md`

## Standing rules baked into the calendar

- **Mix 70 / 20 / 10:** ~70% evergreen, ~20% timely, ~10% experimental.
- **Slack:** ~25% of slots are `reactive-open` (empty owner) — do not pre-fill them.
- **Update budget:** ~20% of weekly capacity refreshes winners (`update-article` rows), not net-new only.
- **Cadence:** 1 flagship/month, ~5 supporting/week, 1 proof/month.

## Verify

`scripts/verify.sh 02-DOCS/wiki/content/q3-2026-calendar.csv` lints structure: required
columns, valid stages, every flagship has a brief_link + atomization plan, and mix sanity.
Read-only; it gates structure, not whether the plan is good.
