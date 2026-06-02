# Railway CLI cookbook

Full command catalog and recipes. Commands run against the linked project/environment unless you
pass `--service` / `--environment`.

## Install matrix

```bash
brew install railway                          # macOS (Homebrew)
npm i -g @railway/cli                          # any host with Node 16+
bash <(curl -fsSL railway.com/install.sh)      # shell installer (Linux/macOS)
railway --version                              # verify
```

## Auth

```bash
railway login                # interactive browser login (dev machines)
railway login --browserless  # paste a code; for headless/remote shells
railway logout
```

For CI / non-interactive: **do not** `railway login`. Set a project token instead — the CLI
reads `RAILWAY_TOKEN` and acts as that project, no login step.

```bash
RAILWAY_TOKEN=$RAILWAY_PROJECT_TOKEN railway up --detach --service api
```

## Project setup

```bash
railway init               # create a new project from the current directory
railway link               # link this dir to an existing project (and pick service/env)
railway status             # show the linked project / environment / service
railway open               # open the project in the dashboard
```

## Deploy

```bash
railway up                                   # build + deploy current dir, stream logs
railway up --detach                          # don't attach to build/deploy logs
railway up --service api                     # target a service in a multi-service project
railway up --environment staging             # deploy into a specific environment
railway redeploy                             # re-run the latest deployment unchanged
```

There is no `railway deploy`. Deploys happen via `railway up` or a push to the GitHub-connected
branch.

## Variables

```bash
railway variables                            # list variables for the active service/env
railway variables --set "LOG_LEVEL=info"     # set one (repeat --set for several)
railway variables --set "API_URL=${{RAILWAY_PUBLIC_DOMAIN}}"   # set a reference var
# older documented form:
railway variable set KEY=value
```

Reference syntax (set as a variable's value): `${{ServiceName.VAR}}`, `${{shared.VAR}}`,
`${{RAILWAY_PUBLIC_DOMAIN}}`, `${{RAILWAY_PRIVATE_DOMAIN}}`.

## Run with Railway env injected

```bash
railway run <cmd>                            # run a local command with prod/linked env vars
railway run npm run dev                      # local dev against the linked environment's vars
railway run -- printenv DATABASE_URL         # inspect a resolved value locally
```

`railway run` injects the linked environment's variables into a local process — handy to run
migrations or scripts locally against the real config without copying secrets.

## Services & environments

```bash
railway service                              # switch the active service
railway environment                          # switch the active environment
railway environment staging                  # switch to a named environment
```

## Add services & databases

```bash
railway add                                  # interactive: add a service or a database template
# pick Postgres / MySQL / Redis / MongoDB from the template list,
# or in the dashboard use + New / cmd-K
```

After adding a DB, reference its vars into the app service as `${{Postgres.DATABASE_URL}}` rather
than copying the literal URL.

## Database shells

```bash
railway connect              # open a shell to the linked DB service (psql/mysql/mongosh/redis-cli)
railway connect Postgres     # target a specific DB service by name
```

## Logs & domains

```bash
railway logs                 # stream logs for the active deployment
railway logs --service api   # logs for a specific service
railway domain               # generate a *.up.railway.app domain for the service
```

## CI/CD snippet (GitHub Actions)

```yaml
# .github/workflows/deploy.yml
name: deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm i -g @railway/cli
      - run: railway up --detach --service api
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_PROJECT_TOKEN }}
```

Use a **project token** (`RAILWAY_TOKEN`) for CI — never a personal login. Scope the token to the
project and rotate it from the dashboard if leaked.

## Notes

- Most commands act on the *linked* project/env/service; run `railway status` if a command targets
  the wrong place.
- `railway run` resolves reference variables (`${{...}}`) the same way the deployed container
  does, so it's a faithful local mirror of prod config.
