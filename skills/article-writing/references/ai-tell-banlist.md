# AI-tell banlist + E-E-A-T self-review

The single source of truth for the fluff/AI-tell phrases. `scripts/verify.sh` greps the draft against the fenced `BANLIST` block below — keep **one phrase per line**, lowercase, so the script can read it. The padding patterns and the E-E-A-T self-review are for the human/agent pass; the script only handles the literal phrase grep.

## BANLIST

These are case-insensitive substrings. A match is a fail — rewrite or delete the sentence.

```text
in today's fast-paced world
in today's digital age
in the world of
when it comes to
it's important to note that
it's worth noting that
it is worth noting
needless to say
at the end of the day
let's dive in
let's dive into
let's explore
dive deep into
navigating the landscape
navigating the world of
the ever-evolving landscape
unlock the power of
unleash the power of
unlock the potential
harness the power of
take your x to the next level
in conclusion
in summary,
when all is said and done
a game-changer
game changer in the
the key takeaway is
without further ado
look no further
whether you're a beginner or
this comprehensive guide
in this article, we will
buckle up
rest assured
it goes without saying
plays a crucial role in
plays a vital role
a testament to
embark on a journey
the realm of
```

## Padding patterns (rewrite, not just delete)

These are not single phrases the grep catches; they are shapes. Spot them in review.

| Pattern | Tell | Fix |
| --- | --- | --- |
| Restating the question as a paragraph before answering | "You might be wondering whether…" | Cut it; answer directly |
| Listing what the article *will* cover | "In this guide we'll look at A, B, and C" | Delete; let the headings do it |
| Hedged non-claims | "can potentially help in some cases" | State the claim with a condition and a number |
| Empty transitions | "Now that we've covered X, let's move on to Y" | Delete; the next H2 is the transition |
| Definition padding for a known term | "SEO, which stands for search engine optimization, is…" | Define only if the audience needs it |
| Symmetry filler | "On the one hand… on the other hand…" with no real tension | Pick the answer; note the real trade-off |
| Summary that repeats the body verbatim | A conclusion restating each H2 | Replace with a next step or a decision rule |

## The delete-no-fact pass

Read each sentence and ask: **does this add a fact, a number, a step, or a named example?** If no, delete it. A 1,500-word draft that survives this pass beats a 2,500-word draft that does not.

Concrete test — every paragraph should contain at least one of: a number, a proper noun, a measured result, a named tool, a date, a specific step, or a cited source. A paragraph of pure adjectives is filler.

## Bad → Good rewrites

```markdown
<!-- Bad -->
When it comes to choosing a standing desk, it's important to note that there
are many factors to consider. In today's world, ergonomics plays a crucial
role in our daily lives, so let's dive in and explore your options.
```

```markdown
<!-- Good -->
Choose a standing desk on three specs: height range (match your standing elbow
height, usually 95–120 cm), motor (dual beats single for stability), and lift
capacity (100 kg+ if you mount a monitor arm and a heavy display).
```

```markdown
<!-- Bad -->
Oat milk has become increasingly popular as a game-changer in the world of
dairy alternatives. Without further ado, let's unlock the secrets of why so
many people are making the switch.
```

```markdown
<!-- Good -->
Oat milk overtook almond as the top US plant milk by 2022 sales. It is creamier
because oats release beta-glucan; the trade-off is more carbs (~16 g/cup) than
soy or almond, which matters if you watch blood sugar.
```

## E-E-A-T self-review (human/agent pass, not scripted)

Before ship, answer each. A "no" is a gap to fix, not a nuance to wave past.

- [ ] **Experience** — does the piece include something only someone who did/tested/used the thing would know?
- [ ] **Expertise** — are claims accurate, current, and at the right technical level for the audience?
- [ ] **Authoritativeness** — is there a named author with a bio and relevant standing (not "admin")?
- [ ] **Trust** — are non-obvious claims cited to credible sources, linked inline? Is anything misleading?
- [ ] **Original value** — is there a number, comparison, or angle not already on page one of the SERP?
- [ ] **Intent match** — does the piece fully answer the query, in the SERP's winning format?
- [ ] **Human review** — has a person read it end to end and would they put their name on it?

If the draft passes the banlist grep but fails this list, it is structurally clean and substantively thin. Thin content is what the March 2026 scaled-content-abuse target penalizes. Fix the substance before shipping.
