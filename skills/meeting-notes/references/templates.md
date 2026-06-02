# Meeting-record templates & verification checklist

Lookup material for [`../SKILL.md`](../SKILL.md). Copy a template, fill it,
verify, ship within 24–48h. Every record stays a curated artifact — not a
transcript.

## Canonical action-item row

```text
- [ ] <verb-first task> — <named owner> — by <real date>
```

Status markers: `[ ]` open · `[~]` in progress · `[x]` done · `[!]` blocked.
Never use "team", "we", "soon", "ASAP", or "next week".

## Canonical decision row

```text
- <decision as a fact>. *Why:* <one sentence>. *Reversibility:* reversible |
  partially-reversible | irreversible. Dissent: <name + position, or "none">.
```

---

## Template 1 — Decision meeting

Heaviest template. Use when the meeting's job was to *decide*.

```markdown
# <Topic> Decision — <Date>
**Attendees:** <names> (note-taker: <name>) · **Purpose:** <one line>

## TL;DR
<One screen: what we decided, who owns the next move, what's still open.>

## Decisions
- <Decision>. *Why:* <one sentence>. *Reversibility:* <tag>. Dissent: <…>.

## Action items
- [ ] <verb> — <owner> — by <date>

## Open questions
- <question> (raised by <name>, unresolved)

## Parking lot
- <out-of-scope item to revisit>

## Hand-offs
- Durable ADR for <decision> → decision-records
- Tasks above → project-ops
```

---

## Template 2 — Standup / sync

Lightest template. No RACI, no reversibility unless a real decision happened.

```markdown
# <Team> Standup — <Date>
**Present:** <names>

## Decisions (if any)
- <decision>. *Why:* <one line>.

## Action items
- [ ] <verb> — <owner> — by <date>

## Blockers / open
- <blocker> — needs <name/decision>
```

---

## Template 3 — Retro

```markdown
# <Sprint/Project> Retro — <Date>
**Attendees:** <names> (facilitator: <name>)

## TL;DR
<Top theme + the one change we're committing to.>

## What went well
- <point>

## What to improve
- <point>

## Action items (commitments, not wishes)
- [ ] <verb> — <owner> — by <date>

## Parking lot
- <recurring theme to watch>
```

---

## Template 4 — 1:1

Tighter distribution; redact before any wider share.

```markdown
# 1:1 — <Name A> / <Name B> — <Date>

## Agreed
- <agreement>. *Why:* <one line>.

## Action items
- [ ] <verb> — <owner> — by <date>

## Follow-ups for next time
- <topic>
```

---

## AI-transcript verification checklist

Mandatory before any AI-drafted task or quote ships. AI transcripts hallucinate
and misattribute speakers, and even strong ASR is not error-free (Whisper:
~2.5–3% word error on clean read speech, ~4.7% on TED talks, worse on real
meeting audio) — a clean-looking draft is the trap. Run every box:

- [ ] **Speaker attribution** — each commitment traces to the correct person.
      Re-check overlapping talk, post-silence lines, and similar-sounding voices.
- [ ] **Hallucinated task** — every action item maps to something actually said.
      If you can't find it in the source, drop it or flag it — don't ship it.
- [ ] **Quote vs. source** — every verbatim quote matches the source word for
      word. Unsure? Paraphrase. Never present an unverified quote as exact.
- [ ] **Attribution of commitments** — the person credited with an action is the
      one who accepted it, not whoever happened to be talking nearby.
- [ ] **No invented owners/dates** — a missing owner or date is flagged "needs
      confirmation", never guessed.
- [ ] **Tangents filtered** — banter and off-topic threads are cut, not recorded.
- [ ] **Sensitive content** — names/secrets redacted before distribution beyond
      the room.

When a line is suspect, write it as: `> [VERIFY] <line> — attribution/quote
unconfirmed against source`. Resolve every `[VERIFY]` before finalizing.
