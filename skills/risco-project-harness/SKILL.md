---
name: risco-project-harness
description: "Use when bootstrapping or auditing a workspace that needs a `01-TOOLS/` operational tooling layer and a `02-DOCS/` LLM-wiki layer. Triggers: 'audita mi proyecto', 'bootstrap workspace', 'monta 01-TOOLS y 02-DOCS', 'risco harness', 'project harness', migrating numbered `XX-*` folders into the canonical structure, detecting external provider integrations (Stripe, Mailjet, Hetzner, Firebase, OAuth, Postgres…) and scaffolding connection-ready tools, generating root `CLAUDE.md`/`AGENTS.md`, or consolidating scattered docs into a Karpathy-style wiki. Brownfield-first; greenfield is the degenerate case."
---

# Risco Project Harness

A workspace orchestrator that audits a project root, proposes a concrete migration plan, and — only with explicit user consent — scaffolds two canonical layers:

- **`01-TOOLS/<PROVIDER>/`** — operational tooling, one folder per external provider, co-locating credentials (`.env`) with the scripts that consume them. Each tool ships a working `probar_conexion` against the real API.
- **`02-DOCS/`** — LLM wiki (`raw/` + `wiki/` + `wiki/index.md` + `wiki/log.md` + `wiki/gaps.md` + `wiki/scores.json`) following the Karpathy pattern, fully embedded in this skill. The protocol lives at `references/wiki-protocol.md` with templates at `references/wiki-*.md`. The wiki **self-improves continuously**: every Ingest and Query triggers a Maintenance Pass (deterministic lint, score recomputation, gap detection, See Also sweep), and every N interactions a Micro-Improve runs (rewrite 1 low-scoring article, fill 1 gap, preserving old versions in `_archive/`). Deep Improve runs on explicit request or via scheduled cron. No external skill needed.

Also generates root `CLAUDE.md` and `AGENTS.md`, and migrates legacy `XX-*` numbered folders into the canonical layout.

## Core principle

**Detection with interactive confirmation. Never speculative tools. Never destructive without explicit consent.**

The skill proposes, the user confirms, the skill executes. Every destructive operation (deleting a legacy folder, merging into an existing `CLAUDE.md`) requires explicit consent quoted back from the user, not inferred.

## When to use

- A workspace has grown organically and needs the canonical `01-TOOLS` / `02-DOCS` structure.
- Old numbered folders (`00-TOOLS`, `03-NOTES`, `04-LEGACY`…) exist and need to be consolidated.
- A new project is being kicked off and needs the harness from day one.
- Provider integrations exist in code but there's no operational tooling for them.

**Do NOT use when:**
- The user only wants to add a single tool — they can `cp -r 01-TOOLS/_TEMPLATE 01-TOOLS/<X>` manually.
- The user wants to refactor runtime code — this skill is operational tooling only, never runtime.

## Architecture

```
risco-project-harness/
├── SKILL.md                          ← this file (the protocol)
├── references/
│   ├── providers.yaml                ← detector catalog with full file bodies per provider
│   ├── claude-md-template.md         ← root CLAUDE.md template
│   ├── agents-md-template.md         ← root AGENTS.md template
│   ├── tools-readme-template.md      ← 01-TOOLS/README.md catalog template
│   ├── audit-report-template.md      ← exact format of the audit report shown to user
│   ├── wiki-protocol.md              ← embedded wiki protocol + Continuous Improvement
│   ├── wiki-raw-template.md          ← format for raw/<topic>/*.md
│   ├── wiki-article-template.md     ← format for wiki/<topic>/*.md
│   ├── wiki-index-template.md       ← format for wiki/index.md (with Score column)
│   ├── wiki-archive-template.md     ← format for archived query answers
│   └── wiki-gaps-template.md        ← format for wiki/gaps.md (Knowledge Gaps log)
├── assets/
│   └── _TEMPLATE/                    ← per-tool boilerplate (cp -r seed)
└── examples/
    └── audit-example.md              ← walked-through audit on a synthetic project
```

## Protocol — five phases

```
SCAN → AUDIT → CONSENT → APPLY → VERIFY
```

Never skip a phase. Never collapse phases. The user reads the AUDIT before anything is written.

### Phase 1 — SCAN (read-only)

Walk the workspace root and gather:

