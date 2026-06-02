# Evals — embeddings-search

These cases are routing and capability checks for a human or an LLM grader, not an automated
test suite. To run them: read each `should_trigger` prompt and confirm an agent would reach for
`embeddings-search`; read each `should_not_trigger` prompt and confirm it routes to the named
sibling (`vector-db`, `rag`, `structured-extraction`, `prompt-engineering`) for the stated
reason; then grade the `capability` scenario by checking the produced answer against every item
in its `must_include` rubric. A pass covers all routing cases plus full rubric coverage on the
capability scenario. The separate `scripts/verify.sh` lints produced embedding/eval artifacts
and is independent of these cases.
