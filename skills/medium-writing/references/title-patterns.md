# Title / subtitle / kicker pattern library

The hook system is three coupled lines: the **title** earns the click, the **subtitle** extends and qualifies it (and is search-indexed and shown as preview text), the **kicker** frames the category. Write all three after the body exists, so you only promise what you deliver. Strong always; sensational never (sensational disqualifies the story from Boost).

## Title archetypes

Each archetype below carries when-to-use and two annotated examples. Match the archetype to the kind of payoff your body actually contains.

### Specific result

Use when the body lands a concrete, quantified outcome. The number is the hook.

- "How I Cut Our Build Time From 14 Minutes to 90 Seconds" — the gap (14m → 90s) is the promise; the body must show exactly how.
- "We Deleted 40% of Our Tests and Shipped Faster" — counter-intuitive number; works because it names a measurable result, not a vibe.

### Contrarian

Use when you genuinely disagree with received wisdom and can defend it. The tension is the hook.

- "Stop Writing Unit Tests First" — sets up a real argument; only works if the body earns the claim with reasoning.
- "Your Microservices Are Probably a Mistake" — "probably" keeps it honest rather than absolutist; the body must qualify *when*.

### How-to

Use when the value is a repeatable method the reader can apply tomorrow.

- "A 4-Step Way to Debug Any Flaky Test" — the step count signals scope and finishability.
- "How to Read a Postgres Query Plan Without Guessing" — names the pain ("without guessing") the method removes.

### Listicle with teeth

Use when you have a genuine set of distinct, non-obvious items — not filler padded to a round number.

- "5 Postgres Indexes That Quietly Slow Down Writes" — specific domain + a non-obvious angle; each item must be real.
- Bad version: "10 Amazing Tips for Better Code" — round number, no specificity, no teeth. Avoid.

### Narrative first-person

Use when the lesson rides on something that happened to you. The story is the hook; the lesson is the payoff.

- "I Shipped to Production on Day One. Here's What Broke." — concrete stakes, promises a reckoning.
- "I Spent Three Months on a Feature Nobody Used" — vulnerability + a clear lesson the reader can avoid.

### Question

Use when the reader carries the same open question and your body answers it.

- "Why Does Every Postgres Index Slow Down My Writes?" — the answer must be in the body, not teased.
- Bad version: "Is This the End of REST APIs?" — rhetorical bait with no committed answer. Avoid.

## Subtitle: do and don't

The subtitle is the preview text under the title and is indexed for search. Treat it as the second half of the promise.

- Do: add the specificity the title omits. Title "How I Cut Our Build Time" → subtitle "The fix was three lines of cache config — but finding them took a week of profiling."
- Do: name the payoff or the catch. It should make the click more, not less, likely once the reader knows what's inside.
- Don't: restate the title in other words ("A story about CI build performance").
- Don't: leave it decorative or empty ("Read on to find out"). That wastes an indexed line and a preview slot.

## Kicker: examples

A short framing phrase above the title. It orients the reader's expectation.

- Category: "Engineering", "Product", "Career".
- Series/angle: "Lessons From a Failed Launch", "Notes From Production".
- Keep it short — a phrase, not a sentence. It is not a second subtitle.

## Sensational vs. strong

Boost curation rejects shocking or sensational hooks. The difference is a deliverable promise versus manufactured alarm or withheld payoff.

| Sensational (disqualifying) | Strong (curation-friendly) |
|---|---|
| "This One Trick Will SHOCK Your DevOps Team" | "The Cache Config That Cut Our Build Time 90%" |
| "You're Doing Testing ALL WRONG" | "Why Writing Tests First Slowed My Team Down" |
| "The TRUTH About Microservices Nobody Tells You" | "When Microservices Cost Us More Than They Saved" |
| "I Almost QUIT Engineering Forever…" | "The Burnout Quarter That Changed How I Plan Work" |

The tell: a sensational hook relies on caps, superlatives, vague menace, or a withheld reveal to bait the click; a strong hook states a specific, real, deliverable claim and trusts the reader to want it.
