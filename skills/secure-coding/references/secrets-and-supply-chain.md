# Secrets & supply chain

Keep secrets out of the repo and out of client bundles, pin every dependency,
and gate the result in CI. Tools: `gitleaks`, `pip-audit` (or `uvx pip-audit`), `osv-scanner`,
`npm`/`pnpm`, `govulncheck`, `syft`. Versions: Python 3.12+ /
`pydantic-settings`, Next.js 15, Go 1.22+, PostgreSQL 16.

## Env vs vaults

12-factor env vars for dev; a secret manager (HashiCorp Vault, cloud Secrets
Manager, Doppler) for prod. **Fail fast** on a missing secret at startup so a
misconfigured deploy never runs half-authenticated.

```python
# GOOD (FastAPI) — pydantic-settings BaseSettings; missing secret = startup error.
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="forbid")
    database_url: str
    jwt_signing_key: SecretStr          # never logged when interpolated

settings = Settings()                   # raises if a required var is unset
```

```go
// GOOD (Go) — mustEnv panics at startup if the variable is missing.
func mustEnv(key string) string {
    v, ok := os.LookupEnv(key)
    if !ok || v == "" {
        panic("missing required env var: " + key)
    }
    return v
}
var dbURL = mustEnv("DATABASE_URL")
```

```ts
// Next.js — ONLY NEXT_PUBLIC_* reaches the browser bundle. Everything else is
// server-only. BAD: reading a secret in a Client Component ships it to users.
// "use client" + process.env.STRIPE_SECRET_KEY  -> leaked to the browser.
// GOOD: read secrets in Server Components, Route Handlers, or Server Actions.
const stripeKey = process.env.STRIPE_SECRET_KEY; // server-only file, no "use client"
```

```dart
// Flutter — there is NO server-side; anything compiled into the app binary is
// extractable. NEVER ship a backend API secret in the client. Inject build-time
// public config with --dart-define; store per-user tokens in the OS keystore.
// BAD: const apiSecret = "sk_live_...";  // shipped in the APK/IPA, trivially dumped
const apiBaseUrl = String.fromEnvironment("API_BASE_URL");  // flutter run --dart-define=API_BASE_URL=...
```

### Which secret lives where

| Secret kind | Dev | Prod | Never |
|---|---|---|---|
| Backend API keys (Stripe secret, DB URL) | `.env` (gitignored) | Secret manager / platform env | Repo, client bundle, mobile binary |
| JWT signing key | `.env` | Secret manager (rotatable) | Repo, logs, `NEXT_PUBLIC_*` |
| Per-user access/refresh token | n/a | OS keystore (mobile) / `HttpOnly` cookie (web) | `localStorage`, `SharedPreferences` |
| Public config (base URL, publishable key) | `.env` | env / `--dart-define` / `NEXT_PUBLIC_*` | — (public by design) |

## Never in repo

`.gitignore` patterns — ignore real env files, keep the example:

```text
.env
.env.*
!.env.example
```

Run `gitleaks` as a pre-commit hook, against history, and in CI. **Incident
order when a secret IS committed: rotate FIRST, then scrub history.** History
rewriting with `git filter-repo` is slow and forces every clone to re-sync; the
secret is already public the instant it's pushed, so revoke/rotate the
credential immediately and treat the scrub as cleanup.

```bash
# Rotate the credential at the provider FIRST. Then:
git filter-repo --path config/secrets.yml --invert-paths   # scrub from history
gitleaks git . --no-banner --redact --exit-code 1          # confirm history is clean
gitleaks dir . --no-banner --redact --exit-code 1          # confirm working tree is clean
```

## Rotation

Rotate on a cadence (e.g. quarterly) and immediately on any suspected exposure.
After rotation, **invalidate active sessions and tokens** so credentials minted
under the old secret can't keep riding along (a JWT signing-key rotation must
revoke outstanding access/refresh tokens, or attackers keep their forged ones).

On-exposure runbook, in order — each step assumes the previous is done:

1. **Revoke/rotate at the provider** (Stripe, AWS, the OIDC IdP). The leaked
   value is dead the moment a new one is minted; this is the only step that
   actually stops the bleed.
2. **Roll forward in prod** — push the new value to the secret manager and
   redeploy. Keep the old key valid for a short overlap only if a zero-downtime
   handoff requires it, then disable it.
