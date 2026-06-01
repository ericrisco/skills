# Audit — `harness` — {{TODAY}}

Workspace: `{{WORKSPACE_ROOT}}`

---

## 1. Stack detected

{{STACK_SUMMARY}}

> Example:
> - Backend: FastAPI (Python 3.11) — `myapp-backend/`
> - Frontend: Next.js 15 — `myapp-frontend/`
> - Mobile: Flutter — `myapp-mobile/`

## 2. Tools to create in `01-TOOLS/`

| Tool | Category | Evidence | Action |
|------|----------|----------|--------|
{{TOOLS_TABLE}}

> Actions:
> - **CREATE** — didn't exist, created from the catalog template.
> - **MERGE** — already exists (e.g. migrated from `00-TOOLS/`); new
>   catalog files are written under `01-TOOLS/<X>/migrated/<file>` if
>   they collide with a user file.
> - **SKIP** — no evidence in code; not created (no speculative tools).

## 3. Legacy `XX-*` folders detected

{{LEGACY_FOLDERS_SECTION}}

> Per folder, a sub-section with:
>
> ### `00-TOOLS/`
>
> | File | Classification | Proposed destination |
> |------|----------------|----------------------|
> | `STRIPE/test_connection.sh` | TOOLING | `01-TOOLS/STRIPE/test_connection.sh` |
> | `STRIPE/README.md` | TOOLING (tool doc) | `01-TOOLS/STRIPE/README.md` |
> | `RANDOM_NOTES.md` | DOCS | `02-DOCS/raw/migrated/00-TOOLS/RANDOM_NOTES.md` |
> | `unclassified_script.py` | AMBIGUOUS | (stays in `00-TOOLS/`) |
>
> Result:
> - Total: 42 files · TOOLING: 35 · DOCS: 5 · AMBIGUOUS: 2
> - **Deletion of `00-TOOLS/`**: requires AMBIGUOUS = 0 + second consent after migration.

## 4. Documentation → `02-DOCS/` (embedded protocol)

`02-DOCS/` is built following `references/wiki-protocol.md` (embedded in
this skill, no external dependency).

Sources ingested in this bootstrap:

{{WIKI_SOURCES}}

> Example:
> - `myapp-backend/README.md`
> - `myapp-frontend/README.md`
> - `01-TOOLS/README.md` (after creation)
> - `01-TOOLS/<TOOL>/README.md` and `CREDENTIALS.md` per detected tool
> - Content of `02-DOCS/raw/migrated/` (after migration)
> - Root `CLAUDE.md` and `AGENTS.md`

Resulting structure: `02-DOCS/raw/<topic>/`, `02-DOCS/wiki/<topic>/`,
`02-DOCS/wiki/index.md`, `02-DOCS/wiki/log.md`.

## 5. Root files

| File | State | Action |
|------|-------|--------|
| `CLAUDE.md` | {{CLAUDE_MD_STATE}} | {{CLAUDE_MD_ACTION}} |
| `AGENTS.md` | {{AGENTS_MD_STATE}} | {{AGENTS_MD_ACTION}} |

> Possible actions:
> - **CREATE** — doesn't exist, created from template.
> - **MERGE-ADDITIVE** — exists; missing sections appended with marker
>   `<!-- added by harness YYYY-MM-DD -->`. Nothing
>   removed.
> - **SKIP** — the existing file already covers the template.

## 6. Files I will NEVER touch

- `01-TOOLS/**/.env` (real)
- `01-TOOLS/**/keys/`, `*.p8`, `*.p12`, `*.jks`, service account JSONs
- `node_modules/`, `.next/`, `.venv/`, `.pytest_cache/`, `.ruff_cache/`,
  `__pycache__/`, `.dart_tool/`, `build/`, `dist/`
- Any `.git/`, internal subproject content beyond its declarative root.

## 7. Subprojects git state

{{GIT_STATUS_REPORT}}

> If there are uncommitted changes, commit or stash them before the skill
> moves anything (some files might belong to user work in flight).

## 8. Destructive operations

| Operation | When |
|-----------|------|
{{DESTRUCTIVE_OPS_TABLE}}

> Every deletion requires a SECOND explicit consent quoting the exact
> path. The first consent ("yes, proceed") does NOT authorize deletions.

---

## Proceed?

Respond with the literal string:

- `yes, proceed` — run the plan as-is (no legacy folder deletions yet).
- `adjust` — I want to drop or add something from the plan.

Any other response (including "ok", "sure", "sounds good", silence) is
interpreted as do NOT proceed, and I will ask again.
