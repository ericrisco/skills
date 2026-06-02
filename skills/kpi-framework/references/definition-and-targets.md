# Writing definitions, measuring baselines, and calibrating targets

Depth offloaded from `SKILL.md` Steps 1-4. This is where a metric definition stops being a
slogan and becomes a number two analysts compute identically.

## Write an unambiguous definition

A definition that drifts produces arguments instead of decisions. Every metric needs four
components spelled out:

1. **Event** — the exact tracked action. Not "uses the product"; "completes `core_action`
   (a saved project with >=1 collaborator)".
2. **Time window** — rolling vs calendar, and its length. "Weekly active" must say *rolling
   7-day* or *calendar week*; they differ by ~15% on most products.
3. **Denominator** — what you divide by. "Active teams" vs "all signed-up teams" vs "paying
   teams" are three different metrics wearing the same name.
4. **Segment** — who's included. New vs existing, paid vs trial, by plan or region. State it
   even when it's "all", so the choice is explicit.

- Bad: `weekly active users`
- Good: `accounts with >=1 member completing core_action in a rolling 7-day window / accounts with an active subscription, all regions`

Rule: prefer a **rate or ratio** over a raw count. Counts grow with time and size and mask
decline; a rate normalizes and exposes health.

## Measure the baseline first

You cannot set a target without a baseline — "get to 50%" is empty until you know you're at
12% or 48%.

- Pull the metric over a stable recent period (typically the last 4-8 weeks, long enough to
  smooth noise, short enough to reflect the current product).
- Note **variance**, not just the point value. A metric bouncing 30-46% week to week has a
  baseline *range*; a target inside that range is no target at all.
- If the event isn't instrumented yet, the first deliverable is "instrument it and measure
  4 weeks" — hand the event to `../analytics/SKILL.md`. Do not invent a target over an
  unmeasured metric.

## Calibrate the target magnitude

Targets break in two directions: too ambitious (burnout, shortcuts, gaming) or sandbagged
(no improvement, theatre).

- **Improvement over baseline, not a round number.** Derive the band from (a) the levers you
  actually have this period and (b) what comparable improvements have historically yielded.
  "38% → 52%" grounded in a named initiative beats "→ 50%" chosen because it's round.
- **Set a realistic band, then commit to a point.** E.g. "expect 48-55% from the onboarding
  rework; commit to 52%." The band is your reasoning; the point is the target.
- **Avoid round-number theatre.** 50%, 100%, 1M — round targets are usually chosen for how
  they read in a deck, not because the levers support them. Treat a suspiciously round
  target as unexamined until proven otherwise.
- **Date + owner are mandatory.** No date → it's a wish. No owner → it's nobody's job.

## Re-validation checklist (run semi-annually)

- [ ] Does the north star still **predict** retention/revenue? Re-check the correlation
      against the last two quarters; a metric can quietly stop predicting value.
- [ ] Are the inputs still **controllable** by the owning team, and do they still move the
      north star when pushed?
- [ ] Has any guardrail crept toward its harm threshold while the target improved? (silent
      gaming signal)
- [ ] Did the product/portfolio change enough to retire or redefine a metric?
- [ ] Version and date the doc; record what changed and why. Transparent evolution keeps a
      metric shift from looking like cooking the numbers.
