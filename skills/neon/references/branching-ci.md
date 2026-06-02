# Per-PR Neon branching in CI

Replicate the Neon + Vercel preview integration anywhere: create an isolated, full-data branch when a
PR opens, migrate and seed it, hand the pooled connection string to the preview app, and delete the
branch when the PR closes. A branch is copy-on-write (instant, no data copied) and scales to zero, so
even a dozen open PRs cost almost nothing.

## `neonctl` command reference

`neonctl` (alias `neon`) is the official CLI. Authenticate in CI with `NEON_API_KEY`.

| Command | Purpose |
| --- | --- |
| `neonctl branches create --name <n> --parent main` | Fork a new branch from production at the current point in time. |
| `neonctl connection-string <branch> --pooled` | Print the **pooled** (`-pooler`) string for the app runtime. |
| `neonctl connection-string <branch>` | Print the **direct** string for migrations/DDL. |
| `neonctl branches list` | List branches (find a stale one to delete). |
| `neonctl branches delete <branch>` | Tear the branch down on PR close. |

## GitHub Actions: create on open, delete on close

```yaml
name: neon-pr-branch
on:
  pull_request:
    types: [opened, reopened, synchronize, closed]

env:
  NEON_API_KEY: ${{ secrets.NEON_API_KEY }}
  NEON_PROJECT_ID: ${{ vars.NEON_PROJECT_ID }}

jobs:
  create_and_migrate:
    if: github.event.action != 'closed'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: npm i -g neonctl
      - name: Create branch
        run: neonctl branches create --name pr-${{ github.event.number }} --parent main --project-id "$NEON_PROJECT_ID"
      - name: Resolve strings
        id: db
        run: |
          DIRECT=$(neonctl connection-string pr-${{ github.event.number }} --project-id "$NEON_PROJECT_ID")
          POOLED=$(neonctl connection-string pr-${{ github.event.number }} --pooled --project-id "$NEON_PROJECT_ID")
          echo "::add-mask::$DIRECT"; echo "::add-mask::$POOLED"
          echo "direct=$DIRECT" >> "$GITHUB_OUTPUT"
          echo "pooled=$POOLED" >> "$GITHUB_OUTPUT"
      - name: Migrate + seed (DIRECT string — DDL needs a real session)
        env:
          DATABASE_URL: ${{ steps.db.outputs.direct }}
        run: |
          npm ci
          npm run db:migrate
          npm run db:seed
      # Hand steps.db.outputs.pooled to the preview deploy as the app DATABASE_URL.

  delete:
    if: github.event.action == 'closed'
    runs-on: ubuntu-latest
    steps:
      - run: npm i -g neonctl
      - run: neonctl branches delete pr-${{ github.event.number }} --project-id "$NEON_PROJECT_ID"
```

Rules that keep this honest:

- Migrations and seed run against the **direct** string — PgBouncer transaction-pooling breaks DDL and advisory locks.
- The preview app gets the **pooled** (`-pooler`) string — serverless concurrency needs the pool.
- The `closed` event covers both merge and abandon, so branches never accumulate.

## Neon API (if you can't use the CLI)

Same flow over REST with a bearer `NEON_API_KEY`:

| Step | Endpoint |
| --- | --- |
| Create branch | `POST /api/v2/projects/{project_id}/branches` |
| Get branch endpoints / connection URI | `GET /api/v2/projects/{project_id}/branches/{branch_id}/endpoints` |
| Delete branch | `DELETE /api/v2/projects/{project_id}/branches/{branch_id}` |

Pass `endpoints[].pooler_enabled` / request the pooled URI for the app, the plain URI for migrations.
Engine-level migration mechanics (expand-contract, `CONCURRENTLY`, batched backfill) are not Neon's —
see `../../postgresdb/SKILL.md`.
