# Evals — social-publisher

These cases are routing + capability checks for a human or an LLM judge; there is no
automated test runner beyond `scripts/verify.sh` (which lints an emitted calendar
file, not these prompts). To run them: read `cases.yaml` and confirm the skill's
`description` would fire on every `should_trigger` prompt (including the non-obvious
"same caption flopped" symptom and the Catalan "reaprovechar" phrasing), that each
`should_not_trigger` prompt routes to the named sibling instead (`brand-voice`,
`video-shorts`, `community`, `content-engine`), and that a calendar generated for the
`capability` scenario satisfies every line of its `must_include` rubric — native
per-platform variants, sane 2026 cadence, best-time slots flagged as hypotheses, a
schedulable table with the required columns, surfaced publish-limit/approval gates,
and no invented brand voice or topics. To check an actual emitted calendar, point
`scripts/verify.sh` at the CSV/JSON it produced.
