# DESIGN SPEC — skill `building-agents`

Title: **Building production LLM agents (model-agnostic)**
Skill id: `building-agents` · origin: `risco`
Spec date: 2026-06-01 (research folded in below; all vendor facts dated)

This is the design contract for the skill, not the skill itself. It pins every
heading, every code example, and the verify.sh contract so the implementation
pass is mechanical. Calibrated against the ECC skills (`agentic-engineering`,
`agent-harness-construction`, `autonomous-agent-harness`, `ai-first-engineering`,
`agent-eval`, `eval-harness`, `mcp-server-patterns`, `context-budget`,
`prompt-optimizer`, `cost-aware-llm-pipeline`) and the house style of
`risco-project-harness`. ECC is the floor.

---

## 0. Research snapshot (dated facts to embed, all clearly marked "as of 2026-06")

These are the *only* vendor specifics allowed in the skill, and every one must
carry an inline `(as of 2026-06; verify via …)` marker. The skill body stays
model-agnostic; specifics live in dated tables in `references/provider-abstraction.md`
and `references/evals-and-observability.md`.

- **Anthropic** (as of 2026-06): flagship `claude-opus-4-8` (released 2026-05-28);
  default `claude-sonnet-4-6`; cheap/fast `claude-haiku-4-5`. Pricing $/MTok
  in/out: Haiku 4.5 1.00/5.00, Sonnet 4.6 3.00/15.00, Opus 4.7 5.00/25.00
  (Opus 4.8 confirm at runtime). Prompt caching −90% on cached input; Batch −50%;
  1M-token context flat-rate on Opus/Sonnet. Tool schema = `input_schema` (JSON
  Schema); structured output via tool-forcing or `output_format`. SDK `anthropic`
  (Python) / `@anthropic-ai/sdk`.
- **OpenAI** (as of 2026-06): flagship `gpt-5.5`; `gpt-5.4`, `gpt-5.4-mini`,
  `gpt-5.4-nano`; `gpt-5.2-codex`. Pricing $/MTok: 5.5 5.00/30.00, 5.4 2.50/15.00,
  5.2-codex 1.75/14.00; cached input −90%; >272K-token prompts billed 2× in/1.5× out.
  Tools via `tools=[{"type":"function",…}]`; **Structured Outputs** with strict
  JSON Schema; prefer the **Responses API** for agent/tool loops. SDK `openai`.
- **Google Gemini** (as of 2026-06): `gemini-3.5-flash`, `gemini-3.1-pro` (GA
  2026-02-19), legacy `gemini-2.5-pro`. Pricing $/MTok: 3.5-flash 1.50/9.00
  (cached 0.15); Pro paid-only since 2026-04-01. Function calling + structured
  output via `responseSchema`/`responseMimeType`; 1M-token context on Flash. SDK
  `google-genai` (the unified `google.genai` client; the old `google-generativeai`
  is deprecated).
- **OSS / OpenAI-compatible**: vLLM, Ollama, TGI, and aggregators expose the
  OpenAI Chat Completions shape. **litellm** (`v1.85.x` as of 2026-06; pin exact
  version, avoid the quarantined `1.82.7/1.82.8`) gives one OpenAI-format call
  surface to 100+ providers + Router fallbacks/budgets. Use it as the *reference
  implementation* of the normalization layer, not a hard dependency.
- **MCP**: current stable spec `2025-11-25`; release candidate `2026-07-28`
  introduces a **stateless protocol core**, Extensions, Tasks, MCP Apps. Transports:
  **stdio** (local) and **Streamable HTTP** (remote; SSE legacy only). SDKs:
  `@modelcontextprotocol/sdk` (TS), `mcp` (Python, FastMCP-style). Pin spec date.
- **Observability**: OpenTelemetry **GenAI semantic conventions** (`gen_ai.*`
  spans/attributes) are the vendor-neutral standard; Langfuse / Phoenix / Braintrust
  consume them. Emit OTel spans; treat dashboards as swappable backends.

