# Evals — shopify

Run these against the repo's eval harness pointed at the `shopify` skill id. The
`should_trigger` cases mirror the `description` triggers across all three surfaces (theme, app,
checkout) and include the non-obvious ones — the "broke after the August upgrade" checkout-
migration framing, the `MAX_COST_EXCEEDED` query-cost framing, and the Catalan phrasing — to
confirm the skill fires when the surface is implicit. The `should_not_trigger` cases each route to
a real sibling (`wordpress`, `stripe`, `nextjs`, `no-code-app`, `api-design`) and exist to catch
surface confusion: WooCommerce/PHP, non-Shopify payments, the headless React layer, no-code
builders, and generic API-contract design must *not* pull in Shopify. The single `capability` case
is graded against its `must_include` rubric — a correct answer scaffolds an OS 2.0 section
(`render` not `include`, a `presets` + `@app` block schema) plus a Remix loader on a pinned
`apiVersion` with `admin.graphql()` and cost/throttle awareness, and never reaches for
`checkout.liquid`.