1. **Workspace root** — current directory unless the user passes one explicitly.
2. **Subprojects** — top-level directories containing a manifest (`package.json`, `pyproject.toml`, `pubspec.yaml`, `Cargo.toml`, `go.mod`). Record stack per subproject (Next.js, FastAPI, Flutter, Express, etc.) from manifest contents.
3. **Provider detection** — for every entry in `references/providers.yaml`, search the workspace for evidence:
   - `imports`: grep for the SDK import patterns across source files (skip `node_modules/`, `.venv/`, `.next/`, `__pycache__/`, `.git/`, `dist/`, `build/`, `.dart_tool/`).
   - `env_vars`: grep for the variable names in `.env*`, `*.yaml`, `*.yml`, source files.
   - `deps`: search the dependency name in manifest files.
   - Record evidence with `path:line` for each hit. A provider counts as **detected** if any detector matches.
4. **Legacy `XX-*` folders** — list root entries matching `^[0-9]+-[A-Z_]+$`. For each, recursively classify every file:
   - **TOOLING** — folder contains `.env`, `.env.example`, executable scripts (`*.sh`, `*.py` with shebang), or integrates a provider from the catalog.
   - **DOCS** — `*.md`, `*.txt`, diagrams (`*.png`, `*.svg`, `*.mmd`), notes.
   - **AMBIGUOUS** — mixed, runtime code (Python modules without shebang, TS files), or content the classifier cannot place with high confidence.
5. **Existing canonical layout** — check whether `01-TOOLS/`, `02-DOCS/`, `CLAUDE.md`, `AGENTS.md` already exist. If yes, read their current content.
6. **Git state** — for each subproject that's a git repo, capture `git status --short`. Don't act on dirty trees without flagging.

### Phase 2 — AUDIT (presented to user)

Render **two artifacts**:

1. **A compact text summary in the conversation** — 1–3 sentences per section, the full destructive-ops list, the consent prompt. This keeps the terminal flow fast.
2. **A full HTML report at `<workspace_root>/02-DOCS/audits/audit-YYYY-MM-DD-HHMM.html`** using `references/audit-report-template.html`. Self-contained (inline CSS, no CDN). Includes color-coded action tables, collapsible legacy-folder sections, highlighted destructive ops, and the consent prompt. **Gitignored** (per-run artifact).

If `02-DOCS/audits/` does not exist, create it (with `.gitkeep`) before writing — even on first run, before Phase 4 builds the rest of `02-DOCS/`. Same for `02-DOCS/` itself: the audits subdirectory is the only piece allowed to materialize during Phase 2; the rest waits until APPLY. Never write the audit HTML at the workspace root.

The text summary points to the HTML: `"Full audit at ./02-DOCS/audits/audit-XXX.html — open it to review details, then reply 'yes, proceed' or 'adjust'."`

The HTML must contain:

- **Stack summary** — one line per subproject with detected stack and path.
- **Tools to create** — table: `Tool | Evidence (path:line) | Action (CREATE / MERGE / SKIP)`.
- **Legacy `XX-*` folders** — one sub-section per folder, with a per-file classification table and a proposed destination.
- **Ambiguous files** — explicit list. These will NOT be moved. The user decides later.
- **Root files** — what happens to `CLAUDE.md` / `AGENTS.md` (CREATE, MERGE-additive, or SKIP if identical).
- **`02-DOCS/` plan** — list of sources to ingest (per `references/wiki-protocol.md`), the topics that will appear in `wiki/`, and confirmation that the wiki layer is built in-skill.
- **Files NEVER touched** — explicit list reminding the user of the safety boundary: real `.env`, contents of `node_modules/`, `.venv/`, `.next/`, `__pycache__/`, `.git/`, subproject runtime source.
- **Destructive operations** — separate section, bold. List every folder that would be deleted and under what condition.
- **Dirty git trees** — if any subproject has uncommitted changes, list them and recommend stashing/committing before proceeding.

### Phase 3 — CONSENT

The user must respond with explicit approval. Accept ONLY these forms:

- `"yes, proceed"` / `"go"` / `"proceed"` → APPLY.
- `"adjust"` / `"modify"` → ask which tools to drop/add, then re-AUDIT.
- Anything else, including silence, ambiguous "ok", "sure", "sounds good" → DO NOT PROCEED. Re-prompt explicitly: "I need explicit confirmation. Reply `yes, proceed` or `adjust`."

**Destructive consent is separate.** Even after the main "yes, proceed", the deletion of any legacy `XX-*` folder requires a SECOND consent after migration is verified (see APPLY step 7).

### Phase 4 — APPLY

Execute in this exact order. Each step writes to disk; abort and report on first error.

1. **Root files.**
   - If `CLAUDE.md` does not exist: render `references/claude-md-template.md` with the scan data and write it.
   - If `CLAUDE.md` exists: read it, compute a section-level diff against the template, and apply ONLY additive merges. Never delete user content. Never overwrite a section the user has customized. Append missing sections at the end with an `<!-- added by risco-project-harness YYYY-MM-DD -->` marker.
   - Same logic for `AGENTS.md`.
