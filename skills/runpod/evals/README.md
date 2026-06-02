# Evals — runpod

These cases are a manual sanity check on routing and coverage, not an automated harness.
To run them, read `cases.yaml` and confirm three things by hand: a fresh agent fires this
skill on every `should_trigger` prompt (including the cost-symptom and cold-start ones that
never say "serverless"); it defers to the named `route_to` sibling on each
`should_not_trigger` prompt instead of grabbing the work; and given the `capability`
scenario it produces an answer hitting every item in the `must_include` rubric (flex over a
24/7 Pod with reasoning, a right-sized GPU instead of H100, bounded Max Workers, explicit
idle/execution timeouts, FlashBoot, a `runpod.serverless.start` handler or worker-vllm, env
API key, and a local test step). No network or RunPod account is involved.
