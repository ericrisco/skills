# Evals — content-engine

`cases.yaml` is read by the repo's standard eval harness. The `should_trigger` and
`should_not_trigger` cases check routing discrimination: each `should_trigger` prompt
must select this skill (including the non-obvious "turn this pillar post into everything"
atomization-plan case, the symptom-only "our content is chaos" case, and the Spanish
phrasing), while each `should_not_trigger` prompt must route to the named sibling
(`article-writing`, `social-publisher`, `seo-geo`, `brand-voice`, `calendar-scheduling`)
rather than here — they guard the description's boundary between *the system* and
*producing/distributing one artifact*. The single `capability` case is rubric-graded,
not auto-scored: have the skill build the 4-person B2B SaaS Q3 calendar+pipeline and
check the output against the `must_include` list (grounded in 02-DOCS, 4–6 pillars,
cadence baseline, slot-mix, a CSV artifact, briefs, stage gates, a ≥10 atomization plan,
and everything routed out). Run it through whatever runner the skills repo uses. For the
CSV-artifact subset you can sanity-check a real calendar with
`../scripts/verify.sh path/to/calendar.csv` — it lints columns, stages, flagship
brief/atomization, and mix sanity, but does not judge whether the plan is good.
