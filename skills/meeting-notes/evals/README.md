# Evals — meeting-notes

These cases are graded by an LLM against the rubric in `cases.yaml`; run them
through the repo's eval harness. The `should_trigger` and `should_not_trigger`
sets check routing — that meeting recaps and AI-transcript cleanups land here,
while the near-misses route correctly (durable ADRs to `decision-records`,
reusable procedures to `sop-builder`, slot-finding to `calendar-scheduling`,
board tracking to `project-ops`). The `capability` case checks the produced
record against `must_include` — especially that AI-suspect content (a
misattributed line, a quote) is flagged for verification rather than fabricated,
that the dateless commitment is marked "needs confirmation" instead of guessed,
and that every action item carries a named owner plus a real due date. There is
no `verify.sh`: the output is a human-judged meeting record, not a machine-
lintable artifact, so the rigor lives entirely in this capability eval.
