<div align="center">

```
 ██████╗ ███████╗ ██████╗
 ██╔══██╗██╔════╝██╔════╝
 ██████╔╝███████╗██║     
 ██╔══██╗╚════██║██║     
 ██║  ██║███████║╚██████╗
 ╚═╝  ╚═╝╚══════╝ ╚═════╝
```

# `rsc` — 231 agent skills, one CLI, zero bloat

**A self-recommending skill catalog for Claude Code, Cursor, Codex & Gemini.**
Describe what you want in plain language. It reads your repo, installs *only* the
skills that fit — one at a time — and keeps your assistant equipped as you work.

From *"document my company"* to *"ship a FastAPI service"* to *"grow my YouTube
channel"* — **231 skills across 21 domains**, every one researched against live
2025-2026 sources and **adversarially scored ≥ 8.5/10** before it shipped.

```bash
npx @ericrisco/rsc            # plain-language wizard — no jargon, installs what your project needs
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
  *adversarial review* pipeline and had to clear an objective rubric
  (`scripts/skill-rubric.md`, written *before* any skill existed). The bar was
  real: skills that scored 8.0 were sent back and fixed, not waved through.

`skills/<name>/` is the single source of truth. There are no bundles to argue
over: you start with a tiny floor and grow one piece at a time.

---

## Install

```bash
npx @ericrisco/rsc            # no install step — runs the latest published catalog
```

Prefer the short `rsc` command? Install once, globally:

```bash
npm install -g @ericrisco/rsc   # then just: rsc
```

Run it inside any project and describe what you want. Working on the catalog
itself? Clone and link:

```bash
git clone https://github.com/ericrisco/skills.git ~/rsc-skills
cd ~/rsc-skills && npm install && npm link
```

The first run installs the **floor** — `orient` + `rsc-suggest` (always-on) +
`harness` + `init` — and, in Claude Code, wires a `SessionStart` hook so your
assistant proposes new skills on its own from then on.

---

## 30-second tour

```
$ rsc
 ██████╗ ███████╗ ██████╗     ← animated gradient wordmark
 ██╔══██╗██╔════╝██╔════╝
 ██████╔╝███████╗██║
  231 skills · one CLI · zero bloat

What do you want to do?          ↑↓ move · enter select
❯ Base install — the essentials (orient + suggest + harness + init)
  Base + Spec-Driven Development — specify → plan → implement → ship
  Pick skills by hand, by area
```

Pick **by area** and you get a checkbox list — **↑↓ to move, space to toggle,
enter to confirm**:

```
Languages:                       ↑↓ move · space toggle · a all · enter confirm
❯ ◉ typescript
  ◯ python
  ◉ go
  ◯ rust
```

It auto-detects your IDE and stack, installs only what you chose, then prints the
exact next steps for **Claude Code / Cursor / Codex / Gemini** — and from there
keeps proposing the skills a task needs.

---

## The CLI

```bash
rsc                                  # plain-language wizard (recommended)
rsc add fastapi postgresdb           # install specific skills, by name
rsc add youtube-api remotion-video   # …grow a channel, edit with Remotion
rsc install --profile minimal        # the floor: orient + suggest + harness + init
rsc install --profile core           # floor + the full SDD workflow
rsc install --profile full           # everything (all 231)
rsc install --profile full --without go
rsc consult "I want to launch a SaaS"  # recommend only, no install
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

## The catalog

231 skills, grouped by what you're trying to do. Click any skill to read its
`SKILL.md`. It fires on its own when a task matches.

### 🧭 Core & control plane
The front door and the workspace brain.

[init](skills/init/) · [harness](skills/harness/) · [orient](skills/orient/) · [suggest](skills/suggest/) · [author-skill](skills/author-skill/) · [sdd-init](skills/sdd-init/)

> **harness** is the Karpathy *chaos→knowledge* engine — a `01-TOOLS/` layer (one
> folder per provider, each with a working `test_connection`) and a `02-DOCS/`
> self-improving wiki. It governs software *or* a whole company. **orient** is the
> always-on compass that keeps a non-technical human oriented after every step.

### 📐 Spec-Driven Development
Take a fuzzy intent to a shipped, verified change — phase by phase. `npx @ericrisco/rsc install --profile core`.

[sdd](skills/sdd/) · [constitution](skills/constitution/) · [specify](skills/specify/) · [clarify](skills/clarify/) · [plan](skills/plan/) · [tasks](skills/tasks/) · [analyze](skills/analyze/) · [implement](skills/implement/) · [verify](skills/verify/) · [review](skills/review/) · [ship](skills/ship/) · [debug](skills/debug/) · [worktrees](skills/worktrees/) · [parallel](skills/parallel/)

### 💼 Run a business

