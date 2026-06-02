# Caching layers: prefix vs semantic

Two caches, different mechanisms, different risk profiles. Do not conflate them.

## Layer 1 — prefix / prompt cache (provider-native)

Matches an **exact prefix** of your prompt at the provider and reuses the cached compute. Transparent and safe: identical input → identical cached state. Free upside, no correctness risk.

**OpenAI** — automatic, on by default, ~50% off cached input tokens. No write penalty, no storage fee. First request full price; subsequent prefix hits half price.

**Anthropic** — explicit: you mark cache breakpoints (`cache_control`). Deeper discount:

| Operation | Multiplier vs base input |
| --- | --- |
| Cache read | 0.1× (~90% off) |
| 5-minute cache write | 1.25× |
| 1-hour cache write | 2× |

On long, stable prefixes this is ~90% cost and ~85% latency reduction.

### Order prompts for maximum prefix hits

Put content **most stable first, most variable last**:

1. System prompt / role instructions (never changes)
2. Fixed reference context, tool definitions, few-shot exemplars (changes rarely)
3. Retrieved/dynamic context (changes per request)
4. The user's actual turn (changes every time)

If you put the user's variable input first, the prefix never matches and you cache nothing. For Anthropic, set the breakpoint at the end of the stable block (1–2).

## Layer 2 — semantic cache (your gateway)

Embeds the incoming query, looks up an **embedding-similar prior query**, and returns *that prior response*. Lives in your gateway: GPTCache, a Redis vector store, Bifrost, etc.

The danger: it returns a **different** prior answer for a **similar** query. Quality is dominated by the embedding model — a weak embedder yields **false cache hits**, i.e. a confidently wrong answer to a question that only looked similar (GPTCache is documented returning incorrect saved responses for similar prompts; cf. Microsoft GenCache, NeurIPS 2025).

### Enable it only when all hold

- Queries are paraphrase-heavy (FAQ, support, repeated intents).
- An approximate / near-match answer is acceptable for the use case.
- It is **not** a correctness-critical path (no legal, medical, financial, or contract logic).

### Tuning

- **Embedding model:** use a strong, current embedder. The cheap default is where false hits come from.
- **Similarity threshold:** start strict (e.g. cosine ≥ 0.95) and loosen only with eval data on real query pairs. Too loose = false hits; too strict = no hits.
- **TTL:** short for time-sensitive answers (prices, status), longer for stable knowledge. Stale-but-confident is its own failure mode.
- **Scope keys:** namespace the cache by tenant/locale/model so you never serve tenant A's answer to tenant B.

## Multi-tier order

Check caches cheapest-and-safest first, fall through to inference:

```text
semantic cache  ->  prefix cache  ->  live inference
   (gateway)        (provider)         (full price)
```

Only reach inference on a miss. But if correctness matters more than cost, drop the semantic tier entirely and rely on prefix cache + inference — prefix cache never changes the answer.
