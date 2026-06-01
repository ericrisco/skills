# IMPLEMENTATION PLAN — `secure-coding`

> This plan is the **build order** for the implementer subagent. Follow it verbatim.
> Source of truth: `/Volumes/EXTERN/DEV/skills/skill-build/secure-coding/spec.md`.
> Target output root: `/Volumes/EXTERN/DEV/skills/skills/secure-coding/`.
> Quality bar: match or exceed the ECC reference skills (`/tmp/ECC/skills/*`); write fresh, current, denser.
> Audience: an LLM coding agent loaded into a real repo whose stack is FastAPI/Python 3.12+, Next.js 15 (App Router) / React 19 / TS, Go 1.22+, Flutter/Dart 3, PostgreSQL 16.
> Versions to state explicitly everywhere: Python 3.12+, Pydantic v2 (`ConfigDict(extra="forbid")`), SQLAlchemy 2.0 (`select()` + bound params), FastAPI ≥0.115, Next.js 15 App Router, React 19, Zod ≥3.23, Go 1.22+ (`http.ServeMux` method+path patterns, `log/slog`), Dart 3 / Flutter stable, PostgreSQL 16, Argon2id, `osv-scanner`, `govulncheck`, `pip-audit`, `gitleaks`, `semgrep`.

---

## 0. Directory & file list (create exactly these, nothing else)

```
/Volumes/EXTERN/DEV/skills/skills/secure-coding/
├── SKILL.md
├── references/
│   ├── threat-modeling.md
│   ├── owasp-by-stack.md
│   ├── authn-authz.md
│   └── secrets-and-supply-chain.md
└── scripts/
    └── verify.sh        (chmod +x after writing)
```

Build order: (1) `scripts/verify.sh`, (2) the four `references/*.md`, (3) `SKILL.md` last (so its pointers match what exists). Create the directories first:

```bash
mkdir -p /Volumes/EXTERN/DEV/skills/skills/secure-coding/references
mkdir -p /Volumes/EXTERN/DEV/skills/skills/secure-coding/scripts
```

Global writing rules (apply to every file):

- One `#` H1 per file; consistent `##`/`###` nesting; never skip a level.
- Every fenced code block has a language tag (`python`, `ts`, `tsx`, `go`, `dart`, `sql`, `bash`, `json`, `yaml`, `text`, `markdown`).
- Good/Bad pairs: label them with a `// BAD —` / `# BAD —` comment as the first line of the block and a `// GOOD —` / `# GOOD —` in the fixed block. Keep BAD short, GOOD complete and copy-pasteable.
- No placeholders, no `TODO`, no `...`, no "etc." Every snippet must compile/run in context (correct imports, correct API names for the pinned versions).
- Internal links between skill files are relative: `references/owasp-by-stack.md`, `scripts/verify.sh`. See-also links to sibling skills use `../<id>/SKILL.md`.
- Use `404 not found` (not 403) on access-control misses to avoid resource enumeration — state this rationale wherever IDOR appears.

---

## 1. `scripts/verify.sh` (write FIRST, ~150–190 lines, then `chmod +x`)

Exact contract from spec §4. Write the file with this structure verbatim (adapt only formatting, not behavior).

### 1.1 Header + boilerplate

- Shebang `#!/usr/bin/env bash`, then `set -euo pipefail`.
- A top usage comment block (lines start with `#`) stating:
  - NAME: `verify.sh — secure-coding application-security gate`.
  - USAGE: `./verify.sh` run from the **user's project root** (not this skills repo).
  - WHAT IT DOES: secret scan + SAST + per-stack dependency CVE audit; detects tools and **skips (yellow warning) when a tool is missing**; **exits non-zero only on real high/critical findings**.
  - GUARANTEES: idempotent, read-only (no writes to the repo, no auto-fix), network only where a tool inherently needs it; `semgrep --config=auto` is **opt-in** via `SECURE_CODING_SEMGREP_AUTO=1`.
  - ENV TOGGLES: `SECURE_CODING_SEMGREP_AUTO=1` (enable semgrep auto network rules), `NO_COLOR=1` (disable ANSI).

### 1.2 Helpers (write exactly)

```bash
RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
[[ -n "${NO_COLOR:-}" ]] && { RED=""; YEL=""; GRN=""; RST=""; }
FAILED=0
warn() { printf '%s[skip]%s %s\n' "$YEL" "$RST" "$*" >&2; }
ok()   { printf '%s[ok]%s %s\n'   "$GRN" "$RST" "$*"; }
bad()  { printf '%s[FAIL]%s %s\n' "$RED" "$RST" "$*" >&2; FAILED=1; }
have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n=== %s ===\n' "$*"; }
```

