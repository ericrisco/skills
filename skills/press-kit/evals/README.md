# Evals — press-kit

`cases.yaml` is run by the repo's eval harness. The `should_trigger` and
`should_not_trigger` prompts test the SKILL.md `description`: each trigger prompt
should route to `press-kit`, and each near-miss should route to the named real
sibling (`lead-gen`, `cold-outreach`, `brand-voice`, `article-writing`) instead —
this is how we confirm the NOT-boundary in the description actually holds. The
`capability` block is graded manually or by an LLM rubric: hand the skill the
one-paragraph launch brief and check the produced release contains every structural
marker in `must_include` (header line, dateline, 5-W lede, a real soundbite quote,
a ≤100-word boilerplate, a contact block with an email, the `###` end marker, under
~500 words). The mechanical subset of that rubric is enforceable by
`scripts/verify.sh <release.md>`, which fails on a missing required marker and warns
on filler/length — run it against any generated release to check the form before a
human reads it.
