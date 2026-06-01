# GitHub Actions — CI/CD playbook

Least-privilege, OIDC-first workflows for build, scan, release, and deploy. Every workflow here passes `actionlint`. Back to the entrypoint: `../SKILL.md`.

## Workflow anatomy & least privilege

Default-deny at the top, escalate per job. Cancel superseded runs to save minutes.

```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request: {}
permissions:
  contents: read                       # default for every job; escalate where needed
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Pin actions by major tag (`@v4`) for routine use. For supply-chain hardening — and always for security-scanning actions — pin the full 40-char commit SHA (Dependabot still bumps it):

```yaml
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.2.2
- uses: aquasecurity/trivy-action@57a97c7e7821a5776cebc9bb87c984fa69cba8f1 # v0.35.0
```

A moving tag trusts the action's maintainer forever. In the March 2026 `trivy-action` supply-chain incident ([GHSA-69fq-xp46-6x23](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23) / CVE-2026-33634), an attacker force-pushed 76 of 77 version tags to credential-stealing malware. The advisory's named known-safe reference is `v0.35.0` — commit `57a97c7e7821a5776cebc9bb87c984fa69cba8f1`, the single clean tag still pointing at the genuine `master` HEAD; that exact SHA pin would have stayed on the known-good commit and ignored the malicious force-push. SHA-pin every third-party action you can't fully trust to never be compromised, and re-pin from the advisory's safe ref — not the latest tag — after any incident.

## Caching

Use each setup action's built-in cache; key custom caches on the lockfile hash so they invalidate correctly.

```yaml
- uses: actions/setup-node@v4
  with: { node-version: 24, cache: npm }
- uses: actions/setup-go@v5
  with: { go-version: "1.26", cache: true }
- uses: astral-sh/setup-uv@v8
  with: { enable-cache: true }
- uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/uv.lock') }}
```

Docker layer cache via the GitHub Actions cache backend:

```yaml
- uses: docker/build-push-action@v7
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

- GOOD: `key: ${{ runner.os }}-pip-${{ hashFiles('**/uv.lock') }}` — invalidates when deps change.
- BAD: `key: pip-cache` — a static key never refreshes and serves stale dependencies forever.

## Job matrix

Test every stack in the monorepo in parallel; `fail-fast: false` so one stack's failure doesn't cancel the others.

```yaml
jobs:
  verify:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        stack: [python, go, node]
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/verify.sh
        env:
          STACK: ${{ matrix.stack }}
```

## Build & push to ghcr (no stored key)

OIDC-style: the per-run `GITHUB_TOKEN` authenticates to ghcr — no long-lived registry password. Provenance + SBOM attest the build.

```yaml
build-push:
  needs: verify
  runs-on: ubuntu-latest
  permissions:
    contents: read
    packages: write
    id-token: write
  steps:
    - uses: actions/checkout@v4
    - uses: docker/setup-buildx-action@v3
    - id: meta
      uses: docker/metadata-action@v5
      with:
        images: ghcr.io/${{ github.repository }}
        tags: |
          type=sha
          type=semver,pattern={{version}}
    - uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    - uses: docker/build-push-action@v7
      with:
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        provenance: true
        sbom: true
        secrets: |
          npm_token=${{ secrets.NPM_TOKEN }}
```

The build secret reaches the Dockerfile via `--mount=type=secret,id=npm_token` — it is never written to a layer.

## OIDC to cloud (AWS example)

No stored access keys. The job mints a short-lived role session via OIDC.

```yaml
deploy-aws:
  runs-on: ubuntu-latest
  permissions:
    id-token: write
    contents: read
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::123456789012:role/gha-deploy
        aws-region: eu-west-1
    - run: aws sts get-caller-identity
```

The IAM role's trust policy restricts who may assume it via the OIDC `sub` claim: `repo:ORG/REPO:ref:refs/heads/main` means only the `main` branch of that exact repo can assume the role — a PR from a fork cannot.

## Reusable & composite workflows

A `workflow_call` reusable centralizes the verify/build logic; callers pass inputs and inherit secrets.

```yaml
# .github/workflows/reusable-verify.yml
on:
  workflow_call:
    inputs:
      stack:
        required: true
        type: string
    secrets:
      NPM_TOKEN:
        required: false
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: ./.github/actions/setup-and-verify
        with: { stack: ${{ inputs.stack }} }
```

```yaml
# caller
jobs:
  verify:
    strategy:
      matrix: { stack: [python, go, node] }
    uses: ./.github/workflows/reusable-verify.yml
    with: { stack: ${{ matrix.stack }} }
    secrets: inherit
```

A composite action wraps checkout + setup + verify so every workflow shares one definition:

```yaml
# .github/actions/setup-and-verify/action.yml
name: setup-and-verify
inputs:
  stack: { required: true }
runs:
  using: composite
  steps:
    - uses: actions/checkout@v4
    - shell: bash
      run: bash scripts/verify.sh
      env:
        STACK: ${{ inputs.stack }}
```

## Security gates

Enforce these as required status checks via branch protection so a red gate blocks merge.

```yaml
security:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - run: trivy fs --scanners vuln,secret --exit-code 1 --severity HIGH,CRITICAL .
    - uses: gitleaks/gitleaks-action@v2
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

- Lint per stack: `ruff check .` / `eslint .` / `golangci-lint run`.
- Test per stack with coverage.
- `trivy fs` (deps + leaked secrets) and `trivy image` (CVEs in the built image).
- `actionlint` (workflow syntax) and `hadolint` (Dockerfile) — both run by `scripts/verify.sh`.
- `gitleaks` catches committed credentials before they reach `main`.

## Environments & approvals

Gate production behind a GitHub Environment with required reviewers and a wait timer; environment-scoped secrets are only readable by jobs that target it.

```yaml
deploy:
  needs: build-push
  runs-on: ubuntu-latest
  environment:
    name: production
    url: https://app.example.com
  steps:
    - run: echo "deploying ${{ github.sha }}"
```

Configure required reviewers, a wait timer, and deployment branch rules (e.g. only `main`) in repo Settings → Environments.

## Release automation

Tag-triggered build that publishes versioned images and a GitHub Release with generated notes.

```yaml
name: release
on:
  push:
    tags: ["v*"]
permissions:
  contents: write
  packages: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=raw,value=latest
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v7
        with:
          push: true
          tags: ${{ steps.meta.outputs.tags }}
      - uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
```

## Calling verify.sh

The same gate runs locally (developer) and in CI (parity) — there is exactly one definition of "passing".

```yaml
- run: bash scripts/verify.sh
```

Inside the matrix, each stack invokes it with its own `STACK` env so the script can scope per-stack lint/test while keeping one entrypoint. Local↔CI parity means a green local run predicts a green CI run; a divergence is always a bug in the gate, not the developer's machine.

## Deploy step (→ Coolify)

Final job gated on the `production` environment; trigger Coolify's deploy webhook. `--fail` makes curl exit non-zero on an HTTP error so a failed trigger fails the job.

```yaml
deploy:
  needs: build-push
  runs-on: ubuntu-latest
  environment: production
  steps:
    - run: |
        curl --fail -X POST \
          -H "Authorization: Bearer ${{ secrets.COOLIFY_TOKEN }}" \
          "https://coolify.example.com/api/v1/deploy?uuid=${{ vars.COOLIFY_APP_UUID }}&force=false"
```

Alternatively, rely on the Coolify GitHub App: CI only builds and scans, and Coolify itself builds + deploys on push. Pick one trigger — running both double-deploys.
