# SOP skeleton, interview script, and a worked example

Lookup material for drafting. Copy the template, run the interview, pick the
format, then prune to the leanest document that still survives the owner being
out.

## Format-selection decision table

| Flow shape | Format | Tell |
| --- | --- | --- |
| Same steps, same order, every time | Numbered step-by-step | "First X, then Y, then Z" with no "it depends" |
| Many independent pieces, skilled doer | Checklist | The doer knows *how*; the risk is forgetting a piece |
| One or more decision points | Decision table or flowchart | The owner says "well, it depends on…" |
| 1–3 small forks inside a mostly linear flow | Numbered steps + inline `if/then` | Don't reach for a flowchart yet |

## The capture interview script

Ask in roughly this order. The goal is to surface the branches and tacit steps
the owner won't volunteer because, to them, they're obvious.

1. In one sentence, what does this process produce, and what kicks it off?
2. Walk me through the last real time you did it, start to finish — don't
   clean it up.
3. Where does this break when you're on holiday or out sick?
4. What's the most common thing that goes wrong, and what do you do then?
5. When do you have to check with or wait on someone else before continuing?
6. Is there a case where you skip a step, or do it differently? When?
7. What would a new hire get wrong on their first attempt?
8. Which tool or system is the source of truth here?
9. How do you know the output is *correct* before you call it done?
10. What's the deadline or SLA, if any?
11. Has anything about this changed recently that the old way got wrong?
12. Who, besides you, needs to know when this is done?

Map answers: Q3/Q4/Q5/Q6 → branches and escalations. Q9 → the quality check.
Q5/Q12 → the RACI. Q2/Q7 → the step body.

## The full SOP template

```markdown
# SOP-<id>: <process name>

| Field          | Value                                  |
| -------------- | -------------------------------------- |
| Version        | 1.0                                    |
| Owner (A)      | <named role/person — exactly one>      |
| Last updated   | <YYYY-MM-DD> by <author>               |
| Next review    | <YYYY-MM-DD>  (annual min + on change) |
| Status         | Draft | Active | Retired                |

## 1. Purpose
One sentence: why this procedure exists.

## 2. Scope
- In scope: <what this covers>
- Out of scope: <what it doesn't — hand-offs to other SOPs>
- Trigger: <the event that starts it>

## 3. Responsibilities (RACI — only if >1 role)
| Activity | R | A | C | I |
| -------- | - | - | - | - |
| <step>   |   |   |   |   |

## 4. Procedure
1. <Actor> does <one action>.
2. <Actor> does <one action>.
   - If <condition> → <branch>.
   - If <condition> → escalate to <role>; STOP until resolved.
3. ...

## 5. Quality check
How the doer confirms the output is correct before calling it done.

## 6. Output
The defined artifact/result this produces.

## 7. Exceptions & escalation
- <failure case> → <named escalation target> → <stop or proceed condition>

## 8. Change log
| Version | Date       | Author | What changed                |
| ------- | ---------- | ------ | --------------------------- |
| 1.0     | YYYY-MM-DD | <name> | Initial version             |
```

Mandatory regardless of size: title/version, purpose, scope, owner, trigger,
steps, quality check, output, change log, next-review date. Add §3 RACI only
when more than one role touches the process; add §7 only when the process can
fail in a way the doer must handle.

## Worked example — "publish the weekly newsletter"

### Bad (the wall-of-prose version that gets ignored)

```markdown
# Newsletter Process

The newsletter goes out weekly. Someone writes it and then it should be
reviewed and scheduled, making sure everything looks good and the links work
before it's sent. If there are issues they should be fixed. Marketing owns it.
```

Problems: no trigger, no named actor (passive "should be reviewed"), no
decision for what "issues" means, no quality check you can verify, no owner you
can call, no version or review date, no escalation. A new hire learns nothing
runnable from this.

### Good (right altitude, branches explicit, alive)

```markdown
# SOP-014: Publish the weekly newsletter

| Field        | Value                               |
| ------------ | ----------------------------------- |
| Version      | 2.1                                 |
| Owner (A)    | Content Lead                        |
| Last updated | 2026-05-20 by J. Roca               |
| Next review  | 2027-05-20 (or on tool change)      |
| Status       | Active                              |

## 1. Purpose
Ship one reviewed newsletter every Tuesday 09:00 without the Content Lead
present.

## 2. Scope
- In: drafting through send for the weekly list.
- Out: campaign design (see SOP-008), list hygiene (see SOP-021).
- Trigger: Monday 10:00, draft due in the CMS.

## 3. Responsibilities
| Activity     | R       | A            | C        | I    |
| ------------ | ------- | ------------ | -------- | ---- |
| Draft        | Writer  | Content Lead | —        | —    |
| Review       | Editor  | Content Lead | —        | —    |
| Schedule     | Editor  | Content Lead | —        | Team |

## 4. Procedure
1. Writer completes the draft in the CMS by Monday 10:00.
2. Editor reviews the draft against the §5 checklist.
   - If a link is broken or a claim is unsourced → return to Writer; STOP
     until fixed.
   - If the send list is > 50k recipients → notify Finance before scheduling
     (billing tier).
3. Editor schedules the approved draft for Tuesday 09:00.
4. Editor confirms the send appears in the queue and pings #marketing.

## 5. Quality check
All links resolve (200), subject line ≤ 60 chars, one CTA, preview rendered
on mobile.

## 6. Output
One scheduled newsletter visible in the send queue for Tuesday 09:00.

## 7. Exceptions & escalation
- CMS down at scheduling time → escalate to Content Lead; hold, do not send
  late without sign-off.
- Legal/PR-sensitive content → route to Comms before send.

## 8. Change log
| Version | Date       | Author  | What changed                       |
| ------- | ---------- | ------- | ---------------------------------- |
| 2.1     | 2026-05-20 | J. Roca | Added >50k list Finance notice     |
| 2.0     | 2026-02-11 | J. Roca | Split list-hygiene into SOP-021    |
```

Note what changed: a named actor on every step, two explicit branches plus an
escalation, a verifiable quality check, one accountable owner, and a live change
log. It stays at SOP altitude — "schedules the approved draft," not "click
Settings → Schedule → 09:00." Those keystrokes, if the team needs them, go in a
linked work instruction, not here.
