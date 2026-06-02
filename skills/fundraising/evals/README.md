# Eval harness — `fundraising` skill

These cases are read by the skill-eval harness (an agent harness with the full
skill catalog loaded for routing, e.g. `agent-eval`), not a shell runner —
triggering precision and round-strategy quality are judgment calls. `cases.yaml`
holds three blocks. `should_trigger` / `should_not_trigger` check **routing**:
the skill must fire on round-strategy/process asks and stay quiet on near-misses
that belong to a sibling (the recurring traps are the deck → `pitch-deck`, the
numbers → `financial-model`, the collateral → `investor-materials`, the message
copy → `cold-outreach`, and the binding legal doc → `contracts`). `capability`
checks the **reasoning**: for the pre-seed scenario, run the agent with and
without the skill and grade the output against the `must_include` rubric —
the win condition is sizing to a milestone, the correct SAFE call with the
pile-up flag, a back-solved warm-weighted funnel, a parallel sprint, clean
handoffs to the siblings, and zero dishonest-FOMO coaching. No live API or
network is needed — cases are static prompts plus rubrics; run several trials
per prompt (context is stochastic), report the raw fraction, and re-grade after
any edit to `SKILL.md` or its `references/`.
