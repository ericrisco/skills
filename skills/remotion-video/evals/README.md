# Evals — remotion-video

`cases.yaml` is a routing-and-capability spec, not an automated test suite. To run it,
load a model with the skill catalog available and replay each prompt:

- **should_trigger** — each prompt must select `remotion-video`. These cover the core
  render, the captions pipeline, the upstream silence pass, transitions, CI/headless
  render, plus Spanish and Catalan phrasings and the non-obvious "remove silences
  before render" cue.
- **should_not_trigger** — each prompt must route to the named sibling instead
  (`video-shorts`, `podcast`, `youtube-thumbnails`, `youtube-packaging`,
  `course-storytelling`). They probe the frames-vs-words boundary.
- **capability** — load the skill and have it produce the scenario; grade the output
  against the `must_include` rubric line by line. A pass means every rubric item is
  present (pinned fps/dimensions, frames=seconds*fps math, a TransitionSeries with a
  timing, the toCaptions → createTikTokStyleCaptions pipeline, the silence pass
  located before Remotion, the b-roll overlay, an explicit render command, the
  determinism note, and a region test before the full render).

There is no harness script here; judge by reading the model's selection and output
against the YAML. The runnable artifact check lives in `../scripts/verify.sh`, which
validates an emitted Remotion project (compositions list + a region render that
`ffprobe` confirms, with a static fallback when Node/ffmpeg are absent).
