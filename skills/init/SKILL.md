---
name: init
description: "Use when starting from nothing or pointing the rsc-skills harness at an existing project — the front door / bootstrapper. It gauges the user's technical level FIRST (non-technical by default), sets an explanation/accompaniment dial, then discovers what they want to build OR govern (any software stack, OR a non-code harness: running a company/ops, research, personal knowledge, content). It detects greenfield vs brownfield, profiles the user into 02-DOCS, RECOMMENDS which rsc bundles to install (printing the exact install commands), and hands off to /rsc-core:harness to scaffold 01-TOOLS + 02-DOCS. Triggers: 'empezar de cero', 'no sé por dónde empezar', 'start a new project', 'bootstrap', 'set up the harness', 'monta el proyecto', 'quiero montar una empresa/ops/wiki con esto', 'arranca', 'init'. NOT the scaffolder itself (that's /rsc-core:harness) and NOT a specific stack skill."
origin: risco
---

# init — the rsc-skills Front Door

*The very first thing you run. It meets the user where they are — assuming non-technical until told otherwise — figures out what they actually want, recommends the right bundles, and hands off to `/rsc-core:harness` to build the workspace.*

It **profiles, discovers, and recommends**, then prints the exact install commands and the handoff. The boundary is fixed: **`init` writes ONLY the user-profile + decisions log under `02-DOCS/wiki/harness/` and the `CLAUDE.md` Knowledge-map link; ALL other `01-TOOLS/` + `02-DOCS/` scaffolding is `/rsc-core:harness`'s job.** Think of `init` as the receptionist: it learns who you are and what you need, writes that down where every other skill can read it, and walks you to the right room.

It is **domain-agnostic**. The thing being built or governed may be:

- **Software** — any stack (web, mobile, backend, agents, a CLI, a data pipeline).
- **A non-code harness** — running a company / operations, a research program, a personal knowledge base, or a content operation that connects to tools (email, calendar, CRM, docs, payments). No code required; the same `01-TOOLS/` + `02-DOCS/` structure governs it (scaffolded by `/rsc-core:harness`, not here).

## Non-technical-first + the accompaniment dial (read this first)

This is the most important section. The whole harness behaves differently depending on two values set here. **Set them before doing anything else, on first contact, in this order.**

### Step 1 — Gauge technical level (the VERY FIRST question)

The system **always starts assuming the user is non-technical.** The very first thing you say, before any discovery, gauges their technical level — framed kindly, never making anyone feel small. Ask once, in their language. For a Spanish speaker:

> "Antes de nada, para hablarte como te resulte más cómodo: ¿te manejas con código y términos técnicos, o prefieres que te lo explique todo en cristiano? No hay respuesta mala — solo me ayuda a no aburrirte ni perderte."

For an English speaker:

> "First, so I talk to you the right way: are you comfortable with code and technical terms, or would you rather I explain everything in plain language? There's no wrong answer — it just helps me not bore you or lose you."

Until they say otherwise, **default to non-technical framing**: plain language, no jargon, analogies over acronyms. Record the answer as `technical_level: non-technical | mixed | technical`.

### Step 2 — Set the accompaniment / explanation dial

Immediately after, present the dial and let them pick. Describe each option clearly — do not just list letters:

- **L0 — "Modo cavernícola"**: mínimas palabras. Hago las cosas y ya, casi sin explicar. Para quien quiere resultados y cero ruido.
- **L1 — "Breve"**: una línea de *por qué* en cada paso. Sabes lo que hago sin que te cuente la vida.
- **L2 — "Explica decisiones"**: justifico cada decisión relevante a medida que avanzo. Para quien quiere entender el porqué de lo importante.
- **L3 — "Acompañamiento total"**: te lo explico TODO, te hago muchas preguntas para entender bien tu contexto, y razono cada decisión. Ideal si no eres técnico y quieres aprender mientras montamos esto.

Record as `accompaniment_level: L0 | L1 | L2 | L3`. If the user is non-technical and gives no preference, **default to L3**. If technical and silent, default to L1.

### Step 3 — Persist BEFORE anything else

Before discovery, before any recommendation, write the profile to `02-DOCS` and link it from the root `CLAUDE.md`. This is non-negotiable: every other skill reads these values to decide how much to explain and how many questions to ask.

- `02-DOCS/wiki/harness/user-profile.md` — the living profile (technical level, accompaniment level, goals, context, constraints). Format in `references/accompaniment-and-profile.md`.
- `02-DOCS/wiki/harness/decisions.md` — an **append-only** decisions log. Every significant decision gets one entry, never edited or deleted. Format in `references/accompaniment-and-profile.md`.
- Root `CLAUDE.md` → a `## Knowledge map` section linking to BOTH files. Create `CLAUDE.md` if absent (additive only — never delete existing sections).

If `02-DOCS/` does not yet exist (greenfield), create `02-DOCS/wiki/harness/` now — just enough to hold these two files. That, plus the `CLAUDE.md` Knowledge-map link, is everything `init` writes; ALL other `01-TOOLS/` + `02-DOCS/` scaffolding is `/rsc-core:harness`'s job.

