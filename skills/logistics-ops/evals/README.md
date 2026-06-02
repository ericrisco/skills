# Evals — logistics-ops

`cases.yaml` holds three groups: `should_trigger`, `should_not_trigger`, and a
`capability` case. These are LLM-graded routing and capability checks, not unit
tests — there is no `verify.sh`, because the skill emits operational judgment (a
carrier choice, an exception-response plan, a return disposition, a claim-filing
call), not a single machine-checkable artifact. Run them through whatever eval
harness the repo provides, or by hand: feed each `should_trigger` prompt to the
router and confirm it selects `logistics-ops` — including the non-obvious one (the
"delivery exception, what do I tell the customer" prompt that never says "shipping")
and the Spanish/Catalan return and rate-shop phrasings. Feed each
`should_not_trigger` prompt and confirm it routes to the named sibling
(`inventory`, `procurement`, `customer-support`, `bookkeeping`, `webhooks`) and not
here; every `route_to` id must resolve to a real sibling skill. Grade the
`capability` case against its `must_include` rubric on an actual generated answer:
tick each line — damage → same-business-day outreach, the claim window + evidence at
detection, the dual 60-day/15-day clocks, the proactive tracker-fact message with
tone handed to customer-support, exchange/store-credit before cash with no
restocking fee on a defect, and the hand-offs to bookkeeping and inventory — and
confirm it never invents an ETA the carrier didn't give.
