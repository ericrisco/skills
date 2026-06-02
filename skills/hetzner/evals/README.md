# Eval harness — hetzner

`cases.yaml` is the fixture; this file is the procedure. The evals are run by an
**agent harness** (an agent with the full skill catalog loadable on demand), not
a pure script. Two things are measured: **triggering** (does the skill fire on
Hetzner provision/harden/plan/firewall prompts and stay quiet for sibling
providers and app-deploy) and **capability** (does loading it produce a genuinely
reproducible, hardened flow rather than a console walkthrough).

## Triggering

For each `should_trigger` / `should_not_trigger` item: start a fresh session with
the full catalog, feed the `prompt` verbatim, record which skill the agent
invokes, and run 3–5 trials (the choice is stochastic). Pass when **hetzner** is
chosen for the majority of `should_trigger` trials and is *not* chosen for
`should_not_trigger` (ideally the agent routes to the listed `route_to` sibling).
Target >= 90% trigger accuracy across prompts.

## Capability

For the `capability` scenario run two arms — **WITH** only hetzner loaded vs
**WITHOUT** any skill — three times each. Grade each response against
`must_include` (one point per item that is genuinely present and correct, not
hand-waved). Pass when WITH covers >= 80% of the rubric and beats WITHOUT by a
clear margin (target >= 25 points). A skill that doesn't move the needle fails
even if the baseline answer was decent.

## Honesty notes

These are stochastic, LLM-graded evals — re-run on edits and treat small deltas
as noise. `route_to` targets (coolify, digitalocean, docker, domains-dns, fly-io)
assume those siblings exist in the catalog; a missing sibling can cause a
near-miss mis-route that isn't a hetzner fault — note it, don't count it against
the skill. A static lint of the emitted cloud-init artifact is available
separately via `scripts/verify.sh`.
