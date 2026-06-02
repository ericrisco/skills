# Evals for the `ruby` skill

`cases.yaml` holds three kinds of fixture. `should_trigger` lists prompts whose
situation this skill should claim (idiomatic plain-Ruby work — Enumerable refactors,
gem packaging, metaprogramming judgment, Minitest/RSpec, the FrozenError-after-upgrade
case, plus a Catalan phrasing). `should_not_trigger` lists adjacent prompts that must
route to a real sibling instead (`rails`, `python`, `elixir`, `github-actions`), each
with the reason. The single `capability` case is a build-a-gem scenario scored against
a `must_include` rubric. Run them with the repository's eval harness over `evals/`,
which matches the trigger/route fixtures against the skill description and checks a
capability transcript against the rubric. No network or Ruby toolchain is required to
score the routing cases; the capability rubric is judged on the produced answer.
