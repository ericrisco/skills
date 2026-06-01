# skills

Eric Risco's personal collection of agent skills for [skills.sh](https://skills.sh).

[![skills.sh](https://skills.sh/b/ericrisco/skills)](https://skills.sh/ericrisco/skills)

## Install

Install everything to your active agent (Claude Code, Codex, Cursor, etc.):

```bash
npx skills add ericrisco/skills --all
```

Install a single skill:

```bash
npx skills add ericrisco/skills --skill risco-project-harness
```

List what's in this catalog without installing:

```bash
npx skills add ericrisco/skills --list
```

## Skills in this catalog

### [risco-project-harness](skills/risco-project-harness/)

Workspace bootstrapper / brownfield auditor. Scans any project, detects
external provider integrations from 100+ catalog entries (Stripe, OpenAI,
Anthropic, Supabase, Sentry, Twilio, …), and — only with explicit
consent — scaffolds a canonical `01-TOOLS/` layer (one folder per
provider, each with a working `probar_conexion` smoke-test) plus a
`02-DOCS/` **chaos→knowledge engine** (Karpathy-style, fully embedded —
no external skill dependency).

The `02-DOCS/` layer is the second-brain pattern, domain-agnostic and
multiformat: drop **any raw file** (PDF, image, CSV, JSON, notes, html)
into `inbox/` and an **Inbox Sweep** — the agent "going for a walk" —
extracts it, classifies it by content into topics (`finanzas/`, `legal/`,
`crm/`…), cross-links it, and compiles it into a living wiki that
**self-improves** with every file (Maintenance Pass → Micro-Improve →
Deep Improve, schedulable via cron). The app on top consumes the
knowledge model, not the loose documents.

Also generates the root `CLAUDE.md` and `AGENTS.md`, and migrates legacy
`XX-*` numbered folders into the canonical structure.

Triggers: `"audit my project"`, `"bootstrap workspace"`, `"set up
01-TOOLS and 02-DOCS"`, `"risco harness"`, `"project harness"`,
`"procesa el inbox"`, `"sal a pasear"`.

## Stack skills

A tight set of best-in-class skills for the Risco stack — FastAPI/Python,
Next.js, Go, Flutter, PostgreSQL — plus cross-cutting design, marketing,
presentations, course storytelling, security, agents and deployment. Each is
**hybrid**: a focused `SKILL.md`, deep-dive
`references/`, and an executable `scripts/verify.sh` quality gate you run
inside your own project. Testing, security and production guidance are
embedded in each stack skill rather than scattered.

### [fastapi](skills/fastapi/)

Build, review, test, secure and ship FastAPI / async Python services —
Python 3.12+, Pydantic v2, async SQLAlchemy 2.0, DI, JWT/OAuth2, pytest, and
production settings. `references/`: testing, database, security, production.

### [nextjs](skills/nextjs/)

Next.js 15 App Router done right — Server vs Client Components, server
actions, route handlers, caching/revalidation, React 19, end-to-end TS,
vitest + Playwright, security and Core Web Vitals. `references/`: react,
data-and-caching, testing, performance, security.

### [go](skills/go/)

Idiomatic Go HTTP services — errors, concurrency (context, errgroup, no
leaks), net/http 1.22 routing, slog, table-driven `-race` tests, govulncheck.
`references/`: concurrency, http-services, testing.

### [postgresdb](skills/postgresdb/)

Engine-level PostgreSQL 16 — schema & type correctness, the right index,
reading `EXPLAIN (ANALYZE, BUFFERS)`, keyset pagination, zero-downtime
migrations, RLS, pooling, partitioning, backups. `references/`:
schema-and-indexing, query-optimization, migrations, operations-and-security.

### [flutter](skills/flutter/)

Flutter / Dart 3 apps — feature-first clean architecture, Riverpod (and Bloc),
Material 3 tokens, go_router, widget/golden/integration tests, rebuild &
jank performance. `references/`: architecture-and-state, ui-and-navigation,
testing, performance.

### [design](skills/design/)

Research-first product design and high-converting landing pages — grounds in
the project's brand study (links root `CLAUDE.md` → `02-DOCS/wiki/brand/`, and
asks until complete if missing), researches current **2026 UX/UI trends**, then
ships a premium, accessible (WCAG 2.2 AA), fast (LCP/INP/CLS) visual system with
Tailwind + Next.js. `references/`: research-method, visual-system,
landing-anatomy-and-cro, copywriting-frameworks, motion-and-interaction,
trends-2026, brand-grounding.

### [marketing](skills/marketing/)

The words, not the pixels — conversion copywriting for landings and web pages.
Grounds in the brand study first (links root `CLAUDE.md` → `02-DOCS/wiki/brand/`,
asking for voice samples and positioning until complete), then writes specific,
benefit-led, on-brand copy: value props, hero/section copy, CTAs, email and
launch sequences, channel-adapted messaging. Pairs with `design` (pixels) and
`nextjs` (build). `references/`: brand-grounding, copy-frameworks, landing-copy,
campaigns-and-channels.

### [presentations](skills/presentations/)

Stunning PPTX and PDF decks, grounded in the brand study. Two pipelines —
design-led Markdown (Marp/Slidev themed from the `design` tokens, exported to
PDF + PPTX) and native editable `python-pptx` — plus deck storytelling/arcs,
slide copy (from `marketing`) and projection-grade visual design. `references/`:
storytelling-and-decks, markdown-decks, pptx-python, slide-design,
brand-grounding.

### [course-storytelling](skills/course-storytelling/)

Turn course/lesson content into teaching that lands — profiles the learner and
audience first, then runs every concept through Russell Brunson's *Expert
Secrets* machine (Epiphany Bridge, the three false beliefs, Big Domino, named
mental models, grounded analogies) into a hook → story → model → analogy →
proof → application → so-what recipe. `references/`: brunson-frameworks,
learner-grounding, mental-models, course-analysis, concept-landing-recipe.

### [building-agents](skills/building-agents/)

Build production LLM agents that are **model-agnostic by construction** — a
thin provider adapter (OpenAI ↔ Anthropic ↔ Gemini ↔ OSS as a config
change), a disciplined agent loop, schema-validated tools, provider-neutral
RAG, eval gates, OTel GenAI tracing, and an MCP server when warranted.
`references/`: provider-abstraction, agent-loops-and-harness, tools-and-rag,
evals-and-observability, mcp-servers.

### [secure-coding](skills/secure-coding/)

Transversal security — lightweight STRIDE threat modeling and the OWASP Top
10 mapped to concrete vulnerable→fixed examples in FastAPI, Go and Next.js,
plus authn/authz, secrets and supply-chain gates. `references/`:
threat-modeling, owasp-by-stack, authn-authz, secrets-and-supply-chain.

### [deployment](skills/deployment/)

Source → hardened container → green CI/CD → live: multi-stage Dockerfiles per
stack, GitHub Actions (matrix, caching, OIDC, security gates), and Coolify
self-hosted deploys (zero-downtime, secrets flow, rollbacks). `references/`:
dockerfiles-by-stack, github-actions, coolify.

## Skill format

Each skill is a directory under `skills/<name>/` with at minimum a
`SKILL.md` that has YAML frontmatter:

```yaml
---
name: my-skill
description: Use when [specific triggering conditions]
---
```

The full spec lives at [agentskills.io/specification](https://agentskills.io/specification).

## Contributing

This is a personal catalog. Bug reports welcome via GitHub issues. PRs
fixing detector patterns, provider endpoints, or English typos are
appreciated.

## License

MIT. See [LICENSE](LICENSE).
