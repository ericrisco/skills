# Evals — ads

`cases.yaml` has three blocks. **should_trigger** and **should_not_trigger** are
routing checks: feed each `prompt` to the router and confirm it picks `ads` for the
triggers (including the non-obvious "the bank account disagrees" finance-looking one
and the Spanish/Catalan phrasings) and the named real sibling for each near-miss
(`landing-copy`, `ab-testing`, `marketing`, `dashboard`, `brand-voice`). The
near-miss cases pass only when the router prefers the named sibling over `ads`. The
**capability** block is an LLM- or human-graded rubric: run the scenario with the
skill loaded and check the produced launch plan hits every `must_include` line —
break-even computed (2.0x), target ≥ break-even, ~50× CPA budget floor, the 20–30%
existing-customer cap, 15–20+ in-spec creatives, the Consent Mode v2 / Enhanced
Conversions / CAPI gate, incrementality/MER (not platform ROAS) as the kill switch,
and the handoffs. There's no automated runner here — grade by reading the output
against the list, or wire it into your eval harness of choice.
