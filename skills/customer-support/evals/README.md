# Evals — customer-support

These cases are graded by an LLM judge against `cases.yaml`, run through the
repo's eval harness. `should_trigger` and `should_not_trigger` check routing —
that a real support ticket loads this skill while near-misses (writing the KB
doc, the onboarding flow, the win-back program, the voice guide, the bot) route
to their correct sibling. The `capability` case checks reply *quality*: the
judge scores the produced triage + draft against the `must_include` rubric
(P1 + FRT target, acknowledge-before-promise, de-escalation without banned
phrases, no invented fix/ETA, an escalation handoff packet, the right metric).
There is no `verify.sh` — this is a judgment skill whose output is a triaged
ticket and a drafted reply, not a machine-checkable artifact, so the capability
rubric carries the rigor.
