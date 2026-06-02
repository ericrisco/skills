# rsc-universal — CLI installer & in-chat recommender (ECC-faithful)

**Date:** 2026-06-02
**Status:** Approved (brainstorming) → ready for implementation plan
**Author:** Eric Risco

## Summary

Replace the Claude Code plugin-marketplace distribution of the rsc skills catalog
with a custom Node CLI — `rsc-universal`, invoked as `npx rsc` — modelled
faithfully on [ECC](https://github.com/affaan-m/ECC)'s `ecc-universal` installer.

The system has two faces sharing one catalog:

1. **`npx rsc`** — a terminal assistant. Default mode is an **ultra-simple
   conversational wizard** for non-programmers: they describe what they want in
   plain language, it reads the current repo, and it recommends + installs the
   right skills one at a time. Power users get `add`, `install --profile`,
   `consult`, `doctor`, `list`, `uninstall`.

2. **`rsc-suggest`** — a **mandatory, always-on detector skill** that runs inside
   Claude Code / Codex. When the current task would benefit from a skill that is
   not installed, it says so and installs it (with a one-word confirm) by calling
   `npx rsc add <skill>`.

The unit of installation is the **individual skill** (maximum granularity): you
install `fastapi` without ever pulling `go`. This resolves the original "the Go
part of the backend bundle is context noise" problem at install time.

## Goals

- **Ultra-simple for non-programmers.** The default flow never shows the words
  "skill", "capability", "profile", "target", or "install". The user speaks in
  outcomes; the CLI translates.
- **Maximum granularity.** Install per skill, on demand. No "install everything
  to be safe". Arranque mínimo, crece pieza a pieza.
- **Self-recommending.** Both the terminal (`consult`) and the chat
  (`rsc-suggest`) detect what the project needs — from the repo contents and the
  user's words — and propose the next skill.
- **Not code-only.** First-class support for non-code outcomes: connect &
  document a company via the `harness` skill (`01-TOOLS/` connectors + `02-DOCS/`
  Karpathy wiki), run ops, personal knowledge.
- **ECC-faithful.** Same architecture: Node ≥18 npm package; `plan → apply`
  split; `install-state.json`; `consult` advisor backed by `sql.js` FTS; `ajv`
  frontmatter validation; manifest with CI-enforced counts; multi-target writers
  (Claude / Cursor / Codex / Gemini).
- **Clean cutover.** Remove every trace of the marketplace model — no orphan
  files, no stale references.

## Non-goals

- Real embedding-based semantic search (ECC uses `sql.js` FTS keyword matching;
  we match that, not exceed it).
- Keeping the plugin marketplace working in parallel. The CLI replaces it.
- A GUI. Terminal + in-chat only.

## Source of truth

`skills/<id>/` remains the **single source of truth** for every skill. Nothing is
hand-edited under a distribution tree; everything is generated/copied from
`skills/`. Current catalog (29 skills):

```
analyze author-skill building-agents clarify constitution course-storytelling
debug deployment design fastapi flutter go harness implement init marketing
nextjs parallel plan postgresdb presentations review sdd secure-coding ship
specify tasks verify worktrees
```

## Architecture

```
rsc-skills/                          (this repo)
├── package.json                     # name "rsc-universal"; bin { rsc, rsc-install }; node>=18
├── manifest.json                    # GENERATED catalog (build-manifest.js); committed
├── schema/
│   └── frontmatter.schema.json      # ajv schema for every SKILL.md frontmatter
├── scripts/
│   ├── rsc.js                       # CLI dispatcher + default interactive wizard
│   ├── build-manifest.js            # skills/*/SKILL.md  ->  manifest.json (+ count assert)
│   ├── install-plan.js              # {skills, target} -> declarative plan (no writes)
│   ├── install-apply.js             # execute plan; write install-state.json   (bin: rsc-install)
│   ├── consult.js                   # advisor: repo-detect + sql.js FTS -> ranked recommendations
│   ├── detect-repo.js               # shared brownfield stack detector
│   ├── doctor.js                    # health: state vs disk, orphans, counts, target
│   ├── lib/
│   │   ├── manifest.js              # load/query manifest
│   │   ├── state.js                 # read/write install-state.json
│   │   ├── recommend.js             # ranking + `recommends` expansion (shared by consult & wizard)
│   │   └── ui.js                    # tiny prompt/printing helpers (no deps)
│   ├── eval-lint.sh                 # KEPT
│   └── sync-bundles.sh              # REMOVED
├── targets/
│   ├── index.js                     # detect target; dispatch to writer
│   ├── claude.js                    # ~/.claude/skills/rsc/<id>/ + SessionStart hook wiring
│   ├── cursor.js                    # .cursor/rules/
│   ├── codex.js                     # AGENTS.md + .codex/ (TOML via @iarna/toml)
│   └── gemini.js                    # GEMINI.md / .gemini/
├── skills/<id>/SKILL.md             # SOURCE OF TRUTH; frontmatter extended (tags + recommends)
├── skills/suggest/                  # NEW mandatory detector skill (rsc-suggest)
├── .claude-plugin/marketplace.json  # REMOVED
└── plugins/                         # REMOVED (8 dirs incl orphan rsc-review)
```

**Dependencies (match ECC):** `sql.js` (FTS index for `consult`), `ajv`
(frontmatter validation), `@iarna/toml` (Codex writer). Dev: `eslint`, `c8`,
`markdownlint`.

## Catalog model

### Frontmatter (validated by ajv)

```yaml
---
name: fastapi
description: "Use when building FastAPI / async Python services…"
tags: [python, api, async, backend]        # feed the consult FTS index
recommends: [postgresdb, secure-coding]     # "people who install this usually want these"
profiles: [full]                            # optional: which named profiles include it by default
---
```

- `name`, `description` — already present on every skill; required.
- `tags` — keywords the advisor searches over. Required (≥1).
- `recommends` — skill ids the system offers next. Optional. Must reference real
  skill ids (validated by build-manifest, not ajv).
- `profiles` — optional named-profile membership. Default `[]`.

We deliberately **do not** use ECC's rigid `capabilities` buckets. `tags` (for
search) + `recommends` (for chaining) are finer-grained and simpler.

