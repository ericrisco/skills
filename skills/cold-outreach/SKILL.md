---
name: cold-outreach
description: "Use when writing a cold email or DM to someone with no prior relationship, building a follow-up sequence, deciding how fast/how much to send per inbox so it stays out of spam, or rescuing outreach that reads like a template. Covers first-touch copy under a word ceiling, 4-7 step bump sequences, email-vs-LinkedIn variants, per-inbox volume and new-domain warm-up ramps, and the CAN-SPAM/GDPR opt-out footer. Triggers: 'write me a cold email', 'fix my follow-up sequence', 'my cold emails get opened but nobody replies', 'how many emails per inbox per day before I get blacklisted', 'write a LinkedIn connection note + DM', 'this email reads like a template', 'escríbeme una secuencia de cold email en frío', 'missatge en fred a LinkedIn'. NOT the SPF/DKIM/DMARC/tracking-domain setup (that is email-deliverability), NOT sourcing the prospect list (that is lead-gen), NOT what happens after a reply (that is sales-pipeline)."
tags: [cold-email, outreach, sequences, deliverability, sales]
recommends: [lead-gen, sales-pipeline, email-deliverability, proposals, marketing]
origin: risco
---

# Cold Outreach — The Words and the Cadence of the Cold Touch

*You write the message a stranger actually replies to, and the sending rhythm that keeps the mailbox provider delivering it. You do not set up DNS, source the list, or run the CRM.*

This skill owns two things and only two: the **copy** of an unsolicited 1:1 touch (cold email, LinkedIn note/DM) and the **cadence** around it (step count, spacing, per-inbox volume, warm-up ramp, the compliant footer). Everything upstream and downstream belongs to a sibling — see the route table below and honor it.

## When to use / When NOT

Use when:

- Writing a cold email or its subject line to a recipient with no prior relationship.
- Building or fixing a multi-step follow-up sequence (the "bump" cadence) — step count and spacing.
- Writing a LinkedIn connection note or cold DM sequence.
- Deciding daily/weekly send volume per inbox, or a new-domain warm-up ramp.
- Writing the CAN-SPAM/GDPR-compliant footer and one-click opt-out line.
- Rescuing a cold email that "reads like a template" or gets opens but no replies.

Do NOT use when (route to the sibling that owns it):

| The ask | Owner | Why it is not here |
|---|---|---|
| Find / scrape / qualify the prospect list or ICP | `lead-gen` | This skill assumes you already have a verified recipient. |
| Set up SPF, DKIM, DMARC, a tracking domain, or diagnose DNS-level spam landing | `email-deliverability` | This skill *applies* the provider rules to cadence; it does not configure auth. |
| Manage what happens after a reply — stages, tasks, CRM hygiene, close forecast | `sales-pipeline` | The moment a reply lands the relationship leaves this skill. |
| Write the proposal / SOW / pricing after a prospect engages | `proposals` | A cold touch earns a conversation, not a contract. |
| Inbound launch emails, nurture to an opted-in list, marketing-site copy | `marketing` (`../marketing/SKILL.md`) | Opted-in and broadcast copy is a different game from a 1:1 cold touch. |
| Actually wire the send through Gmail/an ESP API or a scheduler | `email-connector` / `google-workspace` | This skill produces text + a plan; it does not push the send. |

Only `marketing` exists in this catalog today, so it is the only sibling linked as a file. The rest are named by id — route by naming the owner, do not improvise their job.

## The reply-rate reality (calibrate before you write)

Cold email is a low-yield channel by nature, and most "improve my copy" requests are really "stop fighting the math." Set expectations against the 2026 band:

- **Average reply rate ≈ 3.43%.** Top quartile ≈ 5.5%. Elite (top 10%) ≈ 10.7%+. *(Instantly Cold Email Benchmark Report 2026, accessed 2026-06-02.)*
- So **5-10% is solid, 10%+ is excellent, under 2% means something upstream is broken** — usually the list or the deliverability, not the prose.

The two levers that actually move the number, in order:

1. **Relevance** — the right person, with a real reason you reached out *now*. A perfect email to the wrong list still dies.
2. **Deliverability** — if it lands in spam, copy is irrelevant. This is why cadence and volume (below) are part of *this* skill's job even though the DNS plumbing is not.

Cleverness ranks a distant third. Do not sell wit; sell relevance, delivered.

## Anatomy of a first touch

Hard constraints for the opening email:

