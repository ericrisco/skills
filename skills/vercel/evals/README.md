# Eval harness — `vercel`

These cases are graded by an agent/human judge, not a shell script. No live Vercel account, login,
or network is needed: triggering checks routing, and the capability check grades a generated
`vercel.json` against a `must_include` rubric (you can additionally pipe that file through
`scripts/verify.sh` for a mechanical sanity pass).

## How to run

- **Triggering.** Load the full skill catalog so routing is realistic (vercel alongside deployment,
  nextjs, domains-dns, cloudflare, …). For each `should_trigger` prompt, run 3-5 fresh sessions and
  confirm the `vercel` skill fires. For each `should_not_trigger`, confirm `vercel` stays silent and
  the agent routes toward the named `route_to` sibling. A near-miss leaking into `vercel` is a worse
  failure than a missed trigger — investigate any leak. Pass bar: ~90% trigger accuracy.
- **Capability.** Run the scenario twice — once with `skills/vercel/SKILL.md` (and its `references/`)
  loaded, once without — and score each output against the `must_include` list (one point per item).
  Pass when the with-skill run covers >=80% AND clearly beats the without-skill run; if both score
  the same, the skill is adding no value on that scenario. Optionally run the produced `vercel.json`
  through `bash scripts/verify.sh <file>` to confirm it mechanically passes (no `builds`+`functions`,
  no in-file `memory`, well-formed crons).

Record per-prompt fire rates, routing targets on near-misses, and with/without capability scores.
Note borderline cases honestly rather than rounding up to a green check.
