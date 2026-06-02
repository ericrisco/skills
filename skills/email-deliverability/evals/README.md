# Evals — email-deliverability

`cases.yaml` holds three blocks. `should_trigger` (7 prompts) are situations this
skill must own — the SPF-passes-but-DMARC-fails alignment trap, domain warmup,
the one-click-unsubscribe rule, the BIMI verified-logo request, and a Spanish
phrasing of the spam-folder flagship. `should_not_trigger` (5 prompts) are
near-misses that each route to a
real sibling (`email-connector`, `newsletter`, `cold-outreach`, `gdpr-privacy`,
`data-policy`) so the boundary is checked, not just recall — the sharpest being
the send-path question that belongs to `email-connector`. `capability` (1
scenario) is an 8k/day Gmail-sender remediation with a `must_include` rubric
covering alignment diagnosis, SPF/DKIM fix, the bulk-sender threshold, one-click
unsubscribe, complaint-rate targets, and staged DMARC tightening.

There is no automated runner. To evaluate, paste each `should_trigger` /
`should_not_trigger` prompt into an agent loaded with the catalog and confirm it
selects (or declines) `email-deliverability` and routes to the named sibling.
For `capability`, run the scenario and check the answer against every
`must_include` line — then run `scripts/verify.sh <path-to-dns-or-config>` to
mechanically confirm the DMARC policy and authentication invariants in any DNS
zone / mail config the answer produces.
