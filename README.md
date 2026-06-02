<div align="center">

# `rsc` — 231 agent skills, one CLI, zero bloat

**A self-recommending skill catalog for Claude Code, Cursor, Codex & Gemini.**
Describe what you want in plain language. It reads your repo, installs *only* the
skills that fit — one at a time — and keeps your assistant equipped as you work.

From *"document my company"* to *"ship a FastAPI service"* to *"grow my YouTube
channel"* — **231 skills across 21 domains**, every one researched against live
2025-2026 sources and **adversarially scored ≥ 8.5/10** before it shipped.

```bash
npx rsc            # plain-language wizard — no jargon, installs what your project needs
```

</div>

---

## Why this exists

Most skill packs dump hundreds of files into your context and call it a day. This
one is the opposite bet:

- **Granular by default.** The unit of installation is *one skill*. Install
  `fastapi` without ever pulling `go`. Nothing you don't use touches your context.
- **Self-recommending.** Both the terminal (`rsc consult`) and the chat
  (`rsc-suggest`, an always-on detector) watch what you're doing and propose the
  *next* skill the moment a task needs it — a one-word confirm installs it.
- **Not code-only.** First-class support for running a *company*: bookkeeping,
  invoicing, hiring, GDPR, pitch decks, SEO, a YouTube/TikTok/LinkedIn presence —
  each wired to a `02-DOCS/` knowledge loop that learns from your own results.
