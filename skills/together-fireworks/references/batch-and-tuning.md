# Batch, dedicated & fine-tuning — Together / Fireworks

Facts dated 2026-06-02. Re-check the provider batch docs before relying on limits.

## Together native Batch API (NOT the OpenAI Batch endpoint)

Together's OpenAI-compat layer does **not** expose `/v1/batches`. Pointing the OpenAI Batch client at Together fails. Use Together's **native** Batch API.

**Limits:** default **24h** completion window, up to **50,000 requests/file**, up to **50% off** serverless pricing, **separate rate-limit pool** from real-time.

**JSONL request file** — one request per line:

```jsonl
{"custom_id": "req-1", "body": {"model": "openai/gpt-oss-20b", "messages": [{"role": "user", "content": "Label as spam or ham: ..."}]}}
{"custom_id": "req-2", "body": {"model": "openai/gpt-oss-20b", "messages": [{"role": "user", "content": "Label as spam or ham: ..."}]}}
```

**Flow** (use the `together` SDK or REST):

```python
from together import Together

client = Together()  # reads TOGETHER_API_KEY from env

up = client.files.upload(file="requests.jsonl", purpose="batch-api")
job = client.batches.create_batch(file_id=up.id, endpoint="/v1/chat/completions")

# poll until terminal
status = client.batches.get_batch(job.id)   # PENDING -> IN_PROGRESS -> COMPLETED / FAILED

# on COMPLETED, download the output file id and parse one JSON result per line,
# matched back to requests by custom_id.
```

Each output line carries the `custom_id` so you can join results back to inputs. Handle `FAILED`/partial lines — a row erroring does not fail the whole job.

## Fireworks batch (a serving path, not a separate API)

Fireworks **Serverless 2.0** exposes Standard / Priority / **Batch** through the same API. Batch = **50%** of serverless price on input and output. You select the batch path per request/config rather than uploading a separate JSONL job. Priority (≈1.5×) works with both OpenAI- and Anthropic-compatible endpoints.

## When batch pays off

- No human waiting on the response (eval runs, synthetic-data generation, bulk classification/extraction, backfills).
- More than ~1k requests — the 50% cut clears any added orchestration overhead.
- You can tolerate the completion window (Together default 24h).

Do **not** batch a user-facing request — the latency window makes it unusable in real time.

## Dedicated deployments

Both providers offer reserved-GPU / dedicated endpoints billed by GPU-hour (not per token). It only beats serverless above a **high, sustained** QPS or when you need a **fixed latency SLA** or a model not on the serverless menu. Below that load, an idle dedicated GPU burns money a token endpoint never would. If you are leaning dedicated mostly to control infra, that is the self-host tradeoff — compare against renting raw GPUs (`../runpod/SKILL.md`, `../modal/SKILL.md`).

## Fine-tuning (Together)

Tiered per 1M training tokens (together.ai/pricing, 2026-06-02): up to 16B SFT **$0.48** / Full $1.20–$1.35; 17B–69B SFT **$1.50**; 70B–100B SFT **$2.90** / Full $7.25–$8.00 — the published size tiers **stop at 70B–100B; there is no 405B tier**. Beyond that the catalog prices by named specialized model, not size (DeepSeek-R1 SFT $10.00 / DPO $25.00; Llama 4 Maverick SFT $8.00 / DPO $20.00). Serve the result on a dedicated deployment. Re-check the pricing page — these tiers shift.

## Sources (accessed 2026-06-02)
- https://docs.together.ai/docs/inference/batch/overview · https://www.together.ai/blog/batch-api
- https://fireworks.ai/blog/serverless-2 · https://docs.fireworks.ai/serverless/pricing
