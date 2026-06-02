# Evals — knowledge-ops

`cases.yaml` is a behavioral spec, not an automated test runner — there is no
script to execute. Use it two ways. First, the `should_trigger` /
`should_not_trigger` prompts sharpen the description boundary: read each prompt
and confirm the router would (or would not) reach for `knowledge-ops`, with the
near-misses correctly routing to `harness` (engine/sweep), `meeting-notes`
(transcript recap), `decision-records` (ADR), `sop-builder` (procedure), and
`codebase-onboarding` (first-pass walkthrough). Second, run the `capability` case
by hand: stand up a scratch messy `02-DOCS/wiki/` matching the scenario (a
two-thesis 600-line article, two near-duplicates, three orphans in
`scores.json`, a stale archive, an unresolved conflict, a homeless note), invoke
the skill against it, and grade the result against the `must_include` rubric —
every item is a pass/fail. There is no `verify.sh`: this is a judgment skill, and
the only deterministically checkable thing (broken links / index drift) is
already owned and auto-fixed by harness's Maintenance Pass.
