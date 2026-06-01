# Campaigns & Channels — Email, Launch, X/LinkedIn/Newsletter, SEO-Aware Structure

The copy beyond the page. When the task is a launch, an email flow, or cross-channel messaging, the same brand study and value prop drive it — but the format adapts per channel. One claim per asset; every claim traceable to the brand study's proof. Adapt the *format* to the platform; never resize the same copy across channels.

## Email sequences

Email is the highest-intent channel you own. Defaults below reflect current (2026) deliverability and engagement data.

### Welcome flow (fires on opt-in)

- **Send the welcome email within 5 minutes of opt-in.** It has the highest open rate of the whole flow (60–80%), and every hour of delay costs roughly 10% of opens.
- **4-touch starter cadence:** Day 1 welcome → Day 4 educational → Day 8 case study → Day 12 soft pitch.
- **One purpose per email.** Don't stack welcome + pitch + survey into one send.
- **Hold promo language out of early emails.** Words like "free", "guarantee", "limited time" in emails 1–3 hurt both trust and deliverability; save them for the later soft-pitch send once trust is built.

```text
EMAIL 1 — Welcome (Day 1, send within 5 min)
Subject ... You're in. Here's the 30-second start.   (short, plain, no promo words)
Preview ... One command and your first preview URL.
Body ......
  You signed up to stop babysitting staging — let's get you a win in 30 seconds.
  1. Install: npm i -g driftway
  2. Run `driftway up` on any branch.
  3. Open the URL it prints. That's your first live preview.
  Reply if it doesn't work — a human reads these.
CTA ....... Open the quickstart   (single, low-friction)
```

```text
EMAIL 3 — Case study (Day 8)
Subject ... How Northwind cut review setup from 22 min to 90 sec
Preview ... 40 engineers, one CLI step, zero staging queue.
Body ...... Before/After/Bridge: the queue problem → the 90-second outcome → how Driftway
            got them there (one CLI step in their existing CI). End with their number.
CTA ....... See the full story
```

### Subject-line patterns

| Pattern | Example | Use |
| --- | --- | --- |
| Specific number | "3 ways to cut review setup to 90 seconds" | educational sends |
| Curiosity (honest) | "The staging queue problem nobody names" | top-of-flow |
| Named-outcome | "How Northwind shipped 40% faster" | case study |
| Plain & short (2–5 words) | "Your first preview" | Day-1 welcome |

Avoid all-caps, excessive punctuation, and `free`/`guarantee`/`limited time` in early sends. The subject must match the body — no bait-and-switch (it trips the QA gate and trains unsubscribes).

### Deliverability note (hand the technical work to ops/infra)

Authentication is not optional: SPF, DKIM (2048-bit), DMARC starting at `p=none` with reporting, tightening to quarantine/reject once aligned. Warm a new domain gradually. This skill writes the copy; flag the technical setup as a dependency rather than owning it.

## Launch sequence

A launch is a sequence of beats, one claim per beat, every claim traceable to the brand study's proof.

```text
LAUNCH ARC
1. Tease   — signal something's coming; create a small information gap (no hype).
2. Reveal  — the value prop, stated plainly; the one credible claim up front.
3. Proof   — the demo, the number, the named customer; show, don't assert.
4. Urgency — a REAL reason to act now (a deadline, a cohort, a price change) — never fake.
5. Recap   — for those who missed it; restate the value + the single CTA.
```

```text
REVEAL post
Bad  — "Excited to share our game-changing new launch! 🚀"
Good — "Driftway is live. Every pull request now gets its own live URL in 30 seconds —
        no staging queue. Here's a 40-second demo:"
```

Sequence the beats across channels: reveal on the landing page + email + X thread; proof in the case study + a LinkedIn post; urgency in the final email. The same claim, formatted per channel.

## Channel adaptation

Adapt the format to the platform; keep the claim constant. One source asset → distinct native drafts, never one draft resized.

### X

- Open with the sharpest claim, artifact, or tension — no warm-up.
- Keep the compression if the brand voice is compressed; one claim per post.
- In a thread, every post advances the argument; don't pad for length.
- No bait questions, no engagement-farming closers (ban-list).

```text
Bad  — "Tired of slow deploys? 🧵 Here's why this matters... (1/12)"
Good — "Staging is a shared queue. We removed it. Every PR now gets its own live URL in
        30s. How it works ↓"
```

### LinkedIn

- Expand just enough for people one ring outside the niche to follow.
- No corporate-inspiration cadence, no fake "journey" arc, no praise-stacking.
- Lead with the concrete outcome or number; the lesson, if any, comes after the proof.

```text
Bad  — "I'm humbled and excited to announce a game-changing journey... 🙏"
Good — "Northwind's 40 engineers were losing 22 minutes per review to the staging queue.
        We gave every PR its own environment. New number: 90 seconds. Here's how."
```

### Newsletter

- The first screen does real work — open with the point, the conflict, or the artifact.
- No warm-up paragraph; every section adds something new.
- Section labels only when they improve scanning.

```text
Bad  — "Hope you're having a great week! Lots of exciting updates to share..."
Good — "We deleted the staging queue. Below: how per-PR environments work, the number
        from Northwind, and how to try it in 30 seconds."
```

### Ads

- 3–4 variants, each testing ONE different angle (pain vs. outcome vs. differentiator) — not random wording.
- Short headline + long headline + one-line body, each self-contained.
- Ad claims must match the landing page exactly (mismatched claims tank Quality Score and trust).

## SEO-aware structure

A structural constraint on the copy, not a keyword program — the keyword/SERP workflow and technical audits live in `seo-geo.md`.

- Exactly one `<h1>`; linear heading order (`h1` → `h2` → `h3`, no skips).
- `<h2>`/`<h3>` subheads double as answers to likely search queries.
- Primary keyword in the `<h1>` naturally; secondary keywords in subheads, never stuffed.
- Title 50–60 characters; meta description 120–160; benefit in the first ~160 chars so the snippet reads well.

```text
Title formula           — Primary Topic - Specific Modifier | Brand
Meta description formula — Action + topic + value proposition + one supporting detail
```

## Cross-channel consistency QA

- [ ] One claim per asset; every claim traceable to the brand study's proof.
- [ ] Ad/email/social claims match the landing page exactly.
- [ ] Email subject matches the body; promo words held out of early sends.
- [ ] Welcome email fires within 5 minutes of opt-in.
- [ ] Each channel is adapted in format, not resized from one draft.
- [ ] Urgency, if used, is backed by a real deadline.
- [ ] Voice matches the brand samples on every channel.

## See Also

- `copy-frameworks.md` — frameworks and headline formulas reused across channels.
- `landing-copy.md` — the page these campaigns drive traffic to.
- `brand-grounding.md` — the proof and voice every channel inherits.
- `seo-geo.md` — technical SEO, GEO (AI-engine citation), JSON-LD schema, keyword research.