2. **Create `01-TOOLS/` skeleton.**
   - Create `01-TOOLS/` directory.
   - Copy `assets/_TEMPLATE/` to `01-TOOLS/_TEMPLATE/`. This template is **generic boilerplate with placeholders (`<NOMBRE_TOOL>`, `<TOOL>_API_KEY`)**. The user copies it manually when adding a tool NOT in the catalog. The skill itself does NOT use `_TEMPLATE/` to generate the detected tools — those come from `providers.yaml`.
3. **Per detected tool** (in catalog order):
   - Create `01-TOOLS/<ID>/`.
   - Write every file from the provider entry's `files:` map verbatim (replacing template variables: `{{TOOL_ID}}`, `{{DASHBOARD_URL}}`, etc.).
   - Write `.env.example` from the provider entry's `env_example` field.
   - Write `.gitignore` from the template (`.env`, `keys/`, `out/`, common secrets).
   - `chmod +x` on `probar_conexion.*` and any other executables.
   - **NEVER write a real `.env` file. NEVER fill credentials.**
4. **Migrate legacy `XX-*` folders.**
   - For each TOOLING file: move to its mapped destination in `01-TOOLS/<X>/`. If the destination file already exists from step 3, the legacy file goes to `01-TOOLS/<X>/migrated/<original-name>` so nothing is overwritten. The user resolves manually.
   - For each DOCS file: move to `02-DOCS/raw/migrated/<original-folder>/<path>`.
   - For each AMBIGUOUS file: leave in place. Record in the verification report.
5. **Verify migration.**
   - Count files moved vs files originally present. They must match (moved + ambiguous-remaining = original).
   - If counts don't match, abort and report. Don't proceed to deletion.
6. **Write `01-TOOLS/README.md`.**
   - Render `references/tools-readme-template.md` AFTER all tool folders exist (steps 3 + 4 completed). The catalog table then reflects actual on-disk state, not a promise.
7. **Destructive consent for legacy folder deletion.**
   - For each legacy folder where ALL files were classified (zero ambiguous) AND migration verified: prompt the user with the exact path: `"Migration verified. Delete 00-TOOLS/? Reply with the literal string 'yes, delete 00-TOOLS'."`
   - Only delete on exact-string match. Anything else: skip the deletion, preserve the now-empty folder.
   - For folders WITH ambiguous files: never delete. The folder stays with the ambiguous content.
8. **Build `02-DOCS/` (embedded wiki protocol).**
   - Open `references/wiki-protocol.md` and follow it. It defines initialization, ingest, query, and lint flows in full.
   - For the bootstrap pass on this APPLY: run the Initialization sub-section (create `02-DOCS/raw/`, `02-DOCS/wiki/`, `02-DOCS/wiki/index.md`, `02-DOCS/wiki/log.md`), then run Ingest for each of these sources (see the "How `risco-project-harness` uses this protocol" section at the bottom of `wiki-protocol.md`):
     - Each subproject `README.md` if present.
     - `01-TOOLS/README.md` (just written in step 6).
     - Each `01-TOOLS/<TOOL>/README.md` and `CREDENTIALS.md`.
     - Every file under `02-DOCS/raw/migrated/` (from legacy `XX-*` migration in step 4).
     - Root `CLAUDE.md` and `AGENTS.md`.
   - Use the templates in `references/wiki-*.md` verbatim. Do NOT invent a different format.

### Phase 5 — VERIFY

Print a final report:

- Files written (full list with paths).
- Folders deleted (with consent quote).
- Ambiguous files preserved (with locations).
- Suggested next steps:
  - `cp 01-TOOLS/<X>/.env.example 01-TOOLS/<X>/.env && chmod 600 01-TOOLS/<X>/.env` per tool.
  - `01-TOOLS/<X>/probar_conexion.{sh,py}` once `.env` is filled.
  - Any subproject with a dirty git tree to clean up.

## Iron rules (non-negotiable)

These rules cut across every phase. Violating any one of them aborts the run.

