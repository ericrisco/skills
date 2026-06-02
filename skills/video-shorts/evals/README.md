# Evals — video-shorts

These cases are routing + capability checks for a human or an LLM judge; there is
no automated runner beyond `scripts/verify.sh` (which lints an emitted script file,
not these prompts). To run them: read `cases.yaml` and confirm the skill's
`description` would fire on every `should_trigger` prompt — including the
non-obvious "my Reels lose everyone in the first 3 seconds" symptom and the Spanish
"convierte este vídeo largo en un Short" phrasing — and that each `should_not_trigger`
prompt routes to the named sibling instead (`social-publisher`, `content-engine`,
`brand-voice`, `ads`, `podcast`) rather than here. For the `capability` scenario,
generate the script + EDS and grade it line by line against the `must_include`
rubric: a 0:00–0:03 hook with 4–7-word on-screen text, a timecoded beat sheet that
sums to a 15–30s runtime, on-screen text on every beat, a cut-cadence note, a loop
seam or single CTA (no outro), and the 9:16/1080×1920/burned-in-caption export note.
To lint an actual produced script, point `scripts/verify.sh` at the `.md` it emitted.
