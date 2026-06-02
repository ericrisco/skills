# Evals — tauri

These cases are a behavioral spec for routing and capability coverage, not a runtime test of
Tauri itself — nothing here compiles Rust or builds an app. Run them through the repo's eval
harness: `should_trigger` feeds the skill's `description` + body to the router and asserts it
selects this skill (including the non-obvious "stream download progress" case, where the right
answer is a `Channel<T>` and the word "Tauri" never appears); `should_not_trigger` asserts the
router declines and routes to the named real sibling (electron, expo, rust, react,
compose-multiplatform); the `capability` scenario prompts the agent and grades the answer against
the `must_include` rubric (annotated + registered command, `Result<T, E>`, a scoped `fs` glob,
the default-deny note, and the capability-vs-permission explanation). `scripts/verify.sh` is a
separate standalone static lint over an `src-tauri/` tree and needs no harness.
