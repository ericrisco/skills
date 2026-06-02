# tuning.md — recall, parameters, quantization, filter pitfalls

## HNSW vs IVFFlat

| | HNSW | IVFFlat |
|---|---|---|
| Recall | High, smooth with `ef_search` | Lower; depends on `lists`/`probes` |
| Build cost | Higher (graph) | Lower / faster |
| Memory | Higher | Lower |
| Build params | `m` (default 16), `ef_construction` (default 64) | `lists` (≈ rows/1000, capped) |
| Query param | `ef_search` (default 40) | `probes` (more = better recall, slower) |
| Selective filter | Use with iterative scan (pgvector 0.8) | Drops rows on selective filters — avoid |
| Default choice | **Yes** | Only when build speed > recall |

Invariant: keep `ef_construction >= 2*m`. A too-low `ef_construction` permanently degrades the
graph; you cannot tune it back at query time — only a rebuild fixes it.

## Recall-measurement recipe

Do this on a sample before shipping. "Search is bad" is unactionable without a recall number.

1. Pick ~200–500 representative query vectors.
2. **Exact baseline**: compute true top-k by brute force (full scan / no index). In pgvector,
   query with the index disabled to get ground truth.
3. **Index result**: same queries through the ANN index.
4. `recall@k = mean(|index_topk ∩ exact_topk| / k)`.
5. Raise the search knob (below) until recall hits target (often ≥0.95), then stop — extra `ef`
   buys latency, not quality.

| Engine | Search-time recall knob | Default |
|---|---|---|
| pgvector | `hnsw.ef_search` | 40 |
| Qdrant | `hnsw_ef` (`SearchParams`) | per-collection |
| Weaviate | `ef` (vectorIndexConfig; `-1` = dynamic) | dynamic |
| Pinecone | managed (no manual knob) | — |

## Quantization tradeoffs

| Method | Compression | Recall risk | Notes |
|---|---|---|---|
| Scalar (int8) | ~4x | Low | Safe default RAM cut |
| Product (PQ) | 8–64x | Medium–high | Needs tuning; recall-test mandatory |
| Binary | ~32x, ~40x faster (SIMD popcount) | High on low dims | Only ≥1024 dims; rescore with full precision |
| pgvector `halfvec` | ~2x | Negligible | 16-bit float; required for >2000 dims |

Order of reach: `halfvec`/scalar first (near-free) → product for huge corpora → binary only on
high-dim vectors after a measured recall test, with optional full-precision rescoring.

## Per-engine filtered-search pitfalls

- **pgvector**: a selective `WHERE` on a pre-0.8 setup (or without `hnsw.iterative_scan`) returns
  fewer than `LIMIT` rows because the index returns `ef_search` candidates and then the filter
  removes most. Set `hnsw.iterative_scan='relaxed_order'` and index the filter column.
- **Qdrant**: filtering only works well when the payload field has a payload index; otherwise it
  degrades to a scan. Filtering happens in-graph during traversal — keep the index.
- **Weaviate**: combine `filters=` with `hybrid(...)`; an unfiltered prefetch followed by an
  app-side filter is the post-filter trap.
- **Pinecone**: metadata filtering is in the retrieval path, but very high-cardinality metadata
  still costs; keep filterable fields lean and use namespaces for tenant isolation.

Cross-cutting rule: **filter inside the search, index the filter field, and verify you still get
`k` rows on your most selective real filter.**