[finance-ops](skills/finance-ops/) · [invoicing](skills/invoicing/) · [bookkeeping](skills/bookkeeping/) · [pricing](skills/pricing/) · [sales-pipeline](skills/sales-pipeline/) · [lead-gen](skills/lead-gen/) · [cold-outreach](skills/cold-outreach/) · [proposals](skills/proposals/) · [contracts](skills/contracts/) · [customer-support](skills/customer-support/) · [client-onboarding](skills/client-onboarding/) · [retention](skills/retention/) · [hiring](skills/hiring/) · [people-ops](skills/people-ops/) · [inventory](skills/inventory/) · [logistics-ops](skills/logistics-ops/) · [procurement](skills/procurement/) · [meeting-notes](skills/meeting-notes/) · [sop-builder](skills/sop-builder/) · [project-ops](skills/project-ops/)

### 💸 Raise & model money

[pitch-deck](skills/pitch-deck/) · [investor-materials](skills/investor-materials/) · [financial-model](skills/financial-model/) · [fundraising](skills/fundraising/) · [unit-economics](skills/unit-economics/) · [grants](skills/grants/)

### ⚖️ Legal, privacy & compliance

[gdpr-privacy](skills/gdpr-privacy/) · [terms-conditions](skills/terms-conditions/) · [compliance](skills/compliance/) · [data-policy](skills/data-policy/) · [ip-trademark](skills/ip-trademark/)

### 📣 Market & brand

[marketing](skills/marketing/) · [seo-geo](skills/seo-geo/) · [content-engine](skills/content-engine/) · [social-publisher](skills/social-publisher/) · [brand-voice](skills/brand-voice/) · [brand-identity](skills/brand-identity/) · [newsletter](skills/newsletter/) · [landing-copy](skills/landing-copy/) · [ads](skills/ads/) · [article-writing](skills/article-writing/) · [case-studies](skills/case-studies/) · [video-shorts](skills/video-shorts/) · [podcast](skills/podcast/) · [market-research](skills/market-research/) · [competitor-watch](skills/competitor-watch/) · [press-kit](skills/press-kit/) · [community](skills/community/) · [webinar](skills/webinar/) · [review-management](skills/review-management/)

### 🎬 Grow a channel
Each with a `02-DOCS` feedback loop that learns from your own results. `remotion-video` edits programmatically — transitions, Whisper captions, silence removal.

[youtube-api](skills/youtube-api/) · [youtube-strategy](skills/youtube-strategy/) · [youtube-ideation](skills/youtube-ideation/) · [youtube-thumbnails](skills/youtube-thumbnails/) · [youtube-packaging](skills/youtube-packaging/) · [remotion-video](skills/remotion-video/) · [tiktok-api](skills/tiktok-api/) · [instagram-api](skills/instagram-api/) · [shortform-strategy](skills/shortform-strategy/) · [shortform-ideation](skills/shortform-ideation/) · [shortform-packaging](skills/shortform-packaging/) · [shortform-editing](skills/shortform-editing/) · [linkedin-api](skills/linkedin-api/) · [linkedin-strategy](skills/linkedin-strategy/) · [linkedin-content](skills/linkedin-content/) · [linkedin-carousels](skills/linkedin-carousels/) · [linkedin-outreach](skills/linkedin-outreach/) · [medium-writing](skills/medium-writing/) · [medium-publishing](skills/medium-publishing/) · [medium-strategy](skills/medium-strategy/)

### 🔌 Connect & automate

[stripe](skills/stripe/) · [email-connector](skills/email-connector/) · [google-workspace](skills/google-workspace/) · [notion-connector](skills/notion-connector/) · [whatsapp-telegram](skills/whatsapp-telegram/) · [automation-flows](skills/automation-flows/) · [api-connector-builder](skills/api-connector-builder/) · [webhooks](skills/webhooks/) · [data-scraper](skills/data-scraper/) · [spreadsheet-ops](skills/spreadsheet-ops/) · [calendar-scheduling](skills/calendar-scheduling/) · [document-processing](skills/document-processing/) · [e-signature](skills/e-signature/)

### 📊 Data & analytics

[analytics](skills/analytics/) · [dashboard](skills/dashboard/) · [kpi-framework](skills/kpi-framework/) · [reporting](skills/reporting/) · [ab-testing](skills/ab-testing/) · [forecasting](skills/forecasting/) · [data-cleaning](skills/data-cleaning/) · [business-intelligence](skills/business-intelligence/)

### 🤖 AI — build it in

[building-agents](skills/building-agents/) · [rag](skills/rag/) · [embeddings-search](skills/embeddings-search/) · [prompt-engineering](skills/prompt-engineering/) · [llm-pipeline](skills/llm-pipeline/) · [agent-eval](skills/agent-eval/) · [chatbot](skills/chatbot/) · [ai-media](skills/ai-media/) · [replicate-images](skills/replicate-images/) · [structured-extraction](skills/structured-extraction/) · [agent-safety](skills/agent-safety/) · [cost-tracking](skills/cost-tracking/)

