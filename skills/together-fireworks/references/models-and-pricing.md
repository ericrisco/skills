# Models & pricing — Together AI / Fireworks AI

Every figure here is **per 1M tokens, USD**, and was read directly off the provider's own pricing/model page on **2026-06-02**. No number on this page is sourced to a third-party tracker — aggregators are addressed (and excluded) in the last section. Prices move and ids get retired; **re-read the primary page before quoting a customer**:
- Together pricing (authoritative $/1M): https://www.together.ai/pricing — read 2026-06-02
- Together serverless model catalog (authoritative id list): https://docs.together.ai/docs/serverless-models — read 2026-06-02
- Fireworks serverless pricing (authoritative $/1M + id): https://docs.fireworks.ai/serverless/pricing — read 2026-06-02

Rule of thumb for grounding: every $/1M figure and every model id below traces to one of the three pages above, as read on the date stated. If you cannot find a model on the provider's own catalog, treat the id as unverified and do not quote it — a tracker listing is not a confirmation.

## Together AI

Base URL `https://api.together.ai/v1`. Model id shape `<vendor>/<model>`. Confirm the exact id string and rate on docs.together.ai/docs/serverless-models and together.ai/pricing before quoting — casing and suffixes (`-Turbo`, `-Lite`) are load-bearing.

Each row's `V` column is the verifiability of the **id + price** as read off together.ai/pricing on 2026-06-02:
- **stable** — long-lived id, low price churn; safe to quote after a glance at the page.
- **projected** — current-generation flagship whose id/price moves fast (and whose id you may not recognize from training data); the number is the page's figure on this date, but treat it as a moving target and re-read the page before any quote.

| Model | Model id | Input $/1M | Output $/1M | V | Notes |
|---|---|---|---|---|---|
| GPT-OSS 20B | `openai/gpt-oss-20b` | 0.05 | 0.20 | stable | cheapest; classify/extract |
| GPT-OSS 120B | `openai/gpt-oss-120b` | 0.15 | 0.60 | stable | bigger open GPT-OSS |
| Llama 3 8B Instruct Lite | `meta-llama/Meta-Llama-3-8B-Instruct-Lite` | 0.14 | 0.14 | stable | small & fast, 8K ctx |
| Llama 3.3 70B | `meta-llama/Llama-3.3-70B-Instruct-Turbo` | 1.04 | 1.04 | stable | general chat |
| Qwen 3.6 Plus | `Qwen/Qwen3.6-Plus` | 0.50 | 3.00 | projected | high output cost — watch it; ~1M ctx |
| DeepSeek V4-Pro | `deepseek-ai/DeepSeek-V4-Pro` | 2.10 | 4.40 | projected | top reasoning; $0.20 cached input; 512K serverless ctx (1M on dedicated) |

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

**Named models** (docs.fireworks.ai/serverless/pricing — input / cached input / output, Standard tier). `V` = verifiability of id+price as read on 2026-06-02 (same legend as the Together table: **stable** = long-lived; **projected** = fast-moving current flagship, re-read the page before quoting):

| Model | Model id | Input | Cached | Output | V |
|---|---|---|---|---|---|
| GPT-OSS 20B | `accounts/fireworks/models/gpt-oss-20b` | 0.07 | 0.035 | 0.30 | stable |
| GPT-OSS 120B | `accounts/fireworks/models/gpt-oss-120b` | 0.15 | 0.015 | 0.60 | stable |
| Llama 3.1 8B Instruct | `accounts/fireworks/models/llama-v3p1-8b-instruct` | 4B–16B tier (0.20) | — | 4B–16B tier (0.20) | stable |
| Kimi K2.6 | `accounts/fireworks/models/kimi-k2p6` | 0.95 | 0.16 | 4.00 | projected |
| DeepSeek V4-Pro | `accounts/fireworks/models/deepseek-v4-pro` | 1.74 | 0.145 | 3.48 | projected |
| DeepSeek V4 Flash | `accounts/fireworks/models/deepseek-v4-flash` | 0.14 | 0.028 | 0.28 | projected |

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
