# skill-scout evals — how to run

`cases.yaml` is read by the catalog eval runner. The `should_trigger` / `should_not_trigger` sets
check the description's routing precision: each `should_trigger` prompt should pull this skill in,
and each `should_not_trigger` prompt should route to its named sibling instead (the sharp edges are
against `suggest` — routing among skills you already have — and `author-skill` — writing the skill
that doesn't exist; the rest guard `context-budget`, `continuous-learning`, and `knowledge-ops`).
The `capability` case is a manual/LLM-graded rubric: run the scenario with the skill loaded and
confirm every `must_include` line is satisfied — especially that it never fabricates a catalog id
and never does the implementation itself. No network or credentials needed; everything is local and
static. To sanity-check the optional artifact path, run `scripts/verify.sh` against a directory
containing a `skill-gaps.jsonl` (it is a clean no-op on an empty or absent file).