Rule baked into SKILL.md: **"Model names and prices rot. Never hardcode them in
app logic — resolve from config/registry, and re-verify the dated tables before
quoting a number."**

---

## 1. Purpose & precise trigger

**Purpose (one line):** Build production LLM agents that are model-agnostic by
construction — a thin provider adapter, a disciplined agent loop, schema-validated
tools, provider-neutral RAG, eval gates, OTel tracing, and (optionally) an MCP
server — so swapping OpenAI ↔ Anthropic ↔ Gemini ↔ OSS is a config change, not a
rewrite.

**`description` frontmatter (trigger-rich, starts with "Use when"):**
> Use when designing or building an LLM agent, tool-using system, RAG pipeline,
> eval harness, or MCP server in this repo — across any provider (OpenAI,
> Anthropic, Google Gemini, or OSS via OpenAI-compatible endpoints / litellm).
> Triggers: "build an agent", "add tool calling / function calling", "structured
> JSON output", "RAG / retrieval / embeddings / rerank", "agent loop / ReAct /
> orchestrator-worker / multi-agent", "LLM eval / golden set / LLM-as-judge /
> regression gate", "prompt caching / model routing / token budget / cost
> control", "trace / observability for LLM calls", "build an MCP server", or
> "make our LLM code provider-agnostic / swap models". FastAPI/Python, Next.js,
> Go, Flutter, Postgres stacks.

**When to use**
- Starting any LLM feature that will see production traffic (not a throwaway script).
- Code is hardwired to one SDK and the team wants to swap/route models or add a fallback.
- Adding tools/function calling, structured outputs, or streaming to an LLM call.
- Standing up RAG over Postgres/`pgvector` or an external vector store.
- Building an eval harness / regression gate / CI quality gate for prompts or agents.
- Adding tracing, cost tracking, caching, or model routing/cascades.
- Building or hardening an MCP server.

**When NOT to use (delegate / skip)**
- One-shot throwaway prompt with no tools, no eval, no production path → just call the SDK.
- Pure prompt-wording improvement with no architecture → that's prompt engineering, not this.
- The work is Anthropic-SDK-specific tuning (prompt caching internals, thinking,
  batch) in a file that *only* imports `anthropic` → defer to the repo's
  `claude-api` skill; this skill stays multi-provider.
- Workspace scaffolding / `01-TOOLS`/`02-DOCS` layout → `risco-project-harness`.
- Picking *which coding agent* (Claude Code vs Aider) → that's agent-eval territory, not this.
- No retrieval, no tools, no loop, no evals at all → you don't need an agent; say so.

---

## 2. SKILL.md outline (every heading, what it delivers, code shown)

Target length ~360 lines. Dense, directive, copy-pasteable. Progressive
disclosure: principles + the smallest correct adapter + decision tables live
here; everything long is pushed to `references/`.

### Frontmatter
`name`, `description` (above), `origin: risco`. No `tools:` restriction.

### `# Building production LLM agents (model-agnostic)`
Single H1. One-line purpose restated.

### `## The one rule`
> Program against a **capability interface**, never a vendor SDK. Vendor specifics
> (model id, tool schema shape, JSON mode, caching, token limits) live behind one
> adapter resolved from config. If a model name or price appears in business logic,
> it's a bug.
Plus the "names and prices rot" warning from §0.

### `## When to use / When NOT to use`
Condensed version of §1 as two tight bullet lists, including the explicit
delegations to `claude-api`, `risco-project-harness`, agent-eval.

### `## Decision rules (read before writing code)`
Six numbered rules an agent applies before touching code:
1. Adapter first — define the `LLMProvider` Protocol before any provider call.
2. Smallest loop that works — single-agent tool loop before multi-agent; ReAct
   only when the path is uncertain; plan-execute when steps are knowable.
3. Tools are typed contracts — Pydantic/Zod schema + validation + idempotency key
   on every side-effecting tool; no catch-all tools.
4. Retrieve, don't stuff — RAG when ground truth lives in data; cite or refuse.
5. Eval before ship — a golden set + regression gate in CI, or it's not production.
6. Cheapest model that passes the eval — route/cascade up, never default to flagship.

