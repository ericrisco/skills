# Evals — webhooks

These cases are descriptive routing/capability checks, not an automated test
suite. To run them, feed each `should_trigger` prompt to the skill router and
confirm `webhooks` is selected (the `why` explains the intent, including the
non-obvious raw-body and fast-ack symptoms); feed each `should_not_trigger`
prompt and confirm the router picks the named sibling in `route_to` instead
(these guard the boundaries against `stripe`, `email-connector`,
`api-connector-builder`, `automation-flows` and `redis`). The `capability` case
is graded by generation: have the skill produce the Express handler and check
the output against the `must_include` rubric — every line should be present
(raw-body HMAC, constant-time compare, 5-min window, dedupe-on-event-id with a
TTL that outlives retries, 2xx-after-enqueue, secret-from-env, 400/401 on a bad
signature). `scripts/verify.sh` is a complementary static linter for those same
invariants against real handler files; it is advisory, not part of this eval.
