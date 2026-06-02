# Evals — cloudflare

These cases exercise the skill's routing and coverage. `should_trigger` lists prompts the
`cloudflare` skill must claim (config/bindings, storage choice, Static Assets deploy, Queues,
runtime-limit fixes), including a non-obvious symptom (stale KV reads) and a Catalan phrasing.
`should_not_trigger` lists adjacent prompts that must route elsewhere (deployment, nextjs,
domains-dns, postgresdb, redis) — each names the real sibling it belongs to. The `capability`
case checks the body actually produces a working wrangler.jsonc plus typed binding code for a
realistic multi-primitive Worker.

To run: feed `cases.yaml` to the repo's eval harness, which scores the skill description+body
against each prompt's expected routing and the capability rubric. To check manually, read
`cases.yaml` and confirm `SKILL.md` (and its references) answers each should_trigger prompt,
sends each should_not_trigger prompt to the named sibling, and covers every `must_include` item
in the capability scenario.
