# Example — AUDIT output for a synthetic brownfield project

This is a real example of the AUDIT report the skill produces. Use it as
a reference for formatting, level of detail, and how to handle edge
cases (ambiguous files, legacy folder migration, the embedded wiki
bootstrap).

## Input project

```
/tmp/risco-harness-test/
├── backend/
│   ├── pyproject.toml          ← deps: fastapi, stripe, mailjet-rest
│   ├── .env.example            ← STRIPE_SECRET_KEY, MAILJET_*
│   └── app/services/
│       ├── billing.py          ← import stripe
│       └── email.py            ← from mailjet_rest import Client
├── frontend/
│   └── package.json            ← deps: next@15, @stripe/stripe-js
├── 00-TOOLS/
│   ├── STRIPE/
│   │   ├── test_connection.sh  ← legacy bash, has shebang
│   │   └── README.md           ← legacy tool doc
│   └── random_helper.py        ← Python without shebang, unclear purpose
└── 03-NOTES/
    └── architecture.md         ← prose docs
```

## AUDIT output

```
# Audit — harness — 2026-05-31

Workspace: /tmp/risco-harness-test

## 1. Stack detected
- Backend: FastAPI (Python) — backend/ — pyproject.toml (fastapi, stripe, mailjet-rest)
- Frontend: Next.js 15 — frontend/ — package.json (next@15, @stripe/stripe-js)

## 2. Tools to create in 01-TOOLS/

| Tool   | Category    | Evidence | Action |
|--------|-------------|----------|--------|
| STRIPE | pagos       | backend/app/services/billing.py:1 (import stripe); pyproject.toml dep; frontend dep | MERGE — legacy 00-TOOLS/STRIPE/ exists |
| MAILJET| email       | backend/app/services/email.py:1 (from mailjet_rest); pyproject.toml dep            | CREATE |

Rest of the catalog: SKIP — no evidence.

## 3. Legacy XX-* folders

### 00-TOOLS/
| File | Classification | Proposed destination |
|------|----------------|----------------------|
| STRIPE/test_connection.sh | TOOLING | 01-TOOLS/STRIPE/migrated/test_connection.sh (collision with catalog) |
| STRIPE/README.md          | TOOLING | 01-TOOLS/STRIPE/migrated/README.md (collision with catalog) |
| random_helper.py          | AMBIGUOUS | (stays in 00-TOOLS/) |

Total: 3 · TOOLING: 2 · DOCS: 0 · AMBIGUOUS: 1
Deletion of 00-TOOLS/: BLOCKED — AMBIGUOUS present.

### 03-NOTES/
| File | Classification | Proposed destination |
|------|----------------|----------------------|
| architecture.md | DOCS | 02-DOCS/raw/migrated/03-NOTES/architecture.md |

Total: 1 · TOOLING: 0 · DOCS: 1 · AMBIGUOUS: 0
Deletion of 03-NOTES/: candidate for second consent.

## 4. Documentation → 02-DOCS/ (embedded protocol)
Sources to ingest (following references/wiki-protocol.md):
- 01-TOOLS/README.md (after creation)
- 01-TOOLS/STRIPE/README.md + CREDENTIALS.md
- 01-TOOLS/MAILJET/README.md + CREDENTIALS.md
- 02-DOCS/raw/migrated/03-NOTES/architecture.md (after migration)
- Root CLAUDE.md and AGENTS.md

## 5. Root files
| File       | State       | Action |
|------------|-------------|--------|
| CLAUDE.md  | does not exist | CREATE from template |
| AGENTS.md  | does not exist | CREATE from template |

## 6. Files I will NEVER touch
- 01-TOOLS/**/.env (real)
- backend/.env.example, backend/app/**, frontend/package.json — subproject internals
- node_modules/, .venv/, .next/, __pycache__/, .dart_tool/, .git/

## 7. Subprojects git state
No Git repos in the subprojects. Nothing to stash.

## 8. Destructive operations
| Operation         | When |
|-------------------|------|
| Delete 00-TOOLS/  | NEVER in this run (AMBIGUOUS present) |
| Delete 03-NOTES/  | After migration + literal second consent "yes, delete 03-NOTES" |

## Proceed?
Respond with the literal string:
- "yes, proceed" — run the plan
- "adjust" — modify
```

## Lessons from this example

1. **Ambiguity blocks deletion.** `random_helper.py` (no shebang, no
   catalog provider integration) → AMBIGUOUS → `00-TOOLS/` is preserved
   after migration. Don't force the classification.

2. **Collision = `migrated/`.** When a legacy file
   (`00-TOOLS/STRIPE/test_connection.sh`) collides with the catalog
   file, it goes to `01-TOOLS/STRIPE/migrated/` for the user to resolve
   manually. The catalog is NEVER overwritten.

3. **Subproject internals are invisible.** `backend/.env.example`,
   `backend/app/services/*.py`, `frontend/package.json` are READ for
   detection but NEVER moved or modified.

4. **Two distinct consents.** "yes, proceed" authorizes the general
   APPLY. "yes, delete 03-NOTES" is ANOTHER, deletion-specific consent
   quoting the exact path.
