# expo evals

These cases are a routing + capability rubric, not an automated test harness. To run
them, feed each `should_trigger` / `should_not_trigger` prompt to the skill router and
confirm it (a) selects `expo` for the triggers — paying attention to the non-obvious
("update isn't showing up", the New-Arch-mandatory blocker) and the Catalan/Spanish ones — and
(b) routes each non-trigger to the stated sibling (`react-native`, `github-actions`,
`flutter`, `swift-ios`, `react`). For `capability`, give the scenario to the skill and
score the answer against the `must_include` rubric, either by hand or with an LLM judge:
every bullet should be present and correct (eas.json profiles + channel, fingerprint
runtime policy with the exact-match rule, the build/submit/update commands, the
hand-editing/keystore warnings, and the New-Arch-already-mandatory note). The config artifacts the
skill emits can be additionally gated with `scripts/verify.sh`.
