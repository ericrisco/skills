# Evals — competitor-watch

`cases.yaml` has three blocks. **should_trigger** and **should_not_trigger** are routing
checks: feed each `prompt` to the router and confirm it selects `competitor-watch` for the
triggers (including the non-obvious "keep the matrix updated" and "how their positioning
shifted over 6 months" framings and the Catalan phrasing) and the named real sibling for each
near-miss — `market-research` (list/sizing), `pricing` (our price), `sales-pipeline` (the
battlecard), `data-scraper` (one-off extraction), `automation-flows` (scheduling). A near-miss
passes only when the router prefers the named sibling over `competitor-watch`. The
**capability** block is an LLM- or human-graded rubric: run the scenario with the skill loaded
and check the produced plan hits every `must_include` line — ethics gate first, tracker
persisted under `02-DOCS/` with a `source_url`+`date` on every price/feature cell (no invented
numbers), each surface mapped to URL+selector+tiered cadence, the change-log axis+materiality
schema, `changedetection.io` as the runnable default with Wayback flagged as archive-only, and
the handoffs to automation-flows and sales-pipeline. There is no automated runner and no live
network call — the agent produces the tracker, watch config, and change-loop process as
artifacts; grade by reading the output against the list, or wire it into your eval harness of
choice. `scripts/verify.sh` separately lints an emitted tracker/change-log for sourcing and
schema (see its header).