### `## Architecture at a glance`
One ASCII diagram: `Caller → Agent loop → [Provider adapter ↔ {OpenAI|Anthropic|
Gemini|OSS}] + [Tool registry → sandboxed tools] + [Retriever → vector store] +
[Tracer → OTel] + [Eval gate (CI)]`. Mirrors the house-style diagram in
`risco-project-harness`. Labels point to the reference file owning each box.

### `## The provider adapter (the heart of the skill)`
The ONE big inline code block: a complete, runnable, Python 3.12 + Pydantic v2
`LLMProvider` `Protocol` with a normalized request/response model and **two**
concrete adapters (OpenAI + Anthropic) showing the quirk-normalization, plus a
`get_provider(name)` factory resolving from env/config. ~70–90 lines. This is the
copy-paste payload; Gemini + OSS/litellm adapters and streaming/tool-result
plumbing are pushed to `references/provider-abstraction.md`.

Shows normalization of: messages (role mapping), system prompt (top-level vs first
message), tool schema (`tools[].function` vs `input_schema`), structured output
(strict JSON Schema vs tool-forcing vs `responseSchema`), and a `Usage`/cost field.

### `## Good vs Bad`
Three side-by-side contrasts (fenced, language-tagged), each ~8–12 lines:
- **Bad:** `client = OpenAI(); client.chat.completions.create(model="gpt-5.5", …)`
  scattered across handlers. **Good:** `provider = get_provider(settings.llm)` +
  `provider.complete(req)`.
- **Bad:** hand-built JSON parsing of model output with try/except. **Good:**
  `response_format` strict schema → validated Pydantic model.
- **Bad:** `while True:` tool loop with no max-steps/timeout/idempotency. **Good:**
  bounded loop with step cap, per-tool timeout, idempotency keys (points to
  agent-loops reference).

### `## Tools & structured output (minimum viable)`
Smallest correct tool definition: a Pydantic args model → JSON Schema → registered
tool with a validating dispatcher and a `ToolResult{status,summary,data,
next_actions}` envelope (echoing agent-harness-construction's observation contract,
but concrete code). One FastAPI-flavored example since the repo is FastAPI. Deep
schema/validation/sandboxing → `references/tools-and-rag.md`.

### `## RAG in 30 lines (provider-agnostic embeddings)`
A compact `pgvector`-on-Postgres-16 retrieve→(optional rerank)→cite snippet using
the same provider-agnostic `embed()` interface. Chunking/hybrid/rerank/citation
depth → `references/tools-and-rag.md`. Chosen because the repo runs Postgres.

### `## Evals & cost gates (the production line)`
A ~20-line offline eval-runner sketch: golden set (JSONL) → run candidate →
graders (exact / schema / LLM-judge) → metrics (accuracy, faithfulness, p95
latency, $/task) → exit non-zero if below threshold (CI gate). Plus the model-routing
cascade one-liner (`route(task) → cheapest model whose eval passes`). Depth →
`references/evals-and-observability.md`.

### `## Observability (OTel GenAI, vendor-neutral)`
~12-line snippet: wrap `provider.complete` in an OTel span emitting `gen_ai.system`,
`gen_ai.request.model`, token counts, cost, latency. Note Langfuse/Phoenix are
swappable OTLP backends. Depth → reference.

### `## MCP: when and the smallest server`
Two-line decision: **native tools** when the agent and tools share a process/repo;
**MCP** when tools must be reused across clients/teams or run out-of-process.
Smallest FastMCP (Python) stdio server with one validated tool + one resource.
Transports, HTTP, auth, stateless-core (2026-07-28 RC) → `references/mcp-servers.md`.

