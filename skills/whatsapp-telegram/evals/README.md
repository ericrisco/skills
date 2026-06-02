# Evals — whatsapp-telegram

These cases are LLM-graded. `should_trigger` / `should_not_trigger` check that the skill's
description and body route correctly: each `should_trigger` prompt (including a Catalan and a
non-obvious error-code phrasing) must select this skill, while each `should_not_trigger` prompt
must defer to the named sibling (`route_to`). The `capability` case is scored against its
`must_include` rubric — a grader reads the skill body + references and confirms each bullet is
satisfiable (pinned `v25.0` endpoint, env-sourced token, `messaging_product` body, 24h-window
branch with #131047, captured message id). Run them with the repo's eval runner pointed at this
skill directory; there is no live API call — grading is on the produced guidance, not on sending a
real message.
