# Eval harness — `course-builder`

This is an **agent-run** eval, not an automated grader. `cases.yaml` has three blocks:
`should_trigger` (7), `should_not_trigger` (5), and `capability` (1 scenario with a rubric). To run
it, load **only** `course-builder` into a fresh agent (no sibling skills, so a miss can't be masked),
paste each `should_trigger` / `should_not_trigger` prompt verbatim over 3–5 trials, and record
whether the agent invokes the skill — `should_trigger` should fire, `should_not_trigger` should
stay quiet and ideally route to the named sibling. Aim for ≥90% correct decisions across trials; a
prompt that misses on a majority of its trials is a real defect — fix the description/triggers in
`SKILL.md`, don't loosen the case. For the `capability` scenario, run it once and score the output
against the `must_include` rubric by hand: did it work backward (outcomes first), ban vanity verbs,
verb-match assessment to outcomes with both formative and summative, sequence modules with no
orphans/unproven outcomes, emit the alignment matrix, and hand storytelling off rather than doing
it? Grading is judgement, not grep — `scripts/verify.sh` only checks the greppable structure of a
finished curriculum doc (banlist verbs, matrix presence, proven outcomes, formative+summative); the
rubric here is the real bar.