### `## Anti-patterns → STOP` (table)
House-style rationalization table. Columns: **Rationalization | Reality**. ≥10 rows, e.g.:
| "I'll just call the OpenAI SDK directly, we'll never switch" | Adapter is ~40 lines; retrofitting it across 30 call-sites later is a rewrite. Adapter first. |
| "JSON output is usually valid, I'll parse it" | "Usually" = pages at 3am. Use strict structured output + schema validation. |
| "The agent loop works, I don't need a step cap" | Unbounded loops burn budget and wedge on errors. Cap steps, timeouts, and budget. |
| "One mega-tool that takes a freeform command is flexible" | It's unobservable and unsafe. Narrow typed tools with idempotency keys. |
| "We can eval by eyeballing outputs" | Vibes don't gate CI. Golden set + graders + threshold or it's not production. |
| "Default everything to the flagship model, it's smartest" | 5–20× cost for no measured gain. Route to the cheapest model that passes eval. |
| "Stuff the whole doc in the prompt instead of RAG" | Blows context + cost and still hallucinates. Retrieve + cite + refuse. |
| "Retry on every exception" | Retrying a 400/401 wastes budget. Retry only transient (429/5xx/timeout) with backoff+jitter. |
| "Hardcode the model name, it's fine" | Names rot (Opus 4.7→4.8 in weeks). Resolve from config/registry. |
| "MCP for everything" | In-process native tools are simpler/faster when reuse isn't needed. MCP only for cross-client reuse. |
| "Tool results just return the raw API blob" | Give the model `status/summary/next_actions`; raw blobs waste context and stall recovery. |
| "Prompt caching is Anthropic-only so skip caching" | Each provider has its own caching/dedup; abstract it, don't skip it. |

### `## Quick reference` (table)
Compact lookup: **Task → Do this → Reference**. Rows: define provider →
`LLMProvider` Protocol → provider-abstraction.md; add a tool → Pydantic args +
ToolResult → tools-and-rag.md; structured output → strict schema per provider →
provider-abstraction.md; build the loop → bounded perceive/decide/act/observe →
agent-loops-and-harness.md; multi-agent → orchestrator-worker → agent-loops; RAG →
pgvector + rerank + cite → tools-and-rag.md; eval gate → golden set + graders +
CI threshold → evals-and-observability.md; trace → OTel GenAI spans →
evals-and-observability.md; cut cost → cache + route + batch → evals-and-observability.md;
MCP server → FastMCP stdio/HTTP → mcp-servers.md.

### `## verify.sh`
One paragraph: what `scripts/verify.sh` checks (lints example code, dry-runs eval
smoke), that it skips missing tools with a yellow warning, and the exact invocation
(`bash scripts/verify.sh` from project root). Contract detailed in §4.

### `## See Also`
Links to sibling skills: `claude-api` (Anthropic-specific tuning),
`risco-project-harness` (workspace `01-TOOLS`/`02-DOCS`), `deep-research`
(research harness pattern), and the ECC analogues by name
(agent-harness-construction, eval-harness, cost-aware-llm-pipeline, mcp-server-patterns,
context-budget) so a reader can cross-reference.

---

## 3. references/ files — outline + key code per file

Each 200–500 lines, one sub-topic, real runnable code, language-tagged fences,
dated vendor notes.

### 3.1 `references/provider-abstraction.md` (~420 lines)
**Goal:** the full normalization layer so swapping models is config.
Outline:
1. **The interface** — full `LLMProvider` Protocol + Pydantic v2 models
   (`Message`, `ToolSpec`, `CompletionRequest`, `CompletionResponse`, `Usage`,
   `ToolCall`). Async-first (`async def complete`/`stream`).
2. **Four adapters, full code** — OpenAI (Responses API + Chat Completions
   fallback), Anthropic (`input_schema`, system top-level, `cache_control`),
   Gemini (`google-genai`, `responseSchema`), OSS via litellm / any
   OpenAI-compatible base_url. Each adapter ~50–70 lines.
3. **Quirk matrix (dated 2026-06 table)** — per provider: tool-schema shape,
   structured-output mechanism, system-prompt placement, streaming event shape,
   prompt-caching support, max context, JSON-mode strictness. With the
   "verify before quoting" disclaimer.
