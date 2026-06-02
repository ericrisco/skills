# Proposal skeleton

Full ordered template, then a filled one-page mini-example. Replace every `[...]`.
Keep the section order — buyers read top-down and the exec summary carries the most weight.

## Template

```markdown
# Proposal: [Project name]
**Prepared for:** [Client name] · **By:** [Your company] · **Date:** [date]
**Valid through:** [date — give them a reason to decide]

## Executive summary
[200–400 words. At least ~30% specific to this buyer. Structure:]
- The challenge: [their problem, in their words, with its cost].
- Our solution: [your approach in one paragraph — outcomes, not features].
- The outcome: [the measurable change — their success metric].
- The investment: [the band, pointing to the recommended tier below].

## The problem
[Restate their situation and what it costs them today. Earn the right to propose.]

## Proposed solution
[Your approach mapped to the problem. What changes for them, and how you'll get there.]

## What's included (scope summary)
[Numbered, specific. One line on what's out — full exclusions in the SOW.]

## Investment
[Three tiers, outcome-named, middle marked recommended. See the tier block below.]

## Timeline
[Phased with dates. Each phase ties to a deliverable.]

## Why us
[One or two relevant results with numbers. Not a logo wall.]

## Terms
- Payment: [schedule tied to milestones].
- Validity: [date].
- Governed by [MSA dated …] / binding terms to follow in the SOW + agreement.

## Next steps
[2–4 dated mutual actions + one concrete CTA. Pre-handle one likely objection.]
```

## Pricing tier block

```markdown
| Tier         | Outcome                                  | Investment |
|--------------|------------------------------------------|------------|
| Launch       | Get it live and handed off               | $[X]       |
| Scale ★      | Live + measurably working (recommended)  | $[Y]       |
| Dominate     | Scale + a compounding system             | $[Z]       |
```

The numbers come from `../../pricing/SKILL.md`. Here you only present and frame them.

## Filled mini-example (services engagement)

```markdown
# Proposal: Customer portal rebuild
**Prepared for:** Northwind Logistics · **By:** Atlas Studio · **Date:** 2026-06-02
**Valid through:** 2026-06-20

## Executive summary
Northwind's support team told us the current portal generates "200+ password and
order-status tickets a week" — roughly a third of all support volume — because
customers can't self-serve. That ticket load is the problem we're solving, not the
portal's looks. We propose to rebuild the portal around the four jobs your customers
actually come to do: check order status, manage shipments, update billing, and reset
access — each instrumented so you can watch ticket volume fall. The target you set on
our call was "cut self-service tickets in half within one quarter." Our recommended
Scale engagement is built to hit that and prove it with before/after dashboards. The
investment for that path is $42,000, phased across a 6-week build.

## The problem
~200 self-service tickets/week, ~30% of support volume, each ~$14 fully loaded — about
$145k/year of avoidable cost, plus the customer friction behind it.

## Proposed solution
Rebuild the four core flows, instrument each with event tracking, and ship a
ticket-volume dashboard so the impact is visible, not asserted.

## What's included (scope summary)
1. Order-status, shipment, billing, and access-reset flows. 2. Analytics + dashboard.
3. Two rounds of revisions per flow. Migration of legacy tickets is out (see SOW).

## Investment
| Tier      | Outcome                                         | Investment |
|-----------|-------------------------------------------------|------------|
| Launch    | New portal live, four flows shipped             | $28,000    |
| Scale ★   | Live + instrumented + 90-day tuning (recommended)| $42,000   |
| Dominate  | Scale + agent-deflection bot + quarterly review | $66,000    |

## Timeline
Wk 1 discovery & design · Wk 2–4 build · Wk 5 QA & instrumentation · Wk 6 launch.

## Why us
We cut self-service tickets 58% for a comparable 3PL in one quarter (case on request).

## Terms
Payment: 40% on signature, 30% at Wk 4 milestone, 30% on acceptance. Valid to 2026-06-20.
Governed by the MSA dated 2026-01-15; scope detailed in the attached SOW.

## Next steps
1. 2026-06-09 — you confirm the Scale tier. 2. 2026-06-10 — we send the SOW for sign-off.
3. 2026-06-16 — kickoff. On budget: the Scale tier pays for itself in ~3.5 months of
deflected tickets. Reply to confirm the tier and we'll send the SOW the next morning.
```
