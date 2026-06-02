# Evals — google-workspace

These cases are routing and coverage checks for the skill harness, not live
Google API calls. `should_trigger` asserts a prompt should load and use this
skill (server-side Gmail/Drive/Calendar/Sheets via a service account, scope and
delegation decisions, 403/429/unauthorized_client debugging), including a
Spanish phrasing and non-obvious error-symptom triggers. `should_not_trigger`
asserts that a neighboring concern instead routes to the named real sibling
(email-deliverability, calendar-scheduling, spreadsheet-ops, document-processing,
automation-flows), guarding the boundaries in SKILL.md. The single `capability`
case is a rubric: feed the scenario to the skill and check the generated answer
covers every `must_include` bullet (correct DWD `subject`, minimal scopes, the
Admin-console client-ID authorization, the googleapis client build, backoff on
429, and the never-commit-the-key / keyless guidance). Nothing here touches a
real GCP project or sends mail; `scripts/verify.sh` is the only executable
artifact and it is a no-network static linter you can run against any repo.
