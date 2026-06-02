# Evals — calendar-scheduling

`cases.yaml` holds three groups scored by an LLM judge against the rendered
skill — there are no live calendar/API calls. `should_trigger` and
`should_not_trigger` check routing: each prompt is classified and we confirm
this skill owns it, or that it correctly defers to the named sibling (every
`route_to` id is a real skill). `capability` checks that SKILL.md plus
`references/` contain enough to satisfy the `must_include` rubric for a
solo-consultant Google Calendar booking build — freebusy-first slot math, narrow
scopes, timezone-correct writes, a verified idempotent webhook, and orphan-free
reschedule. Run them through the repo's eval runner, which discovers
`evals/cases.yaml` under each skill; there is no standalone harness here. Treat a
judge miss as a signal to sharpen the description's triggers/boundary or fill a
gap in the body, not as noise.
