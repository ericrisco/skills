# analytics — evals

These cases feed the repo's skill-eval harness. `should_trigger` and `should_not_trigger` check routing
precision: each negative names the real sibling id it should route to instead (`dashboard`, `kpi-framework`,
`ab-testing`, `gdpr-privacy`, `observability`, `clickhouse-analytics`), so the grader can confirm the
boundary holds. `capability` is a single rubric-graded scenario — the model proposes an instrumentation plan
and code, and the grader checks the `must_include` list against the answer. No live GA4 or PostHog account is
needed: nothing here sends real events; the harness grades the *proposed* taxonomy, wiring, consent gate, and
PII handling, not a live data flow. Run it through the repo's standard eval runner against this `cases.yaml`.
