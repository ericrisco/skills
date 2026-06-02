# Evals for the `huggingface` skill

These are routing and capability checks read from `cases.yaml` by the skill eval harness — no
network, no HF token, no model calls. `should_trigger` prompts must select this skill (they cover
the router path, embeddings, dedicated Endpoints, Hub uploads, the non-obvious hf-inference-is-
CPU-only case, and a Spanish phrasing). `should_not_trigger` prompts must route to the named real
sibling instead (ollama, runpod, replicate-images, rag, together-fireworks). The single
`capability` case is a rubric: a good answer to the Llama-3.1-8B scenario must mention every item
in `must_include` (router/InferenceClient, a partner provider, env-based HF_TOKEN, credit/PAYG
cost, and scale-to-zero Endpoints as the graduation path). Run them with whatever harness loads
`evals/cases.yaml`; there is nothing to install or connect.
