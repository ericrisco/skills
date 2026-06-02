# Handoff & sales-bot — lookup

Reach for this when designing the escalation path or the sales branch. Lookup, not linear reading.

## Handoff packet template

Every escalation — warm or cold, support or sales — carries this. The cost of skipping it: ~18 CSAT points and 90–180s per ticket when the customer re-explains (Fini Labs, accessed 2026-06-02).

```json
{
  "conversation_id": "string",
  "trigger": "explicit | implicit | topic | empty_retrieval | sales_hot_lead",
  "trigger_detail": "e.g. 'user typed: talk to a human' or 'refund-decision bucket'",
  "summary": "one-paragraph statement of the unresolved problem, written by the bot",
  "transcript": [{ "role": "user|bot", "text": "...", "ts": "..." }],
  "variables": {
    "account_id": "...",
    "order_id": "...",
    "plan": "...",
    "intent": "...",
    "sentiment": "neutral | frustrated | angry",
    "already_tried": ["steps the bot already walked the user through"]
  },
  "route_to": "support_tier1 | billing | legal | sales | offline_ticket"
}
```

## Trigger catalog with detection cues

| Family | Cue | How the bot detects it | Action |
| --- | --- | --- | --- |
| Explicit | "human", "agent", "representative", "real person", "speak to someone" | keyword/intent match | Hand off now, no friction, no "are you sure?" loop |
| Implicit — frustration | "this is useless", profanity, ALL CAPS, "!!!" | sentiment + lexical cues | Proactively offer a human |
| Implicit — dead-end | same question asked twice, "that didn't work", loop of 2+ failed answers | repeated-intent detection | Offer a human; stop retrying the same path |
| Implicit — rage input | identical message sent repeatedly, rapid resubmits | dedupe consecutive inputs | Offer a human |
| Topic — refuse bucket | legal, payments, refund-decision, compliance, account-sensitive | bucket classifier (see guardrails ref) | Route to the right human queue |
| System — empty retrieval | no KB chunk above threshold | retrieval score | "I don't have that" → offer human |

## Warm vs cold transfer wording

**Warm (a human is online):** bot posts the packet to the agent, then tells the user:
> "I'm bringing in a teammate who can help with this — sharing what we've covered so you won't have to repeat yourself. One moment."

The agent opens the conversation already holding the transcript + variables; they continue, they don't restart.

**Cold / offline (no human available):** never drop the user into silence. Capture a ticket with the same packet and set an expectation:
> "Our team is offline right now. I've logged everything we discussed (ref #$TICKET) and someone will reply by $WHEN. Anything you'd like me to add before I send it?"

## Sales-bot qualification flow (lightweight BANT)

The sales bot runs **qualify → answer objection → book demo → hand hot lead**. It still obeys the one rule: it never promises a price, discount, or term a human hasn't approved.

```text
1. QUALIFY (conversationally, not as an interrogation):
   - Need     — what problem are they trying to solve?
   - Authority— are they the buyer / who else is involved?
   - Budget    — rough range / plan tier they're considering (no quote back)
   - Timeline  — when are they hoping to decide / go live?

2. ANSWER OBJECTION — from KB only; cite. Pricing question → published
   tiers + "for a custom quote I'll get a human." Never freelance a discount.

3. BOOK DEMO — offer a calendar slot / capture contact. (Calendar plumbing
   itself is not this skill's job.)

4. HAND HOT LEAD — a qualified lead is a WARM handoff: attach the
   qualification packet (the 4 answers + transcript + contact + intent) and
   route_to: "sales". Lukewarm/early → nurture, don't burn a human on it.
```

**Hot-lead packet** = the standard handoff packet with `trigger: "sales_hot_lead"` and the BANT answers folded into `variables`. Same machinery as support handoff — sales just adds the qualification fields and a clearer "this one is ready to talk to a person" signal.
