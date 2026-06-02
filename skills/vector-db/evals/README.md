# evals — vector-db

These cases are run by the repo's standard skill-eval harness against the skill router. The
`should_trigger` prompts assert that vector-db is the skill that fires (including the non-obvious
"search ignores my filter" and the Spanish/Catalan phrasings); `should_not_trigger` prompts assert
the router yields to the named sibling (`embeddings-search`, `rag`, `postgresdb`, `redis`,
`supabase`) instead of vector-db; and the `capability` scenario is graded by a judge against its
`must_include` rubric. No live vector database or Postgres instance is required — routing is
matched against the skill's description/triggers and the capability answer is judged on content.
Run them with the repo's usual eval command pointed at `skills/vector-db/evals/cases.yaml`.