4. **Structured / JSON output** — strict JSON Schema (OpenAI), tool-forcing
   (Anthropic), `responseSchema` (Gemini); a single `complete_structured(req,
   schema: type[BaseModel]) -> BaseModel` that picks the right mechanism and
   validates; retry-on-invalid pattern.
5. **Tool/function calling normalization** — convert one `ToolSpec` list into each
   provider's wire format; parse each provider's tool-call events back into the
   normalized `ToolCall`; feed tool results back in each provider's expected role.
6. **Streaming** — normalized async iterator of `StreamEvent{type: text|tool_call|
   usage|done}`; per-provider event mapping.
7. **Token & context-window management** — provider-agnostic token counting
   (tiktoken/`count_tokens` per provider, with fallback heuristic chars/4),
   context-budget trimming (system invariant, drop oldest turns, summarize),
   pre-flight "will this fit" guard.
8. **Sampling params** — normalize `temperature/top_p/max_tokens/stop` and note
   which provider ignores/renames which (dated).
9. **Config-driven selection** — `settings.llm = "anthropic:claude-sonnet-4-6"`
   parsed into adapter+model; env precedence; a model registry dict so app code
   says `route("default"|"cheap"|"smart")` not raw ids.
10. **litellm note** — when to adopt litellm/its proxy as the adapter vs hand-roll;
    pin `v1.85.x`, the 2026-03 supply-chain note, Router fallbacks/budgets.

### 3.2 `references/agent-loops-and-harness.md` (~470 lines)
**Goal:** the loop and orchestration patterns.
Outline:
1. **The loop** — `perceive → decide → act → observe`, as a bounded async loop
   with `max_steps`, per-step timeout, budget cap, and a typed `AgentState`.
   Full ~60-line runnable single-agent tool loop using the §3.1 provider.
2. **ReAct vs plan-execute** — when each; code for both; hybrid (plan then typed
   execution), echoing agent-harness-construction but with code.
3. **Observation design** — the `ToolResult{status,summary,data,next_actions,
   artifacts}` envelope and *why* (recovery + context economy).
4. **Error recovery contract** — per error: root-cause hint, safe-retry
   instruction, explicit stop condition; classify transient vs permanent;
   backoff+jitter; circuit-breaker on repeated identical failures.
5. **Determinism & idempotency** — seed/temperature pinning for evals,
   idempotency keys for side effects, replayable transcripts, content-addressed
   tool-call dedup.
6. **Retries / timeouts / guardrails** — wall-clock + step + token budgets;
   input/output guardrails (PII, injection, schema); a guardrail decorator.
7. **Multi-agent** — orchestrator-worker, parallel fan-out (`asyncio.gather` with
   a semaphore), pipeline/sequential, when to use each, and the cost/latency
   tradeoff. Concrete orchestrator dispatching typed subagents.
8. **Subagents** — spawning a constrained sub-loop with a narrowed tool set and
   its own budget; passing results back as a single summarized observation.
9. **Human-in-the-loop** — approval gates on high-risk tools (deploy, migration,
   spend), a pause/resume interrupt, and surfacing diffs for sign-off.
10. **Checkpoint / resume** — persist `AgentState` (JSON to Postgres/`jsonb` or
    file) after each step; resume from last checkpoint; idempotent replay.
11. **Anti-patterns** — unbounded loops, hidden global state, tool sprawl,
    swallowing errors, no budget.

### 3.3 `references/tools-and-rag.md` (~480 lines)
**Goal:** tools done safely + provider-agnostic RAG + memory.
Outline:
1. **Tool schema design** — narrow typed inputs (Pydantic v2), stable names,
   deterministic output shapes; JSON Schema generation; descriptions the model
   reads; enum over freeform; no catch-all tools.
2. **Validation** — validate args *before* execution; reject with a structured,
   model-readable error; never trust model-supplied paths/ids.
3. **Side-effect safety & sandboxing** — allowlist commands, path jails, network
   egress controls, dry-run mode, read-only by default; running untrusted tool
   code in a subprocess/container; the FastAPI dependency-injection pattern for
   scoping a tool's DB session.
