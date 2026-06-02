# Evals — continuous-learning

These cases are eyeballed against the SKILL.md description and body, not run by a
harness. Two axes. **Triggering:** read each `should_trigger` prompt and confirm
the description's "Use when …" / "Triggers:" clauses would route it here, and
read each `should_not_trigger` prompt and confirm it routes to its `route_to`
sibling instead (the `NOT … (that is decision-records)` boundary plus the
when-NOT list should make every one of those a clean miss). **Capability:** walk
the scenario through the body and check every `must_include` rubric item is
satisfied — the blameless root cause, the 2+-recurrences structural fix, the
routing to an exact durable path, the hand-off to `author-skill` for craft, the
situation-tagged entry, and the "prove it fires next time" surface.

There is no `scripts/verify.sh`: this is a process skill whose only output is a
durable write into *another* surface, which is checked there (a rule, an eval, a
verify.sh on the owning skill). Its rigor is the capability eval above.
