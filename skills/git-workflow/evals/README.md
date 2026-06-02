# Evals — git-workflow

These are routing and capability checks for the `git-workflow` skill. Run them with the repo's eval
harness: load `cases.yaml`, fire each `should_trigger` and `should_not_trigger` prompt at the router,
and confirm the trigger ones select `git-workflow` while the negatives route to their stated sibling
(`ship`, `worktrees`, `deployment`, `review`). For the `capability` entry, give the scenario to the
skill and judge the produced commit plan, semver bump, and `gh release create` command against the
`must_include` rubric — the bump is MAJOR, the breaking change uses an uppercase `BREAKING CHANGE:`
footer, the push uses `--force-with-lease`, and there is no AI-attribution trailer. No code is
executed and the skill emits no artifact, so this is a judgment pass, not a build.
