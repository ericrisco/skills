# Evals — aws-essentials

These cases are LLM routing and quality checks, not executable AWS calls — nothing here touches
a real account or needs credentials. Run them through the repo's eval harness: `should_trigger`
and `should_not_trigger` feed the skill's `description` + body to the router and assert it
selects (or correctly declines, routing to the named real sibling) this skill; `capability`
prompts the agent with the scenario and grades the produced answer against the `must_include`
rubric (private bucket, OAC-not-OAI, scoped IAM, no long-lived keys, encryption acknowledged).
The static linter `scripts/verify.sh` is separate and runs standalone over a directory of
policy/config files — it needs no harness and no AWS access.