### How every skill adapts to the dial

Every rsc skill MUST read `user-profile.md` at the start of a session and adapt:

| Level | Verbosity | Questions it asks | Jargon |
| --- | --- | --- | --- |
| L0 | One line of output, results only | None beyond hard blockers | Avoided |
| L1 | One *why* line per step | Only when genuinely ambiguous | Minimal, defined inline |
| L2 | Justify each relevant decision | Asks before each significant decision | OK if defined once |
| L3 | Explain everything, narrate reasoning | Many — contextualizes every choice | Always translated to plain language |

`technical_level` is an orthogonal modifier: even at L0, a non-technical user gets plain-language phrasing; even at L3, a technical user gets to skip the 101 explanations. Full rules and the exact file formats → `references/accompaniment-and-profile.md`.

## The "siempre 3 opciones" decision pattern

For **any** significant decision — deploy target, database, framework, hosting, tooling, which CRM, where to keep documents — never decide silently and never dump ten options. Run this pattern:

1. **Gather requirements first.** Ask the questions that actually drive the choice. For a deploy target: expected number of users, concurrent users, budget, data region / residency rules, the team's comfort operating servers, and scaling needs. Match the number and depth of questions to the accompaniment level (L0: ask only blockers; L3: ask all, explaining why each matters).
2. **Present EXACTLY 3 options** with honest trade-offs — what each is good at, what it costs, what it demands of them.
3. **Recommend one**, matched to their answers AND their level, and say why in language they understand.
4. **Log the decision** to `02-DOCS/wiki/harness/decisions.md` (append-only) once they pick.

Canonical deploy example (tailor the third option to the case):

1. **Hetzner VPS + Coolify** — cheapest, total control, but you self-manage the server (updates, backups, uptime).
2. **Vercel** — zero-ops, fully managed, scales itself; gets expensive at scale and locks you into its model.
3. **A third matched to the case** — Fly.io (run close to users, simple containers), Railway (managed, gentle learning curve), or a managed cloud (AWS/GCP) when compliance or an existing org demands it.

Full pattern, the requirements-gathering checklists per decision type, and the worked deploy example → `references/recommend-bundles.md`.

## The flow

Run these phases in order. Phase 1 is mandatory and comes before everything.

```text
PROFILE → DISCOVER → RECOMMEND → HANDOFF
```

### Phase 1 — PROFILE

Gauge technical level (Step 1), set the accompaniment dial (Step 2), and persist the profile + Knowledge-map link (Step 3) — all per the section above. Do not proceed until `user-profile.md` exists and `CLAUDE.md` links it.

### Phase 2 — DISCOVER

Figure out two things: **the state of the ground** and **what they want**.

**Greenfield vs brownfield** — detect, don't ask blindly:

- **Brownfield** if the workspace has subproject manifests (`package.json`, `pyproject.toml`, `pubspec.yaml`, `go.mod`, `Cargo.toml`), source files, legacy `XX-*` folders, or an existing `01-TOOLS/` / `02-DOCS/`. Detect the stack and current state the way `harness` SCAN does (read-only walk; ignore `node_modules/`, `.venv/`, `.next/`, `.git/`, `dist/`, `build/`, `__pycache__/`, `.dart_tool/`). Summarize what you found and confirm with the user.
- **Greenfield** if the workspace is empty or has only stray notes. Then it's a brand-new idea — interview from zero.

**What they want to build OR govern** — establish the domain. Is it software (which surfaces: backend, frontend, mobile, agents)? Or a non-code harness (company/ops, research, personal knowledge, content)? Then capture goals, audience, constraints, and any tools/providers already in play.

Record everything to `02-DOCS/wiki/harness/` as you go. Use the greenfield and brownfield questionnaires (for software AND non-code harnesses) in `references/discovery.md`. Ask in batches sized to the accompaniment level — never dump every question at once.

### Phase 3 — RECOMMEND

Map what you learned to rsc bundles and **print the exact install commands**. A skill cannot install plugins itself — it recommends and prints commands the user runs. Bundle map:

| Need | Bundle | Why (one line, matched to level) |
| --- | --- | --- |
| Always | `rsc-core` | The harness itself: `init` + `harness` to scaffold and govern the workspace. |
| Software backend | `rsc-backend` | FastAPI, Go, PostgreSQL — the server, the database, the API. |
| Software frontend | `rsc-frontend` | Next.js, Flutter, design — the web/mobile UI people see. |
| Marketing / landing / decks / teaching | `rsc-content` | Marketing copy, presentations, course storytelling — the words and slides. |
| AI agents | `rsc-agents` | building-agents — agent loops, tools, RAG. |
| Security & shipping / ops (incl. non-code company harness connecting tools) | `rsc-ops` | secure-coding + deployment — ship it safely and wire up external tools. |