- **Honestly good.** Every skill was built by a research → spec → implement →
  *adversarial review* pipeline and had to clear an objective rubric (see
  [The quality bar](#the-quality-bar)). The bar was real: skills that scored 8.0
  were sent back and fixed, not waved through.

`skills/<name>/` is the single source of truth. There are no bundles to argue
over: you start with a tiny floor and grow one piece at a time.

---

## Install

The catalog ships as the `rsc-universal` CLI. Until it's on npm, install from
source (one minute, once):

```bash
git clone https://github.com/ericrisco/skills.git ~/rsc-skills
cd ~/rsc-skills && npm install && npm link   # puts `rsc` on your PATH
```

Then, inside any project of yours:

```bash
cd ~/my-project
rsc                # the wizard: describe what you want, it installs what fits
```

> Once published: `npx rsc` with no install step. Prefer no global link? Call it
> directly: `node ~/rsc-skills/scripts/rsc.js <args>`.

The first run installs the **floor** — `rsc-suggest` (always-on detector) +
`harness` + `init` — and, in Claude Code, wires a `SessionStart` hook so your
assistant proposes new skills on its own from then on.

---

## 30-second tour

```
$ rsc
Hola 👋 ¿Qué quieres hacer?
> una tienda web con base de datos, y llevar la contabilidad

He preparado esto para ti:
   • Tu tienda (rápida y lista para Google)        → nextjs, design, seo-geo
   • Guardar tus datos de forma fiable             → postgresdb
   • Cobrar y facturar                             → stripe, invoicing
   • Llevar las cuentas                            → bookkeeping, finance-ops
   • Publicarlo online                             → vercel
¿Lo monto? (sí / no) > sí

✅ Listo. Abre tu editor y empieza a pedir cosas en tu idioma.
   💡 Cuando una tarea necesite algo más, te lo propongo yo.
```

It detects your stack from the repo, maps your words to outcomes, installs the
matching skills, then suggests what usually comes next.

---

## The CLI

```bash
rsc                                  # plain-language wizard (recommended)
rsc add fastapi postgresdb           # install specific skills, by name
rsc add youtube-api remotion-video   # …grow a channel, edit with Remotion
rsc install --profile minimal        # the floor: suggest + harness + init
rsc install --profile core           # floor + the full SDD workflow
rsc install --profile full           # everything (all 231)
rsc install --profile full --without go
rsc consult "quiero lanzar un saas"  # recommend only, no install
rsc registry refresh                 # write .rsc/skill-registry.{json,md}
rsc list                             # what rsc has installed
rsc doctor                           # health check (state, hook, counts)
rsc uninstall postgresdb --dry-run   # preview a removal
```

---

## How recommendation works

Two faces, one catalog (`manifest.json`):

- **In the terminal** — `rsc` / `rsc consult` rank the catalog against your words
  (an FTS index over each skill's description + tags), merge that with what they
  detect in your repo, and expand via each skill's `recommends`.
- **In the chat** — `rsc-suggest` is a tiny always-on skill. When a task would
  benefit from a skill you don't have, it names it and (one-word confirm) runs
  `rsc add <id>` for you. It's the floor — installed with every profile.

Repo detection maps real signals to skills: `package.json` + `next` → `nextjs`;
`go.mod` → `go`; `pyproject.toml` → `fastapi`; `*.sql`/`prisma/` → `postgresdb`;
`Dockerfile`/`.github/` → `docker`/`github-actions`; and so on. An empty repo
just asks in plain language.

---

## The quality bar

This catalog was built to a test that was **written before any skill existed**
(`scripts/skill-rubric.md`). Each finished skill was scored 0-10 by an
independent adversarial reviewer across seven weighted dimensions — with
**freshness & grounding the heaviest (0.25)**: every load-bearing claim had to be
*current* (2025-2026 versions/APIs) and cited to a dated source. The ship gate
was **≥ 8.5**; anything below was sent back through a fix loop, not rounded up.

| | |
|---|---|
| **Skills** | 231 (30 core + 201 added) |
| **Domains** | 21 |
| **Median family score** | **~9.1 / 10** |
| **Below the 8.5 gate** | 0 (three were flagged, then remediated to 9.0-9.3) |
| **Deterministic gates** | eval-lint ✓ · frontmatter+`recommends` validate ✓ · 50/50 unit tests ✓ · every description ≤ 1024 chars ✓ |

Each skill is **hybrid**: a focused `SKILL.md` (120-400 lines), deep-dive
`references/`, an `evals/cases.yaml` (≥5 trigger / ≥4 near-miss / ≥1 capability
scenario), and — for anything with a checkable artifact — an executable
`scripts/verify.sh`.

---

## The catalog

231 skills, grouped by what you're trying to do. Invoke any installed skill by
name in your assistant; it fires on its own when a task matches.

### 🧭 Core & control plane
The front door and the workspace brain.
`init` · `harness` · `author-skill` · `suggest` · `sdd-init`

> **harness** is the Karpathy *chaos→knowledge* engine — a `01-TOOLS/` layer (one
> folder per provider, each with a working `test_connection`) and a `02-DOCS/`
> self-improving wiki. It governs software *or* a whole company.

### 📐 Spec-Driven Development
Take a fuzzy intent to a shipped, verified change — phase by phase. `rsc install --profile core`.
`sdd` · `constitution` · `specify` · `clarify` · `plan` · `tasks` · `analyze` · `implement` · `verify` · `review` · `ship` · `debug` · `worktrees` · `parallel`

### 💼 Run a business
`finance-ops` · `invoicing` · `bookkeeping` · `pricing` · `sales-pipeline` · `lead-gen` · `cold-outreach` · `proposals` · `contracts` · `customer-support` · `client-onboarding` · `retention` · `hiring` · `people-ops` · `inventory` · `logistics-ops` · `procurement` · `meeting-notes` · `sop-builder` · `project-ops`

### 💸 Raise & model money
`pitch-deck` · `investor-materials` · `financial-model` · `fundraising` · `unit-economics` · `grants`

### ⚖️ Legal, privacy & compliance
`gdpr-privacy` · `terms-conditions` · `compliance` · `data-policy` · `ip-trademark`

### 📣 Market & brand
`seo-geo` · `content-engine` · `social-publisher` · `brand-voice` · `brand-identity` · `newsletter` · `landing-copy` · `ads` · `article-writing` · `case-studies` · `video-shorts` · `podcast` · `market-research` · `competitor-watch` · `press-kit` · `community` · `webinar` · `review-management` · `marketing`

### 🎬 Grow a channel (each with a `02-DOCS` feedback loop)
- **YouTube** — `youtube-api` · `youtube-strategy` · `youtube-ideation` · `youtube-thumbnails` · `youtube-packaging` · `remotion-video` *(Remotion edits: transitions, Whisper captions, silence removal)*
- **TikTok / Reels** — `tiktok-api` · `instagram-api` · `shortform-strategy` · `shortform-ideation` · `shortform-packaging` · `shortform-editing`
- **LinkedIn** — `linkedin-api` · `linkedin-strategy` · `linkedin-content` · `linkedin-carousels` · `linkedin-outreach`
- **Medium** — `medium-writing` · `medium-publishing` · `medium-strategy`

### 🔌 Connect & automate
`stripe` · `email-connector` · `google-workspace` · `notion-connector` · `whatsapp-telegram` · `automation-flows` · `api-connector-builder` · `webhooks` · `data-scraper` · `spreadsheet-ops` · `calendar-scheduling` · `document-processing` · `e-signature`

### 📊 Data & analytics
`analytics` · `dashboard` · `kpi-framework` · `reporting` · `ab-testing` · `forecasting` · `data-cleaning` · `business-intelligence`

### 🤖 AI features & infra
- **Build AI in** — `building-agents` · `rag` · `embeddings-search` · `prompt-engineering` · `llm-pipeline` · `agent-eval` · `chatbot` · `ai-media` · `replicate-images` · `structured-extraction` · `agent-safety` · `cost-tracking`
- **Run AI on** — `replicate` · `runpod` · `modal` · `huggingface` · `ollama` · `together-fireworks` · `fal`

### 🗣️ Languages
`typescript` · `python` · `java` · `csharp-dotnet` · `php` · `ruby` · `cpp` · `elixir` · `bash-scripting` · `sql` · `go` *(+ `fastapi` for async Python services)*

### 🏗️ Frameworks & app stacks
`nextjs` · `react` · `react-native` · `vue-nuxt` · `angular` · `svelte` · `astro` · `solid-js` · `htmx` · `nodejs` · `nestjs` · `django` · `laravel` · `rails` · `spring-boot` · `phoenix` · `flutter` · `swift-ios` · `kotlin-android` · `compose-multiplatform` · `expo` · `tauri` · `electron` · `rust` · `wordpress` · `shopify` · `no-code-app` · `chrome-extension` · `api-design`

### 🗄️ Databases & data layer
`postgresdb` · `mysql` · `mongodb` · `redis` · `supabase` · `neon` · `planetscale` · `sqlite-turso` · `prisma-orm` · `drizzle-orm` · `firebase` · `dynamodb` · `vector-db` · `clickhouse-analytics` · `duckdb` · `db-migrations` · `backups`

### ☁️ Ship & operate
- **Platforms** — `vercel` · `netlify` · `cloudflare` · `railway` · `render` · `fly-io` · `coolify` · `hetzner` · `digitalocean` · `aws-essentials` · `gcp-essentials`
- **DevOps** — `docker` · `github-actions` · `git-workflow` · `domains-dns` · `monitoring` · `email-deliverability` · `scaling` · `deployment`
- **Quality & security** — `code-review` · `security-scan` · `secure-coding` · `testing-py` · `testing-web` · `testing-go` · `e2e-testing` · `accessibility` · `performance` · `error-handling` · `observability`

### 🎨 Design & content craft
`design` · `presentations` · `course-storytelling` · `course-builder` · `technical-writing` · `translation-l10n`

### 🧠 Knowledge & meta
`knowledge-ops` · `codebase-onboarding` · `research-ops` · `decision-records` · `continuous-learning` · `skill-scout` · `context-budget`

---

## Multi-target

`skills/<name>/` is the source; the installer writes the right format for your
IDE (auto-detected, or `--target`):

| Target | Destination | Always-on detector |
| --- | --- | --- |
| `claude` | `~/.claude/skills/rsc/<id>/` | SessionStart hook in `settings.json` |
| `cursor` | `.cursor/rules/<id>.mdc` | always-apply rule |
| `codex` | `.codex/rsc/<id>/` + `AGENTS.md` | block in `AGENTS.md` |
| `gemini` | `.gemini/rsc/<id>/` + `GEMINI.md` | block in `GEMINI.md` |

---

## Skill format

Each skill is a directory under `skills/<name>/` whose `SKILL.md` frontmatter
drives both triggering and the installer's recommendations:

```yaml
---
name: my-skill
description: Use when [specific triggers]… Triggers: 'phrase', 'frase'. NOT x (that is sibling).
tags: [keyword, keyword]        # what the consult advisor searches over
recommends: [sibling-skill]     # what the system offers to install next
profiles: [core, full]          # optional: named-profile membership
origin: risco
---
```

The full agent-skill spec lives at
[agentskills.io/specification](https://agentskills.io/specification).

---

## Repo layout & contributing

`skills/<name>/` is the **single source of truth** — every skill is authored
there, once. After editing any skill:

```bash
npm run manifest      # regenerate manifest.json from skills/*/SKILL.md
npm run validate      # ajv-validate frontmatter + check recommends integrity
npm test              # unit + integration tests
bash scripts/eval-lint.sh   # validate every skills/*/evals/cases.yaml
```

`manifest.json` is generated, never hand-edited; CI runs `npm run manifest:check`
and fails if it's stale or the skill count drifts. Adding a skill is: create
`skills/<id>/SKILL.md` with `tags` + `recommends`, run `npm run manifest`, done —
the rubric to hold it to is `scripts/skill-rubric.md`.

This is a personal catalog. Bug reports welcome via GitHub issues; PRs fixing
detector patterns, provider endpoints, or typos are appreciated.

## License

MIT. See [LICENSE](LICENSE).
