# Evals — docker

`cases.yaml` has two kinds of checks. `should_trigger` / `should_not_trigger` are routing cases:
they validate that this skill's `description` fires on real container/image/Compose phrasings
(including the size-symptom and Catalan/Spanish ones) and stays quiet for CI-deploy, k8s,
app-security, and PaaS-host prompts, each routing to a named sibling. The `capability` case is a
rubric-graded scenario: feed the naive single-stage root Dockerfile to the skill and grade the
output against `must_include` (multi-stage, cache mount, non-root, pinned base, `.dockerignore`,
exec-form CMD, healthcheck, compose watch, no ARG/ENV secrets, hadolint/trivy). Run these through
the repo's eval harness; routing cases are mechanical, the capability case is manual or LLM-graded.