### Profiles (power-user shortcuts only)

Named bundles, never shown to non-programmers:

- `minimal` → `suggest`, `harness`, `init` (the floor: detector + bootstrap).
- `core` → `minimal` + the SDD workflow (`sdd`, `constitution`, `specify`,
  `clarify`, `plan`, `tasks`, `analyze`, `implement`, `verify`, `review`, `ship`,
  `debug`, `worktrees`, `parallel`).
- `full` → every skill.

### Outcomes (the recommender's vocabulary)

The recommender maps plain-language goals to outcomes, spanning **both** code and
company-harness families. This mapping lives in `lib/recommend.js` as a small
table keyed by tags; it is not user-visible config.

| User says (plain language) | Outcome shown | Skills under the hood |
|---|---|---|
| "documentar mi empresa" | Base de conocimiento que se documenta sola | `harness` (→ `02-DOCS/` wiki) |
| "conectar pagos / email / datos" | Tus herramientas conectadas | `harness` (→ `01-TOOLS/` connectors) |
| "llevar mi empresa / procesos" | Espacio de trabajo ordenado | `harness` |
| "una web / app / API" | El producto | `nextjs` / `flutter` / `fastapi` |
| "que sea seguro y esté online" | Seguro y publicado | `secure-coding`, `deployment` |

### Manifest

`manifest.json` is generated by `build-manifest.js` from all `skills/*/SKILL.md`:

```json
{
  "version": "<from package.json>",
  "counts": { "skills": 30 },
  "skills": [
    { "id": "fastapi", "description": "…", "tags": ["python","api"], "recommends": ["postgresdb"], "profiles": ["full"] }
  ]
}
```

