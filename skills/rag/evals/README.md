# rag evals — how to run

These are routing and capability checks, not unit tests. Run the `should_trigger` prompts against
your skill router and confirm `rag` fires; run the `should_not_trigger` prompts and confirm the
router instead defers to the named sibling (`vector-db`, `embeddings-search`, `document-processing`,
`chatbot`, `structured-extraction`) — a miss there means the boundary in the description needs
sharpening. For the `capability` case, hand the scenario to the agent with this skill loaded and
grade the answer against the `must_include` rubric line by line (does it name all five pipeline
stages, hybrid + RRF, the rerank funnel, the grounding-plus-refusal contract, the eval gate, and
the two handoffs); each rubric item is pass/fail. You can do this by hand or wire it through the
`agent-eval` harness for a repeatable score. `scripts/verify.sh` is the static gate on the skill's
own artifacts (frontmatter, the grounding contract, the references, the RAGAS metric names) and is
separate from these capability checks.
