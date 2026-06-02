# Evals — research-ops

These cases are run by the rsc eval harness. `should_trigger` and `should_not_trigger`
check description routing — does the skill fire on real research asks (including the
non-obvious "settle this argument" and the Spanish/Catalan phrasings) and stay quiet on
market-sizing, standing-watch, scraping, and knowledge-filing asks that belong to siblings.
The `capability` case is a rubric a human or LLM grader scores against an actual research
run: did the agent loop rather than one-shot, triangulate a load-bearing claim, date and
tier every claim, surface (or rule out) disagreement, and ship an answer-first memo with an
open-questions section. There is no automated grading of memo *correctness* — the only
mechanical check is `scripts/verify.sh`, which lints a produced memo for provenance
structure (answer section, citations, dates, confidence tiers, open-questions section), not
for whether the answer is right.
