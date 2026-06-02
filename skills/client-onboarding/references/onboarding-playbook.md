# Onboarding playbook — fill-in templates

Long, branch-specific lookup material offloaded from `SKILL.md`. Copy the
relevant block, fill the brackets, delete the rest.

## 1. Sales → CS/delivery handoff checklist

Run this internally **before** first customer contact. Source it from the deal
record (`sales-pipeline`) and the signed SOW (`proposals`); do not re-interview
the customer.

```md
# Handoff: [Customer name] — [order form date]
AE: [name]   Receiving CSM/owner: [name]   Kickoff target: [date]

## Stakeholders
- Economic buyer: [name, role] — cares about: [outcome]
- Champion: [name, role] — internal motivation: [why they pushed this]
- End users: [teams/roles, headcount]
- Skeptic / risk: [name, role] — concern: [what could stall this]

## Why they bought
- Trigger event: [what made them act now]
- Compared against: [competitors / status quo / build-vs-buy]
- Primary driver: [the one thing]

## Promised scope & commitments (anything said in the cycle)
- [ ] [Integration / custom work / timeline / discount / SLA promised]
- [ ] [...]

## Success criteria the buyer is measuring you on
- [ ] [Metric or outcome, with target if stated]

## Known risks
- [ ] [Politics / hard go-live date / competing tool still in place]

## Constraints & dates
- Contract start: [date]   Hard deadlines: [date]   Blackout windows: [...]
```

## 2. Welcome-packet contents

Send before the kickoff call so nobody walks in cold.

- The 30/60/90 plan (Section 5 below).
- The RACI (Section 4).
- Who-to-contact card: CSM, support channel, escalation path.
- Setup prerequisites the customer must complete before kickoff.
- The kickoff agenda (Section 3) with date, time, duration, join link.

## 3. Kickoff-call agenda script (45 minutes, high-touch)

```text
00:00–00:05  Introductions — names, roles, both sides
00:05–00:12  Project overview — restate the goal in the buyer's words (from handoff)
00:12–00:22  Roles & responsibilities — walk the RACI; confirm each owner agrees
00:22–00:30  Communication plan — cadence, channel, escalation, status-report format
00:30–00:40  Action items / next steps — every item gets an owner and a date
00:40–00:45  Q&A — surface blockers now, not in week 3
```

Close by restating the day-30 exit milestone and the date of the next check-in.

## 4. Worked RACI matrix

R = does the work · A = accountable (one per row) · C = consulted · I = informed.

```text
| Task                       | Champion | CSM | Cust. admin | Exec sponsor |
|----------------------------|----------|-----|-------------|--------------|
| Provision accounts/seats   |    C     |  A  |      R      |      I       |
| Import first real dataset  |    A     |  C  |      R      |      I       |
| Define the success metric  |    A     |  R  |      I      |      C       |
| Configure first workflow   |    C     |  R  |      A      |      I       |
| Train end users            |    A     |  R  |      C      |      I       |
| Sign-off on go-live        |    R     |  A  |      I      |      C       |
| Day-90 value review        |    C     |  R  |      I      |      A       |
```

## 5. Filled 30/60/90 success plan

```text
| Phase    | Goal / focus                  | Owner             | Date   | Exit milestone                              |
|----------|-------------------------------|-------------------|--------|---------------------------------------------|
| Day 0    | Kickoff + handoff confirmed   | CSM               | [d0]   | Plan shared; prerequisites assigned         |
| Day 1–7  | Setup + activation event      | Champion + admin  | [d7]   | Activation event fires (e.g. first dataset) |
| Day 8–30 | First meaningful outcome      | CSM + champion    | [d30]  | First weekly report / first real output     |
| Day 31–60| Expand to 2nd use case/team   | CSM               | [d60]  | Milestone review; usage across ≥2 teams     |
| Day 61–90| Prove value vs. criteria      | CSM → account team| [d90]  | Value review; formal transition to retention|
```

Front-load: most of the work and the activation event land inside days 1–30.

## 6. Self-serve day-0 → day-14 nudge sequence

Channel: in-app for the doer, email for the absent. Each row: trigger → message
→ goal. Stop the sequence the moment the activation event fires.

```text
| Day | Channel | Trigger             | Message                                   | Goal                  |
|-----|---------|---------------------|-------------------------------------------|-----------------------|
| 0   | in-app  | signup complete     | Checklist + one-step setup, deep-linked   | Reach first setup step|
| 0   | email   | welcome             | "Your first win in 3 minutes" + deep link | Start the path        |
| 1   | email   | no activation yet   | "Do the one thing" — single CTA           | Hit activation event  |
| 3   | email   | activated           | "You did X — now do Y"                     | Pull to second value  |
| 3   | in-app  | activated           | Surface the next feature in context       | Deepen usage          |
| 7   | email   | still not activated | Remove the blocker; offer a call/help doc | Recover at-risk user  |
| 10  | in-app  | activated, low use  | Nudge toward habit-forming action         | Build the habit       |
| 14  | email   | trial ending soon   | Convert/upgrade or graduate               | Onboarded exit        |
```

Keep one CTA per message. Two CTAs halve the odds either gets clicked.

## 7. "Onboarded" exit-gate checklist

Onboarding is done only when every box is checked. Then hand off to `retention`.

```md
- [ ] Activation event has fired (verifiable in product data, not assumed)
- [ ] Success plan agreed and shared with the customer
- [ ] First meaningful outcome delivered against the buyer's success criteria
- [ ] Communication cadence + escalation path set and confirmed
- [ ] Health baseline captured: usage, key metric, stakeholder sentiment
- [ ] Steady-state owner named and introduced to the customer
- [ ] Open promised-scope items closed or explicitly scheduled
```
