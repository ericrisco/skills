# IMPLEMENTATION PLAN — skill `building-agents`

Source of truth: `/Volumes/EXTERN/DEV/skills/skill-build/building-agents/spec.md`.
This plan is mechanical: follow it verbatim. No further design decisions.
Calibration floor: the ECC skills (`agentic-engineering`, `agent-harness-construction`,
`autonomous-agent-harness`, `ai-first-engineering`, `agent-eval`, `eval-harness`,
`mcp-server-patterns`, `context-budget`, `prompt-optimizer`, `cost-aware-llm-pipeline`).
Match or exceed their density with FRESH, more current code. Do NOT copy ECC text.

Audience: an LLM coding agent loading this skill while working in a real repo whose
stack is FastAPI/Python, Next.js, Go, Flutter, Postgres. Write directive, dense,
copy-pasteable.

---

## 0. Global conventions (apply to EVERY file you write)

- **Versions to state explicitly where relevant:** Python 3.12+, Pydantic v2,
  SQLAlchemy 2.0 (async), FastAPI (latest stable), Next.js 15 App Router, React 19,
  Go 1.22+ (`net/http` routing + `log/slog`), Dart 3 / Flutter stable,
  PostgreSQL 16 + `pgvector` (HNSW), Node 20+ / TypeScript 5.
- **Dated vendor facts:** every model id, price, MCP spec date, SDK version MUST
  carry an inline `(as of 2026-06; verify before quoting)` marker. The skill body
  stays model-agnostic; concrete numbers live ONLY in the dated tables of
  `provider-abstraction.md` and `evals-and-observability.md`.
- **Vendor facts to embed (copy these exactly; all `as of 2026-06`):**
  - Anthropic: flagship `claude-opus-4-8` (2026-05-28); default `claude-sonnet-4-6`;
    cheap `claude-haiku-4-5`. $/MTok in/out: Haiku 4.5 1.00/5.00, Sonnet 4.6
    3.00/15.00, Opus 4.7 5.00/25.00 (Opus 4.8 confirm at runtime). Prompt caching
    −90% cached input; Batch −50%; 1M-token context flat-rate on Opus/Sonnet. Tool
    schema = `input_schema` (JSON Schema). SDK `anthropic` / `@anthropic-ai/sdk`.
  - OpenAI: flagship `gpt-5.5`; `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.4-nano`;
    `gpt-5.2-codex`. $/MTok: 5.5 5.00/30.00, 5.4 2.50/15.00, 5.2-codex 1.75/14.00;
    cached input −90%; >272K-token prompts billed 2× in / 1.5× out. Tools via
    `tools=[{"type":"function",…}]`; Structured Outputs with strict JSON Schema;
    prefer the **Responses API** for agent/tool loops. SDK `openai`.
  - Google Gemini: `gemini-3.5-flash`, `gemini-3.1-pro` (GA 2026-02-19), legacy
    `gemini-2.5-pro`. $/MTok: 3.5-flash 1.50/9.00 (cached 0.15); Pro paid-only since
    2026-04-01. Function calling + `responseSchema`/`responseMimeType`; 1M-token
    context on Flash. SDK `google-genai` (unified `google.genai`; old
    `google-generativeai` deprecated).
  - OSS / OpenAI-compatible: vLLM, Ollama, TGI expose OpenAI Chat Completions shape.
    **litellm** `v1.85.x` (as of 2026-06; pin exact version, avoid quarantined
    `1.82.7`/`1.82.8`) → one OpenAI-format surface to 100+ providers + Router
    fallbacks/budgets. Use as the reference normalization implementation, not a hard dep.
  - MCP: current stable spec `2025-11-25`; RC `2026-07-28` adds stateless protocol
    core, Extensions, Tasks, MCP Apps. Transports: **stdio** (local), **Streamable
    HTTP** (remote; SSE legacy only). SDKs `@modelcontextprotocol/sdk` (TS),
    `mcp` (Python FastMCP).
  - Observability: OpenTelemetry **GenAI semantic conventions** (`gen_ai.*`) are the
    vendor-neutral standard; Langfuse / Phoenix / Braintrust consume them.
- **Baked rule (put verbatim in SKILL.md "The one rule"):** "Model names and prices
  rot. Never hardcode them in app logic — resolve from config/registry, and re-verify
  the dated tables before quoting a number."
- **Markdown hygiene:** exactly one H1 per file; every fenced block has a language tag
  (`python`, `typescript`, `go`, `dart`, `sql`, `bash`, `text`, `json`, `yaml`);
  consistent ATX headings; no trailing TODO/`etc.`/placeholders. All code must be
  correct and runnable in context.
- **Cross-links:** use relative paths (`references/<file>.md`, `../<skill>/SKILL.md`).
- **House style reference (for tone/diagram/anti-pattern table):**
  `/Volumes/EXTERN/DEV/skills/skills/risco-project-harness/SKILL.md`. Match its
  density and the ASCII-diagram + rationalization-table format. Do not copy content.

---

## 1. File list (exact paths) — create ALL of these

