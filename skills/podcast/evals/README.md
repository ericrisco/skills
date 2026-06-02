# Evals — podcast

These cases are routing + capability checks for a human or an LLM judge; there is no
automated test runner beyond `scripts/verify.sh` (which lints emitted artifacts — a
`chapters.json`, an RSS feed/`<item>`, or a `transcript.vtt` — not these prompts). To
run them: read `cases.yaml` and confirm the skill's `description` would fire on every
`should_trigger` prompt (including the jargon-only "chapters.json + double-ender + -16
master" case that never says "podcast" and the Catalan "masteritzar l'àudio" phrasing),
that each `should_not_trigger` prompt routes to the named sibling instead
(`video-shorts`, `social-publisher`, `brand-voice`, `newsletter`, `content-engine`), and
that an end-to-end answer to the `capability` scenario satisfies every line of its
`must_include` rubric — the -16 LUFS / -1 dBTP master-once rule with Spotify's -14
normalization, 48 kHz WAV master + MP3 enclosure, a monotonic `chapters.json` wired via
`podcast:chapters`, a `podcast:transcript` carrying a `type`, an `<item>` with the
required enclosure/guid/duration/artwork fields, blog-shaped timestamped show notes, and
the one-episode-first + 72h-Apple submission note. To check an actual emitted artifact,
point `scripts/verify.sh` at the file or directory it produced.
