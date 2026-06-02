# Evals — email-connector

`cases.yaml` holds three blocks. `should_trigger` (5 prompts) are situations
this skill must own — including the non-obvious "emails double-send on retry"
(idempotency) and a Spanish bounce-webhook phrasing. `should_not_trigger` (4
prompts) are near-misses that each route to a real sibling (`newsletter`,
`email-deliverability`, `google-workspace`, `api-connector-builder`) so the
routing boundary is checked, not just recall. `capability` (1 scenario) is an
end-to-end SaaS wiring task with a `must_include` rubric covering the seam, env
key, idempotency, templating, batch partial-failure, stream split, webhook
signature, and suppression.

There is no automated runner here. To evaluate, paste each `should_trigger` /
`should_not_trigger` prompt into an agent loaded with the catalog and confirm it
selects (or declines to) `email-connector` and routes to the named sibling. For
`capability`, run the scenario and check the produced integration against every
`must_include` line — then run `scripts/verify.sh <path-to-integration>` to
mechanically confirm the env-key, idempotency, seam, and webhook-signature
invariants on the generated code.
