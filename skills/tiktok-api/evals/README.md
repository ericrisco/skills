# Evals — tiktok-api

These are routing and coverage checks run by the skill harness, not live API tests. No
TikTok or OAuth network calls are made. `should_trigger` asserts this skill fires on
TikTok transport/ingestion prompts — including the non-obvious ones (24h access-token
death, `url_ownership_unverified` on PULL_FROM_URL, `rate_limit_exceeded` at 6/min, and
the Display-can't-give-watch-time distinction) and the Spanish/Catalan phrasings.
`should_not_trigger` asserts the right sibling wins on intent (`shortform-strategy` /
`shortform-packaging` / `shortform-editing`), on multi-network posting
(`social-publisher`), on other platforms (`instagram-api`), and on generic connector
work (`api-connector-builder`). `capability` is a rubric for a generated answer to the
daily-cron scenario — graded on whether it covers token refresh, the chunked
init→PUT→poll publish flow, the correct Display-vs-Business API split, the 6/min
throttle, least-privilege scopes + the audit caveat, append-not-overwrite wiki
ingestion, secret hygiene, and the 24–48h metric-lag caveat. Run them through the
repo's standard skill-eval runner against `cases.yaml`. The companion `scripts/verify.sh`
is a separate static, no-network linter you can point at integration code.