- **Under ~80 words.** Elite performers stay below this; brevity plus a single binary CTA beats a long multi-CTA email. *(Instantly Benchmark 2026.)*
- **One observed hook** — a specific, real signal about *them* (a launch, a job post, a number from their site). Not "I came across your company."
- **One binary CTA** — a yes/no question they can answer in one tap ("Worth a 15-min look next week?"), not "let me know your thoughts" and not two asks.
- **Subject line under ~6 words, no clickbait, no "Re:" fakery.** It should read like a colleague wrote it, not a campaign.

Bad → Good rewrite:

```text
BAD (78 words, no real hook, vague + double CTA, spam-flavored):
Subject: Quick question + a free guide for you!!

Hi there, I hope this email finds you well! I came across your company
and was really impressed by what you're doing in the space. We help
companies like yours grow faster with our cutting-edge platform. I'd
love to hop on a call to walk you through it, or I can send over a free
guide — whatever works! Let me know your thoughts. Looking forward to
hearing from you!

GOOD (49 words, one signal, one binary CTA):
Subject: your March hiring for 3 SREs

Hi Dana — saw Acme is hiring three SREs this quarter. Usually that means
on-call pain is outrunning the team. We cut alert noise ~40% for two
infra teams your size in their first month.

Worth a 15-min look next week — yes or no?
```

The Good version names a real signal (`{{signal}}`), states one concrete outcome (`{{outcome}}`), and asks one binary question. No greeting filler, no "free", no double ask.

## The sequence — decision table

A first email captures **~58% of replies; steps 2-7 add the remaining ~42%**, and reply rates fall off sharply after the 5th email. *(Instantly Benchmark 2026.)* So the sequence is non-optional, but it is short. **4-7 touches, 2-4 days apart, each adding ONE new angle** — never "just bumping this up."

| Step | Day offset | Angle (one new thing) | CTA |
|---|---|---|---|
| 1 | 0 | The observed signal + outcome | Binary yes/no |
| 2 | +3 | A proof point / mini case study | Same binary ask, reframed |
| 3 | +7 | A different pain or angle on the value | Lower-friction ask (a resource, not a call) |
| 4 | +12 | Social proof or a relevant comparison | Binary ask |
| 5 (breakup) | +18 | Permission to stop — "should I close the file?" | One-question close |
| 6-7 (optional) | +25 / +35 | New trigger only if one genuinely appeared | Re-open, binary |

Rules that make the table work:

- **Stop at 5 unless a real new trigger appears.** Replies past the 5th email are thin; do not pad to 7 for its own sake.
- **The breakup (step 5) is the highest-converting follow-up after step 1** — it gives a graceful out and often gets the "actually, yes" reply. Always include it.
- **One angle per step.** If step 3 just restates step 1, delete step 3.
- **Keep follow-ups in the same thread** (reply to your own first email) so context travels with the touch.

## Channel adaptation — email vs LinkedIn

| Dimension | Cold email | LinkedIn |
|---|---|---|
| First-touch length | ≤ ~80 words | Connection note ≤ ~300 chars; DM ~3-4 sentences |
| Hook source | A site/news/hiring signal | One specific profile signal (a post, a role change, a shared group) |
| CTA | Binary yes/no question | Soft — a question or a relevant share, not a pitch in the note |
| Volume ceiling | 20-50/day per inbox (see below) | ~100 connection requests/week free, **safer under 80**, rolling weekly |
| Reply benchmark | ~3.43% avg, 10%+ elite | ~6-7% avg, 10%+ excellent |

*(LinkedIn figures: Skylead / Kondo / Expandi 2025-2026 guides, accessed 2026-06-02.)*

On LinkedIn the connection note must **not** pitch — earn the connection on a real signal, then make the ask in the first DM after they accept. Skeletons for both channels live in `references/templates.md`.

## Sending cadence & deliverability guardrails

You own the *cadence* side of deliverability; the DNS/auth side is `email-deliverability`. Apply these limits to the plan you hand the user:

- **Per inbox: 20-50 cold sends/day even after warm-up.** The technical Gmail ceiling is ~100, but cold mail should stay well under it. Need more volume? Add inboxes, do not raise the per-inbox number.
- **New-domain warm-up ramp** (warm-up mail counts toward the daily cap):

| Week | Sends/day per inbox |
|---|---|
| 1 | ~10-20 |
| 2 | ~20-35 |
| 3 | ~35-50 |
| 4+ | ~50-65 (hold cold sends at 20-50) |

