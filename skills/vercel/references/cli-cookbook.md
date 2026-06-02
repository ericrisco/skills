# Vercel CLI cookbook

Copy-paste recipes. All read-only unless noted. Assumes `npm i -g vercel` (or `npx vercel`).

## Link & first deploy

```bash
vercel link                  # associate the current dir with a project (writes .vercel/)
vercel                       # preview deploy, prints a unique URL
vercel --prod                # production deploy
vercel dev                   # local emulation of functions + routing
vercel pull                  # fetch project settings + env into .vercel/.env.* for local builds
vercel inspect <url>         # details for a specific deployment
vercel logs <url>            # runtime logs for a deployment
```

## Env var round-trip

```bash
vercel env ls                                   # which vars exist in which environments
vercel env add API_URL production               # add to production (prompts for value)
vercel env add API_URL preview                  # separate command — preview
vercel env add LOCAL_ONLY development            # development MUST be its own command
vercel env pull .env.local                      # pull the linked env into .env.local (overwrites)
vercel env pull .env.local --environment=preview # pull a SPECIFIC environment
vercel env rm API_URL preview                   # remove a var from one environment
vercel env run -- npm run seed                  # run a command with project vars injected
```

Reminders:

- You cannot mix `development` with `production`/`preview` in one `vercel env add`.
- Vars added to production/preview/custom default to **sensitive** (write-only).
- `vercel env pull` **overwrites** the target file for one environment — re-pull after changes.

## Domains & aliases

```bash
vercel domains add example.com           # attach a domain to the current project
vercel domains ls                        # list domains
vercel domains inspect example.com       # config + record/nameserver status
vercel domains add example.com --force   # move the domain off whatever project holds it
vercel domains rm example.com            # detach (mutating)
vercel alias set <deployment-url> staging.example.com  # point an alias at a deployment
vercel dns ls example.com                # list DNS records (managed-domain case)
```

For DNS-record theory and registrar transfers, defer to the `domains-dns` skill.

## Promote a preview to production

A preview deployment is already built; promote it instead of rebuilding.

```bash
vercel ls                                # find the preview deployment URL
vercel promote <deployment-url>          # promote that exact build to production
vercel rollback <deployment-url>         # roll the production domain back to a prior deploy
```

## Skip redundant builds (monorepo)

```json
{ "ignoreCommand": "git diff --quiet HEAD^ HEAD -- ." }
```

Vercel cancels the build when `ignoreCommand` exits `0` (zero = skip).

## Deployment-protection bypass for CI

When CI must reach a protected preview, don't disable protection — send the bypass header.
Configure "Protection Bypass for Automation" in project settings to get the secret, then:

```bash
curl -H "x-vercel-protection-bypass: $VERCEL_AUTOMATION_BYPASS_SECRET" \
     "https://my-preview-xyz.vercel.app/api/health"
```

On Hobby, Standard Protection covers preview deployments and the generated deployment URLs; the
production custom domain stays public.

## System env vars (`VERCEL_*`, read-only)

| Var | Value |
| --- | --- |
| `VERCEL` | `1` when running on Vercel |
| `VERCEL_ENV` | `production` \| `preview` \| `development` |
| `VERCEL_URL` | Deployment host (no protocol) |
| `VERCEL_BRANCH_URL` | Git-branch deployment URL |
| `VERCEL_PROJECT_PRODUCTION_URL` | Production domain |
| `VERCEL_REGION` | Region the function is executing in |
| `VERCEL_GIT_PROVIDER` | e.g. `github` |
| `VERCEL_GIT_REPO_SLUG` | Repository slug |
| `VERCEL_GIT_COMMIT_REF` | Branch/ref that triggered the deploy |
| `VERCEL_GIT_COMMIT_SHA` | Commit SHA |
| `VERCEL_GIT_COMMIT_MESSAGE` | Commit message |
| `VERCEL_GIT_COMMIT_AUTHOR_LOGIN` | Author login |

Read them in the app (`process.env.VERCEL_ENV`); never try to set them.