CI runs `build-manifest.js --check` and fails if the committed manifest is stale
or if `counts.skills` ≠ actual skill dirs (ECC's count-enforcement pattern).

## The simple interface (default `npx rsc`)

Rules: zero jargon; outcomes not skills; one plain question; auto-detect target;
confirm in natural language.

```
$ npx rsc

Hola 👋 ¿Qué quieres hacer?
> documentar mi empresa y tener todo conectado en un sitio

He preparado esto para ti:
   📚 Una base de conocimiento de tu empresa (se documenta sola)
   🔌 Conexiones a tus herramientas (pagos, email, base de datos…)
   🗂️  Un espacio de trabajo ordenado donde todo vive
¿Lo monto? (sí / no)
> sí

✅ Listo. Abre tu editor y dime "documenta mi proceso de ventas".
   💡 Cuando quieras añadir algo más, vuelve a escribir: npx rsc
```

Internals:
1. `detect-repo.js` scans cwd for stack signals.
2. `consult.js` runs the user's phrase through the `sql.js` FTS index over the
   manifest; merges with repo signals; expands via `recommends`.
3. `recommend.js` renders results as **outcomes** (not skill names) for the
   non-programmer view.
4. On confirm, `install-plan.js` → `install-apply.js` copies to the detected
   target and updates `install-state.json`.
5. Prints the **next** suggestion based on `recommends` of what was installed.

Power-user surface (same engine underneath):

```
npx rsc add fastapi postgresdb         # granular, by name
npx rsc install --profile full         # named shortcut
npx rsc install --profile minimal --target cursor --without go
npx rsc consult "security review"      # recommend only, no install
npx rsc list                           # what rsc installed (from state)
npx rsc doctor                         # health check
npx rsc uninstall postgresdb --dry-run # preview removal
```

## Repo / project detection (brownfield)

`detect-repo.js` (shared by the CLI and the `init` skill) maps file signals to
suggested skills:

| Signal in repo | Suggests |
|---|---|
| `package.json` with `next`/`react` | nextjs, design |
| `pubspec.yaml` (Dart) | flutter |
| `requirements.txt` / `pyproject.toml` (+FastAPI) | fastapi |
| `go.mod` | go |
| `*.sql`, `migrations/`, `prisma/`, Postgres conn strings | postgresdb |
| `Dockerfile`, `.github/workflows/`, `compose.yaml` | deployment |
| empty / README-only | greenfield → ask in plain language |

Recommendation = repo detection (what exists) + user phrase (what they want) +
`recommends` (what usually accompanies). `doctor` reports already-installed skills
so we never recommend a duplicate.

## Install pipeline

- **`install-plan.js`**: input `{skillIds, target, dryRun}` → output a declarative
  plan: an array of `{ from: skills/<id>, to: <target path>, kind: "skill"|"hook"|"agents.md" }`.
  Pure; no filesystem writes. Resolves `recommends`? No — planning installs only
  the explicitly chosen ids; recommendation happens upstream in `consult`.
- **`install-apply.js`** (also exposed as bin `rsc-install`): executes a plan,
  copies skill dirs through the target writer, wires the always-on hook for
  `rsc-suggest` if present, and records every written path in `install-state.json`.
- **`install-state.json`** (written at the install location, e.g.
  `~/.claude/skills/rsc/.rsc-state.json`): the truth of "what rsc manages". Lists
  installed skill ids and their files. Enables clean `uninstall` without touching
  user-authored files.

## Lifecycle

- **`rsc list`** — reads state; prints installed skills.
- **`rsc doctor`** — compares state vs disk (missing/orphan files), validates
  manifest counts, reports detected target and whether the `rsc-suggest` hook is
  wired.
- **`rsc uninstall <skill> [--dry-run]`** — removes only state-tracked files;
  `--dry-run` previews.

## Multi-target writers

`skills/<id>/` is the source; each writer translates to its IDE format. Target is
auto-detected (presence of `.claude/`, `.cursor/`, `.codex/`, `.gemini/`,
`AGENTS.md`) or forced with `--target`.

| Target | Destination | Format | Always-on mechanism for rsc-suggest |
|---|---|---|---|
| `claude` | `~/.claude/skills/rsc/<id>/SKILL.md` | SKILL.md verbatim | SessionStart hook in `settings.json` |
| `cursor` | `.cursor/rules/<id>.mdc` | rule per skill | always-apply rule |
| `codex` | `AGENTS.md` + `.codex/` | append block / TOML | block in `AGENTS.md` (always loaded) |
| `gemini` | `.gemini/` + `GEMINI.md` | Gemini format | block in `GEMINI.md` |

Default: the wizard detects the target and does not ask (simplicity).

## The mandatory detector — `rsc-suggest`

A new skill at `skills/suggest/` whose body is **tiny** (~15 lines) because it is
the only thing permanently in context every session — the exact permanent-noise
cost the project set out to minimize. All heavy logic (what to recommend) is
resolved at call time by querying `manifest.json` via `npx rsc consult`, not
carried in the always-on text.

**Behaviour:** during any conversation, if the task would benefit from a skill
that is not installed, state which, ask a one-word confirm, and on yes run
`npx rsc add <skill>` (a Bash call) — then continue. Installing writes to the
user's environment, so it always confirms first.

**Made mandatory by construction:** the very first `npx rsc` installs
`profile: minimal` (which includes `suggest`) and wires the per-target always-on
mechanism. It is the floor of the system, not opt-in.

```
Tú: ayúdame a montar la base de datos de pedidos
Claude: Para esto va de perlas `postgresdb`, que aún no tienes. ¿La instalo? (sí/no)
Tú: sí                → npx rsc add postgresdb  → ✅  → continúa
```

## The zero-to-running loop

1. `npx rsc` → installs only the floor (`suggest` + `harness` + `init`, profile
   `minimal`). Seconds. No stacks, no addons.
2. User works in plain language.
3. Detector reads repo + words → proposes the next skill → one-word confirm →
   `npx rsc add <id>`.
4. Repeat. The system grows with the project, one skill at a time.

## Cleanup (clean cutover off marketplace)

**Delete:**
- `.claude-plugin/marketplace.json`
- `plugins/` entirely (8 dirs: rsc-core/backend/frontend/content/agents/ops/sdd +
  orphan `rsc-review` with its agents/commands)
- `plugins/*/.claude-plugin/plugin.json` (×8)
- `scripts/sync-bundles.sh`

**Rewrite references** (not just delete files) so every mention of
`/plugin install … @rsc-skills`, "bundle", `npx skills`, and `sync-bundles`
becomes `npx rsc …`, in:
- `README.md`
- `skills/init/SKILL.md`, `skills/init/references/recommend-bundles.md`
- `skills/author-skill/SKILL.md`, `skills/author-skill/references/rsc-conventions.md`,
  `skills/author-skill/evals/README.md`
- `skill-build/rsc-sdd/spec.md`

**Acceptance:** `grep -rIn -E "marketplace|/plugin install|sync-bundles" .` (excluding
`node_modules/`, `docs/superpowers/specs/`, and git history) returns **0 hits**.

## Testing

- **Unit:** `detect-repo.js` (fixture dirs per stack), `recommend.js` (ranking +
  `recommends` expansion), `lib/state.js` (round-trip), `install-plan.js` (plan
  shape per target).
- **Manifest:** `build-manifest.js --check` is idempotent and count-accurate.
- **Frontmatter:** ajv validates every `skills/*/SKILL.md`; CI fails on a missing
  `tags` or a dangling `recommends` id.
- **Integration (per target):** `install-apply.js` into a temp HOME, then `doctor`
  reports healthy and `uninstall --dry-run`/real leaves the temp clean.
- **Cleanup gate:** the 0-hit grep above runs in CI.

## Open questions / deferred

- npm package name `rsc-universal` assumed available; confirm before publish
  (fallback `@ericrisco/rsc`). Does not block local `node scripts/rsc.js`.
- Cursor/Gemini exact rule formats verified against current docs during
  implementation of those writers (Claude + Codex are the primary tested paths).
```