3. **Invalidate derived credentials** — sessions, access/refresh tokens, and any
   cache keyed on the old secret (see the JWT note above).
4. **Scrub history** with `git filter-repo` (slow; do it after the rotation, not
   before) and force every clone to re-sync.
5. **Add a `gitleaks` rule / pre-commit hook** so the same class of leak can't
   recur, and note the incident in the audit log.

## Dependency pinning & lockfiles

Commit the lockfile; install with the frozen/verified flag in CI.

| Ecosystem | Pin / lock | Verified install |
|---|---|---|
| Python | `uv lock` or `pip-tools` compile **with hashes** | `pip install --require-hashes -r requirements.txt` |
| Node | `package-lock.json` / `pnpm-lock.yaml` committed | `npm ci` / `pnpm i --frozen-lockfile` |
| Go | `go.sum` committed | `go mod verify` |
| Dart | `pubspec.lock` committed | `dart pub get --enforce-lockfile` |

`--require-hashes` and `go mod verify` defend against a registry serving a
different artifact than the one you locked (A08 integrity).

## Audit tooling — command, how to read, how to fix

| Tool | Command | A finding looks like | Fix |
|---|---|---|---|
| pip-audit | `pip-audit` | `Name Version ID Fix-Versions` row per vuln | Upgrade to a fix version; use constraints for a transitive |
| osv-scanner | `osv-scanner --lockfile=pnpm-lock.yaml` | OSV id + severity + introduced/fixed range; lockfile-aware, multi-ecosystem | Upgrade; `overrides` for a transitive |
| npm audit | `npm audit --omit=dev --audit-level=high` | severity + path through the dep tree | `npm audit fix`, or `overrides` for transitive |
| govulncheck | `govulncheck ./...` | only vulns your code **calls** (reachability) + the call trace | Upgrade; `go mod replace` for a transitive |
| dart | `dart pub outdated --mode=null-safety` | outdated (no CVE feed) — advisory only | Upgrade to latest resolvable |

`govulncheck`'s reachability advantage: it won't flag a CVE in a function your
code never invokes, cutting false positives that `osv-scanner` (which matches
by version) reports. Use both — osv for breadth, govulncheck for Go precision.

Overriding a transitive (recap):

```json
{ "overrides": { "vulnerable-lib": "1.2.4" } }
```

```text
vulnerable-lib==1.2.4
```

```go
replace vulnerable-lib v1.2.3 => vulnerable-lib v1.2.4
```

## SBOM & provenance

Emit a Software Bill of Materials with `syft` so you can answer "are we
affected by CVE-X?" instantly:

```bash
syft dir:. -o cyclonedx-json=sbom.cdx.json     # or spdx-json
```

For build provenance, sign artifacts with `cosign` and target SLSA build
levels so consumers can verify an artifact came from your pipeline, not a
tampered one. For browser-loaded third-party scripts, use SRI
(`integrity="sha384-…" crossorigin`) — see A08 in `owasp-by-stack.md`.

## CI security gate (the payoff)

This GitHub Actions job is `verify.sh` in CI: secret scan + SAST + per-stack
CVE audit, failing the build on high/critical findings.

```yaml
name: security
on: [pull_request]
jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }          # full history for gitleaks
      - name: gitleaks
        uses: gitleaks/gitleaks-action@v2
      - name: semgrep
        # The semgrep-action wrapper is deprecated; run the CLI directly
        # (here in its official image) and let `semgrep ci` gate the build.
        run: docker run --rm -v "$PWD:/src" -w /src semgrep/semgrep semgrep ci --config=auto
      - name: python audit
        if: hashFiles('**/pyproject.toml', '**/requirements*.txt') != ''
        run: pipx run pip-audit
      - name: node audit
        if: hashFiles('**/package.json') != ''
        run: npm audit --omit=dev --audit-level=high
      - name: go audit
        if: hashFiles('**/go.mod') != ''
        run: go run golang.org/x/vuln/cmd/govulncheck@latest ./...
```

Add Dependabot or Renovate to open dependency-bump PRs automatically (e.g.
`.github/dependabot.yml` with `package-ecosystem` entries per manifest), so
CVEs get patched on a schedule rather than only when the gate fails.

---

`scripts/verify.sh` is the local equivalent of this job — run it before opening
the PR. See the "Secrets & supply chain" section of `SKILL.md` for the
one-paragraph rules, and `owasp-by-stack.md` (A06, A08) for the per-stack
override/replace code.
