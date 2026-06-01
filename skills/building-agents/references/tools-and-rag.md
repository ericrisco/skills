# Tools done safely + provider-agnostic RAG + memory

Tools are the agent's hands; RAG is its memory of ground truth. Both fail the same way:
trusting model-supplied input and stuffing unbounded data into context. This file shows
typed, validated, sandboxed tools and a `pgvector`-on-Postgres-16 RAG pipeline that
cites or refuses. Python 3.12+, Pydantic v2, SQLAlchemy 2.0 async, Go 1.22+.

## Tool schema design

Narrow, typed inputs; stable names; deterministic output shapes. The JSON Schema you
hand the model *is* its instruction manual — descriptions and `enum`s matter.

```python
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class RefundArgs(BaseModel):
    model_config = ConfigDict(extra="forbid")  # reject keys the model invents

    order_id: str = Field(min_length=1, description="Order id, e.g. 'ord_8123'.")
    amount_cents: int = Field(gt=0, le=1_000_000, description="Refund amount in cents.")
    reason: Literal["defective", "late", "duplicate", "goodwill"] = Field(
        description="Use the closest enum; do not invent reasons.")


schema = RefundArgs.model_json_schema()  # hand this to the provider as the tool's parameters
```

Rules: one verb per tool (`create_invoice`, not `manage_invoice`); `Literal`/`enum` over
free strings; constrain ranges (`gt`, `le`, `min_length`); write descriptions for the
*model*, not for humans; never a catch-all `run(command: str)` tool.

## Validation

Validate **before** any side effect. Reject with a structured, model-readable error so
the agent can self-correct. Never trust model-supplied paths or ids.

```python
from pathlib import Path

from pydantic import ValidationError

from agent_loops_and_harness import ToolResult  # the typed envelope


def validate_and_run(args_model: type[BaseModel], handler, raw: dict) -> ToolResult:
    try:
        args = args_model.model_validate(raw)        # parse + coerce + bounds-check
    except ValidationError as e:
        return ToolResult(status="error", summary="invalid arguments",
                          data={"errors": e.errors()},
                          next_actions=["fix the listed fields and call again"])
    return handler(args)


def safe_path(root: Path, candidate: str) -> Path:
    # Reject path traversal: resolve and require the result to stay under root.
    p = (root / candidate).resolve()
    if not p.is_relative_to(root.resolve()):
        raise ValueError(f"path escapes sandbox: {candidate!r}")
    return p
```

## Side-effect safety & sandboxing

Default to read-only. Allowlist commands, jail paths, allowlist network egress, support a
dry-run mode, and run untrusted tool code out-of-process.

```python
import asyncio

_ALLOWED_CMDS = {"ls", "cat", "grep", "rg"}            # explicit allowlist, never a denylist
_ALLOWED_HOSTS = {"api.internal", "files.internal"}    # egress allowlist


async def run_command(argv: list[str], *, dry_run: bool = False, timeout_s: float = 10.0) -> ToolResult:
    if argv[0] not in _ALLOWED_CMDS:
        return ToolResult(status="error", summary=f"command not allowed: {argv[0]!r}")
    if dry_run:
        return ToolResult(status="success", summary=f"[dry-run] would run: {' '.join(argv)}")
    proc = await asyncio.create_subprocess_exec(       # subprocess isolation, no shell=True
        *argv, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        out, err = await asyncio.wait_for(proc.communicate(), timeout=timeout_s)
    except TimeoutError:
        proc.kill()
        return ToolResult(status="error", summary="command timed out")
    return ToolResult(status="success" if proc.returncode == 0 else "error",
                      summary=out.decode()[:500] or err.decode()[:500])
```

**FastAPI dependency-injection** scopes a tool's DB session to the request, so a tool
never holds a long-lived connection and transactions are cleanly committed/rolled back:

```python
from collections.abc import AsyncIterator

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

engine = create_async_engine("postgresql+asyncpg://app:secret@db/app")
Session = async_sessionmaker(engine, expire_on_commit=False)


async def get_session() -> AsyncIterator[AsyncSession]:
    async with Session() as s:
        yield s                                        # one session per request/tool call


async def refund_tool(args: RefundArgs, session: AsyncSession = Depends(get_session)) -> ToolResult:
    # session is request-scoped; commit/rollback handled by the context manager
    ...
```

## Idempotency

Side-effecting tools (`POST`-like) must be safe to retry. Persist an idempotency key and
short-circuit duplicates.

```sql
CREATE TABLE IF NOT EXISTS tool_idempotency (
    key        text PRIMARY KEY,
    tool       text NOT NULL,
    result     jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
```

```python
from sqlalchemy import text


async def idempotent(session: AsyncSession, key: str, tool: str, run) -> ToolResult:
    hit = (await session.execute(
        text("SELECT result FROM tool_idempotency WHERE key = :k"), {"k": key})).scalar_one_or_none()
    if hit is not None:
        return ToolResult.model_validate(hit)          # replay prior result; no re-execution
    result = await run()
    await session.execute(
        text("INSERT INTO tool_idempotency (key, tool, result) VALUES (:k, :t, :r) "
             "ON CONFLICT (key) DO NOTHING"),
        {"k": key, "t": tool, "r": result.model_dump_json()})
    await session.commit()
    return result
```