4. **Idempotency** — idempotency keys, dedup table in Postgres, safe-retry
   semantics for `POST`-like tools.
5. **RAG — chunking** — token-aware chunking with overlap, structure-aware
   splitting (headings/code), metadata per chunk; Go and Python variants.
6. **Embeddings (provider-agnostic)** — `embed(texts) -> list[vector]` interface
   behind the §3.1 provider; dimension/normalize handling; batching; cost note.
7. **Vector store — pgvector on Postgres 16** — DDL with `vector` column +
   HNSW index, upsert, ANN query with metadata filter; SQLAlchemy 2.0 async; why
   Postgres-first for this repo. External stores (Qdrant/Pinecone) as a swappable
   `Retriever` interface.
8. **Hybrid search** — combine `pgvector` ANN + Postgres full-text (`tsvector`) +
   Reciprocal Rank Fusion; SQL + Python fusion code.
9. **Reranking** — cross-encoder / provider rerank endpoint behind a `Reranker`
   interface; when reranking pays off.
10. **Citation & faithfulness** — return chunk ids/spans, force the model to cite,
    refuse when retrieval is empty/low-score; a citation-validation grader.
11. **Memory** — short-term (rolling window + summarization), long-term (vector +
    structured facts in Postgres), retrieval of memory as just-another-tool;
    write-policy (what's worth persisting) and forgetting/TTL.

### 3.4 `references/evals-and-observability.md` (~470 lines)
**Goal:** the production line — measure, gate, trace, control cost.
Outline:
1. **Eval-first** — define success criteria before building; capability vs
   regression evals (concept from eval-harness, but with a runnable harness).
2. **Golden sets** — JSONL schema (`input`, `expected`, `metadata`), versioning
   as fixtures, building from real traffic, avoiding train/eval leakage.
3. **Graders** — exact/code grader, schema/rule grader, **LLM-as-judge** (rubric
   prompt, pairwise + pointwise, judge-model independence, bias mitigation,
   calibration against human labels). Full judge implementation using the §3.1
   provider so the judge is itself provider-agnostic.
4. **Metrics** — accuracy/pass@k/pass^k, faithfulness/groundedness, answer
   relevance, cost/task, p50/p95 latency, tool-call validity rate. Formulas + code.
5. **Eval runner** — full async runner: load golden set → run candidate →
   grade → aggregate → write report (JSON + markdown) → exit code from threshold.
   This is the file the verify.sh smoke dry-runs.
6. **Regression gates in CI** — GitHub Actions snippet: run evals on PR, fail if
   any metric regresses past tolerance vs baseline; store baseline; flaky-grader
   guardrail.
7. **Tracing (OTel GenAI)** — full setup emitting `gen_ai.*` spans/attributes;
   span per LLM call + per tool + per agent step; linking to a Langfuse/Phoenix
   OTLP exporter; trace-id propagation through the agent loop.
8. **Cost & latency control** —
   - **Caching:** prompt caching where supported (Anthropic `cache_control`,
     OpenAI/Gemini automatic cached input) abstracted behind the adapter; plus an
     app-level **semantic cache** (embed request → vector lookup → return prior
     answer above similarity threshold) with code.
   - **Batching:** provider batch APIs (−50% class) for offline workloads.
   - **Model routing / cascades:** classify task → cheapest model; escalate only
     on low confidence / failed self-check. Full `route()` + cascade code.
   - **Budgets:** immutable `CostTracker` (frozen dataclass, like
     cost-aware-llm-pipeline but extended with per-tenant budgets and a hard stop).
9. **Anti-patterns** — overfitting prompts to the eval set, happy-path-only evals,
   chasing accuracy while cost/latency drift, flaky graders in release gates,
   tracing PII without redaction.

### 3.5 `references/mcp-servers.md` (~400 lines)
**Goal:** build an MCP server correctly, decide MCP vs native.
Outline:
1. **MCP vs native tools** — decision table: in-process/single-repo → native;
   cross-client/cross-team/out-of-process/needs-its-own-deploy → MCP. Cost of MCP
   (schema tokens, transport, ops) noted (ties to context-budget).
2. **Concepts** — tools (actions), resources (read-only data), prompts (templates);
   the request/response lifecycle; dated note that spec is `2025-11-25`, RC
   `2026-07-28` makes the core stateless.
3. **Python server (FastMCP)** — full server: `mcp` SDK, `@mcp.tool` with Pydantic
   validation, `@mcp.resource("uri://…")`, `@mcp.prompt`; stdio entrypoint.
4. **TypeScript server** — full `@modelcontextprotocol/sdk` `McpServer` with Zod
   schemas, a tool, a resource; stdio + Streamable HTTP entrypoints. (TS because
   the repo runs Next.js.)
5. **Transports** — stdio (local, Claude Desktop/Code) vs **Streamable HTTP**
   (remote, horizontal scale, the stateless-core direction); SSE legacy only;
   `.well-known` capability discovery note (RC).
6. **Security** — auth on HTTP transport (OAuth/bearer), input validation, no raw
   stack traces to the model, rate limiting, egress controls, tool allowlisting,
   the "confused deputy" risk and least-privilege tokens.
7. **Testing & debugging** — MCP Inspector, a contract test that lists tools and
   round-trips a call; idempotency check.
8. **Packaging** — pin SDK + spec version in manifest; config snippet for
   registering the server with a client.

---

## 4. verify.sh contract

Path: `skills/building-agents/scripts/verify.sh`. Executable, idempotent,
END-USER runs it inside THEIR project root. **Do not execute it in this repo.**

**Header:** `#!/usr/bin/env bash` then `set -euo pipefail`. Top usage comment:
```text
# Usage: bash scripts/verify.sh
# Lints example agent code and dry-runs the eval smoke test in THIS project.
# Detects each tool; missing tools print a yellow WARN and are skipped (not failures).
# Exit 0 = all present checks passed (or only skips). Non-zero = a real failure.
```

**Behavior contract (exact tools, order, skip/fail):**
1. Setup: define `yellow`/`red`/`reset` color vars (guard for non-TTY), a
   `warn()` (yellow, no exit), `fail()` (red, sets `rc=1`), and a `have()` helper
   = `command -v "$1" >/dev/null 2>&1`. Track `rc=0`.
2. **Python lint** — if `have ruff`: discover example dirs (prefer
   `examples/`, `agents/`, `src/` if present; else `.` excluding `node_modules`,
   `.venv`, `dist`, `build`) and run `ruff check` on `*.py`. On non-zero → `fail`.
   If no `ruff` → `warn "ruff not found; skipping Python lint"`. If `ruff` present
   but zero `.py` files → info, skip.
3. **Python typecheck (optional/soft)** — if `have mypy` AND a `mypy`/`pyproject`
   config exists: run `mypy` on the same dirs; non-zero → `fail`. Else `warn`/skip.
   (Soft: only runs if config present, to avoid false positives.)
4. **TS/JS check** — if `have npx` and a `tsconfig.json` exists: run
   `npx --no-install tsc --noEmit`; non-zero → `fail`. Elif `have node` and `*.mjs`/
   `*.js` examples exist: `node --check` each. Else `warn "no tsc/node; skipping TS check"`.
5. **Go vet (only if module present)** — if `have go` and `go.mod` exists:
   `go vet ./...`; non-zero → `fail`. Else skip silently if no `go.mod`,
   `warn` if `go.mod` but no `go`.
6. **Eval smoke dry-run** — look for an eval entrypoint in priority order:
   `evals/run.py`, `evals/smoke.py`, `scripts/eval_smoke.py`, or an
   `eval`/`evals` script in `package.json`. If found and `have python`/`node`:
   run it in **dry-run mode** (`--dry-run`/`--smoke` flag, or `EVAL_DRY_RUN=1`
   env) so it must not hit live APIs; non-zero → `fail`. If no eval entrypoint →
   `warn "no eval smoke found; skipping"` (skip, not fail).
7. **Markdown lint (soft)** — if `have markdownlint` (or `markdownlint-cli2`):
   lint `*.md` examples; non-zero → `warn` only (never fail; docs style is advisory).
8. Final: if `rc -ne 0` print red `verify.sh: FAILED` and `exit "$rc"`; else print
   green `verify.sh: OK` and `exit 0`.

**Guarantees:** never fails on a *missing* tool (only yellow warn + skip); fails
only on a real lint/typecheck/vet/eval error; idempotent (read-only — never writes
files, never installs anything; uses `--no-install` for npx). After writing,
`chmod +x scripts/verify.sh`.

---

## 5. Quality differentiators (why this beats the ECC equivalents)

1. **True model-agnosticism with running code, not advice.** ECC
   `cost-aware-llm-pipeline` and `agent-harness-construction` assume/illustrate one
   vendor; this skill ships a complete four-provider `LLMProvider` adapter +
   normalization (tools, structured output, streaming, caching, token counting) so
   "swap the model" is a config string. None of the ECC skills give a working
   cross-provider layer.
2. **Current, dated vendor facts (2026-06).** Real model ids and prices (Opus 4.8,
   GPT-5.5, Gemini 3.5 Flash), MCP spec `2025-11-25` + `2026-07-28` stateless RC,
   OTel GenAI conventions, litellm `v1.85.x` incl. the 2026-03 supply-chain
   caveat — each carrying a "verify before quoting" marker. ECC skills cite stale
   `claude-sonnet-4-6`/`gpt`/no MCP versioning.
3. **One coherent system, not four disconnected skills.** ECC splits eval,
   harness, cost, MCP, context-budget into separate islands. This unifies them: the
   *same* provider interface powers the agent loop, the RAG embedder, the
   LLM-as-judge, and the cost router — so the examples compose.
4. **Production-grade, stack-matched code.** FastAPI DI for tool scoping,
   `pgvector` on Postgres 16 with HNSW + hybrid RRF, Pydantic v2, async-first,
   OTel spans, CI regression gate — concrete to the user's real stack (FastAPI/
   Next.js/Go/Flutter/Postgres), where ECC stays prose/pseudocode.
