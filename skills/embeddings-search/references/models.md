# Embedding model matrix (mid-2026)

Read this to pick a model, size its dimensions, and call it with the right `input_type`. Facts
dated 2026-06-02; re-check provider docs before committing a corpus, since model names and
prices move.

## Matrix

| Model | Provider | Dims | Matryoshka truncation | Max input | ~Price /1M tok | Query/doc convention |
|---|---|---|---|---|---|---|
| `text-embedding-3-small` | OpenAI | 1536 | yes (`dimensions` param) | 8191 tok | ~$0.02 | symmetric (no input_type) |
| `text-embedding-3-large` | OpenAI | 3072 | yes (`dimensions` param) | 8191 tok | ~$0.13 | symmetric |
| `embed-v4` | Cohere | up to 1536 | yes | long | API-priced | `input_type=search_query` / `search_document` |
| `voyage-3-large` | Voyage | model-set | partial | long | API-priced | `input_type="query"` / `"document"` |
| Gemini Embedding | Google | truncatable | yes | long | API-priced | task type (retrieval query vs document) |
| `BGE-M3` | open (self-host) | 1024 | no | 8192 tok | infra-only | prefix `query:` / `passage:` |
| `e5-large` family | open (self-host) | 1024 | no | 512 tok | infra-only | prefix `query:` / `passage:` |

MTEB English-retrieval anchors at the time of writing: Gemini ~68.3, Cohere `embed-v4` ~65.2,
OpenAI `text-embedding-3-large` ~64.6, `BGE-M3` ~63.0. Voyage models lead retrieval-specific
task slices.

## How to read MTEB without over-trusting it

- MTEB is an **average across many tasks and domains**. A model two points higher on the
  overall board can be worse on legal Catalan, code, or your support tickets.
- The board is **English-weighted**. For multilingual corpora, weight the multilingual slice
  and confirm your languages are actually covered.
- Leaderboards get **gamed and contaminated** over time. Treat the top 3–4 as a shortlist, then
  run your own golden-set eval (see `evaluation.md`) — that number is the only one that decides.

## input_type asymmetry — the silent recall killer

Asymmetric models were trained so the query vector and the passage vector live in compatible
but differently-prompted spaces. Embedding both sides the same way produces no error and
quietly worse recall.

```python
# Cohere
co.embed(texts=[q], model="embed-v4", input_type="search_query")
co.embed(texts=[d], model="embed-v4", input_type="search_document")

# Voyage
vo.embed([q], model="voyage-3-large", input_type="query")
vo.embed([d], model="voyage-3-large", input_type="document")

# e5 / BGE — textual prefix
embed("query: " + q)
embed("passage: " + d)

# OpenAI 3-* — symmetric, no input_type needed
client.embeddings.create(model="text-embedding-3-small", input=[q])
```

## Matryoshka: shrink without re-embedding

Matryoshka-trained models pack the most important signal in the leading dimensions, so you can
slice a vector and keep most of the quality.

```python
# Ask for fewer dims at embed time…
client.embeddings.create(model="text-embedding-3-large", input=[d], dimensions=1024)
# …or truncate + re-normalise an already-stored full vector:
import numpy as np
def truncate(vec, n):
    v = np.asarray(vec[:n], dtype="float32")
    return (v / np.linalg.norm(v)).tolist()
```

Storage math: a float32 dim costs 4 bytes. 3072 dims = 12 KB/vector; 1024 dims = 4 KB. At 10M
docs that is the difference between ~120 GB and ~40 GB. Cut dims first, measure recall on the
golden set, and only keep the cut if recall holds. Do **not** re-embed the corpus from scratch
just to change dimension count when the model is Matryoshka-trained.
