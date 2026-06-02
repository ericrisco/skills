# Retrieval evaluation

Turn "search is bad" into a number you can move. Everything here runs offline against a labeled
query set — no LLM judge, no network.

## 1. Build the golden query set

The golden set is the asset. Aim for **30–50+** entries; more is better. Each entry is a real
question plus the doc ids that genuinely answer it.

```json
[
  {"query": "how long do refunds take", "relevant": ["doc_412", "doc_77"]},
  {"query": "SKU AB-9931 specs",        "relevant": ["doc_1290"]},
  {"query": "puc cancel·lar la subscripció?", "relevant": ["doc_88", "doc_640"]}
]
```

Sourcing tips:
- Pull real queries from logs; don't invent only easy ones — include the exact-match and the
  multilingual cases that break dense-only retrieval.
- Label relevance against the **chunk/doc id your retriever returns**, not the source PDF.
- Keep it in version control. A change to the set invalidates old numbers.

## 2. Metrics — what each one catches

- **recall@k**: fraction of an entry's relevant docs found in the top-k. Catches *the right
  chunk never came back* (a recall problem no reranker can fix).
- **nDCG@k**: discounted gain that rewards relevant docs ranked higher (uses `log2(rank+1)`
  discount). Catches *right docs, wrong order*.
- **MRR**: mean of `1/rank` of the first relevant doc. Catches *the one answer is buried deep*.

## 3. Runnable skeleton

```python
import math

def recall_at_k(retrieved, relevant, k):
    top = set(retrieved[:k])
    rel = set(relevant)
    return len(top & rel) / len(rel) if rel else 0.0

def ndcg_at_k(retrieved, relevant, k):
    rel = set(relevant)
    dcg = sum(1.0 / math.log2(i + 2) for i, d in enumerate(retrieved[:k]) if d in rel)
    ideal = sum(1.0 / math.log2(i + 2) for i in range(min(len(rel), k)))
    return dcg / ideal if ideal else 0.0

def mrr(retrieved, relevant):
    rel = set(relevant)
    for i, d in enumerate(retrieved):
        if d in rel:
            return 1.0 / (i + 1)
    return 0.0

def evaluate(golden, search_fn, k=10):
    rs, ns, ms = [], [], []
    for row in golden:
        got = search_fn(row["query"])          # -> ordered list of doc ids
        rs.append(recall_at_k(got, row["relevant"], k))
        ns.append(ndcg_at_k(got, row["relevant"], k))
        ms.append(mrr(got, row["relevant"]))
    n = len(golden)
    return {
        f"recall@{k}": sum(rs) / n,
        f"ndcg@{k}":   sum(ns) / n,
        "mrr":         sum(ms) / n,
    }
```

## 4. A/B one change at a time

```text
baseline   = evaluate(golden, search_v0)        # record it
candidate  = evaluate(golden, search_v1)         # changed ONE thing
# compare on the SAME golden set; keep the change only if the metric you care about went up
```

Change exactly one variable per run: the embedding model, OR the chunk size/strategy, OR the
fusion (`k` in RRF, fan-in), OR the reranker. Stacking changes means you can't attribute the
delta — and a regression hides inside an improvement.

Typical decision pattern:
- recall@k low → upstream: model choice, chunking, add sparse/hybrid. A reranker won't help.
- recall@k high but nDCG/MRR low → ordering: add or tune the reranker.
- exact-term queries failing while paraphrases pass → add BM25/sparse and re-measure.
