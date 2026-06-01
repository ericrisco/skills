# skills

Eric Risco's personal collection of agent skills for [skills.sh](https://skills.sh).

[![skills.sh](https://skills.sh/b/ericrisco/skills)](https://skills.sh/ericrisco/skills)

There are two ways to install: as **Claude Code plugins** (the `rsc-skills`
marketplace, namespaced as `/<plugin>:<skill>`) or with **`npx skills`** (the
flat catalog). Both read the same `skills/<name>/` directories — nothing is
duplicated.

## Install as a plugin

This repo is a Claude Code **plugin marketplace** named `rsc-skills`. Add it
once, then install only the bundles you want.

```bash
# 1. add the marketplace (from inside Claude Code)
/plugin marketplace add ericrisco/skills

# 2. install the bundles you need
/plugin install rsc-core@rsc-skills       # init + harness
/plugin install rsc-backend@rsc-skills    # fastapi + go + postgresdb
/plugin install rsc-frontend@rsc-skills   # nextjs + flutter + design
/plugin install rsc-content@rsc-skills    # marketing + presentations + course-storytelling
/plugin install rsc-agents@rsc-skills     # building-agents
/plugin install rsc-ops@rsc-skills        # secure-coding + deployment
```

Once a bundle is installed, its skills are **namespaced under the plugin name**
and invoke as `/<plugin>:<skill>`:

```text
/rsc-core:init                  /rsc-backend:fastapi      /rsc-frontend:nextjs
/rsc-core:harness               /rsc-backend:go           /rsc-frontend:flutter
                                /rsc-backend:postgresdb   /rsc-frontend:design

/rsc-content:marketing          /rsc-agents:building-agents
/rsc-content:presentations      /rsc-ops:secure-coding
/rsc-content:course-storytelling /rsc-ops:deployment
```

New here? Install `rsc-core` and run `/rsc-core:init` — it gauges your level,
figures out what you're building, recommends which other bundles to install,
and hands off to `/rsc-core:harness` to scaffold the workspace.

The six bundles map to one marketplace under `.claude-plugin/marketplace.json`;
each bundle lives at `plugins/<bundle>/` and points back at the flat
`skills/<name>/` directories, so a skill is authored once and shipped through
both install paths.

## Install with `npx skills`

Install everything to your active agent (Claude Code, Codex, Cursor, etc.):

```bash
npx skills add ericrisco/skills --all
```

Install a single skill (the flat skill name, e.g. `harness`, `fastapi`):

```bash
npx skills add ericrisco/skills --skill harness
```

List what's in this catalog without installing:

```bash
npx skills add ericrisco/skills --list
```

## Bundles & skills

The 14 skills ship as six plugin bundles. The flat `npx skills` names are the
skill names (e.g. `harness`, `fastapi`); the plugin invocations are namespaced
as `/<bundle>:<skill>`.

| Bundle | Skills |
| --- | --- |
| **rsc-core** | `init`, `harness` |
| **rsc-backend** | `fastapi`, `go`, `postgresdb` |
| **rsc-frontend** | `nextjs`, `flutter`, `design` |
| **rsc-content** | `marketing`, `presentations`, `course-storytelling` |
| **rsc-agents** | `building-agents` |
| **rsc-ops** | `secure-coding`, `deployment` |

### rsc-core

The front door and the control plane.

#### [init](skills/init/) — `/rsc-core:init`

The bootstrapper. Gauges the user's technical level first (non-technical by
default), discovers what they want to build or govern, detects greenfield vs
brownfield, recommends which `rsc-*` bundles to install (printing the exact
install commands), and hands off to `/rsc-core:harness`.

#### [harness](skills/harness/) — `/rsc-core:harness`

The workspace **control plane** (`/rsc-core:harness`). Governs a workspace —
software OR a non-code base (a company, an ops desk, a knowledge vault) —
through three parts: the `01-TOOLS/` operational tooling layer, the `02-DOCS/`
Karpathy chaos→knowledge engine, and the root Knowledge map. `/rsc-core:init`
is the bootstrap front door; this skill is the ongoing control. It starts
non-technical-first and reads/persists the user profile (technical +
accompaniment level) under `02-DOCS/wiki/harness/`. As a brownfield auditor it
scans any project, detects
external provider integrations from 100+ catalog entries (Stripe, OpenAI,
Anthropic, Supabase, Sentry, Twilio, …), and — only with explicit
consent — scaffolds a canonical `01-TOOLS/` layer (one folder per
provider, each with a working `test_connection` smoke-test) plus a
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

The remaining bundles are the stack and craft skills — a tight set of
best-in-class skills for the Risco stack plus cross-cutting design, content,
agents, security and deployment. Each is **hybrid**: a focused `SKILL.md`,
deep-dive `references/`, and an executable `scripts/verify.sh` quality gate you
run inside your own project. Testing, security and production guidance are
embedded in each skill rather than scattered.

### rsc-backend

#### [fastapi](skills/fastapi/) — `/rsc-backend:fastapi`

Build, review, test, secure and ship FastAPI / async Python services —
Python 3.12+, Pydantic v2, async SQLAlchemy 2.0, DI, JWT/OAuth2, pytest, and
production settings. `references/`: testing, database, security, production.

#### [go](skills/go/) — `/rsc-backend:go`

Idiomatic Go HTTP services — errors, concurrency (context, errgroup, no
leaks), net/http 1.22 routing, slog, table-driven `-race` tests, govulncheck.
`references/`: concurrency, http-services, testing.

#### [postgresdb](skills/postgresdb/) — `/rsc-backend:postgresdb`

Engine-level PostgreSQL 16 — schema & type correctness, the right index,
reading `EXPLAIN (ANALYZE, BUFFERS)`, keyset pagination, zero-downtime
migrations, RLS, pooling, partitioning, backups. `references/`:
schema-and-indexing, query-optimization, migrations, operations-and-security.

### rsc-frontend

#### [nextjs](skills/nextjs/) — `/rsc-frontend:nextjs`

Next.js 15 App Router done right — Server vs Client Components, server
actions, route handlers, caching/revalidation, React 19, end-to-end TS,
vitest + Playwright, security and Core Web Vitals. `references/`: react,
data-and-caching, testing, performance, security.

#### [flutter](skills/flutter/) — `/rsc-frontend:flutter`

Flutter / Dart 3 apps — feature-first clean architecture, Riverpod (and Bloc),
Material 3 tokens, go_router, widget/golden/integration tests, rebuild &
jank performance. `references/`: architecture-and-state, ui-and-navigation,
testing, performance.

#### [design](skills/design/) — `/rsc-frontend:design`

Research-first product design and high-converting landing pages — grounds in
the project's brand study (links root `CLAUDE.md` → `02-DOCS/wiki/brand/`, and
asks until complete if missing), researches current **2026 UX/UI trends**, then
ships a premium, accessible (WCAG 2.2 AA), fast (LCP/INP/CLS) visual system with
Tailwind + Next.js. `references/`: research-method, visual-system,
landing-anatomy-and-cro, copywriting-frameworks, motion-and-interaction,
trends-2026, brand-grounding.