- **Bounce rate under 2%.** A higher bounce means the list is stale → that is a `lead-gen` problem, not a copy problem.
- **Spam-complaint rate under 0.3%; Google advises under 0.1%.** One-click unsubscribe (RFC 8058: `List-Unsubscribe` + `List-Unsubscribe-Post`) is required for bulk senders to Gmail/Yahoo; Outlook applied the same from 2025-05-05, with Gmail/Yahoo enforcement ramping from Nov 2025. *(Google Workspace "Email sender guidelines"; Security Boulevard 2025-11; Proofpoint 2025 — accessed 2026-06-02.)*

If the user asks you to *configure* the `List-Unsubscribe` header, SPF, or DKIM, stop and route to `email-deliverability` — you specify that the opt-out must exist and be one-click; that skill wires the header.

## Compliance footer (every cold send needs one)

| Requirement | CAN-SPAM (US) | GDPR (EU B2B) |
|---|---|---|
| Sender identity | Accurate From/Reply-To, honest subject | Same |
| Postal address | A physical mailing address, required | Recommended; identify the controller |
| Opt-out | Clear opt-out, honored within 10 business days | Honored without undue delay (treat as 24-48h) |
| Legal basis | Not consent-based; truthful + opt-out suffices | Art. 6(1)(f) legitimate interest **with a documented LIA** |
| Penalty | Up to $53,088 per email (Jan 2025) | Up to €20M or 4% of global revenue |

*(Instantly compliance guide / Puzzle Inbox; litemail.ai / complydog GDPR guides 2026 — accessed 2026-06-02.)*

EU enforcement varies — UK ICO and France CNIL are permissive for B2B; Germany and Poland are stricter (Poland often requires prior consent). When the recipient is in the EU, write the footer for the strictest plausible jurisdiction. The full footer wording, the LIA checklist, and the CASL/Australia matrix → `references/compliance-footer.md`.

## Personalization without creepiness

- **One real signal, surfaced plainly.** "Saw you're hiring 3 SREs" is relevant; "Saw you were at the lake house last weekend" is surveillance. Stay on professional, public, business-relevant signals.
- **Do not fake personalization with spintax.** Rotating "{Hi|Hey|Hello}" or `{{first_name}}`-only mail-merge is not personalization — it is a template wearing a name tag, and recipients can smell it. If the only variable is the name, the email is generic; add a real `{{signal}}` or do not send.
- **Never invent the signal.** A fabricated "I loved your recent post on X" that does not exist destroys trust on contact. If you cannot find a true signal, that is a `lead-gen` targeting gap, not a copy task.

## Anti-patterns

| Anti-pattern | Why it fails | Do instead |
|---|---|---|
| Blast 200/day from one new inbox | Trips spam filters; tanks domain reputation in days | Ramp per the table; hold 20-50/day; split across inboxes |
| Pitch in sentence one | No earned relevance; reads like a billboard | Lead with the observed signal, earn the ask |
| Two CTAs ("call OR I'll send a guide") | Splits the decision; lowers reply rate | One binary yes/no ask per email |
| "Just following up" / "circling back" with no new angle | Adds noise, not value; trains them to ignore you | Each step adds one new angle or it is deleted |
| Name-only mail merge as "personalization" | Recipients see the template underneath | One true `{{signal}}` per first touch or do not send |
| No opt-out / no postal address | CAN-SPAM/GDPR violation; complaint-rate spike | Always append the compliant footer |
| Subject like "Quick question!!" or "FREE" | Clickbait + spam-trigger words land you in spam | ≤6 plain words that read like a coworker wrote them |
| Padding to 7 steps for completeness | Replies past step 5 are thin; you just annoy | Stop at the breakup unless a real new trigger appears |
| "I hope this email finds you well" opener | The classic AI/template tell; wastes the first line | Open on the signal — your first 6 words are the hook |

## Templates

Reusable skeletons — first-touch + 4-step bump for email and LinkedIn, with every variable slot (`{{signal}}`, `{{outcome}}`, `{{proof}}`) marked — live in `references/templates.md`. Start from a skeleton, then fill every slot with a *real* value before sending. An unfilled slot is a defect, not a placeholder to ship.

To self-check a drafted email or sequence file, run `scripts/verify.sh path/to/draft.md` — it flags missing opt-out, multiple CTAs, over-ceiling word count, and spam/AI-tell phrases (read-only).
