# Recommend Bundles — the bundle map, sample printouts & the "siempre 3 opciones" pattern

Phase 3 detail. Map discovery to rsc bundles, print the exact install commands, and run the requirements-first 3-option decision pattern for any significant choice. A skill **cannot install plugins** — it recommends and prints commands the user runs.

## The bundle map

| Discovery signal | Bundle | What it gives | One-line *why* (adapt to level) |
| --- | --- | --- | --- |
| Always (every project) | `rsc-core` | `init` + `harness` | The harness itself — scaffolds and governs the whole workspace. |
| Backend / API / database | `rsc-backend` | fastapi, go, postgresdb | The server, the API, the database that remembers things. |
| Web or mobile UI | `rsc-frontend` | nextjs, flutter, design | The screens people actually see and tap. |
| Marketing / landing / decks / teaching | `rsc-content` | marketing, presentations, course-storytelling | The words, slides, and lessons that explain and sell it. |
| AI agents | `rsc-agents` | building-agents | Agents that use tools and reason over your data. |
| Security & shipping / ops (incl. non-code company harness connecting tools) | `rsc-ops` | secure-coding, deployment | Ship it safely and wire up the external tools (email, payments, hosting). |

Recommend a bundle **only if discovery justified it** — same discipline as "no speculative tools". Don't recommend `rsc-agents` because agents are trendy; recommend it because the user said they want an agent.

Note on the non-code harness: a company/ops/research/content harness almost always wants `rsc-core` (the structure) + `rsc-ops` (to connect external tools and handle credentials securely), and often `rsc-content`. It usually does NOT want `rsc-backend`/`rsc-frontend` unless they're also building software.

## What to print

Print the marketplace add once, then one install line per recommended bundle, each with its *why* in the user's language and level.

```text
/plugin marketplace add ericrisco/skills
/plugin install <bundle>@rsc-skills
```

### Sample printout — software, full-stack web app with marketing

```text
Based on what you described (a web app with a backend, a Next.js UI, a landing
page, and you want to ship it securely), install these:

/plugin marketplace add ericrisco/skills
/plugin install rsc-core@rsc-skills       # the harness — scaffolds and governs the workspace
/plugin install rsc-backend@rsc-skills    # FastAPI + PostgreSQL — the API and the database
/plugin install rsc-frontend@rsc-skills   # Next.js + design — the web UI people see
/plugin install rsc-content@rsc-skills    # marketing — the words for your landing page
/plugin install rsc-ops@rsc-skills        # secure-coding + deployment — ship it safely

Once they're installed, run /rsc-core:harness and I'll build the project structure.
```

### Sample printout — non-code harness, running an agency's operations

```text
You're organizing how your agency runs — client emails, contracts, invoicing,
and you want it all findable. That's a non-code harness; install:

/plugin marketplace add ericrisco/skills
/plugin install rsc-core@rsc-skills       # the harness — your 01-TOOLS (connections) + 02-DOCS (your second brain)
/plugin install rsc-ops@rsc-skills        # connect email, payments, drive — and keep credentials safe
/plugin install rsc-content@rsc-skills    # for the proposals, decks and copy you send clients

Once installed, run /rsc-core:harness and I'll set up the structure that holds it all.
```

### Sample printout — greenfield AI agent

```text
You want an AI agent that answers questions over your own documents. Install:

/plugin marketplace add ericrisco/skills
/plugin install rsc-core@rsc-skills       # the harness
/plugin install rsc-agents@rsc-skills     # building-agents — agent loops, tools, RAG
/plugin install rsc-backend@rsc-skills    # an API + database to serve it
/plugin install rsc-ops@rsc-skills        # ship it safely

Then run /rsc-core:harness.
```

## The "siempre 3 opciones" decision pattern

For any significant decision — deploy target, database, framework, hosting, which CRM, where documents live — never decide silently and never dump ten choices. Four steps:

### 1. Gather the driving requirements first

Ask the questions that actually change the answer. Match question count/depth to `accompaniment_level` (L0: only hard blockers; L3: ask all, explaining why each matters). Checklists per decision type:

- **Deploy target:** expected number of users; concurrent users; budget; data region / residency rules; the team's comfort operating servers; scaling needs (steady vs spiky); existing org/cloud constraints.
- **Database:** data shape (relational vs documents vs key-value); expected size and growth; query patterns; consistency vs scale needs; managed vs self-hosted preference; budget.
- **Framework / language:** team's existing skills; the surfaces needed; performance constraints; ecosystem/libraries required; hiring/longevity.
- **Where knowledge/documents live (non-code harness):** volume and formats; who needs access; privacy / residency of client data; search needs; existing tools already paid for.

### 2. Present EXACTLY three options

Three, with honest trade-offs — what each is good at, what it costs, what it demands. Not two (false binary), not ten (paralysis). If a fourth is genuinely worth knowing, mention it in one line under the third — but the choice is between three.

### 3. Recommend one, matched to their answers AND their level

State your recommendation and why, in language they understand. At L3 / non-technical, explain each option in plain terms and check they followed before they pick.

### 4. Log the decision

Once they choose, append an entry to `02-DOCS/wiki/harness/decisions.md` (format in `accompaniment-and-profile.md`): context (the requirements you gathered), the three options, the decision, and why.

## Canonical worked example — deploy target

Requirements gathered: ~500 users, ~20 concurrent, low budget, EU data residency required, small team comfortable with a little server work, steady (non-spiky) traffic.

> **Option 1 — Hetzner VPS + Coolify.** Cheapest by far (a capable box is a few euros a month), total control, and Hetzner has EU regions so residency is covered. The catch: you self-manage the server — updates, backups, keeping it up. Coolify makes deploys push-button, but the box is yours.
>
> **Option 2 — Vercel.** Zero-ops: you push, it deploys, it scales itself, nothing to maintain. The catch: it gets expensive as you grow, and you're shaped by its model (best for frontend/serverless; data residency and always-on backends need care).
>
> **Option 3 — Fly.io.** Managed containers that run in an EU region close to your users, simpler than raw cloud, more hands-off than a VPS. The catch: a bit pricier than Hetzner and you still think in containers.
>
> **Recommendation:** Option 1 (Hetzner + Coolify, EU region). Your budget is tight, EU residency is a hard requirement Hetzner satisfies cleanly, traffic is steady so you don't need autoscaling, and your team is fine managing one box. We log this and move on; if ops ever becomes a burden, Option 3 is the easy step up.

This decision triggers `/rsc-ops:deployment` at build time, which knows Hetzner+Coolify, Vercel, Fly.io and the rest in depth. `init` makes the choice and records it; `deployment` executes it.
