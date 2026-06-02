# skills

Eric Risco's collection of agent skills, distributed as **`rsc-universal`** — a
single CLI (`npx rsc`) that installs skills **one at a time**, recommends what
your project needs, and keeps your assistant equipped as you work.

`skills/<name>/` is the single source of truth. There are no bundles to choose
and nothing to over-install: you start with a tiny floor and the system proposes
the next skill when your project actually needs it.

## Quick start (the easy way)

Run the assistant and describe what you want — in plain language, no jargon:

```bash
npx rsc
```

```
Hola 👋 ¿Qué quieres hacer?
> una tienda web con base de datos y publicarla

He preparado esto para ti:
   • Tu web (rápida y lista para Google)
   • Guardar tus datos de forma fiable
   • Publicarlo online
   • Que se vea bien y convierta
¿Lo monto? (sí / no) > sí

✅ Listo. Abre tu editor y empieza a pedir cosas en tu idioma.
```

It reads your repository (what stack is already there), listens to what you say,
and installs only the matching skills. The first run also installs the **floor**:
`rsc-suggest` (the always-on detector) so that — from then on — your assistant
itself proposes installing a skill the moment a task needs one.

## The CLI

```bash
npx rsc                                 # plain-language wizard (recommended)
npx rsc add fastapi postgresdb          # install specific skills, by name
npx rsc install --profile minimal       # the floor: suggest + harness + init
npx rsc install --profile core          # floor + the SDD workflow
npx rsc install --profile full          # everything
npx rsc install --profile full --without go   # everything except one skill
npx rsc consult "security review"       # recommend only, no install
npx rsc list                            # what rsc has installed
npx rsc doctor                          # health check (state, hook, counts)
npx rsc uninstall postgresdb --dry-run  # preview a removal
```

The unit of installation is the **individual skill** — install `fastapi` without
ever pulling `go`. Nothing you don't use ends up in your context.

## How recommendation works

Two faces, one catalog (`manifest.json`):

