# Eval harness — `coolify`

This harness checks two things: **triggering** (does the skill fire on own-the-box self-hosting prompts
and stay quiet on near-misses that belong to a sibling?) and **capability** (does loading the skill
measurably improve the deploy/backup answer?). Cases live in `cases.yaml`. These run through an **agent
harness**, not a pure script — a human or driver agent feeds each prompt to a fresh agent session and
grades the output.

**Triggering.** For each `should_trigger` / `should_not_trigger` prompt, start a clean session with only
`coolify` discoverable, paste the prompt verbatim, run 3–5 trials (the decision is stochastic), and score:
`should_trigger` passes if the skill fires in the majority of trials; `should_not_trigger` passes if it
stays quiet and would plausibly route to the named sibling (`hetzner`, `docker`, `railway`, `postgresdb`,
`domains-dns`). Pass bar: ≥ 90% accuracy across all trigger cases.

**Capability.** Run the scenario twice — WITHOUT the skill (clean agent) and WITH it — and grade each
transcript against the `must_include` checklist, one point per bullet that is specifically and correctly
covered (not just name-dropped). Pass bar: WITH the skill covers ≥ 80% of bullets and clearly beats
WITHOUT (target ≥ +30 points, or fail→pass). If the baseline already nails it, the rubric is too easy.

This is judgment-based grading: record trial counts and per-bullet verdicts so a reviewer can audit — never
report a bare pass/fail.