## RAG — chunking

Split on structure (headings, code fences) and cap by tokens with overlap so a chunk is
self-contained but not oversized.

```python
def chunk_text(text: str, *, max_tokens: int = 400, overlap: int = 60) -> list[str]:
    paras = [p.strip() for p in text.split("\n\n") if p.strip()]
    chunks: list[str] = []
    buf: list[str] = []
    size = 0
    for para in paras:
        est = len(para) // 4                           # chars/4 token heuristic
        if size + est > max_tokens and buf:
            chunks.append("\n\n".join(buf))
            tail = " ".join(buf)[-overlap * 4:]        # carry overlap into next chunk
            buf, size = ([tail] if tail else []), len(tail) // 4
        buf.append(para)
        size += est
    if buf:
        chunks.append("\n\n".join(buf))
    return chunks
```

Go 1.22+ variant for ingestion services written in Go:

```go
package rag

import "strings"

// ChunkText splits on blank lines, capping each chunk at ~maxTokens (chars/4).
func ChunkText(text string, maxTokens, overlap int) []string {
	paras := strings.Split(strings.TrimSpace(text), "\n\n")
	var chunks []string
	var buf []string
	size := 0
	flush := func() {
		if len(buf) > 0 {
			chunks = append(chunks, strings.Join(buf, "\n\n"))
		}
	}
	for _, p := range paras {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		est := len(p) / 4
		if size+est > maxTokens && len(buf) > 0 {
			flush()
			tail := strings.Join(buf, " ")
			if len(tail) > overlap*4 {
				tail = tail[len(tail)-overlap*4:]
			}
			buf, size = []string{tail}, len(tail)/4
		}
		buf = append(buf, p)
		size += est
	}
	flush()
	return chunks
}
```

## Embeddings (provider-agnostic)

Embedding goes through the same `LLMProvider.embed` from `provider-abstraction.md`, so
the vector source is a config string. Batch, and normalize if you use inner-product.

```python
import math

from provider_abstraction import LLMProvider


async def embed_chunks(provider: LLMProvider, chunks: list[str], *, batch: int = 128) -> list[list[float]]:
    out: list[list[float]] = []
    for i in range(0, len(chunks), batch):             # batch to amortize request overhead/cost
        out.extend(await provider.embed(chunks[i:i + batch]))
    return out


def l2_normalize(v: list[float]) -> list[float]:
    n = math.sqrt(sum(x * x for x in v)) or 1.0
    return [x / n for x in v]
```

Cost note: embeddings are 1–2 orders of magnitude cheaper than generation; embed
generously, but cache embeddings keyed by `sha256(text)` so re-ingest is free.

## Vector store — pgvector on Postgres 16

