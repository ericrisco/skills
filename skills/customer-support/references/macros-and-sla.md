# Macros, SLA matrix, and escalation — full lookup

Reach for this mid-ticket. Every macro is a **skeleton you finish** — fill the
fields, add one bespoke line, and never send with a visible `{{placeholder}}`.
All macros follow the 4-beat order: empathy → answer → next step → close.

## Macro skeleton library

### 1. Acknowledgment (P1/P2, before you have the answer)

```text
Hi {{first_name}} — I've got your report about {{problem_in_their_words}} and
I'm on it now. I don't have the full picture yet, but I'll update you by
{{time}} whether or not it's fixed. Thanks for flagging it. — {{agent}}
```

### 2. Info request (you need one thing to proceed)

```text
Hi {{first_name}} — sorry {{feature}} is giving you trouble. To dig in I need
one thing: {{specific_ask}}. Once I have that I can {{next_action}}. — {{agent}}
```

One ask only. If you need three, sequence them or batch them clearly.

### 3. Resolved (closing a fixed ticket)

```text
Hi {{first_name}} — {{problem}} is fixed as of {{time}}. {{what_changed}}.
Give it a try and reply here if anything still looks off; I'll keep this ticket
open until {{date}} just in case. — {{agent}}
```

### 4. Refund / billing adjustment

```text
Hi {{first_name}} — you're right, {{what_went_wrong}}. I've issued a refund of
{{amount}} to {{method}}; it usually lands in {{timeframe}}. Here's the why so
it doesn't happen again: {{explanation}}. Sorry for the hassle. — {{agent}}
```

Quote the refund window from the KB — never invent it.

### 5. Known bug (issue is real, fix is pending)

```text
Hi {{first_name}} — this is a real bug on our side, not anything you did, and
the team is already on it (ref {{tracking_id}}). Current status: {{status}}.
In the meantime this workaround gets you unblocked: {{workaround}}. I'll ping
you the moment it ships. — {{agent}}
```

Never send "this is a known issue" alone — always pair it with status + ETA or
a workaround.

### 6. Outage (P1, multi-customer)

```text
Hi {{first_name}} — we're aware {{service}} is down and engineering is on it as
top priority. Live status: {{status_page_url}}. I'll update you here every
{{interval}} until it's resolved. Sorry for the disruption. — {{agent}}
```

### 7. Churn-save / de-escalation

```text
Hi {{first_name}} — {{acknowledge_the_real_grievance}}, and I understand why
you're considering leaving. I dropped the ball on {{specific_failure}}. Here's
what I can do right now: {{concrete_offer_or_fix}} by {{time}}. If that doesn't
make it right, I'll loop in {{owner}} personally. — {{agent}}
```

Acknowledge the feeling, own it in first person, one timed concrete step.

### 8. Escalation hand-off (to the customer, while you escalate internally)

```text
Hi {{first_name}} — this needs our {{team}} to get you a solid answer, so I've
handed it to {{specialist}} with everything you've told me — you won't have to
repeat anything. They'll reach out by {{time}}. — {{agent}}
```

### 9. Feature-request decline (say no without a dead end)

```text
Hi {{first_name}} — {{feature_idea}} isn't on the roadmap right now, and I want
to be straight with you rather than string you along. I've logged it for the
product team ({{tracking_id}}). The closest thing available today is
{{nearest_alternative}}. — {{agent}}
```

Never "unfortunately there's nothing we can do" — always offer the nearest path.

### 10. Gentle close (no reply after a follow-up)

```text
Hi {{first_name}} — I haven't heard back, so I'll close this for now. If
{{problem}} is still happening, just reply and it reopens right where we left
off — no need to start over. — {{agent}}
```

## Full SLA matrix by channel

First-response targets shift by channel: live channels (chat/phone) set a faster
expectation than async (email). Resolution targets stay constant by priority.

| Priority | Email FRT | Chat FRT | Phone FRT | Resolution |
|---|---|---|---|---|
| P1 critical | 30 min | 5–10 min | immediate | ASAP; status update every 30–60 min |
| P2 high | 1–2 h | 15 min | 5 min | same business day |
| P3 medium | 4–8 h | 30 min | 10 min | 1–2 business days |
| P4 low | ~1 business day | 1 h | n/a | best effort |

Keep to 3–4 tiers. Acknowledge inside the FRT window even when the fix will take
longer — the acknowledgment is the SLA you cannot miss.

## Escalation matrix

| Trigger | Goes to | Owner | What must travel |
|---|---|---|---|
| Production outage / data loss | T3 engineering | on-call eng + support lead | full handoff packet + status-page link |
| "cancel / refund / lawyer / chargeback" | T2 + account owner | account owner | packet + sentiment flag |
| Enterprise / VIP account | T2 specialist | named CSM | packet + contract context |
| SLA about to blow | T2 | shift lead | packet + remaining-time |
| Policy/price claim, unverifiable | T2 | support lead | packet + the exact unanswered question |
| Assisted/AI draft <85% confidence | human T1 | any human agent | packet + the draft + the uncertainty |

## Handoff packet template

Fill every field. A bare ticket link forces the customer to repeat themselves
(+90–180s, and it reads as "nobody read my ticket").

```text
HANDOFF PACKET
- Customer + account tier:  {{name}} — {{tier}}
- Ticket / priority:        #{{id}} — {{priority}}
- One-line summary:         {{what_is_wrong_in_one_line}}
- Steps already tried:      {{what_you_ruled_out_or_attempted}}
- Customer sentiment:       {{calm | frustrated | angry | churn-risk}}
- Collected variables:      {{key=value pairs: plan, timestamps, region, IDs}}
- What I need from you:      {{the_specific_question_or_action}}
```
