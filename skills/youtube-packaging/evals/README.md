# Evals — youtube-packaging

These cases are read by the repo's skill-eval harness. `should_trigger` and
`should_not_trigger` check routing precision: each prompt is matched against this
skill's description versus its siblings, and the `route_to` ids
(`youtube-thumbnails`, `youtube-ideation`, `youtube-api`, `youtube-strategy`,
`seo-geo`) must win their own cases — the thumbnail, the idea, the API call, the
channel plan, and non-YouTube SEO all belong elsewhere. The `capability` case is
scored by a judge against its `must_include` rubric: it checks that a generated
package grounds in `02-DOCS` first, emits a 2-3 title A/B set within the char
budget, an above-the-fold description line plus a natural ~200-350 word body and a
3-5 hashtag line, chapters obeying all four rules, 5-8 tags with the right first
tag, a feedback-log update, correct handoffs, and the watched-time-per-impression
framing. Run them through the repo's eval runner; no live YouTube account, upload,
or network access is required — the capability run is a dry-run producing text
artifacts and a feedback-log row only.