This repo runs Postgres, so vectors live next to your relational data — one store, one
backup, transactional writes. Reach for Qdrant/Pinecone only past ~10M vectors or for
managed scale, behind a swappable `Retriever`.

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS chunks (
    id        bigserial PRIMARY KEY,
    doc_id    text NOT NULL,
    content   text NOT NULL,
    embedding vector(1536) NOT NULL,
    meta      jsonb NOT NULL DEFAULT '{}',
    ts        tsvector GENERATED ALWAYS AS (to_tsvector('english', content)) STORED
);
CREATE INDEX IF NOT EXISTS chunks_hnsw ON chunks USING hnsw (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS chunks_ts   ON chunks USING gin (ts);
CREATE INDEX IF NOT EXISTS chunks_meta ON chunks USING gin (meta);
```

```python
from typing import Protocol

from sqlalchemy import bindparam, text
from sqlalchemy.dialects.postgresql import JSONB


class Retriever(Protocol):
    async def search(self, query_vec: list[float], k: int, flt: dict) -> list[dict]: ...


class PgVectorRetriever:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def search(self, query_vec: list[float], k: int = 5, flt: dict | None = None) -> list[dict]:
        stmt = text(
            "SELECT id, content, meta, 1 - (embedding <=> :q) AS sim "
            "FROM chunks WHERE meta @> :flt "
            "ORDER BY embedding <=> :q LIMIT :k"
        ).bindparams(bindparam("q", value=str(query_vec)),
                     bindparam("flt", value=flt or {}, type_=JSONB),
                     bindparam("k", value=k))
        rows = (await self.session.execute(stmt)).mappings().all()
        return [dict(r) for r in rows]
```

Upsert keeps the index consistent on re-ingest:

```python
async def upsert_chunk(session: AsyncSession, doc_id: str, content: str,
                       embedding: list[float], meta: dict) -> None:
    await session.execute(text(
        "INSERT INTO chunks (doc_id, content, embedding, meta) "
        "VALUES (:d, :c, :e, :m) "
        "ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, embedding = EXCLUDED.embedding"),
        {"d": doc_id, "c": content, "e": str(embedding), "m": meta})
    await session.commit()
```

## Hybrid search

Dense vectors miss exact terms (ids, codes, rare words); full-text misses paraphrase.
Combine both with **Reciprocal Rank Fusion** — robust and parameter-light.

```python
async def hybrid_search(session: AsyncSession, query: str, query_vec: list[float],
                        k: int = 10, rrf_k: int = 60) -> list[dict]:
    dense = (await session.execute(text(
        "SELECT id, content FROM chunks ORDER BY embedding <=> :q LIMIT :k"),
        {"q": str(query_vec), "k": k})).mappings().all()
    lexical = (await session.execute(text(
        "SELECT id, content FROM chunks "
        "WHERE ts @@ websearch_to_tsquery('english', :query) "
        "ORDER BY ts_rank(ts, websearch_to_tsquery('english', :query)) DESC LIMIT :k"),
        {"query": query, "k": k})).mappings().all()

    scores: dict[int, float] = {}
    docs: dict[int, dict] = {}
    for ranking in (dense, lexical):
        for rank, row in enumerate(ranking):           # RRF: 1 / (rrf_k + rank)
            scores[row["id"]] = scores.get(row["id"], 0.0) + 1.0 / (rrf_k + rank)
            docs[row["id"]] = dict(row)
    ranked = sorted(scores, key=scores.get, reverse=True)[:k]
    return [docs[i] | {"score": scores[i]} for i in ranked]
```

## Reranking

After cheap retrieval (k≈20–50), a cross-encoder reranker reorders by true relevance.
Worth it when precision@k matters (legal, support, anything that cites). Behind an
interface so the implementation (local cross-encoder or a provider rerank endpoint) is
swappable.

```python
class Reranker(Protocol):
    async def rerank(self, query: str, docs: list[dict], top_n: int) -> list[dict]: ...


class CrossEncoderReranker:
    def __init__(self) -> None:
        from sentence_transformers import CrossEncoder
        self.model = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")

    async def rerank(self, query: str, docs: list[dict], top_n: int = 5) -> list[dict]:
        scores = self.model.predict([(query, d["content"]) for d in docs])
        ranked = sorted(zip(docs, scores), key=lambda x: x[1], reverse=True)
        return [d | {"rerank_score": float(s)} for d, s in ranked[:top_n]]
```

## Citation & faithfulness

Return chunk ids, force the model to cite them, and **refuse when retrieval is empty or
below threshold** — a confident answer with no source is the failure mode RAG exists to
prevent.

```python
import re

from provider_abstraction import CompletionRequest, Message


async def answer_with_citations(provider, model, query: str, chunks: list[dict],
                                min_score: float = 0.25) -> tuple[str, bool]:
    grounded = [c for c in chunks if c.get("sim", c.get("score", 0)) >= min_score]
    if not grounded:
        return "I don't have grounded sources to answer that.", False
    context = "\n".join(f"[{c['id']}] {c['content']}" for c in grounded)
    resp = await provider.complete(CompletionRequest(model=model, messages=[
        Message(role="system", content="Answer ONLY from the context. Cite every claim as [id]. "
                                        "If the context is insufficient, say so."),
        Message(role="user", content=f"{context}\n\nQuestion: {query}")]))
    return resp.text, _citations_valid(resp.text, {c["id"] for c in grounded})


def _citations_valid(answer: str, allowed_ids: set[int]) -> bool:
    cited = {int(m) for m in re.findall(r"\[(\d+)\]", answer)}
    return bool(cited) and cited.issubset(allowed_ids)  # grader: fail answers citing unknown ids
```

`_citations_valid` doubles as an eval grader (see `evals-and-observability.md`): an answer
citing ids not in the retrieved set is hallucinated.

## Memory

- **Short-term** — a rolling window of recent turns; when it exceeds budget, summarize the
  oldest turns into one `system` note and drop them (`trim_to_budget` in
  `provider-abstraction.md`).
- **Long-term** — durable facts in Postgres: free-text memories as `chunks` (vector
  recall) plus structured facts in typed tables (exact recall). Retrieval is just another
  tool the agent calls.

```python
class MemoryWritePolicy(BaseModel):
    # Persist only durable, reusable facts — not chit-chat or one-off context.
    is_durable: bool                                   # true for preferences, decisions, identities
    ttl_days: int | None = None                        # None = permanent; else expire


async def remember(session: AsyncSession, provider, text_: str, policy: MemoryWritePolicy) -> None:
    if not policy.is_durable:
        return                                         # forgetting is a feature
    [vec] = await provider.embed([text_])
    await upsert_chunk(session, doc_id="memory", content=text_, embedding=vec,
                       meta={"kind": "memory", "ttl_days": policy.ttl_days})
```

A nightly job deletes expired memories (`meta->>'ttl_days'` past `created_at`), keeping
recall sharp and the store bounded.

## See also

- `provider-abstraction.md` — the `embed`/`complete` interface tools and RAG ride on.
- `agent-loops-and-harness.md` — the `ToolResult` envelope and `dispatch` these tools fill.
- `evals-and-observability.md` — graders for faithfulness, citation validity, and cost.
</content>