### rsc-content

#### [marketing](skills/marketing/) — `/rsc-content:marketing`

The words, not the pixels — conversion copywriting for landings and web pages.
Grounds in the brand study first (links root `CLAUDE.md` → `02-DOCS/wiki/brand/`,
asking for voice samples and positioning until complete), then writes specific,
benefit-led, on-brand copy: value props, hero/section copy, CTAs, email and
launch sequences, channel-adapted messaging. Pairs with `design` (pixels) and
`nextjs` (build). `references/`: brand-grounding, copy-frameworks, landing-copy,
campaigns-and-channels.

#### [presentations](skills/presentations/) — `/rsc-content:presentations`

Stunning PPTX and PDF decks, grounded in the brand study. Two pipelines —
design-led Markdown (Marp/Slidev themed from the `design` tokens, exported to
PDF + PPTX) and native editable `python-pptx` — plus deck storytelling/arcs,
slide copy (from `marketing`) and projection-grade visual design. `references/`:
storytelling-and-decks, markdown-decks, pptx-python, slide-design,
brand-grounding.

#### [course-storytelling](skills/course-storytelling/) — `/rsc-content:course-storytelling`

Turn course/lesson content into teaching that lands — profiles the learner and
audience first, then runs every concept through Russell Brunson's *Expert
Secrets* machine (Epiphany Bridge, the three false beliefs, Big Domino, named
mental models, grounded analogies) into a hook → story → model → analogy →
proof → application → so-what recipe. `references/`: brunson-frameworks,
learner-grounding, mental-models, course-analysis, concept-landing-recipe.

### rsc-agents

#### [building-agents](skills/building-agents/) — `/rsc-agents:building-agents`

Build production LLM agents that are **model-agnostic by construction** — a
thin provider adapter (OpenAI ↔ Anthropic ↔ Gemini ↔ OSS as a config
change), a disciplined agent loop, schema-validated tools, provider-neutral
RAG, eval gates, OTel GenAI tracing, and an MCP server when warranted.
`references/`: provider-abstraction, agent-loops-and-harness, tools-and-rag,
evals-and-observability, mcp-servers.

### rsc-ops

#### [secure-coding](skills/secure-coding/) — `/rsc-ops:secure-coding`

Transversal security — lightweight STRIDE threat modeling and the OWASP Top
10 mapped to concrete vulnerable→fixed examples in FastAPI, Go and Next.js,
plus authn/authz, secrets and supply-chain gates. `references/`:
threat-modeling, owasp-by-stack, authn-authz, secrets-and-supply-chain.

#### [deployment](skills/deployment/) — `/rsc-ops:deployment`

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