Print, with a one-line *why* per recommended bundle (language matched to the user's level):

```text
/plugin marketplace add ericrisco/skills
/plugin install <bundle>@rsc-skills
```

Recommend only bundles their answers justify — same discipline as "no speculative tools". Full bundle map, sample printouts per scenario, and the requirements-first decision pattern → `references/recommend-bundles.md`.

### Phase 4 — HANDOFF

Tell the user to run **`/rsc-core:harness`** to actually scaffold the `01-TOOLS/` + `02-DOCS/` workspace. `init` stops here — it has set the profile, recorded the discovery, and recommended the bundles. `harness` reads the profile and builds the structure.

> "Tu perfil y lo que hemos hablado ya están guardados. Cuando hayas instalado los bundles de arriba, ejecuta `/rsc-core:harness` y monto el esqueleto del proyecto (`01-TOOLS/` + `02-DOCS/`) leyendo todo lo que acabamos de decidir."

## Iron rules (non-negotiable)

1. **Profile first, always.** Technical-level question is the literal first thing. Nothing — no discovery, no recommendation — happens before `user-profile.md` exists and `CLAUDE.md` links it.
2. **Non-technical by default.** Plain language until told otherwise. Never assume the user reads code.
3. **The dial governs verbosity AND question count.** Read it, obey it, in this skill and every skill downstream. L0 means *do it and stop talking*; L3 means *explain everything and ask*.
4. **Three options, requirements first.** For any significant decision: gather the driving requirements, present exactly 3 options with honest trade-offs, recommend one, log it.
5. **Recommend, never install.** A skill cannot run `/plugin install`. Print the commands; the user runs them.
6. **No speculative bundles.** Recommend a bundle only if the discovery justified it. No "you'll probably want agents too".
7. **Persist as you learn.** Goals, context, constraints, decisions go to `02-DOCS/wiki/harness/` continuously — `user-profile.md` for state, `decisions.md` append-only for choices.
8. **`init` writes only the profile + the link.** It writes ONLY the user-profile + decisions log under `02-DOCS/wiki/harness/` and the `CLAUDE.md` Knowledge-map link. ALL other `01-TOOLS/` + `02-DOCS/` scaffolding is `/rsc-core:harness`'s job. Hand off; do not do its job.
9. **Additive to `CLAUDE.md`.** Create it if absent; otherwise add/update only the `## Knowledge map` section. Never delete user content.
10. **Domain-agnostic.** Software and non-code harnesses get the same first-class treatment. Never assume "project" means "code".

## Rationalizations — STOP

These thoughts mean the skill is about to break its own rules. Recognize and abort:

| Excuse | Reality |
| --- | --- |
| "They sound technical, I'll skip the level question" | No. The level question is the first thing, always. Ask it. |
| "I'll just pick Vercel, it's obviously best" | No. Gather requirements, present 3, recommend with reasons, log it. |
| "I'll recommend every bundle to be safe" | No. Recommend only what discovery justified. |
| "I'll scaffold 01-TOOLS now while I'm here" | No. That's `/rsc-core:harness`. `init` profiles and hands off. |
| "The profile can wait until after discovery" | No. Profile first — every later question's framing depends on it. |
| "This is a company, not code, so the harness doesn't apply" | No. Domain-agnostic. A non-code harness uses the same structure. |
| "I'll install the plugins for them" | No. A skill can't install. Print the commands. |
| "They said 'ok', that's enough to pick the database" | No. A significant decision needs the 3-option pattern and a log entry. |

## Project grounding (02-DOCS + CLAUDE.md)

This skill's `02-DOCS` record is the **user profile** at `02-DOCS/wiki/harness/user-profile.md` plus the append-only **decisions log** at `02-DOCS/wiki/harness/decisions.md`. Both are written in Phase 1 and updated throughout, and both are linked from a `## Knowledge map` section in the root `CLAUDE.md` (created if absent, additive only). Every rsc skill reads the profile first and adapts its verbosity and question count to `accompaniment_level` and `technical_level`. Those two files plus the Knowledge-map link are everything `init` writes; ALL other `01-TOOLS/` + `02-DOCS/` scaffolding is `/rsc-core:harness`'s job, and it reads this same profile.

Verify the profile and the Knowledge-map link exist with `scripts/verify.sh` (read-only; warns, never fails).

## See Also

- `/rsc-core:harness` — the scaffolder this skill hands off to; builds `01-TOOLS/` + `02-DOCS/` from the profile (the `harness` SCAN→AUDIT→CONSENT→APPLY→VERIFY engine).
- `/rsc-ops:deployment` — invoked at runtime when the deploy decision (the "siempre 3 opciones" canonical example) is made; Hetzner+Coolify, Vercel, Fly.io and friends.
- `/rsc-ops:secure-coding` — input validation, authn/z, secret handling; recommended whenever software is being shipped.
- Domain bundles (`rsc-backend`, `rsc-frontend`, `rsc-content`, `rsc-agents`) are **recommended at runtime** by Phase 3 based on discovery — not hardwired here.
- References: `references/accompaniment-and-profile.md`, `references/discovery.md`, `references/recommend-bundles.md`.