```text
/Volumes/EXTERN/DEV/skills/skills/building-agents/SKILL.md
/Volumes/EXTERN/DEV/skills/skills/building-agents/references/provider-abstraction.md
/Volumes/EXTERN/DEV/skills/skills/building-agents/references/agent-loops-and-harness.md
/Volumes/EXTERN/DEV/skills/skills/building-agents/references/tools-and-rag.md
/Volumes/EXTERN/DEV/skills/skills/building-agents/references/evals-and-observability.md
/Volumes/EXTERN/DEV/skills/skills/building-agents/references/mcp-servers.md
/Volumes/EXTERN/DEV/skills/skills/building-agents/scripts/verify.sh
```

Create parent dirs first:
```bash
mkdir -p /Volumes/EXTERN/DEV/skills/skills/building-agents/references \
         /Volumes/EXTERN/DEV/skills/skills/building-agents/scripts
```

Line-budget targets (enforce): SKILL.md 250–450 (aim ~360). Each reference 200–500.
verify.sh ~110–150.

---

## 2. SKILL.md — exact section order + content

Write sections in THIS order. Keep it ~360 lines; push anything long to references.

### 2.1 Frontmatter (YAML)

```yaml
---
name: building-agents
description: "Use when designing or building an LLM agent, tool-using system, RAG pipeline, eval harness, or MCP server in this repo — across any provider (OpenAI, Anthropic, Google Gemini, or OSS via OpenAI-compatible endpoints / litellm). Triggers: 'build an agent', 'add tool calling / function calling', 'structured JSON output', 'RAG / retrieval / embeddings / rerank', 'agent loop / ReAct / orchestrator-worker / multi-agent', 'LLM eval / golden set / LLM-as-judge / regression gate', 'prompt caching / model routing / token budget / cost control', 'trace / observability for LLM calls', 'build an MCP server', or 'make our LLM code provider-agnostic / swap models'. FastAPI/Python, Next.js, Go, Flutter, Postgres stacks."
origin: risco
---
```
No `tools:` restriction. `origin: risco`. `description` MUST start with "Use when".

### 2.2 `# Building production LLM agents (model-agnostic)`