- **In the terminal** — `npx rsc` / `npx rsc consult` rank the catalog against
  your words (a small FTS index over each skill's description + tags) merged with
  what it detects in your repo, then expand via each skill's `recommends`.
- **In the chat** — `rsc-suggest` is a tiny always-on skill. When a task would
  benefit from a skill you don't have, it names it and (with a one-word confirm)
  runs `npx rsc add <id>` for you. Installed by default; the floor of the system.

Repo detection maps real signals to skills: `package.json` + `next` → `nextjs`;
`go.mod` → `go`; `pyproject.toml` → `fastapi`; `*.sql`/`prisma/` → `postgresdb`;
`Dockerfile`/`.github/` → `deployment`; and so on. An empty repo just asks.

## Multi-target

`skills/<name>/` is the source; the installer writes the right format for your
IDE (auto-detected, or `--target`):

| Target | Destination | Always-on detector |
| --- | --- | --- |
| `claude` | `~/.claude/skills/rsc/<id>/` | SessionStart hook in `settings.json` |
| `cursor` | `.cursor/rules/<id>.mdc` | always-apply rule |
| `codex` | `.codex/rsc/<id>/` + `AGENTS.md` | block in `AGENTS.md` |
| `gemini` | `.gemini/rsc/<id>/` + `GEMINI.md` | block in `GEMINI.md` |

## The catalog

Skills are grouped here by theme for reading only — there are no install bundles.
Once installed, invoke a skill by its name in your assistant. Each skill is
**hybrid**: a focused `SKILL.md`, deep-dive `references/`, and (for stack skills)
an executable `scripts/verify.sh` quality gate.

### Core — the front door & control plane

#### [init](skills/init/)

The bootstrapper. Gauges your technical level first (non-technical by default),
discovers what you want to build or govern, detects greenfield vs brownfield,
recommends which skills to install (printing the exact `npx rsc add` commands),
and hands off to `harness`.

#### [harness](skills/harness/)

The workspace control plane. Governs a workspace — software OR a non-code base (a
company, an ops desk, a knowledge vault) — through the `01-TOOLS/` operational
tooling layer, the `02-DOCS/` Karpathy chaos→knowledge engine, and the root
Knowledge map. As a brownfield auditor it scans any project, detects external
provider integrations (Stripe, OpenAI, Anthropic, Supabase, Sentry, Twilio, …),
and — only with explicit consent — scaffolds a canonical `01-TOOLS/` layer (one
folder per provider, each with a working `test_connection`) plus a `02-DOCS/`
second-brain that self-improves with every file dropped into `inbox/`. Also
generates the root `CLAUDE.md` and `AGENTS.md`.

#### [author-skill](skills/author-skill/)

The meta-skill for authoring and editing the skills in this catalog —
frontmatter discipline (`name`, `description`, `tags`, `recommends`), trigger
design, the eval minimums enforced by `scripts/eval-lint.sh`, and the
`manifest.json` distribution model. Use it when creating a new skill or
tightening an existing one.

#### [suggest](skills/suggest/)

The always-on detector. Installed with every profile. During any conversation,
if a task would benefit from a skill you don't have, it proposes installing it
via `npx rsc add <id>`. Tiny by design — it's the one thing always in context.

### Backend

#### [fastapi](skills/fastapi/)

Build, review, test, secure and ship FastAPI / async Python services — Python
3.12+, Pydantic v2, async SQLAlchemy 2.0, DI, JWT/OAuth2, pytest, production
settings. `references/`: testing, database, security, production.

#### [go](skills/go/)

Idiomatic Go HTTP services — errors, concurrency (context, errgroup, no leaks),
net/http 1.22 routing, slog, table-driven `-race` tests, govulncheck.
`references/`: concurrency, http-services, testing.

#### [postgresdb](skills/postgresdb/)

Engine-level PostgreSQL 16 — schema & type correctness, the right index, reading
`EXPLAIN (ANALYZE, BUFFERS)`, keyset pagination, zero-downtime migrations, RLS,
pooling, partitioning, backups. `references/`: schema-and-indexing,
query-optimization, migrations, operations-and-security.

### Frontend

#### [nextjs](skills/nextjs/)

Next.js 15 App Router done right — Server vs Client Components, server actions,
route handlers, caching/revalidation, React 19, end-to-end TS, vitest +
Playwright, security and Core Web Vitals. `references/`: react, data-and-caching,
testing, performance, security.

#### [flutter](skills/flutter/)

Flutter / Dart 3 apps — feature-first clean architecture, Riverpod (and Bloc),
Material 3 tokens, go_router, widget/golden/integration tests, rebuild & jank
performance. `references/`: architecture-and-state, ui-and-navigation, testing,
performance.

#### [design](skills/design/)

Research-first product design and high-converting landing pages — grounds in the
project's brand study, researches current 2026 UX/UI trends, then ships a
premium, accessible (WCAG 2.2 AA), fast (LCP/INP/CLS) visual system with Tailwind
+ Next.js. `references/`: research-method, visual-system,
landing-anatomy-and-cro, copywriting-frameworks, motion-and-interaction,
trends-2026, brand-grounding.

### Content

#### [marketing](skills/marketing/)

Conversion copywriting for landings and web pages. Grounds in the brand study
first, then writes specific, benefit-led, on-brand copy: value props,
hero/section copy, CTAs, email and launch sequences. Pairs with `design` and
`nextjs`. `references/`: brand-grounding, copy-frameworks, landing-copy,
campaigns-and-channels.

#### [presentations](skills/presentations/)

Stunning PPTX and PDF decks, grounded in the brand study. Two pipelines —
design-led Markdown (Marp/Slidev) and native editable `python-pptx` — plus deck
storytelling, slide copy and projection-grade visual design. `references/`:
storytelling-and-decks, markdown-decks, pptx-python, slide-design,
brand-grounding.

#### [course-storytelling](skills/course-storytelling/)

Turn course/lesson content into teaching that lands — profiles the learner, then
runs every concept through Russell Brunson's *Expert Secrets* machine into a hook
→ story → model → analogy → proof → application recipe. `references/`:
brunson-frameworks, learner-grounding, mental-models, course-analysis,
concept-landing-recipe.

### Agents

#### [building-agents](skills/building-agents/)

Build production LLM agents that are model-agnostic by construction — a thin
provider adapter (OpenAI ↔ Anthropic ↔ Gemini ↔ OSS as a config change), a
disciplined agent loop, schema-validated tools, provider-neutral RAG, eval gates,
OTel GenAI tracing, and an MCP server when warranted. `references/`:
provider-abstraction, agent-loops-and-harness, tools-and-rag,
evals-and-observability, mcp-servers.

### Ops

#### [secure-coding](skills/secure-coding/)

Transversal security — lightweight STRIDE threat modeling and the OWASP Top 10
mapped to concrete vulnerable→fixed examples in FastAPI, Go and Next.js, plus
authn/authz, secrets and supply-chain gates. `references/`: threat-modeling,
owasp-by-stack, authn-authz, secrets-and-supply-chain.

#### [deployment](skills/deployment/)

Source → hardened container → green CI/CD → live: multi-stage Dockerfiles per
stack, GitHub Actions (matrix, caching, OIDC, security gates), and Coolify
self-hosted deploys. `references/`: dockerfiles-by-stack, github-actions,
coolify.

### SDD — the Spec-Driven Development workflow

The SDD skills take a fuzzy intent and walk it, phase by phase, to a shipped,
verified change. It is process, not stack: each phase defers concrete tooling to
the stack skills above, and writes artifacts into the `02-DOCS/wiki/sdd/` layer
the `harness` governs. Install the whole workflow with `npx rsc install
--profile core`.

The [sdd](skills/sdd/) dispatcher routes each request to its phase; the happy
path is **constitution → specify → clarify → plan → tasks → analyze → implement
→ verify → review → ship**, with `debug`, `worktrees`, and `parallel` callable on
demand:

- [constitution](skills/constitution/) — project non-negotiables: stack canon, quality bars, conventions
- [specify](skills/specify/) — turn a fuzzy intent into a spec — what & why, no how
- [clarify](skills/clarify/) — surface ambiguities / edge cases, ask, bake answers back in
- [plan](skills/plan/) — technical plan: architecture, interfaces, data flow, tests, risks
- [tasks](skills/tasks/) — break the plan into ordered, independently-verifiable tasks
- [analyze](skills/analyze/) — consistency gate: constitution ↔ spec ↔ plan ↔ tasks
- [implement](skills/implement/) — execute tasks with checkpoints; TDD discipline embedded
- [verify](skills/verify/) — post-build gate: stack checks + done-checks + acceptance
- [review](skills/review/) — adversarial code review — give and receive with rigor
- [ship](skills/ship/) — close the branch: PR / merge / cleanup
- [debug](skills/debug/) — root-cause diagnosis: reproduce → isolate → fix → verify
- [worktrees](skills/worktrees/) — isolate feature work in a branch/worktree
- [parallel](skills/parallel/) — fan out independent tasks across subagents

## Skill format

Each skill is a directory under `skills/<name>/` with a `SKILL.md` whose YAML
frontmatter drives both triggering and the installer's recommendations:

```yaml
---
name: my-skill
description: Use when [specific triggering conditions]
tags: [keyword, keyword]        # what the consult advisor searches over
recommends: [sibling-skill]     # what the system offers to install next
profiles: [core, full]          # optional: named-profile membership
---
```

The full agent-skill spec lives at
[agentskills.io/specification](https://agentskills.io/specification).

## Repo layout & contributing

`skills/<name>/` is the **single source of truth** — every skill is authored and
edited there, once. The catalog is published as the `rsc-universal` npm package;
the CLI copies skills into the target IDE on demand.

After editing any skill:

```bash
npm run manifest      # regenerate manifest.json from skills/*/SKILL.md
npm run validate      # ajv-validate frontmatter + check recommends integrity
npm test              # unit + integration tests
scripts/eval-lint.sh  # validate every skills/*/evals/cases.yaml
```

`manifest.json` is generated, never hand-edited; CI runs `npm run manifest:check`
and fails if it is stale or the skill count drifts. Adding a skill is: create
`skills/<id>/SKILL.md` with `tags` + `recommends`, run `npm run manifest`, done.

This is a personal catalog. Bug reports welcome via GitHub issues. PRs fixing
detector patterns, provider endpoints, or English typos are appreciated.

## License

MIT. See [LICENSE](LICENSE).
