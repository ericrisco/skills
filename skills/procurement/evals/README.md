# Evals — procurement

`cases.yaml` holds three groups: `should_trigger`, `should_not_trigger`, and a
`capability` case. These are LLM-graded routing and capability checks, not unit
tests. Run them through whatever eval harness the repo provides, or by hand: feed
each `should_trigger` prompt to the router and confirm it selects `procurement`
(including the non-obvious ones — the "actually cheaper over three years" TCO trap
and the "2/10 net 30" early-payment-discount question that masquerades as an AP
task — and the Spanish/Catalan phrasings). Feed each `should_not_trigger` prompt
and confirm it routes to the named sibling (`contracts`, `pricing`, `inventory`,
`logistics-ops`, `bookkeeping`) and not here; every `route_to` id must resolve to
a real sibling skill. Grade the `capability` case against its `must_include`
rubric on an actual generated answer: tick each line (Kraljic segmentation,
weights summing to 100, TCO not unit price, the early-discount math, single-source
risk + backup plan, hand-offs to contracts/inventory). Pair the capability grade
with `scripts/verify.sh` against any generated scorecard/TCO file to confirm the
artifact ties out (weights sum to 100, no blank scores, recomputed totals match,
TCO has more than a unit line) — the rubric judges sourcing judgment, verify.sh
judges structural consistency. No automated harness is assumed beyond reading the
prompts and checking routing plus the rubric.