1. **Audit before action.** Nothing is written before the AUDIT is rendered and CONSENT is given.
2. **Explicit consent only.** Silence, ambiguity, "ok" all mean NO. Only the exact-form strings count as yes.
3. **No `.env` real, ever.** The skill writes `.env.example` only. Real credentials are the user's responsibility.
4. **No speculative tools.** A tool is created if and only if the detector found evidence in the user's code. No "we should probably have a Sentry tool too".
5. **No overwrite without merge.** Existing `CLAUDE.md`, `AGENTS.md`, or tool files are merged additively. The skill never deletes user content.
6. **Destructive ops require a second consent quoting the path.** "Yes, delete `00-TOOLS`" is different from a generic "yes, proceed".
7. **Ambiguous files preserve the legacy folder.** Don't force-classify. If you can't classify with confidence, leave it.
8. **Idempotent.** Running the skill twice produces no extra side effects. Re-scanning a project already canonical detects "nothing to do".
9. **Out-of-scope dirs are invisible.** `node_modules/`, `.venv/`, `.next/`, `__pycache__/`, `.git/`, `dist/`, `build/`, `.dart_tool/` are never read for detection and never touched.
10. **`references/wiki-protocol.md` is the source of truth for `02-DOCS`.** Do not invent a different wiki structure.
11. **Subproject internals are out of scope.** `.env.example`, `requirements.txt`, `package.json`, source files inside subprojects are READ for detection only. They are NEVER moved, renamed, modified, or deleted. The skill operates exclusively on workspace-root artifacts (`CLAUDE.md`, `AGENTS.md`, `01-TOOLS/`, `02-DOCS/`, and `XX-*` legacy folders at the root level).

## Rationalizations — STOP

These thoughts mean the skill is about to violate its own rules. Recognize them and abort:

| Excuse | Reality |
|--------|---------|
| "The user clearly meant yes when they said 'ok'" | No. They didn't say the exact string. Re-prompt. |
| "Just this one tool is obviously needed even without evidence" | No. Catalog says no detector hit = no tool. |
| "I'll write the `.env` with placeholder values — it's not real credentials" | No. `.env` is reserved for real credentials. Use `.env.example` only. |
| "The existing `CLAUDE.md` is clearly outdated, I'll rewrite it" | No. Merge additively. The user owns their `CLAUDE.md`. |
| "These files in `00-TOOLS/RANDOM/` look like docs to me, I'll move them" | If the classification confidence isn't high, mark AMBIGUOUS and leave in place. |
| "I'll delete the legacy folder since it's empty after migration" | Only after the second exact-string consent. Empty + no consent = preserve. |
| "Let me also reorganize the subproject internals while I'm here" | No. The skill operates on workspace root only. Subproject internals are out of scope. |
| "The wiki structure could be a bit different here" | No. Follow `references/wiki-protocol.md` verbatim. |
| "The `01-TOOLS/_TEMPLATE/` should be flavored with the user's first detected tool" | No. `_TEMPLATE/` is generic boilerplate with placeholders. Detected tools come from the catalog, not the template. |

## Red flags — abort and re-plan

If any of these occur, stop and report:

- A `git status` on any subproject shows uncommitted changes the user didn't acknowledge.
- The AUDIT shows zero detected tools AND zero legacy folders AND `CLAUDE.md`/`AGENTS.md` already exist → there's nothing for the skill to do. Tell the user.
- The user types anything ambiguous after AUDIT → do not infer consent.
- Migration verification (step 5 of APPLY) shows file count mismatch → abort, don't delete anything.
- The catalog has no entry for a provider obviously present in code → tell the user, suggest adding a catalog entry, don't fake one.

## References

- `references/providers.yaml` — full provider catalog with detectors and per-file content. Edit this to add a new provider; don't edit `SKILL.md`.
- `references/claude-md-template.md` — root `CLAUDE.md` template.
- `references/agents-md-template.md` — root `AGENTS.md` template.
- `references/tools-readme-template.md` — `01-TOOLS/README.md` catalog template.
- `references/audit-report-template.md` — text summary format for the in-conversation audit summary.
- `references/audit-report-template.html` — HTML format for the full per-run audit artifact written to `02-DOCS/audits/`.
- `references/wiki-protocol.md` — embedded protocol for the `02-DOCS/` wiki layer (initialization, ingest, query, lint, **Continuous Improvement**: Maintenance Pass, Micro-Improve, Deep Improve).
- `references/wiki-raw-template.md` — format for `02-DOCS/raw/<topic>/*.md`.
- `references/wiki-article-template.md` — format for `02-DOCS/wiki/<topic>/*.md`.
- `references/wiki-index-template.md` — format for `02-DOCS/wiki/index.md` (with Score column).
- `references/wiki-archive-template.html` — HTML format for archived query answers (point-in-time, never edited).
- `references/wiki-dashboard-template.html` — HTML format for the live wiki dashboard, regenerated by Maintenance Pass.
- `references/wiki-deep-improve-report-template.html` — HTML format for Deep Improve run reports.
- `references/wiki-gaps-template.md` — format for `02-DOCS/wiki/gaps.md` (Knowledge Gaps log).
- `assets/_TEMPLATE/` — the boilerplate copied into every new tool.

This skill is fully self-contained. No external sub-skill required.
