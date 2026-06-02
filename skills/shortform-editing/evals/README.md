# Evals — shortform-editing

These are routing + capability checks for a human or an LLM judge, not a renderer
test — nothing here encodes a video. To run them, read `cases.yaml` and confirm the
skill's `description` would fire on every `should_trigger` prompt (including the
non-obvious "captions out of sync and hidden behind the TikTok buttons" symptom and
the Spanish/Catalan phrasings) and that each `should_not_trigger` prompt routes to
the named sibling instead (`video-shorts`, `remotion-video`, `social-publisher`,
`youtube-thumbnails`, `podcast`) rather than here. For the `capability` scenario,
have the skill produce the pipeline/commands and grade them line by line against the
`must_include` rubric: word-level transcription, a two-pass silence cut that removes
video AND audio together, a beat grid with cuts snapped to it, karaoke `.ass`
captions in the safe middle band, a 1080x1920 H.264/AAC export, and `ffprobe`
verification. The "does it feel on-beat" judgment is subjective and stays in this
rubric. To mechanically check a produced output, point `scripts/verify.sh` at the
emitted `.mp4`.