Single H1. One sentence under it: the purpose line from spec §1 ("Build production
LLM agents that are model-agnostic by construction — a thin provider adapter, a
disciplined agent loop, schema-validated tools, provider-neutral RAG, eval gates,
OTel tracing, and optionally an MCP server — so swapping OpenAI ↔ Anthropic ↔ Gemini
↔ OSS is a config change, not a rewrite.")

### 2.3 `## The one rule`

Blockquote:
> Program against a **capability interface**, never a vendor SDK. Vendor specifics
> (model id, tool-schema shape, JSON mode, caching, token limits) live behind one
> adapter resolved from config. If a model name or price appears in business logic,
> it's a bug.

Then a second blockquote with the "Model names and prices rot…" warning (§0 verbatim).

### 2.4 `## When to use / When NOT to use`

Two tight bullet lists (condense spec §1).
- When to use (7 bullets): any production LLM feature; code hardwired to one SDK +
  want to swap/route/fallback; adding tools/structured output/streaming; RAG over
  Postgres/`pgvector` or external store; eval harness / CI regression gate; tracing /
  cost / caching / routing; building or hardening an MCP server.
- When NOT to use (6 bullets, with explicit delegations): one-shot throwaway prompt →
  just call the SDK; pure prompt-wording → prompt engineering; Anthropic-SDK-specific
  tuning in a file that only imports `anthropic` → defer to **`claude-api`** skill;
  workspace scaffolding (`01-TOOLS`/`02-DOCS`) → **`risco-project-harness`**; picking
  which coding agent (Claude Code vs Aider) → agent-eval territory; no retrieval/tools/
  loop/evals at all → you don't need an agent, say so.

### 2.5 `## Decision rules (read before writing code)`

Numbered list, exactly these six (one line each, directive):
1. **Adapter first** — define the `LLMProvider` Protocol before any provider call.
2. **Smallest loop that works** — single-agent tool loop before multi-agent; ReAct
   only when the path is uncertain; plan-execute when steps are knowable.
3. **Tools are typed contracts** — Pydantic/Zod schema + validation + idempotency key
   on every side-effecting tool; no catch-all tools.
4. **Retrieve, don't stuff** — RAG when ground truth lives in data; cite or refuse.
5. **Eval before ship** — a golden set + regression gate in CI, or it's not production.
6. **Cheapest model that passes the eval** — route/cascade up, never default to flagship.

### 2.6 `## Architecture at a glance`

One fenced `text` ASCII diagram. Use this exact structure (refine labels, keep boxes):

```text
            ┌───────────────────────────────────────────────────────────┐
  Caller ──▶│  Agent loop  (perceive → decide → act → observe, bounded) │
            └───────────────────────────────────────────────────────────┘
               │              │                │              │
               ▼              ▼                ▼              ▼
        ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐
        │  Provider  │  │   Tool     │  │ Retriever  │  │  Tracer    │
        │  adapter   │  │  registry  │  │ (pgvector) │  │  (OTel)    │
        │ ↔ OpenAI / │  │ → sandboxed│  │ → cite/    │  │ gen_ai.*   │
        │ Anthropic /│  │   tools    │  │   refuse   │  │            │
        │ Gemini /OSS│  └────────────┘  └────────────┘  └────────────┘
        └────────────┘
               ▲                                          │
               └──────────── Eval gate (CI) ◀─────────────┘
   provider-abstraction.md  agent-loops…/tools-and-rag.md  evals-and-observability.md
```
The bottom caption maps boxes → owning reference file.

### 2.7 `## The provider adapter (the heart of the skill)`

ONE big `python` block, 70–90 lines, complete and runnable (Python 3.12 + Pydantic v2).
It MUST contain, in order:
- Imports: `from __future__ import annotations`, `typing.Protocol`/`runtime_checkable`,
  `pydantic.BaseModel`/`Field`, `os`.
- Pydantic models: `Message(role: Literal["system","user","assistant","tool"], content: str)`,
  `ToolSpec(name, description, parameters: dict)` (parameters = JSON Schema),
  `Usage(input_tokens, output_tokens, cost_usd: float = 0.0)`,
  `CompletionRequest(model, messages: list[Message], tools: list[ToolSpec] = [],
  response_schema: dict | None = None, temperature: float = 0.0, max_tokens: int = 1024)`,
  `CompletionResponse(text: str, tool_calls: list[dict] = [], usage: Usage,
  raw: dict | None = None)`.
- `@runtime_checkable class LLMProvider(Protocol)` with one sync method for the
  SKILL excerpt: `def complete(self, req: CompletionRequest) -> CompletionResponse: ...`
  (note in a comment that the full async + streaming interface is in
  `references/provider-abstraction.md`).
- `class OpenAIAdapter` — normalizes: builds `messages` (system stays a `system`
  role message), maps `tools` to `[{"type":"function","function":{...}}]`, maps
  `response_schema` to `response_format={"type":"json_schema", "json_schema": {...,
  "strict": True}}`, returns normalized `CompletionResponse` (show how `usage` is read
  and `tool_calls` extracted). Use the SDK shape `from openai import OpenAI`.
- `class AnthropicAdapter` — normalizes the QUIRKS: system prompt goes to top-level
  `system=` param (NOT a message), tools use `input_schema` (not `function`),
  structured output via tool-forcing (`tool_choice={"type":"tool","name":...}`).
  Use `from anthropic import Anthropic`.
- `def get_provider(spec: str) -> LLMProvider` factory: parse `"provider:model"`
  (e.g. from `os.environ["LLM"]`), return the matching adapter; raise on unknown.
  Show the model id as a variable resolved from `spec`, NEVER hardcoded in logic.

Add one trailing comment: "Gemini + OSS/litellm adapters, async, streaming, and
tool-result plumbing → references/provider-abstraction.md".

### 2.8 `## Good vs Bad`

Three contrasts, each two adjacent fenced blocks (Bad then Good), `python`, ~8–12 lines:
1. **Bad:** `OpenAI()` + `client.chat.completions.create(model="gpt-5.5", …)` scattered
   in handlers. **Good:** `provider = get_provider(settings.llm)` then
   `provider.complete(req)`.
2. **Bad:** `json.loads(resp.text)` wrapped in bare `try/except` to parse model output.
   **Good:** `response_schema=Answer.model_json_schema()` → strict structured output →
   `Answer.model_validate_json(resp.text)`.
3. **Bad:** `while True:` tool loop, no cap/timeout/idempotency. **Good:** bounded loop
   `for step in range(max_steps):` with per-tool timeout + idempotency key (one-liner;
   point to `agent-loops-and-harness.md`).

### 2.9 `## Tools & structured output (minimum viable)`

One `python` block: FastAPI-flavored (repo is FastAPI). Show:
- A Pydantic v2 args model `class CreateInvoiceArgs(BaseModel)` with typed/`Field`
  fields and `model_config = ConfigDict(extra="forbid")`.
- `ToolResult(BaseModel)` envelope: `status: Literal["success","warning","error"]`,
  `summary: str`, `data: dict | None = None`, `next_actions: list[str] = []`.
- A `TOOLS` registry dict mapping name → (`args_model`, handler).
- A `dispatch(name, raw_args) -> ToolResult` that validates args with
  `args_model.model_validate(raw_args)` (returns a `status="error"` ToolResult with a
  model-readable message on `ValidationError`), runs the handler, wraps result.
Trailing pointer: "schema design, sandboxing, idempotency, DI-scoped DB sessions →
references/tools-and-rag.md".

### 2.10 `## RAG in 30 lines (provider-agnostic embeddings)`

One block split between `sql` (DDL) and `python` (retrieve+cite), ~30 lines total:
- `sql`: `CREATE EXTENSION IF NOT EXISTS vector;` + table `docs(id, content text,
  embedding vector(1536), meta jsonb)` + HNSW index
  `CREATE INDEX ... USING hnsw (embedding vector_cosine_ops);`.
- `python`: `embed(texts) -> list[list[float]]` via the SAME provider interface;
  `retrieve(query, k=5)` runs the ANN query (`ORDER BY embedding <=> :q LIMIT :k`)
  with a similarity threshold; returns chunks with ids; the answer step is forced to
  **cite chunk ids** and **refuse if no chunk scores above threshold**.
Pointer: "chunking, hybrid RRF, rerank, citation grader, memory →
references/tools-and-rag.md".

### 2.11 `## Evals & cost gates (the production line)`

One `python` block ~20 lines, an offline eval-runner sketch:
- load golden set (JSONL: `{"input":..., "expected":..., "meta":...}`),
- run candidate via provider,
- grade with a list of graders (exact / schema / LLM-judge — show the call sites),
- aggregate metrics (`accuracy`, `faithfulness`, `p95_latency_ms`, `cost_per_task`),
- `sys.exit(1)` if any metric below its threshold (CI gate).
Then one prose line for the routing cascade: `route(task) → cheapest model whose eval
passes; escalate only on failed self-check`.
Pointer: "full runner, judge, CI gate, caching, batching, budgets →
references/evals-and-observability.md".

### 2.12 `## Observability (OTel GenAI, vendor-neutral)`

One `python` block ~12 lines: wrap `provider.complete` in an OTel span; set attributes
`gen_ai.system`, `gen_ai.request.model`, `gen_ai.usage.input_tokens`,
`gen_ai.usage.output_tokens`, plus cost + latency. Note: Langfuse/Phoenix/Braintrust
are swappable OTLP backends — emit spans, swap the exporter.
Pointer: "span-per-tool, trace-id propagation, exporters → references/evals-and-observability.md".

### 2.13 `## MCP: when and the smallest server`

Two-line decision: **native tools** when agent + tools share a process/repo; **MCP**
when tools must be reused across clients/teams or run out-of-process (note the MCP
token/ops cost). Then one `python` block: smallest FastMCP stdio server —
`from mcp.server.fastmcp import FastMCP`, `mcp = FastMCP("name")`, one
`@mcp.tool()` with a typed signature + docstring, one `@mcp.resource("uri://...")`,
`if __name__ == "__main__": mcp.run()`. Mark `(MCP spec 2025-11-25; stateless-core RC
2026-07-28; verify before quoting)`.
Pointer: "TypeScript server, transports, HTTP+auth, testing → references/mcp-servers.md".

### 2.14 `## Anti-patterns → STOP` (table)

Markdown table, two columns **Rationalization | Reality**, exactly these 12 rows
(copy text from spec §2 anti-patterns table verbatim — they are pre-written and correct):
the 12 rows about: call OpenAI SDK directly; JSON usually valid; no step cap; mega-tool;
eval by eyeballing; default to flagship; stuff whole doc; retry on every exception;
hardcode model name; MCP for everything; tool returns raw blob; caching is Anthropic-only.

### 2.15 `## Quick reference` (table)

Three columns **Task | Do this | Reference**. Rows (from spec §2): define provider;
add a tool; structured output; build the loop; multi-agent; RAG; eval gate; trace;
cut cost; MCP server. Each "Reference" cell names the exact `references/*.md` file.

### 2.16 `## verify.sh`

One short paragraph: `scripts/verify.sh` lints example agent code and dry-runs the eval
smoke test in THE USER'S project; it detects each tool and skips missing ones with a
yellow WARN (never fails on a missing tool); run it with `bash scripts/verify.sh` from
the project root; exit 0 = clean or skips only, non-zero = a real failure.

### 2.17 `## See Also`

Bullet list linking sibling skills with relative paths + one-line why:
- `../claude-api/SKILL.md` — Anthropic-SDK-specific tuning (caching internals,
  thinking, batch) when a file only imports `anthropic`.
- `../risco-project-harness/SKILL.md` — workspace `01-TOOLS`/`02-DOCS` scaffolding.
- `../deep-research/SKILL.md` — the research-harness fan-out/verify pattern.
- ECC analogues by name (no links, they are external): `agent-harness-construction`,
  `eval-harness`, `cost-aware-llm-pipeline`, `mcp-server-patterns`, `context-budget`.

---

## 3. references/provider-abstraction.md (~420 lines)

One H1: `# Provider abstraction — one interface, every model`. Sub-sections in order
(use `##`). Each must contain real, runnable, language-tagged code.

1. `## The interface` — full async-first `LLMProvider` Protocol with
   `async def complete(req) -> CompletionResponse` and
   `async def stream(req) -> AsyncIterator[StreamEvent]`; full Pydantic v2 models
   `Message`, `ToolSpec`, `ToolCall`, `CompletionRequest`, `CompletionResponse`,
   `Usage`, `StreamEvent(type: Literal["text","tool_call","usage","done"], ...)`.
2. `## Four adapters (full code)` — four `python` blocks, ~50–70 lines each:
   - **OpenAI** — Responses API primary (`client.responses.create`) with a Chat
     Completions fallback comment; strict Structured Outputs; `tools` function shape.
   - **Anthropic** — `input_schema`, top-level `system=`, `cache_control` on the
     system block; tool-forcing for structured output.
   - **Gemini** — `from google import genai`; `responseSchema` + `responseMimeType`;
     function calling.
   - **OSS via litellm** — `import litellm`; single OpenAI-format call to any
     `base_url`/model; note Router fallbacks/budgets.
3. `## Quirk matrix (as of 2026-06; verify before quoting)` — a markdown TABLE,
   rows = providers (OpenAI / Anthropic / Gemini / OSS-litellm), columns = tool-schema
   shape, structured-output mechanism, system-prompt placement, streaming event shape,
   prompt-caching support, max context, JSON-mode strictness. Put the dated disclaimer
   in the heading.
4. `## Structured / JSON output` — a single
   `async def complete_structured(req, schema: type[BaseModel]) -> BaseModel` that
   picks strict JSON Schema (OpenAI) / tool-forcing (Anthropic) / `responseSchema`
   (Gemini), validates with `schema.model_validate_json`, and shows a retry-on-invalid
   loop (max 2 retries, feed the validation error back).
5. `## Tool / function-calling normalization` — `to_openai_tools()`,
   `to_anthropic_tools()`, `to_gemini_tools()` converting one `list[ToolSpec]` into each
   wire format; `parse_tool_calls(provider, raw)` back into normalized `list[ToolCall]`;
   `tool_result_message(call_id, result)` producing each provider's expected role/shape.
6. `## Streaming` — one normalized async generator yielding `StreamEvent`s, with a
   per-provider mapping note (OpenAI delta events, Anthropic `content_block_delta`,
   Gemini chunk stream).
7. `## Token & context-window management` — `count_tokens(provider, messages)` using
   `tiktoken` for OpenAI, provider `count_tokens` where available, fallback heuristic
   `len(text)//4`; `trim_to_budget(messages, max_tokens)` that keeps the system message
   invariant, drops oldest turns, optionally summarizes; a pre-flight "will this fit"
   guard that raises before the call.
8. `## Sampling params` — `normalize_sampling(req)` mapping `temperature/top_p/
   max_tokens/stop`; a small dated note table on which provider renames/ignores which.
9. `## Config-driven selection` — parse `LLM="anthropic:claude-sonnet-4-6"` into
   adapter+model; env precedence; a `MODEL_REGISTRY` dict so app code calls
   `route("default"|"cheap"|"smart")` returning ids — NEVER raw ids in business logic.
10. `## litellm note (as of 2026-06)` — when to adopt litellm or its proxy vs hand-roll;
    pin `v1.85.x`; the 2026-03 supply-chain caveat (avoid `1.82.7`/`1.82.8`); Router
    fallbacks/budgets snippet.

End with a 2-line "See also" pointing to `agent-loops-and-harness.md` (loop) and
`evals-and-observability.md` (cost router uses this same interface).

---

## 4. references/agent-loops-and-harness.md (~470 lines)

H1: `# Agent loops & harness — bounded, recoverable, observable`. Sub-sections (`##`):

1. `## The loop` — full ~60-line runnable single-agent tool loop using the §3 provider:
   `perceive → decide → act → observe`, bounded by `max_steps`, per-step
   `asyncio.timeout`, a token/`$` budget cap, and a typed `AgentState` (Pydantic:
   `messages`, `step`, `spent_usd`, `done`, `result`). Show the loop calling
   `provider.complete`, dispatching tool calls, appending `ToolResult` observations.
2. `## ReAct vs plan-execute` — when each; a `python` ReAct sketch and a plan-execute
   sketch; the recommended **hybrid** (ReAct planning + typed tool execution).
3. `## Observation design` — the `ToolResult{status,summary,data,next_actions,artifacts}`
   envelope (Pydantic) and WHY (recovery + context economy). Good vs Bad observation.
4. `## Error-recovery contract` — per error return root-cause hint + safe-retry
   instruction + explicit stop condition; `classify_error(e) -> Literal["transient",
   "permanent"]`; backoff+jitter; a circuit breaker that trips on N identical failures.
5. `## Determinism & idempotency` — pin seed/`temperature=0` for evals; idempotency keys
   for side effects; replayable transcripts; content-addressed tool-call dedup
   (`hashlib.sha256` of normalized args).
6. `## Retries, timeouts, guardrails` — wall-clock + step + token budgets; input/output
   guardrails (PII regex, prompt-injection heuristic, schema check); a
   `@guardrail` decorator wrapping a tool handler.
7. `## Multi-agent` — orchestrator-worker; parallel fan-out with
   `asyncio.gather` + a `Semaphore`; sequential pipeline; when to use each + the
   cost/latency tradeoff; a concrete orchestrator dispatching typed subagents.
8. `## Subagents` — spawn a constrained sub-loop with a narrowed tool set + its own
   budget; return a single summarized observation to the parent.
9. `## Human-in-the-loop` — approval gates on high-risk tools (deploy, migration,
   spend); a pause/resume interrupt; surfacing a diff for sign-off.
10. `## Checkpoint / resume` — persist `AgentState` as `jsonb` to Postgres (SQLAlchemy
    2.0 async) or a file after each step; resume from last checkpoint; idempotent replay.
11. `## Anti-patterns` — bullet list: unbounded loops, hidden global state, tool sprawl,
    swallowing errors, no budget.

End with "See also" → `provider-abstraction.md`, `tools-and-rag.md`.

---

## 5. references/tools-and-rag.md (~480 lines)

H1: `# Tools done safely + provider-agnostic RAG + memory`. Sub-sections (`##`):

1. `## Tool schema design` — narrow typed Pydantic v2 inputs, stable names,
   deterministic output shapes; JSON Schema generation (`model_json_schema()`);
   descriptions the model reads; `enum`/`Literal` over freeform; no catch-all tools.
2. `## Validation` — validate args BEFORE execution; reject with a structured
   model-readable error (`ToolResult(status="error", ...)`); never trust
   model-supplied paths/ids (show a path-traversal rejection).
3. `## Side-effect safety & sandboxing` — command allowlist; path jail (resolve +
   `is_relative_to`); network-egress allowlist; dry-run mode; read-only by default;
   running untrusted tool code in a subprocess; the **FastAPI dependency-injection**
   pattern scoping a tool's DB session (`Depends(get_session)` async).
4. `## Idempotency` — idempotency keys; a Postgres dedup table (DDL + upsert);
   safe-retry semantics for `POST`-like tools.
5. `## RAG — chunking` — token-aware chunking with overlap; structure-aware splitting
   (headings/code fences); per-chunk metadata. Provide a **Python** chunker and a **Go**
   chunker variant (Go 1.22+).
6. `## Embeddings (provider-agnostic)` — `async def embed(texts) -> list[list[float]]`
   behind the §3 provider; dimension/normalize handling; batching; a cost note.
7. `## Vector store — pgvector on Postgres 16` — DDL with `vector` column + HNSW index;
   upsert; ANN query with metadata filter using SQLAlchemy 2.0 async; why Postgres-first
   for this repo; external stores (Qdrant/Pinecone) behind a swappable `Retriever`
   Protocol.
8. `## Hybrid search` — `pgvector` ANN + Postgres full-text (`tsvector` + `websearch_to_tsquery`)
   combined with Reciprocal Rank Fusion; SQL + Python fusion code.
9. `## Reranking` — a `Reranker` Protocol (cross-encoder or provider rerank endpoint);
   when reranking pays off; code wiring it after retrieval.
10. `## Citation & faithfulness` — return chunk ids/spans; force the model to cite;
    refuse when retrieval is empty / below score threshold; a citation-validation grader
    that fails answers citing ids not in the retrieved set.
11. `## Memory` — short-term (rolling window + summarization), long-term (vector +
    structured facts in Postgres), memory-as-a-tool retrieval; write-policy (what's
    worth persisting) and forgetting/TTL.

End with "See also" → `provider-abstraction.md`, `agent-loops-and-harness.md`,
`evals-and-observability.md`.

---

## 6. references/evals-and-observability.md (~470 lines)

H1: `# Evals, tracing & cost control — the production line`. Sub-sections (`##`):

1. `## Eval-first` — define success criteria before building; capability vs regression
   evals (a runnable harness, not prose).
2. `## Golden sets` — JSONL schema (`input`, `expected`, `metadata`); versioning as
   fixtures; building from real traffic; avoiding train/eval leakage.
3. `## Graders` — exact/code grader, schema/rule grader, and a full **LLM-as-judge**
   implementation using the §3 provider (so the judge is itself provider-agnostic):
   rubric prompt, pairwise + pointwise, judge-model independence, bias mitigation,
   calibration against human labels.
4. `## Metrics` — `accuracy`, `pass@k`/`pass^k` (give the formulas + code),
   `faithfulness`/groundedness, answer relevance, `cost_per_task`, `p50`/`p95` latency,
   tool-call validity rate.
5. `## Eval runner` — the FULL async runner: load golden set → run candidate → grade →
   aggregate → write report (JSON + markdown) → exit code from threshold. **This is the
   file `verify.sh` dry-runs**, so support a `--dry-run`/`EVAL_DRY_RUN=1` mode that does
   NOT hit live APIs (use a stub provider). Show the dry-run branch explicitly.
6. `## Regression gates in CI` — a GitHub Actions `yaml` snippet running evals on PR,
   failing if any metric regresses past tolerance vs a stored baseline; baseline storage;
   a flaky-grader guardrail.
7. `## Tracing (OTel GenAI)` — full setup emitting `gen_ai.*` spans/attributes; span per
   LLM call + per tool + per agent step; wiring a Langfuse/Phoenix OTLP exporter;
   trace-id propagation through the loop.
8. `## Cost & latency control` — four labelled sub-parts with code:
   - **Caching:** prompt caching where supported (Anthropic `cache_control`;
     OpenAI/Gemini automatic cached input) abstracted behind the adapter; PLUS an
     app-level **semantic cache** (embed request → vector lookup → return prior answer
     above similarity threshold).
   - **Batching:** provider batch APIs (−50% class) for offline workloads.
   - **Model routing / cascades:** `route()` classifying task → cheapest model;
     escalate only on low confidence / failed self-check (full code).
   - **Budgets:** an immutable `CostTracker` (frozen `@dataclass(frozen=True, slots=True)`,
     extend cost-aware-llm-pipeline's pattern) with per-tenant budgets + a hard stop
     (`over_budget` → raise `BudgetExceededError`). Include the dated pricing TABLE
     `(as of 2026-06; verify before quoting)` with the §0 numbers.
9. `## Anti-patterns` — overfitting prompts to the eval set; happy-path-only evals;
   chasing accuracy while cost/latency drift; flaky graders in release gates; tracing
   PII without redaction.

End with "See also" → `provider-abstraction.md`, `agent-loops-and-harness.md`.

---

## 7. references/mcp-servers.md (~400 lines)

H1: `# MCP servers — decide, build, secure`. Sub-sections (`##`):

1. `## MCP vs native tools` — a decision TABLE: in-process/single-repo → native;
   cross-client / cross-team / out-of-process / own-deploy → MCP. Note the MCP cost
   (schema tokens, transport, ops) tying to context-budget.
2. `## Concepts` — tools (actions), resources (read-only data), prompts (templates);
   request/response lifecycle; dated note `(spec 2025-11-25; stateless-core RC
   2026-07-28; verify before quoting)`.
3. `## Python server (FastMCP)` — full `python` server: `from mcp.server.fastmcp import
   FastMCP`; `@mcp.tool()` with Pydantic-validated args; `@mcp.resource("uri://...")`;
   `@mcp.prompt()`; stdio entrypoint `mcp.run()`. ~50 lines, complete.
4. `## TypeScript server` — full `typescript` `@modelcontextprotocol/sdk` `McpServer`
   with **Zod** schemas, one tool, one resource; stdio AND Streamable HTTP entrypoints.
   (TS because the repo runs Next.js.) Use current registration API; if unsure of exact
   signatures, note "verify against @modelcontextprotocol/sdk current docs" but still
   write a concrete, internally-consistent example.
5. `## Transports` — stdio (local, Claude Desktop/Code) vs **Streamable HTTP** (remote,
   horizontal scale, the stateless-core direction); SSE legacy only; `.well-known`
   capability discovery note (RC).
6. `## Security` — auth on the HTTP transport (OAuth/bearer); input validation; no raw
   stack traces to the model; rate limiting; egress controls; tool allowlisting; the
   "confused deputy" risk + least-privilege tokens.
7. `## Testing & debugging` — MCP Inspector; a contract test that lists tools and
   round-trips one call; an idempotency check.
8. `## Packaging` — pin SDK + spec version in the manifest; a client-registration config
   snippet (`json`).

End with "See also" → `tools-and-rag.md` (native tools), `provider-abstraction.md`.

---

## 8. scripts/verify.sh — write EXACTLY this, then chmod +x

Write the file with this content verbatim (it already implements the spec §4 contract:
detect-or-skip, yellow warn on missing tools, fail only on real errors, idempotent,
read-only, `--no-install` for npx). After writing, run
`chmod +x /Volumes/EXTERN/DEV/skills/skills/building-agents/scripts/verify.sh`.
**Do NOT execute verify.sh in this repo** (this repo is not a project of that stack).

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: bash scripts/verify.sh
# Lints example agent code and dry-runs the eval smoke test in THIS project.
# Detects each tool; missing tools print a yellow WARN and are skipped (not failures).
# Exit 0 = all present checks passed (or only skips). Non-zero = a real failure.
# Read-only: never writes files, never installs anything (npx uses --no-install).

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; RESET="$(tput sgr0)"
else
  YELLOW=""; RED=""; GREEN=""; RESET=""
fi

rc=0
warn() { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$1" >&2; }
info() { printf '[INFO] %s\n' "$1"; }
fail() { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$1" >&2; rc=1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Directories likely to hold example code; fall back to "." with vendored dirs pruned.
PRUNE='-path ./node_modules -o -path ./.venv -o -path ./venv -o -path ./dist -o -path ./build -o -path ./.git'
pick_dirs() {
  local found=()
  for d in examples agents src; do
    [ -d "$d" ] && found+=("$d")
  done
  if [ "${#found[@]}" -gt 0 ]; then printf '%s\n' "${found[@]}"; else printf '%s\n' "."; fi
}

# 1. Python lint (ruff)
if have ruff; then
  mapfile -t PYDIRS < <(pick_dirs)
  if find "${PYDIRS[@]}" \( $PRUNE \) -prune -o -name '*.py' -print 2>/dev/null | grep -q .; then
    info "ruff: linting ${PYDIRS[*]}"
    if ! ruff check "${PYDIRS[@]}"; then fail "ruff reported lint errors"; fi
  else
    info "ruff present but no .py files found; skipping"
  fi
else
  warn "ruff not found; skipping Python lint"
fi

# 2. Python typecheck (mypy) — soft: only if config present
if have mypy && { [ -f mypy.ini ] || [ -f setup.cfg ] || grep -qs '\[tool.mypy\]' pyproject.toml 2>/dev/null; }; then
  mapfile -t PYDIRS < <(pick_dirs)
  info "mypy: typechecking ${PYDIRS[*]}"
  if ! mypy "${PYDIRS[@]}"; then fail "mypy reported type errors"; fi
elif have mypy; then
  warn "mypy present but no config (mypy.ini/setup.cfg/[tool.mypy]); skipping typecheck"
else
  warn "mypy not found; skipping Python typecheck"
fi

# 3. TS/JS check
if [ -f tsconfig.json ] && have npx; then
  info "tsc: typechecking (no emit)"
  if ! npx --no-install tsc --noEmit; then fail "tsc reported type errors"; fi
elif have node && find . \( $PRUNE \) -prune -o \( -name '*.mjs' -o -name '*.js' \) -print 2>/dev/null | grep -q .; then
  info "node --check: syntax-checking JS/MJS examples"
  while IFS= read -r f; do
    node --check "$f" || fail "node --check failed: $f"
  done < <(find . \( $PRUNE \) -prune -o \( -name '*.mjs' -o -name '*.js' \) -print)
else
  warn "no tsconfig.json + npx and no node/JS examples; skipping TS/JS check"
fi

# 4. Go vet (only if module present)
if [ -f go.mod ]; then
  if have go; then
    info "go vet ./..."
    if ! go vet ./...; then fail "go vet reported issues"; fi
  else
    warn "go.mod present but go not found; skipping go vet"
  fi
fi

# 5. Eval smoke dry-run (must not hit live APIs)
EVAL_ENTRY=""
for cand in evals/run.py evals/smoke.py scripts/eval_smoke.py; do
  [ -f "$cand" ] && { EVAL_ENTRY="$cand"; break; }
done
if [ -n "$EVAL_ENTRY" ] && have python; then
  info "eval smoke (dry-run): $EVAL_ENTRY"
  if ! EVAL_DRY_RUN=1 python "$EVAL_ENTRY" --dry-run; then fail "eval smoke dry-run failed"; fi
elif [ -f package.json ] && have npx && grep -qs '"eval"' package.json; then
  info "eval smoke (dry-run): npm run eval -- --dry-run"
  if ! EVAL_DRY_RUN=1 npx --no-install npm run eval -- --dry-run; then fail "eval smoke dry-run failed"; fi
else
  warn "no eval smoke entrypoint (evals/run.py|smoke.py|scripts/eval_smoke.py|package.json eval); skipping"
fi

# 6. Markdown lint (soft — advisory, never fails the gate)
if have markdownlint-cli2; then
  markdownlint-cli2 '**/*.md' >/dev/null 2>&1 || warn "markdownlint-cli2 reported style issues (advisory)"
elif have markdownlint; then
  markdownlint '**/*.md' >/dev/null 2>&1 || warn "markdownlint reported style issues (advisory)"
else
  warn "markdownlint not found; skipping markdown lint (advisory)"
fi

if [ "$rc" -ne 0 ]; then
  printf '%sverify.sh: FAILED%s\n' "$RED" "$RESET" >&2
  exit "$rc"
fi
printf '%sverify.sh: OK%s\n' "$GREEN" "$RESET"
exit 0
```

After writing: `chmod +x /Volumes/EXTERN/DEV/skills/skills/building-agents/scripts/verify.sh`.

---

## 9. Acceptance checks (implementer MUST self-verify before finishing)

Run/confirm each; do NOT report done until all pass:

1. **All 7 files exist** at the exact paths in §1. Confirm with
   `ls -R /Volumes/EXTERN/DEV/skills/skills/building-agents`.
2. **verify.sh is executable:** `test -x .../scripts/verify.sh` returns 0; first line
   is `#!/usr/bin/env bash`; second line `set -euo pipefail`; has the usage header.
   Lint it: `bash -n .../scripts/verify.sh` (parse-check only — do NOT run it).
3. **Frontmatter:** SKILL.md `name: building-agents`, `origin: risco`, `description`
   starts with `Use when ` and is trigger-rich (all the trigger phrases from §2.1).
4. **One H1 per file**: `grep -c '^# ' <file>` == 1 for every `.md`.
5. **Every fenced block has a language tag:** no bare ```` ``` ```` opening fences;
   scan each file. Languages used: python, typescript, go, dart, sql, bash, text,
   json, yaml.
6. **No placeholders:** zero occurrences of `TODO`, `FIXME`, `XXX`, `...etc`, `<placeholder>`,
   `your-code-here`. Check `grep -rniE 'TODO|FIXME|placeholder|your-?code-here|\.\.\.etc' <dir>`.
7. **Code correctness:** Python examples are syntactically valid and import-consistent
   (Pydantic v2 APIs: `model_validate`, `model_json_schema`, `model_config = ConfigDict`,
   `model_validate_json`); SQLAlchemy 2.0 async style; Go uses 1.22+ `net/http` + `slog`;
   TS uses Zod + `@modelcontextprotocol/sdk`. No SDK method that contradicts §0 facts.
8. **Dated facts carry the marker:** every model id / price / spec date / SDK version in
   the references carries `(as of 2026-06; verify before quoting)` (or equivalent) and
   appears only in the tables of `provider-abstraction.md` / `evals-and-observability.md`,
   never in SKILL.md business-logic code.
9. **Line budgets:** SKILL.md 250–450 (`wc -l`); each reference 200–500. If SKILL.md is
   over, move depth into the matching reference (progressive disclosure).
10. **Headings consistent:** ATX (`#`/`##`/`###`), sentence-case-ish, no skipped levels
    (no `###` without a parent `##`).
11. **See Also links resolve as siblings:** SKILL.md links `../claude-api/SKILL.md`,
    `../risco-project-harness/SKILL.md`, `../deep-research/SKILL.md` (relative sibling
    paths); each reference ends with a "See also" pointing to sibling reference files
    that exist in §1.
12. **Quick-reference + anti-pattern tables present** in SKILL.md (anti-pattern table ≥12
    rows; quick-ref names a real reference file per row).
13. **Cross-reference integrity:** every `references/<x>.md` named in SKILL.md pointers and
    in the quick-ref exists in §1.

Do NOT execute `verify.sh`, the eval runner, or any example in this repo — this repo is
not a FastAPI/Next/Go/Flutter/Postgres project. Parse-check only.