### 🛰️ AI — run it on

[replicate](skills/replicate/) · [runpod](skills/runpod/) · [modal](skills/modal/) · [huggingface](skills/huggingface/) · [ollama](skills/ollama/) · [together-fireworks](skills/together-fireworks/) · [fal](skills/fal/)

### 🗣️ Languages

[typescript](skills/typescript/) · [python](skills/python/) · [java](skills/java/) · [csharp-dotnet](skills/csharp-dotnet/) · [php](skills/php/) · [ruby](skills/ruby/) · [cpp](skills/cpp/) · [elixir](skills/elixir/) · [bash-scripting](skills/bash-scripting/) · [sql](skills/sql/) · [go](skills/go/)

### 🏗️ Frameworks & app stacks

[fastapi](skills/fastapi/) · [nextjs](skills/nextjs/) · [react](skills/react/) · [react-native](skills/react-native/) · [vue-nuxt](skills/vue-nuxt/) · [angular](skills/angular/) · [svelte](skills/svelte/) · [astro](skills/astro/) · [solid-js](skills/solid-js/) · [htmx](skills/htmx/) · [nodejs](skills/nodejs/) · [nestjs](skills/nestjs/) · [django](skills/django/) · [laravel](skills/laravel/) · [rails](skills/rails/) · [spring-boot](skills/spring-boot/) · [phoenix](skills/phoenix/) · [flutter](skills/flutter/) · [swift-ios](skills/swift-ios/) · [kotlin-android](skills/kotlin-android/) · [compose-multiplatform](skills/compose-multiplatform/) · [expo](skills/expo/) · [tauri](skills/tauri/) · [electron](skills/electron/) · [rust](skills/rust/) · [wordpress](skills/wordpress/) · [shopify](skills/shopify/) · [no-code-app](skills/no-code-app/) · [chrome-extension](skills/chrome-extension/) · [api-design](skills/api-design/)

### 🗄️ Databases & data layer

[postgresdb](skills/postgresdb/) · [mysql](skills/mysql/) · [mongodb](skills/mongodb/) · [redis](skills/redis/) · [supabase](skills/supabase/) · [neon](skills/neon/) · [planetscale](skills/planetscale/) · [sqlite-turso](skills/sqlite-turso/) · [prisma-orm](skills/prisma-orm/) · [drizzle-orm](skills/drizzle-orm/) · [firebase](skills/firebase/) · [dynamodb](skills/dynamodb/) · [vector-db](skills/vector-db/) · [clickhouse-analytics](skills/clickhouse-analytics/) · [duckdb](skills/duckdb/) · [db-migrations](skills/db-migrations/) · [backups](skills/backups/)

### ☁️ Ship & operate — platforms

[vercel](skills/vercel/) · [netlify](skills/netlify/) · [cloudflare](skills/cloudflare/) · [railway](skills/railway/) · [render](skills/render/) · [fly-io](skills/fly-io/) · [coolify](skills/coolify/) · [hetzner](skills/hetzner/) · [digitalocean](skills/digitalocean/) · [aws-essentials](skills/aws-essentials/) · [gcp-essentials](skills/gcp-essentials/)

### 🛠️ Ship & operate — devops

[docker](skills/docker/) · [github-actions](skills/github-actions/) · [git-workflow](skills/git-workflow/) · [domains-dns](skills/domains-dns/) · [monitoring](skills/monitoring/) · [email-deliverability](skills/email-deliverability/) · [scaling](skills/scaling/) · [deployment](skills/deployment/)

### 🔒 Ship & operate — quality & security

[code-review](skills/code-review/) · [security-scan](skills/security-scan/) · [secure-coding](skills/secure-coding/) · [testing-py](skills/testing-py/) · [testing-web](skills/testing-web/) · [testing-go](skills/testing-go/) · [e2e-testing](skills/e2e-testing/) · [accessibility](skills/accessibility/) · [performance](skills/performance/) · [error-handling](skills/error-handling/) · [observability](skills/observability/)

### 🎨 Design & content craft

[design](skills/design/) · [presentations](skills/presentations/) · [course-storytelling](skills/course-storytelling/) · [course-builder](skills/course-builder/) · [technical-writing](skills/technical-writing/) · [translation-l10n](skills/translation-l10n/)

### 🧠 Knowledge & meta

[knowledge-ops](skills/knowledge-ops/) · [codebase-onboarding](skills/codebase-onboarding/) · [research-ops](skills/research-ops/) · [decision-records](skills/decision-records/) · [continuous-learning](skills/continuous-learning/) · [skill-scout](skills/skill-scout/) · [context-budget](skills/context-budget/)

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
