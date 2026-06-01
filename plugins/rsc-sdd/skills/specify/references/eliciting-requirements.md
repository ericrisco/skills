# Eliciting requirements — infer first, then ask one thing

The whole point of this skill is to reach a complete-enough spec with the
fewest questions. That means inferring hard before asking, and asking surgically
when you must. This reference holds the inference checklist and the elicitation
patterns the SKILL body summarizes.

## Inference checklist — answer these from existing material before asking

Run down this list using the `constitution`, the existing wiki, sibling specs,
and the intent itself. Only what survives as unknown becomes a question or a
*point to clarify*.

- **Problem** — does the intent already state the pain, or only the wanted
  feature? If only the feature, the problem is the first thing to recover.
- **Primary user** — who triggers this? The constitution's ICP / users article
  usually answers it.
- **Trigger** — what event or need makes someone want this? Often implicit in
  the intent.
- **Success** — what does the user get that they didn't have before? That's a
  goal, in outcome terms.
- **Boundaries** — what's adjacent but deliberately excluded? Derive non-goals
  from the constitution's scope and quality bars.
- **Happy path** — the common-case behaviour is usually inferable from the
  intent; write it, then test it with the user if L2/L3.
- **Edges** — empty / none / one / many / max, concurrent, repeated, expired,
  unauthorized. Walk these mechanically; each is a candidate criterion.
- **Errors** — what does the user see when it fails, and what must NOT be
  revealed? Security/privacy constraints often live in the constitution.

What you genuinely cannot resolve here is exactly what `clarify` exists for.
Naming it is the correct outcome, not a failure.

## The one-question-at-a-time pattern

A question earns a turn only if a *different answer would change the spec*.
Apply this test before asking:

> "If they answer A vs B, does a goal, a user, the scope, or an acceptance
> criterion change?" — No → don't ask; infer or defer. Yes → ask, alone.

Phrase by register:

- **Non-technical / L3** — plain language, one concept, offer a concrete
  example to react to rather than an open void:
  > "When someone's link has expired, should they be able to ask for a fresh
  > one right there, or is that a separate step?"
- **Technical / L0-L1** — terse, decision-shaped:
  > "Expired-link recovery in scope, or defer?"

Always: ask → wait → record the answer in the relevant section → confirm at L2/L3
→ ask the next. Never present a numbered list of ten questions.

## Turning answers into testable criteria

Once you have an answer, convert it immediately to a Given/When/Then so it's not
lost as prose:

```text
Answer: "Yes, they can request a new link from the expired page."
becomes
Given an expired link, When the user opens it, Then they see a "request a new
link" action that issues a fresh one.
```

If the answer is fuzzy ("it should feel fast"), do not invent a number — push
once for a concrete figure; if none is available, file it under *Points to
clarify* with the assumption you're carrying meanwhile.

## When to stop

Stop eliciting when the WHAT and WHY are complete enough that `plan` could start
without guessing at scope. Lingering unknowns are fine — they belong in *Points
to clarify*. Over-asking to feel thorough is itself an anti-pattern: it burns the
user's patience and pushes them to rubber-stamp answers they haven't thought
through. A short spec with three honest open points beats a long spec with three
fabricated ones.