Add a `need()` helper that wraps `have`: if missing, call `warn "<tool> not installed (install: <hint>)"` and `return 1`, else `return 0`. Use it as a guard before every tool block.

### 1.3 Detection + run order (tool-by-tool, detect-or-skip)

1. **Secrets — `gitleaks`** (`section "Secrets (gitleaks)"`):
   - `need gitleaks "brew install gitleaks / https://github.com/gitleaks/gitleaks"` guard.
   - Run `gitleaks detect --no-banner --redact --exit-code 1` on the working tree; if the cwd is a git repo (`git rev-parse --is-inside-work-tree`), the `detect` already covers history. Capture exit: non-zero → `bad "gitleaks found secrets"`, zero → `ok "no secrets"`.
2. **SAST — `semgrep`** (`section "SAST (semgrep)"`):
   - `need semgrep "pipx install semgrep / brew install semgrep"` guard.
   - Determine config: if a local config exists (`.semgrep.yml` || `.semgrep.yaml` || `semgrep.yml` || directory `.semgrep/`), set `CFG="--config <thatfile/dir>"`. Else if `SECURE_CODING_SEMGREP_AUTO=1`, set `CFG="--config=auto"`. Else `warn "no semgrep config and SECURE_CODING_SEMGREP_AUTO unset; skipping"` and skip.
   - Run `semgrep $CFG --error --severity ERROR --quiet`; non-zero → `bad "semgrep ERROR findings"`. Then a separate informational `semgrep $CFG --severity WARNING --quiet` whose findings only `warn` (never set FAILED). Guard the WARNING run so it can't abort the script (`|| true`).
3. **Per-stack dependency audit — detect by manifest, run ALL that match** (`section "Dependency audit"`). For each, guard with file existence then `need`:
   - `pyproject.toml` or `requirements*.txt` present → prefer `uv pip audit` if `have uv`, else `pip-audit`. Hint: `pipx install pip-audit`. Non-zero → `bad`.
   - `package.json` present → if `have osv-scanner` run `osv-scanner --lockfile=<detected lockfile> ` (detect `pnpm-lock.yaml`/`package-lock.json`/`yarn.lock`; if none, `osv-scanner --recursive .`); else fall back to a package-manager audit: pnpm lock → `pnpm audit --prod --audit-level high`, yarn lock → `yarn npm audit --severity high` (skip+warn if yarn classic), else `npm audit --omit=dev --audit-level=high`. Hint: `https://google.github.io/osv-scanner/`. Non-zero → `bad`.
   - `go.mod` present → `need govulncheck "go install golang.org/x/vuln/cmd/govulncheck@latest"`; run `govulncheck ./...`; non-zero → `bad`.
   - `pubspec.yaml` present → `need dart`; run `dart pub outdated --mode=null-safety` **informational only**, always `warn`-level summary, never sets FAILED (no CVE feed). State this in a comment.
4. **Summary** (`section "Summary"`):
   - If `FAILED -eq 0`: `ok "no high/critical findings"`; else `printf` a red line "high/critical findings present — resolve before merge".
   - `exit "$FAILED"`.

### 1.4 After writing

```bash
chmod +x /Volumes/EXTERN/DEV/skills/skills/secure-coding/scripts/verify.sh
```

**DO NOT execute `verify.sh` in this skills repo** (it is not a target-stack project). Verifying it is executable is enough.

---

## 2. `references/threat-modeling.md` (~240–290 lines)

H1: `# Threat modeling — PR-sized, not enterprise ceremony`. One-line intro: lightweight STRIDE you can finish inside a PR description.

Sections in order:

