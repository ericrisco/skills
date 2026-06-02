# Evals — brand-identity

`cases.yaml` is read by the harness eval runner. The `should_trigger` and
`should_not_trigger` blocks check routing precision: that brand-foundation requests
(logo brief, color/type system, tokens export, the Catalan/Spanish phrasings, and the
non-obvious "consolidate scattered fonts/hex" rebrand case) select this skill, while
adjacent asks correctly route to the real siblings — `design` (applied UI), `brand-voice`
(words/tone), `marketing` (page copy), `press-kit` (media pack), `presentations` (deck).
The `capability` block is a rubric scored against a real generation: the "Ledgerly" prompt
must produce all four deliverable parts (logo brief, four-channel color roles, an AA-proven
contrast pair, a 2-3 typeface system, a W3C `design-tokens.json` with light/dark) plus
usage rules and the hand-off to `design`. Run it via the repo's eval command; no network is
required. To sanity-check the verify gate by hand, run
`scripts/verify.sh path/to/design-tokens.json` against a generated tokens file.
