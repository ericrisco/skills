# Evals — shortform-ideation

These cases are routing + capability checks for a human or an LLM judge; the only
automated runner that ships with the skill is `scripts/verify.sh`, which structurally
lints an emitted backlog or experiment file, not these prompts. To run the routing
checks, feed each `should_trigger` prompt to the router and confirm the skill's
`description` fires — including the non-obvious "why did the ones we bet on flop"
(an outcome-ledger review that looks like analytics but is this skill's loop), the
Spanish "idéame Reels para esta semana basándote en lo que ya nos funcionó", and the
Catalan "prioritza idees de vídeo curt" phrasing — and confirm each
`should_not_trigger` prompt routes to its named sibling (`video-shorts`,
`shortform-strategy`, `shortform-packaging`, `youtube-ideation`, `analytics`) instead
of here. For the `capability` scenario, generate the batch and grade it line by line
against `must_include`: it must ground in the 02-DOCS perf log (re-using winning
hooks, never re-pitching the dead topic), capture at least one dated trend signal
with no scraping, emit the ranked backlog table with all required columns, score by
hook strength + shareability rather than topic interest, write at least one bet as a
dated pending-result hypothesis, and hand the chosen idea off to video-shorts rather
than writing a script. To lint an actual produced artifact, point
`scripts/verify.sh` at the file or the `02-DOCS/shortform/` directory.
