# engines.md — per-engine recipes (current APIs)

Concrete create-collection / create-index + a filtered hybrid query for each of the four engines.
Adjust dims and metric to your model; cosine shown throughout (the common case).

## pgvector (Postgres extension, 0.8.x)

HNSW since 0.5.0; iterative scan, `halfvec`, and `binary_quantize` since 0.8.0.

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE docs (
  id        bigserial PRIMARY KEY,
  tenant_id text NOT NULL,
  body      text,
  embedding vector(1536)          -- text-embedding-3-small; use halfvec(3072) for -3-large
);

-- Filter field gets its own index so the planner can use it.
CREATE INDEX docs_tenant_idx ON docs (tenant_id);

-- HNSW, cosine ops to match the model. ef_construction >= 2*m.
CREATE INDEX docs_embedding_idx
  ON docs USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);
```

`halfvec` to halve storage at near-identical recall (and the only path above 2000 dims):

```sql
ALTER TABLE docs ADD COLUMN embedding_h halfvec(1536);
CREATE INDEX ON docs USING hnsw (embedding_h halfvec_cosine_ops);
```

Filtered query with iterative scan so a selective `WHERE` does not return fewer than `LIMIT` rows:

```sql
SET hnsw.iterative_scan = 'relaxed_order';   -- 'strict_order' if exact ordering required
SET hnsw.ef_search = 100;                     -- raise until recall@k hits target
SELECT id, body
  FROM docs
 WHERE tenant_id = 'acme'
 ORDER BY embedding <=> $1
 LIMIT 10;
```

Hybrid is DIY: keep a `tsvector` column, score with `ts_rank`, run both, fuse ranks yourself.

```sql
ALTER TABLE docs ADD COLUMN tsv tsvector
  GENERATED ALWAYS AS (to_tsvector('english', coalesce(body,''))) STORED;
CREATE INDEX docs_tsv_idx ON docs USING gin (tsv);
-- Then run a vector ORDER BY and a ts_rank query, and combine by reciprocal rank in SQL/app.
```

## Qdrant (named vectors + hybrid via query API)

In-graph payload filtering, named dense+sparse vectors, server-side IDF (v1.15+), RRF/DBSF fusion.

```python
from qdrant_client import QdrantClient, models

client = QdrantClient(url="http://localhost:6333")

client.create_collection(
    collection_name="docs",
    vectors_config={"dense": models.VectorParams(size=1536, distance=models.Distance.COSINE)},
    sparse_vectors_config={"bm25": models.SparseVectorParams()},
)

# Index the field you filter on (in-graph filtering needs it).
client.create_payload_index(
    collection_name="docs",
    field_name="tenant_id",
    field_schema=models.PayloadSchemaType.KEYWORD,
)
```

Hybrid query: prefetch dense + sparse, fuse with RRF, filter inside the search.

```python
flt = models.Filter(must=[models.FieldCondition(
    key="tenant_id", match=models.MatchValue(value="acme"))])

res = client.query_points(
    collection_name="docs",
    prefetch=[
        models.Prefetch(query=dense_vec, using="dense", filter=flt, limit=50),
        models.Prefetch(query=models.SparseVector(indices=idx, values=val),
                        using="bm25", filter=flt, limit=50),
    ],
    query=models.FusionQuery(fusion=models.Fusion.RRF),   # or models.Fusion.DBSF
    limit=10,
)
```

Search-time recall knob: pass `search_params=models.SearchParams(hnsw_ef=128)`.

## Weaviate (alpha + fusionType, BlockMax WAND BM25)

`alpha` slides keyword↔vector; BlockMax WAND BM25 is the default from v1.30 (~10x faster).

```python
import weaviate
import weaviate.classes.config as wc

client = weaviate.connect_to_local()
client.collections.create(
    name="Docs",
    vector_config=wc.Configure.Vectors.self_provided(),   # bring your own vectors
    properties=[
        wc.Property(name="body", data_type=wc.DataType.TEXT),
        wc.Property(name="tenant_id", data_type=wc.DataType.TEXT),
    ],
)
```

Hybrid query with fusion and a filter:

```python
from weaviate.classes.query import Filter, HybridFusion

docs = client.collections.get("Docs")
res = docs.query.hybrid(
    query="how to reset a token",
    vector=dense_vec,
    alpha=0.5,                                   # 0.0 keyword .. 1.0 vector
    fusion_type=HybridFusion.RELATIVE_SCORE,     # or RANKED
    filters=Filter.by_property("tenant_id").equal("acme"),
    limit=10,
)
```

## Pinecone (serverless, API 2025-01)

Serverless is the default; namespaces partition tenants inside one index. Python SDK v6.x.

```python
from pinecone import Pinecone, ServerlessSpec

pc = Pinecone(api_key="...")
pc.create_index(
    name="docs",
    dimension=1536,
    metric="cosine",                             # match the model
    spec=ServerlessSpec(cloud="aws", region="us-east-1"),
)
index = pc.Index("docs")
```

Batched upsert into a namespace (never one-by-one):

```python
index.upsert(
    vectors=[{"id": d["id"], "values": d["vec"], "metadata": {"source": d["src"]}}
             for d in batch],          # send hundreds per call
    namespace="acme",
)
```

Query with metadata filter in the retrieval path (not post-filter):

```python
res = index.query(
    vector=dense_vec,
    top_k=10,
    namespace="acme",
    filter={"source": {"$eq": "handbook"}},
    include_metadata=True,
)
```

Sparse-dense hybrid uses `sparse_values` on upsert and query, or integrated inference to embed +
rerank server-side.
