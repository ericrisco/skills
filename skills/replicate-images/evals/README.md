# Evals — replicate-images

`cases.yaml` is a trigger/routing and capability rubric, not an executable test of the Replicate API.
`should_trigger` lists prompts (including a bug-framed one, a text-rendering one, a Spanish one, and a
Catalan one) that must route here, so the non-English routing claimed in the description is actually tested; `should_not_trigger` lists near-miss prompts that must route to a named sibling
(`replicate`, `prompt-engineering`, `fal`, `ai-media`) so the boundary against the platform skill and
other providers stays sharp. The `capability` case is a scored rubric: give the scenario to an agent
loaded with this skill and check the response covers every `must_include` item. Grade with whatever
harness scores the skills repo — no Replicate token, GPU, or network call is needed. To exercise the
checkable artifact, run `scripts/verify.sh` against a directory of generated image-calling code in a
user's project (it scans `.js`/`.mjs`/`.ts`/`.py` source files, not Markdown, so it finds nothing
inside this skill's own fences); it statically lints slugs, aspect ratios, resolutions, and
image-input shapes without hitting the API.
