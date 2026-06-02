# vue-nuxt evals

These cases are not an executable test suite — they are routing and capability rubrics for humans
or a router harness. To run them, feed each `should_trigger` prompt to the skill router and confirm
`vue-nuxt` is selected, then feed each `should_not_trigger` prompt and confirm it routes to the
named sibling (e.g. `nextjs`, `astro`, `cloudflare`, `e2e-testing`, `fastapi`) rather than here.
The single `capability` case is a manual check: have the agent answer the scenario with the skill
loaded, then verify every line in `must_include` is satisfied by the worked answer (Nuxt-4
detection first, `$fetch`→`useAsyncData`/`useFetch` with a shared key, module-`ref`→`useState`/Pinia
with the per-request-leak explanation, payload-size notes, and no RSC mental models). Pair this with
`scripts/verify.sh` run against a real Vue/Nuxt repo to confirm the emitted code typechecks/builds.
