# Evals — rails

`cases.yaml` is a routing/trigger fixture, not an automated test harness. Run it by
hand (or via your router-eval tool): feed each `should_trigger` prompt to the skill
router and confirm it selects `rails`; feed each `should_not_trigger` prompt and confirm
it routes to the named sibling (`ruby`, `laravel`, `postgresdb`, `deployment`) instead.
For the `capability` case, give the scenario to the agent with this skill loaded and
check the produced Rails code satisfies every line in `must_include` — resourceful
routes, an association + validation, strong params, `includes`-based eager loading, a
Turbo Stream/morph live update, an `ApplicationSystemTestCase` test with auto-waiting
assertions, and Solid Queue (never Sidekiq) for any async. No external services or
network are required.
