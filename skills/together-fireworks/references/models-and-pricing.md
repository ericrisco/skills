# Models & pricing — Together AI / Fireworks AI

All figures **per 1M tokens, USD, dated 2026-06-02**, taken from each **provider's own pricing/model pages** (not aggregators). Prices move and ids get retired; **re-check the primary page before quoting a customer**:
- Together pricing: https://www.together.ai/pricing
- Together serverless model catalog (authoritative id list): https://docs.together.ai/docs/serverless-models
- Fireworks serverless pricing: https://docs.fireworks.ai/serverless/pricing

Rule of thumb for grounding: a $/1M figure or a model id must trace to one of the pages above. If you cannot find a model on the provider's own catalog, treat the id as unverified and do not quote it.

## Together AI

Base URL `https://api.together.ai/v1`. Model id shape `<vendor>/<model>`. The ids and prices below are illustrative of the live catalog at this date; confirm the exact id string and rate on docs.together.ai/docs/serverless-models and together.ai/pricing before quoting — casing and suffixes (`-Turbo`, `-Lite`) are load-bearing.

| Model | Model id | Input $/1M | Output $/1M | Notes |
|---|---|---|---|---|
| GPT-OSS 20B | `openai/gpt-oss-20b` | 0.05 | 0.20 | cheapest; classify/extract |
| GPT-OSS 120B | `openai/gpt-oss-120b` | 0.15 | 0.60 | bigger open GPT-OSS |
| Llama 3 8B Instruct Lite | `meta-llama/Meta-Llama-3-8B-Instruct-Lite` | 0.10 | 0.10 | small & fast, 8K ctx |
| Llama 3.3 70B | `meta-llama/Llama-3.3-70B-Instruct-Turbo` | 1.04 | 1.04 | general chat |
| Qwen 3.6 Plus | `Qwen/Qwen3.6-Plus` | 0.50 | 3.00 | high output cost — watch it; ~1M ctx |
| DeepSeek V4-Pro | `deepseek-ai/DeepSeek-V4-Pro` | 2.10 | 4.40 | top reasoning; $0.20 cached input; 512K serverless ctx (1M on dedicated) |

Not on Together serverless as of this date (do **not** quote these ids against Together): `deepseek-ai/DeepSeek-V3.1`, `meta-llama/Llama-4-Maverick-*`. They appear on aggregators but are absent from the provider's own serverless catalog — confirm at docs.together.ai/docs/serverless-models.

**Embeddings:** `intfloat/multilingual-e5-large-instruct` — $0.02 / 1M input tokens (together.ai/pricing). Confirm the exact id/price on the pricing page before quoting.

**Fine-tuning** (together.ai/pricing, per 1M training tokens): up to 16B — SFT $0.48 / DPO $0.54 / Full $1.20–$1.35; 17B–69B — SFT $1.50 / DPO $1.65 / Full $3.75–$4.12; 70B–100B — SFT $2.90 / DPO $3.20 / Full $7.25–$8.00. The standard size tiers stop at **70B–100B — there is no published 405B tier** as of this date; a >100B fine-tune runs as one of the specialized models, not a size tier. Specialized: DeepSeek-R1 SFT $10.00 / DPO $25.00 (min $20.00); Llama 4 Maverick SFT $8.00 / DPO $20.00 (min $16.00). Serve the result on a dedicated deployment.

## Fireworks AI

Base URL `https://api.fireworks.ai/inference/v1`. Model id shape `accounts/fireworks/models/<name>`.

**Size-tiered base pricing** (docs.fireworks.ai/serverless/pricing; applies in and out, for any model without a named price):

| Model size | $/1M (input and output) |
|---|---|
| < 4B | 0.10 |
| 4B – 16B | 0.20 |
| > 16B (dense) | 0.90 |
| MoE ≤ 56B (e.g. Mixtral 8x7B) | 0.50 |
| MoE 56.1B – 176B (e.g. DBRX, Mixtral 8x22B) | 1.20 |

These are the provider's own published tiers, so they hold up as a sizing estimate in a quote. They are not a per-model promise — the named-model prices below override the tier where a model is explicitly listed.

**Named models** (docs.fireworks.ai/serverless/pricing — input / cached input / output, Standard tier):

| Model | Model id | Input | Cached | Output |
|---|---|---|---|---|
| GPT-OSS 20B | `accounts/fireworks/models/gpt-oss-20b` | 0.07 | 0.035 | 0.30 |
| GPT-OSS 120B | `accounts/fireworks/models/gpt-oss-120b` | 0.15 | 0.015 | 0.60 |
| Llama 3.1 8B Instruct | `accounts/fireworks/models/llama-v3p1-8b-instruct` | 4B–16B tier (0.20) | — | 4B–16B tier (0.20) |
| Kimi K2.6 | `accounts/fireworks/models/kimi-k2p6` | 0.95 | 0.16 | 4.00 |
| DeepSeek V4-Pro | `accounts/fireworks/models/deepseek-v4-pro` | 1.74 | 0.145 | 3.48 |
| DeepSeek V4 Flash | `accounts/fireworks/models/deepseek-v4-flash` | 0.14 | 0.028 | 0.28 |

Note `gpt-oss-20b` on Fireworks is $0.07/$0.30, slightly above Together's $0.05/$0.20 for the same weights — the kind of arbitrage the env-driven config in SKILL.md lets you exploit.

**Embeddings:** input only — up to 150M params $0.008, 150M–350M $0.016, Qwen3 8B $0.10 / 1M input (docs.fireworks.ai/serverless/pricing).

**Multipliers** (docs.fireworks.ai/serverless/pricing):
- **Cached input** defaults to **50%** of input price on text/vision models (named models above publish a lower cached figure — use the published one when available).
- **Priority serving** is opt-in and runs above Standard — the page lists priority per model (e.g. Kimi K2.6 priority input $1.50 vs $0.95 standard, ≈1.5–1.6×). Do not budget at priority rates unless you enable it.
- **Batch = 50%** of serverless on both input and output.
- **Serverless 2.0** routes Standard / Priority / Batch through one API; Priority works with OpenAI- and Anthropic-compatible endpoints.

## Aggregators (use only for cross-provider sizing, never for a per-model quote)

Third-party trackers (Artificial Analysis, aipricing.guru, lmmarketcap, costbench) are useful for a *blended* sense of where the catalog sits but routinely lag and mis-attribute per-model rates — e.g. they still list DeepSeek-V3.1 as a live Together serverless model. For any dollar figure you put in front of a customer, cite the provider page above, not an aggregator.

## Sources (accessed 2026-06-02)
- https://docs.together.ai/docs/serverless-models
- https://www.together.ai/pricing
- https://www.together.ai/blog/deepseek-v4-pro-now-available-on-together-ai
- https://docs.fireworks.ai/serverless/pricing
- https://docs.together.ai/docs/openai-api-compatibility