5. **Safety and recovery as code.** Bounded loops (step/time/token/budget caps),
   idempotency keys + Postgres dedup, guardrails, HITL approval gates, sandboxed
   tools, circuit breakers, checkpoint/resume — ECC describes the *contract*; this
   implements it.
6. **A real CI quality gate.** A runnable eval harness (golden JSONL → graders →
   thresholds → exit code) plus a GitHub Actions regression gate and a verify.sh
   that dry-runs it offline. ECC `eval-harness`/`agent-eval` describe metrics and
   YAML but stop short of a provider-agnostic runnable judge + gate.
7. **Cost control that's measured, not asserted.** Semantic cache (embed→lookup),
   abstracted prompt caching across providers, model cascades gated by *eval pass*
   not vibes, immutable per-tenant budgets with hard stops — extends
   cost-aware-llm-pipeline into a closed loop with the evals.
8. **Crisp MCP-vs-native decision + dual-language servers.** Decision table tied to
   context-budget token cost, plus full Python (FastMCP) *and* TypeScript
   (`@modelcontextprotocol/sdk`) servers with Streamable HTTP + auth — beyond
   `mcp-server-patterns`, which deliberately omits concrete signatures.

---

## Artifact checklist (for the build pass)
- `skills/building-agents/SKILL.md` (~360 lines, headings per §2).
- `skills/building-agents/references/provider-abstraction.md` (§3.1).
- `skills/building-agents/references/agent-loops-and-harness.md` (§3.2).
- `skills/building-agents/references/tools-and-rag.md` (§3.3).
- `skills/building-agents/references/evals-and-observability.md` (§3.4).
- `skills/building-agents/references/mcp-servers.md` (§3.5).
- `skills/building-agents/scripts/verify.sh` (§4) + `chmod +x`.
All code blocks language-tagged and runnable in context; no TODOs/placeholders/"etc.";
one H1 per file; vendor specifics dated and confined to the tables in §0/§3.1/§3.4.
