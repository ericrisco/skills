# Evals — youtube-ideation

Read or run `cases.yaml` manually, or via the catalog eval harness. The `should_trigger` /
`should_not_trigger` prompts confirm the description fires on real "what to make next / did
it work" asks (including the non-obvious learning-loop ones and the Spanish phrasing) and
routes near-misses to the correct YouTube sibling — packaging for the title/thumbnail words,
thumbnails for the image, strategy for durable positioning, youtube-api for raw data,
video-shorts for the script. The `capability` case is graded by inspecting a generated idea
ledger + hypothesis/outcome log against its `must_include` rubric: it must compute an outlier
baseline, ground ideas in named 3x+ outliers (not a blind brainstorm), score all 7
dimensions to a /35 with the right verdict band, attach a dated hypothesis with a predicted
multiple and a judge-by metric to every promoted idea, and define the append-only outcome
log. `scripts/verify.sh <ledger.md>` is the static lint that backs the structural half of
that rubric; it is read-only and skips cleanly on an empty target.