1. `## When to threat-model (and when to skip)` — two bullet lists. DO: new trust boundary, new auth/authz surface, money/PII/file-upload/outbound-fetch, new external integration. SKIP: copy-edit, internal refactor with no boundary change, test-only code, pure styling. State the "good enough" trigger: model only the **changed** boundary, not the whole app.
2. `## STRIDE in one table` — a 6-row markdown table: columns `Threat | Question to ask | Typical control on this stack`. Rows: Spoofing (who is the caller? → verified session/JWT `aud`/`iss`/`exp`, no `alg:none`), Tampering (can the client alter what the server trusts? → server-side authz + signed/HMAC payloads + DB constraints), Repudiation (can we prove who did it? → append-only `slog`/`structlog` audit with `user_id`), Information disclosure (does the response leak more than the caller may see? → field allowlists, generic errors, ownership-scoped queries), Denial of service (can one caller exhaust us? → rate limits, body-size caps, query timeouts, ReDoS-safe regex), Elevation of privilege (can a user act as admin/another user? → deny-by-default, per-object checks, role checks server-side).
3. `## Trust boundaries & a text DFD` — explain the 5-box flow `Client ‖ Edge/CDN ‖ API ‖ DB ‖ 3rd-party` and that `‖` marks a boundary where data becomes untrusted/trusted. Include a worked ASCII DFD (fenced ```text```) for **"user uploads an avatar"**: browser → Next.js route handler (validate size/magic-bytes) ‖ FastAPI presign endpoint (authz: is this the user's own avatar slot?) ‖ object store (private bucket, random key) ‖ CDN (signed URL). Mark each `‖` and annotate the check that lives there.
4. `## Abuse cases — turn each user story into "…and an attacker does X"` — 6 worked rows (use a table `Feature | Abuse case | Control`): login → credential stuffing → per-IP+per-identity rate limit + lockout; avatar upload → polyglot / SVG-with-`<script>` → sniff magic bytes, re-encode images, serve from a separate origin with `Content-Disposition: attachment` + `nosniff`; search → enumeration + ReDoS → bound input, parameterize, use linear-time regex / `re2`; webhook → forgery/replay → verify HMAC signature + timestamp window + idempotency key; password reset → token leak via `Host` header / referrer → single-use hashed short-TTL token, build links from a configured base URL not the request `Host`; export/report → IDOR mass-extraction → ownership scope + per-object authz + rate limit.
5. `## The PR-sized template` — a copy-pasteable fenced ```markdown``` block with headings: `### Threat model: <feature>` then bullet sections **Assets**, **Entry points**, **Trust boundaries**, **STRIDE hits** (only the ones that apply), **Decided controls**, **Residual risk (accepted)**. Follow it with the 1-paragraph **"good enough" stopping rule**: stop when every changed entry point has an explicit authz decision, every untrusted input has a validator, every dangerous sink has a defense, and residual risks are written down — not when the doc is "complete".
6. `## Worked example — FastAPI "create invoice + download via signed URL"` — fill the template end-to-end for this feature. Show the assets (invoice PDF, customer PII), entry points (`POST /invoices`, `GET /invoices/{id}/download`), boundaries, the concrete STRIDE hits (IDOR on download, tampering on amount, info-disclosure of other tenants' invoices), and the controls (ownership-scoped query, server-computed totals, `URL`-signed short-TTL download, audit log). Include one short ```python``` snippet of the signed-download handler doing the ownership check + expiry. Close with a 2-line residual-risk note.

Cross-links at the end: pointer to `owasp-by-stack.md` (fix code per category) and `authn-authz.md` (auth surface).

---

## 3. `references/owasp-by-stack.md` (~440–500 lines — the heaviest file)

H1: `# OWASP Top 10 (2021) — vulnerable→fixed per stack`. Intro: each category has a 2-line "what / why exploitable", then Bad/Good pairs. Where a category is most acute in one language, lead with that one but give at least Python + one other per category; A01, A03, A10 get all three (Python/Go/TS).

For each `### A0X — <name>` subsection, include the 2-line explainer then the code. Exact contents:

1. `### A01 — Broken Access Control / IDOR`
   - **Python (FastAPI + SQLAlchemy 2.0)**: BAD `db.get(Document, doc_id)` returned to any authed user. GOOD `select(Document).where(Document.id == doc_id, Document.owner_id == current_user.id)`, `notFound`→`raise HTTPException(404)`, `current_user` via `Depends(get_current_user)`. Note 404-not-403.
   - **Go (1.22 `ServeMux`, `slog`)**: BAD handler uses `r.PathValue("id")` straight into query. GOOD extract `userID` from validated context (`r.Context().Value(userKey)`), `WHERE id=$1 AND owner_id=$2`, `http.Error(w, "not found", http.StatusNotFound)`, `slog.Warn("authz_miss", "user", userID)`.
   - **TS (Next.js 15 App Router Route Handler / Server Action)**: BAD route returns row from `params.id` trusting the session exists. GOOD `const session = await auth(); if (!session) notFound();` + ownership check + `notFound()`. **Call out: Server Actions are public POST endpoints — re-authorize server-side, never rely on conditionally rendering the button.**
   - **Mass-assignment guard** (sub-block): Pydantic v2 `model_config = ConfigDict(extra="forbid")` + explicit field map; Go decode into an allowlist struct (no `owner_id`/`role` field bound from body); TS Zod `.strict()` then map only allowed keys.
2. `### A02 — Cryptographic Failures` — Argon2id password hashing (`argon2-cffi` Python; `golang.org/x/crypto/argon2` Go), AES-GCM / `cryptography` Fernet for data-at-rest, **secure randomness**: `secrets.token_urlsafe` (Py), `crypto.randomBytes` (TS), `crypto/rand` (Go) — BAD `random`/`math/rand`/`Math.random` for tokens. One-line: TLS enforced everywhere; never MD5/SHA1 for passwords.
3. `### A03 — Injection` (give all three langs):
   - **SQL**: SQLAlchemy 2.0 bound params vs f-string (Py); `db.QueryContext(ctx, "... WHERE email=$1", email)` vs `Sprintf` (Go); `postgres.js` tagged template / Prisma parameterized vs string concat (TS).
   - **Command injection**: Python `subprocess.run([...], shell=False)` vs `shell=True` with interpolation; Go `exec.CommandContext(ctx, "convert", in, out)` (no shell) vs `sh -c` with concat. One line: never build a shell string from user input.
   - **Path traversal**: canonicalize + base-dir containment check — Python `(base / name).resolve().is_relative_to(base.resolve())`; Go `filepath.Clean` + `strings.HasPrefix(filepath.Join(base, name), base)`. BAD: `open(base + user_name)`.
   - **NoSQL/operator injection** (short): reject `$`-prefixed keys / object-typed values in Mongo-style filters.
4. `### A04 — Insecure Design` — rate-limit + lockout on auth (snippet); idempotency keys on payment writes (DB unique constraint on `idempotency_key`); signed/expiring URLs vs guessable sequential IDs; **password reset done right** as the flagship: single-use, store **hash** of the token, short TTL, link built from configured base URL (host-header-independent). One ```python``` reset-token snippet.
5. `### A05 — Security Misconfiguration` — `FastAPI(debug=False)` / no `--reload` in prod; `NODE_ENV=production`; Go: never write panic stack to client (`recover()` → 500 + `slog`); CORS allowlist (not `*` with credentials); directory listing / verbose errors off; no default creds; security headers present (pointer to SKILL.md headers block).
6. `### A06 — Vulnerable & Outdated Components` — pin + commit lockfile; show `pip-audit`, `npm audit --omit=dev` / `osv-scanner`, `govulncheck ./...` invocations **with a 2-line "how to read the output"**; overriding a vulnerable **transitive** dep: npm `overrides`, pip constraints file, `go mod replace`. (Detail lives in `secrets-and-supply-chain.md`; keep this tight and link there.)
7. `### A07 — Identification & Auth Failures` — here only: credential-stuffing/brute-force defense, **session fixation** (regenerate session id on login & privilege change — show the regenerate call per framework), generic "invalid credentials" message (no user-enumeration), MFA hook pointer to `authn-authz.md`.
8. `### A08 — Software & Data Integrity (supply chain)` — lockfile integrity (`npm ci`, `go mod verify`), no `curl … | bash`, verify checksums for downloaded binaries, **SRI** (`integrity="sha384-…" crossorigin`) for any third-party `<script>`; pointer to `secrets-and-supply-chain.md`.
9. `### A09 — Logging & Monitoring Failures` — log authz failures + auth events with `user_id` (not email/PII), structured (`structlog` Py / `slog` Go), never log request bodies on auth routes, alert on spikes of `authz_miss`/`login_fail`. One `slog` + one `structlog` snippet showing redaction.
10. `### A10 — SSRF` (highest-value modern category — full code per stack): user-controlled outbound URL. For **Python (`httpx`)**, **Go (`http.Client`)**, **TS (route handler `fetch`)**:
    - BAD: fetch the user-supplied URL directly.
    - GOOD: parse URL → enforce **scheme allowlist** (`https` only) → resolve DNS → reject if any resolved IP is private/loopback/link-local/ULA/metadata (`169.254.169.254`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `127.0.0.0/8`, `::1`, `fc00::/7`, `fe80::/10`) → host allowlist if possible → **disable redirects** (or re-validate each hop) → short timeout. Python: validate then pin the resolved IP / use a custom transport; Go: `http.Client{CheckRedirect: block, Transport with DialContext that re-checks the IP}`; TS: `new URL()` + allowlist + `redirect: 'error'` + `AbortSignal.timeout`. State the DNS-rebinding caveat (validate the IP actually dialed, not just the pre-resolution IP).

End with a one-line index table `Category → fastest fix → where the SKILL.md flagship lives`.

---

## 4. `references/authn-authz.md` (~290–360 lines)

H1: `# Authentication & authorization`. Sections in order:

1. `## Sessions vs JWT — pick this when` — a trade-off table (columns `Dimension | Server-side session | JWT (access+refresh)`): revocation (instant vs needs a denylist), scale (sticky/shared store vs stateless), mobile/native (cookie awkward vs natural), XSS exposure (HttpOnly cookie immune vs localStorage stealable), CSRF (needs token vs bearer header immune). Bottom line: server-side session is the default for first-party web; JWT for stateless/native, short access (5–15 min) + rotating refresh with reuse detection + a revocation story.
2. `## OAuth2 / OIDC` — authorization-code + **PKCE** flow (2-line). FastAPI as **resource server** verifying access tokens: fetch + cache JWKS, check `aud`/`iss`/`exp`, **pin algorithms** (`algorithms=["RS256"]`), reject `alg:none` and HS-when-RS-expected. One ```python``` verify snippet (`python-jose`/`pyjwt` with explicit `algorithms=` and `audience=`/`issuer=`). Next.js: Auth.js v5 (`next-auth`) server-side session, authz in callbacks; one ```ts``` `auth()` guard.
3. `## RBAC vs ABAC` — role table + permission check vs attribute/policy check. FastAPI dependency `require_role("admin")` (raises 403) and a per-object ABAC check function; Go middleware that reads role from context. Snippets for both.
4. `## Token lifetimes & refresh rotation` — short access (5–15 min), rotating refresh, **reuse detection** (a replayed refresh token revokes the whole family), server-side revocation list, logout invalidates refresh. Short pseudo/`python` snippet of rotate+detect.
5. `## Cookies done right` — canonical `Set-Cookie`: `HttpOnly; Secure; SameSite=Lax` (Strict for sensitive), `__Host-` prefix, scoped `Path=/`, no `Domain`. Full `Set-Cookie` examples in FastAPI (`response.set_cookie(..., httponly=True, secure=True, samesite="lax")`), Next.js (`cookies().set(...)` in a Route Handler/Server Action), Go (`http.SetCookie` with `HttpOnly`, `Secure`, `SameSite: http.SameSiteLaxMode`). BAD: token in `localStorage`.
6. `## CSRF defense` — needed for **cookie-auth state-changing** requests. Double-submit token + Origin/Referer check; SameSite is defense-in-depth, **not** sufficient alone. Bearer-token APIs don't need CSRF tokens **but must not also accept the auth cookie**. One snippet (double-submit verify).
7. `## Password hashing — Argon2id` — concrete params: `time_cost=3, memory_cost=65536 (64 MiB), parallelism=4` (tune to ~0.5s on prod hardware); `argon2-cffi` `PasswordHasher` verify + `check_needs_rehash` on login; bcrypt cost≥12 fallback. ```python``` + a one-line Go note (`argon2.IDKey`). Never SHA-256/MD5.
8. `## MFA` — TOTP enrollment + verify with `pyotp` (one snippet), recovery codes stored **hashed**, step-up auth for sensitive actions.
9. `## Flutter / Dart 3 note` — store tokens in `flutter_secure_storage` (Keychain/Keystore), **never** `SharedPreferences`; one ```dart``` snippet; one-line cert-pinning pointer.

End with cross-links: `owasp-by-stack.md` (A01/A07), `secrets-and-supply-chain.md` (key/secret storage).

---

## 5. `references/secrets-and-supply-chain.md` (~270–340 lines)

H1: `# Secrets & supply chain`. Sections in order:

1. `## Env vs vaults` — 12-factor env for dev; secret manager (Vault / cloud SM / Doppler) for prod. **Next.js**: only `NEXT_PUBLIC_*` reaches the client bundle — everything else is server-only; BAD = a secret read in a Client Component (it ships to the browser). FastAPI `pydantic-settings` `BaseSettings` with fail-fast on missing. Go `os.Getenv` + a `mustEnv()` that panics on startup if unset. Snippets for all three.
2. `## Never in repo` — `.gitignore` patterns (`.env`, `.env.*`, `!*.example`); `gitleaks` as pre-commit hook + history scan + CI; **incident order when a secret IS committed: rotate FIRST, then scrub history** (git-filter-repo) — order matters because history scrub is slow and the secret is already exposed.
3. `## Rotation` — cadence + on-exposure runbook; after rotation, **invalidate sessions/tokens** so old credentials can't ride along.
4. `## Dependency pinning & lockfiles` — per ecosystem: `uv`/`pip-tools` compiled with hashes + `pip install --require-hashes`; `package-lock.json`/`pnpm-lock.yaml` committed + `npm ci`/`pnpm i --frozen-lockfile`; `go.sum` + `go mod verify`; `pubspec.lock` committed.
5. `## Audit tooling — exact commands + how to read + how to fix` — a table or per-tool block: `pip-audit`, `npm audit --omit=dev` / `osv-scanner` (note osv covers more ecosystems + lockfile-aware), `govulncheck` (call out its **reachability** advantage — only reports vulns your code actually calls), `dart pub outdated`. For each: the command, what a finding looks like, and the fix (upgrade / override / replace). Show overriding a transitive: npm `overrides`, pip constraints, `go mod replace`.
6. `## SBOM & provenance` — `syft` to emit CycloneDX/SPDX; one-paragraph on `cosign`/SLSA provenance; SRI for CDN scripts (cross-link A08).
7. `## CI security gate (the payoff)` — a complete ```yaml``` GitHub Actions job that runs gitleaks + semgrep + the per-stack auditors and fails on high/critical — essentially `verify.sh` in CI. Add a 2-line note on Dependabot/Renovate config. Reference that `scripts/verify.sh` is the local equivalent.

End with cross-link to `scripts/verify.sh` and the SKILL.md "Secrets & supply chain" section.

---

## 6. `SKILL.md` (write LAST, enforce **250–450 lines**; aim ~380–430)

### 6.1 Frontmatter (exact)

```yaml
---
name: secure-coding
description: "Use when threat-modeling a feature, reviewing code or a diff for security, hardening authentication/authorization, handling secrets, configuring CORS/CSP/security headers, or fixing OWASP-class vulnerabilities (broken access control, injection, SSRF, auth failures, supply-chain) in FastAPI/Python, Go, Next.js, or Flutter. Triggers: 'security review', 'threat model this', 'is this safe', 'harden auth', 'rotate secrets', 'fix this vuln', 'OWASP', 'why is this endpoint exposed', before merging an endpoint that touches auth/payments/PII/uploads."
origin: risco
---
```

(Single-line `description`; YAML-escape with double quotes; no other frontmatter keys.)

### 6.2 Section order + per-section content

Write these `##` sections in this exact order. Keep each tight; push depth to `references/` via explicit pointers.

1. `# Secure coding — threat modeling + OWASP across the stack`
   One-line purpose. Then the **operating posture** as 3 bold bullets: **Read-only by default** (identify → rank by exploitability → propose diffs; apply only when asked); **Exploitability over theory** (rank reachable + user-controlled + meaningful sink first, like a bounty triager — don't dump a flat checklist); **Every finding ships a fix** (stack-correct corrected code, never "consider sanitizing").

2. `## When to use / When NOT to use`
   Condensed bullets from spec §1. **Must include the boundary**: this skill is about **application code the user ships**; agent/Claude-Code config security (`.claude/`, hooks, MCP, prompt injection, sandboxing) is a **different** concern — point there in See Also, stay in lane. Also: no pentest/bounty PoC against third parties (legal); don't gate trivial refactors through `verify.sh`.

3. `## The 30-second model: lethal trifecta + trust boundaries`
   - **Lethal trifecta** (Simon Willison): private data + untrusted input + ability to exfiltrate — flag any handler where all three meet.
   - **Trust-boundary rule**: every untrusted→trusted crossing is a checkpoint (HTTP body→SQL, user string→shell/URL/HTML, JWT claim→authz decision, filename→fs path, upload→disk/exec).
   - **6-row table** `Untrusted source | Dangerous sink | Defense | Reference`: request body→SQL→parameterize→`references/owasp-by-stack.md#a03`; user URL→outbound fetch→SSRF allowlist→`#a10`; user HTML→DOM→encode/sanitize→`#a03`; filename→fs path→canonicalize+base-check→`#a03`; JWT→authz→verify+claims→`references/authn-authz.md`; upload→disk/exec→type+size+store-outside-webroot→`#a01`.

4. `## Review workflow (PR-sized)`
   Numbered 1–6 exactly per spec §2: Scope → Threat-model lite (→`references/threat-modeling.md`) → map sinks to OWASP (→`references/owasp-by-stack.md`) → rank by exploitability (reachable? user-controlled? meaningful sink?) → propose fixes as diffs in the repo's stack → run `scripts/verify.sh`, resolve high/critical.

5. `## Core principles (non-negotiable)`
   8 one-line imperatives from spec §2.66: validate at boundary with schema; parameterize every query; authorize server-side, per-object, every request, deny by default; encode on output by context; secrets only from env/secret-manager; fail closed (generic errors to client, detail to logs); pin+lock deps (reachable CVE = release blocker); least privilege/least agency.

6. `## OWASP Top 10 — fastest fix per category`
   - A **10-row quick-reference table**: `OWASP 2021 | The mistake you'll actually see | Stack-correct fix in one phrase | Deep ref`. One row per A01–A10, each `Deep ref` linking `references/owasp-by-stack.md#aNN`.
   - Then **3 flagship Good/Bad code blocks** for **A01 Broken Access Control / IDOR** (the #1, stack-agnostic in shape):
     - `python` FastAPI 3.12 + SQLAlchemy 2.0: BAD `db.get(Document, doc_id)` → GOOD ownership-scoped `select(...).where(Document.owner_id == current_user.id)`, 404 on miss, `Depends(get_current_user)`.
     - `tsx`/`ts` Next.js 15 Route Handler or Server Action: BAD trusts `params.id` + assumes session → GOOD `await auth()` guard + ownership check + `notFound()`; one-line note Server Actions are public endpoints.
     - `go` 1.22 `ServeMux`+`slog`: BAD `r.PathValue("id")` straight to query → GOOD `userID` from context, `WHERE id=$1 AND owner_id=$2`, `http.StatusNotFound`.
   - Close with: "Full vulnerable→fixed code for **all 10 categories in all three stacks** lives in `references/owasp-by-stack.md`."

7. `## Input validation & output encoding`
   - **Validate** (Good/Bad): Pydantic v2 model `Field(..., max_length=...)` + `ConfigDict(extra="forbid")`; Zod `.strict()` parsed in a Server Action; Go struct + `go-playground/validator`. BAD = raw `request.json()` / `as any`.
   - **Encode/XSS**: React auto-escapes — the bug is `dangerouslySetInnerHTML`; GOOD = DOMPurify allowlist sanitize or render as text. Name stored vs reflected vs DOM XSS in one line each. Pointer to `owasp-by-stack.md`.
   - **Upload validation**: size + **sniffed** content-type (magic bytes, not `file.type`) + extension allowlist + store outside web root + random filename. One `python` + one `ts` snippet.

8. `## AuthN / AuthZ in 60 seconds`
   - **Sessions vs JWT** one-line trade-off (session = easy revocation, default first-party web; JWT = stateless, short access + rotating refresh + revocation story).
   - **Cookie flags** canonical line: `HttpOnly; Secure; SameSite=Lax` (Strict for sensitive), `__Host-` prefix, scoped `Path`. BAD = token in `localStorage`.
   - **Password hashing**: Argon2id (`time_cost=3, memory_cost=64MiB, parallelism=4`) via `argon2-cffi` (Py) / `golang.org/x/crypto/argon2` (Go); bcrypt cost≥12 fallback; never SHA-256/MD5.
   - **CSRF**: needed for cookie-auth state-changing requests; double-submit or framework token; SameSite is defense-in-depth, not sufficient alone.
   - One **flagship** `python` FastAPI OAuth2 password-flow + JWT verify snippet (pinned `algorithms=["RS256"]` or `["HS256"]`, `audience`/`issuer`, `exp`). Pointer to `references/authn-authz.md` for the rest.

9. `## CORS, security headers, TLS, rate limiting, logging`
   - **CORS** Good/Bad: never `allow_origins=["*"]` with `allow_credentials=True` (illegal + dangerous); explicit origin allowlist (FastAPI `CORSMiddleware`).
   - **Headers**: canonical set — CSP (no `'unsafe-inline'`/`'unsafe-eval'`; nonce/hash path noted), HSTS `max-age=63072000; includeSubDomains; preload` (only when all subdomains HTTPS), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` / CSP `frame-ancestors 'none'`, `Referrer-Policy`. One `ts` `next.config.ts` headers block + one `python` FastAPI middleware.
   - **Rate limiting**: per-IP + per-identity, stricter on auth/OTP/search; note in-memory ≠ multi-instance safe (use Redis). One snippet.
   - **Logging without PII**: redact tokens/passwords/PAN/email; log `user_id` not email; structured (`slog`/`structlog`); never log auth-route bodies.

10. `## Secrets & supply chain (the part that gets you breached)`
    - Env/secret-manager, never repo; `.env` gitignored; only `NEXT_PUBLIC_*` is public (BAD: secret in a Client Component).
    - Pin + lockfile committed; install with `--frozen`/`npm ci`/`go mod verify`.
    - Audit per stack: `pip-audit`, `npm audit --omit=dev` / `osv-scanner`, `govulncheck`, `dart pub outdated`.
    - Rotation on exposure + `gitleaks` history scan; SBOM (`syft`) + provenance note. Pointer to `references/secrets-and-supply-chain.md`.

11. `## Anti-patterns / rationalizations → STOP`
    The signature 2-column table (`Rationalization | Reality`), **12 rows** verbatim from spec §2.112 (it's behind auth / frontend validates / blacklist / JWT in localStorage / `*`+credentials / transitive CVE / log payload later / rate-limit after launch / internal URL SSRF / stack trace to client / secrets in CI YAML / Argon2 overkill).

12. `## verify.sh — the gate`
    2–4 lines: runs gitleaks + semgrep + per-stack CVE audit; it is **the user's to run in their repo root**; skips-not-fails on missing tools; exits non-zero only on high/critical. Pointer to `scripts/verify.sh`.

13. `## Quick reference`
    Compact cheat-sheet table `Concern | Tool / flag | One-liner`: gitleaks (`gitleaks detect --redact`), semgrep (`semgrep --config=auto --severity ERROR`), pip-audit, `npm audit --omit=dev --audit-level=high`, osv-scanner, govulncheck, Argon2id params, cookie flag string, CSP starter, CORS rule, SSRF allowlist ranges.

14. `## See Also`
    - Sibling **stack skills** (FastAPI / Next.js / Go / Flutter) — "they defer security to this skill" (use `../<id>/SKILL.md` form; if those skills don't exist yet, phrase as "the stack skills, which reference this one").
    - The **agent/Claude-Code config security** concern (separate; `.claude/`, hooks, MCP, sandboxing) — explicitly out of this skill's scope.
    - `../risco-project-harness/SKILL.md` — secrets land in `01-TOOLS/<PROVIDER>/.env` (gitignored); reinforces never-in-repo.
    - The four `references/*.md` enumerated each with a one-line "go here when…".

### 6.3 Line-budget guard

After writing SKILL.md, run `wc -l` on it. If > 450, move the longest snippet bodies into the matching `references/*.md` and leave a one-line pointer. If < 250, the content is too thin — expand the OWASP table rationale and the flagship snippets. Target band: 380–430.

---

## 7. Acceptance checks (implementer MUST self-verify before returning)

Run these and confirm each:

1. **Files exist**: `ls -R /Volumes/EXTERN/DEV/skills/skills/secure-coding/` shows exactly the 6 files in §0 (SKILL.md, 4 references, verify.sh) and no extras.
2. **verify.sh executable**: `test -x .../scripts/verify.sh` passes; `bash -n .../scripts/verify.sh` parses clean (syntax check — do NOT execute it for real in this repo).
3. **Frontmatter**: SKILL.md frontmatter has exactly `name: secure-coding`, the trigger-rich `description` starting `"Use when "`, `origin: risco`. No other keys.
4. **One H1 per file**: `grep -c '^# ' <file>` returns 1 for each of the 5 markdown files.
5. **Every fenced block has a language tag**: no bare ` ``` ` opening fences — scan each markdown file (` ```\n` with no language after the backticks is a defect, except closing fences).
6. **No placeholders**: `grep -rn -E 'TODO|FIXME|\.\.\.|<placeholder>|etc\.' .../secure-coding/` returns nothing meaningful (an intentional `...` inside a code ellipsis is not allowed — replace with real code).
7. **Code correctness spot-checks** (read, don't run): SQLAlchemy uses 2.0 `select()` style; Pydantic uses `ConfigDict(extra="forbid")` (v2, not `class Config`); FastAPI JWT verify pins `algorithms=`; Go uses `r.PathValue`/`http.ServeMux` (1.22) and `log/slog`; Next.js uses App Router `await auth()` / `notFound()` and treats Server Actions as public; Dart uses `flutter_secure_storage`. Argon2id params consistent across SKILL.md and authn-authz.md (`time_cost=3, memory_cost=65536, parallelism=4`).
8. **Heading consistency**: no skipped heading levels; OWASP anchors referenced from SKILL.md (`#a01`…`#a10`) match the actual `### A01`…`### A10` headings' GitHub-slug anchors in `owasp-by-stack.md` (slug of `### A01 — Broken Access Control / IDOR` is `a01--broken-access-control--idor`; verify the links you write resolve to real slugs, or use plain prose pointers if unsure).
9. **See Also links** present in SKILL.md: to sibling stack skills, to the agent-config-security concern, to `../risco-project-harness/SKILL.md`, and to all four `references/*.md`.
10. **Line budgets**: SKILL.md 250–450; each reference 200–500; verify.sh ~150–190. Confirm with `wc -l`.
11. **Good/Bad labeling**: every Bad/Good pair is labeled in-comment and the GOOD half is complete and runnable.

Return a 3–5 line summary of what was built and the `wc -l` of each file.
