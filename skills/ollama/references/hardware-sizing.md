# Hardware sizing for local Ollama

Total memory = **weights + KV cache + overhead**. People size for weights and forget the KV cache,
then OOM at long context. Budget all three.

## The quant ladder

| Quant | Bytes/param | Size vs fp16 | Quality | Use it for |
| --- | --- | --- | --- | --- |
| fp16 | 2.0 | 100% | reference | when VRAM is abundant or you need max fidelity |
| Q8_0 | ~1.0 | ~50% | near-lossless | quality-sensitive work that still fits |
| Q6_K | ~0.8 | ~40% | very close to Q8 | a middle step when Q8 is just too big |
| **Q4_K_M** | ~0.5 | ~25% | ~3–5% loss; the default | everyday local inference |
| Q3_K_M | ~0.4 | ~20% | noticeable degradation | last resort to fit |
| Q2_K | ~0.3 | ~15% | often unusable | rarely worth it — change model size instead |

Rule: drop **model size** before dropping below Q4. A 14B at Q4_K_M beats a 70B at Q2_K on both quality
and fit.

## Weights formula

```text
weights_GB ≈ params(B) × bytes_per_param × 1.2
# the ×1.2 absorbs runtime/format overhead; KV cache is separate (below).
```

| Model | Q4_K_M (~0.5 B/p) | Q8_0 (~1.0) | fp16 (2.0) |
| --- | --- | --- | --- |
| 7–8B | ~5–6 GB | ~9 GB | ~16 GB |
| 13–14B | ~9–10 GB | ~16 GB | ~30 GB |
| 32B | ~20 GB | ~36 GB | ~70 GB |
| 70B | ~40–48 GB | ~75 GB | ~140 GB |

## KV-cache math

KV cache holds keys+values for every token in context, per layer. It grows ~linearly with context
length and is allocated on top of the weights:

```text
kv_GB ≈ 2 (K+V) × layers × ctx_tokens × kv_dim × bytes_per_elem / 1e9
```

You don't need the exact number — you need the shape: **doubling `num_ctx` roughly doubles the cache**,
and on big models at long context the cache can rival or exceed the weights. Illustrative, large model:

| Context (`num_ctx`) | KV cache (order of magnitude) |
| --- | --- |
| 4K | small (≪ weights) |
| 32K | several GB |
| 128K | tens of GB on a 70B — often more than the headroom you assumed |

Shrink it: set `OLLAMA_KV_CACHE_TYPE=q8_0` (≈ half) or `q4_0` (≈ quarter) — a small accuracy cost for a
big memory win. Or just cap `num_ctx` to what the task needs.

## Apple Silicon (unified memory)

On a Mac, weights + KV cache draw from the **single unified memory pool** shared with the OS and apps.
Budget against total RAM minus what the system needs (leave several GB). A 64 GB Mac can comfortably run
a 32B Q4_K_M; a 70B Q4_K_M is feasible but leaves little headroom for long context.

**MLX backend gate.** Ollama can run an MLX backend on Apple Silicon (shipped in Ollama 0.19, per
[ollama.com/blog/mlx](https://ollama.com/blog/mlx), 2026-03-30), but it requires a Mac with **more than
32 GB of unified memory** — below that gate it stays on the default llama.cpp/GGUF engine. So MLX is not
a universal Apple-Silicon win: a 16 GB or 32 GB Mac will not use it, and your sizing math is the same
GGUF math as everywhere else. The 64 GB row above is where MLX actually kicks in.

## Env knobs to fit tight boxes

| Variable | Effect |
| --- | --- |
| `OLLAMA_KV_CACHE_TYPE` | `q8_0` / `q4_0` quantize the KV cache → less VRAM at long context |
| `OLLAMA_FLASH_ATTENTION` | enable flash attention → lower memory + faster on supported GPUs |
| `OLLAMA_NUM_PARALLEL` | concurrent requests per model; more = more KV cache allocated |
| `OLLAMA_MAX_LOADED_MODELS` | how many models stay resident at once |
| `OLLAMA_KEEP_ALIVE` | default unload timer (overrides the 5m default) |
| `OLLAMA_HOST` | bind address/port |
| `OLLAMA_MODELS` | where models are stored on disk |

## Decision: fit, or leave the box

1. Compute `weights_GB` for the model+quant you want.
2. Add a KV-cache budget for your target `num_ctx` (and `OLLAMA_NUM_PARALLEL`).
3. Add ~1–2 GB OS/overhead.
4. If the total exceeds your VRAM/unified memory: shrink `num_ctx`, quantize the KV cache, or step the
   model down one size — **not below Q4**.
5. If it still doesn't fit at the quality you need: it's a remote-GPU job → `runpod` (rent a GPU),
   `modal` (serverless + autoscale), or a hosted endpoint (`replicate`, `together-fireworks`, `fal`).
