# Evals — review-management

`cases.yaml` holds three groups. `should_trigger` lists prompts that must load this
skill (including a non-obvious compliance question and a Catalan phrasing);
`should_not_trigger` lists near-miss prompts that must route to a real sibling
(`customer-support`, `retention`, `seo-geo`, `brand-voice`, `social-publisher`) with the
reason; `capability` is a graded scenario with a `must_include` rubric. There is no
automated runner here — drive a model with each prompt, check routing for the trigger
sets, and score the capability answer against every rubric bullet (own-it reply,
do-NOT-flag-a-legit-negative, the 24-48h SLA, an FTC-clean no-gating request flow, and
the +0.7-star / $53,088 rationale). For the copy this skill emits, also run
`../scripts/verify.sh` against a request template or reply to confirm it has no gating,
sentiment-incentive, or dead-Q&A-API phrasing.
