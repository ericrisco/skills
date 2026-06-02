# electron evals

`cases.yaml` is the source of truth. There is no fully automated runner: triggering and
capability are graded **semantically** by an agent harness (an agent with the catalog's sibling
names available for routing) plus a human or judge-agent spot-check, because "did it route to
tauri" and "did it set the secure baseline" are intent judgments, not string matches. For
triggering, feed each `should_trigger` / `should_not_trigger` prompt to a fresh session 3–5
times and record whether the electron skill fires (and, for near-misses, whether it hands off to
the named `route_to` sibling). For capability, answer each scenario once with the skill and once
without, then score against its `must_include` rubric — the skill passes only if the with-skill
answer covers the rubric and clearly beats the baseline. The one mechanical check is
`scripts/verify.sh`: run it against any code the capability case produces to confirm the
hardening is real (it exits non-zero on any insecure pattern).
