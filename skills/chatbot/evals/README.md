# chatbot — evals

`cases.yaml` holds two kinds of checks. **Trigger cases** (`should_trigger` / `should_not_trigger`) are routing judgments: read each prompt and confirm the skill description would (or wouldn't) claim it, and that each `should_not_trigger` lands on the named sibling instead — there's no runner, it's a human/LLM judgment against the frontmatter. The **capability case** is a rubric: give a fresh agent loaded with this skill the scenario, then check the produced system prompt and operating design contain every item in `must_include`.

To exercise the artifact gate, run the verifier against a candidate system prompt:

```bash
# from your project (not the skills repo)
skills/chatbot/scripts/verify.sh path/to/system-prompt.md
skills/chatbot/scripts/verify.sh path/to/system-prompt.md --strict   # warnings fail too
```

It's read-only and dependency-free (POSIX sh + grep). It hard-fails on a leaked secret, a missing refusal/handoff/grounding section, or an unbounded-commitment phrase ("we guarantee", "any price", "always refund", "unlimited"); it warns on a missing length cap or missing injection-defense language. A clean or empty file exits 0, so it never false-fails. A good capability answer should produce a prompt that passes `verify.sh` cleanly.
