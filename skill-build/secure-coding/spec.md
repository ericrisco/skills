# DESIGN SPEC — `secure-coding`

> Title: **Secure coding — threat modeling + OWASP across the stack**
> Origin: `risco` · Audience: an LLM coding agent working in the user's real repo
> Stack targeted: FastAPI/Python 3.12+, Next.js 15 (App Router) / React 19 / TS, Go 1.22+, Flutter/Dart 3, PostgreSQL 16
> Status: SPEC ONLY — the skill itself is built in a later pass.

---

## 1. Purpose & precise trigger

### Purpose (one line)
A transversal secure-coding skill that the stack skills reference: it makes an agent threat-model a feature in PR-sized increments, fix OWASP-class bugs with stack-correct vulnerable→fixed diffs, harden auth/secrets/supply-chain, and gate the result with a runnable `verify.sh`.

### `description` frontmatter (trigger-rich, starts with "Use when …")
> Use when threat-modeling a feature, reviewing code or a diff for security, hardening authentication/authorization, handling secrets, configuring CORS/CSP/security headers, or fixing OWASP-class vulnerabilities (broken access control, injection, SSRF, auth failures, supply-chain) in FastAPI/Python, Go, Next.js, or Flutter. Triggers: "security review", "threat model this", "is this safe", "harden auth", "rotate secrets", "fix this vuln", "OWASP", "why is this endpoint exposed", before merging an endpoint that touches auth/payments/PII/uploads.

### When to use
- Adding or reviewing an endpoint that touches auth, money, PII, file uploads, or external URLs.
- A diff/PR needs a security pass before merge.
- Designing a feature (threat-model it before writing code).
- Hardening: cookies, tokens, CORS, CSP/headers, TLS, rate limits, password hashing, MFA.
- Secrets handling, dependency CVEs, lockfile/supply-chain integrity, CI security gates.

### When NOT to use
- **Agent/Claude-Code config security** (`.claude/`, hooks, MCP, prompt injection, sandboxing) → that is a *different* concern; this skill is about the **application code** the user ships. Point the user there and stay in lane. (We will reference it in "See Also", not duplicate it.)
- Pure infra/network firewalling with no code change → out of scope; mention and defer.
- The user wants a pentest/bounty PoC against a third party → out of scope (legal). This skill defends code; it does not attack external targets.
- Trivial non-security refactors → don't gate them through `verify.sh`.

### Operating posture (stated up front in SKILL.md)
- **Read-only by default.** Identify → rank by exploitability → propose fixes as diffs. Apply only when the user asks.
- **Exploitability over theory.** Rank findings the way a bounty triager would (reachable + user-controlled + meaningful sink), not as a checkbox dump. Borrow the in-scope/skip discipline from `security-bounty-hunter` so the agent doesn't drown the user in low-signal noise.
- **Every finding ships a fix.** No "consider sanitizing"; show the corrected code for *this* stack.

---

## 2. `SKILL.md` outline (every heading + what it delivers)

Target length: **~380–430 lines.** Dense, directive, copy-pasteable. Long material pushed to `references/`.

### Frontmatter
`name: secure-coding`, the `description` above, `origin: risco`.

### H1 `# Secure coding — threat modeling + OWASP across the stack`
One-line purpose + the operating posture (read-only, exploitability-ranked, fix-with-every-finding).

### H2 `## When to use / When NOT to use`
Condensed bullets from §1, including the explicit "this is app code, not agent/`.claude/` config" boundary.

### H2 `## The 30-second model: lethal trifecta + trust boundaries`
Decision lens the agent applies to *any* code it sees, before tooling.
- **Lethal trifecta** (Simon Willison): private data + untrusted input + ability to exfiltrate. Flag any handler where all three meet.
- **Trust boundary rule**: every place untrusted data crosses into a trusted context (HTTP body → SQL, user string → shell/URL/HTML, JWT claim → authz decision) is a checkpoint. List the canonical crossings.
- A 6-row table `Untrusted source → Dangerous sink → Defense → Reference` (e.g. request body→SQL→parameterize; user URL→outbound fetch→SSRF allowlist; user HTML→DOM→encode/sanitize; filename→fs path→canonicalize; JWT→authz→verify+check claims; upload→disk/exec→type+size+store-outside-webroot).

### H2 `## Review workflow (PR-sized)`
The loop the agent runs on a diff/feature. Numbered, tight:
1. Scope: what data, what boundary, what auth context.
2. Threat-model lite (STRIDE per element) — pointer to `references/threat-modeling.md`.
3. Map changed sinks to OWASP categories — pointer to `references/owasp-by-stack.md`.
4. Rank by exploitability (reachable? user-controlled? meaningful sink?) — adopt bounty in/out-of-scope filter.
5. Propose fixes as diffs in the repo's stack.
6. Run `scripts/verify.sh`; resolve high/critical.

### H2 `## Core principles (non-negotiable)`
8–10 dense imperatives, each one line:
- Validate at the boundary with a schema (Pydantic v2 / Zod / Go struct+validator); never trust shape.
- Parameterize every query; ORM or driver bind params, never string-built SQL.
- Authorize on the **server**, per-object, on every request; deny by default.
- Encode on output by context (HTML/attr/JS/URL); never build HTML from user strings.
- Secrets only from env/secret-manager; never in repo, never in logs, never in client bundles.
- Fail closed; generic errors to clients, detail to server logs (no stack traces, no PII).
- Pin + lock dependencies; treat a CVE in a reachable dep as a release blocker.
- Default to least privilege / least agency for tokens, DB roles, CORS origins, file perms.

### H2 `## OWASP Top 10 — fastest fix per category`
A **quick-reference table**: `OWASP 2021 category | The one mistake the agent will actually see | Stack-correct fix in one phrase | Deep ref`. 10 rows. This is the "where do I look" index; the full vulnerable→fixed code lives in `references/owasp-by-stack.md`. Then 3 inline **flagship** Good/Bad blocks (one per language) for the single most common class — **Broken Access Control / IDOR** — because it is #1 and stack-agnostic in shape:

- **Python (FastAPI 3.12 + SQLAlchemy 2.0)**: BAD — `db.get(Document, doc_id)` returned to any authenticated user. GOOD — query scoped `where(Document.owner_id == current_user.id)`, 404 (not 403) on miss to avoid enumeration; dependency-injected `current_user`.
- **TS (Next.js 15 App Router, Server Action / Route Handler)**: BAD — route reads `params.id` and returns row trusting the session exists. GOOD — `const session = await auth()` guard + ownership check + `notFound()`; note Server Actions are public endpoints (must re-authorize, never trust client-side gating).
- **Go 1.22+ (`net/http` ServeMux, `slog`)**: BAD — handler uses `r.PathValue("id")` directly. GOOD — extract `userID` from validated context, `WHERE id=$1 AND owner_id=$2`, `http.Error(..., http.StatusNotFound)`.

### H2 `## Input validation & output encoding`
Concise, with Good/Bad:
- **Validate**: Pydantic v2 model with `Field(..., max_length=…)` + `model_config = ConfigDict(extra="forbid")`; Zod `.strict()` schema parsed in Server Action; Go struct + `go-playground/validator`. Bad = `request.json()` used raw / `as any`.
- **Encode/XSS**: React auto-escapes — the bug is `dangerouslySetInnerHTML`; GOOD = DOMPurify sanitize allowlist, or render as text. Stored vs reflected vs DOM XSS named, each with where it bites in Next.js. Pointer to owasp-by-stack for full set.
- **Upload validation**: size + sniffed content-type (magic bytes, not just `file.type`) + extension allowlist + store outside web root + random filename. One Python + one TS snippet.

### H2 `## AuthN / AuthZ in 60 seconds`
Decision rules + pointer to `references/authn-authz.md`:
- **Sessions vs JWT** one-line trade-off table (server-side session = easy revocation, default for first-party web; JWT = stateless, use short access + rotating refresh, needs a revocation story).
- **Cookie flags** as a single canonical line: `HttpOnly; Secure; SameSite=Lax` (Strict for sensitive), `__Host-` prefix, scoped `Path`. BAD = token in `localStorage`.
- **Password hashing**: Argon2id (params stated) via `argon2-cffi` (Python) / `argon2` (Go `golang.org/x/crypto/argon2`); bcrypt(cost≥12) acceptable fallback. Never SHA-256/MD5.
- **CSRF**: needed for cookie-auth state-changing requests; double-submit or framework token; SameSite is defense-in-depth not sufficient alone.
- One FastAPI OAuth2 password-flow + JWT verify snippet (correct `algorithms=[...]` pin, audience/issuer check, expiry) as the flagship; rest in reference.

### H2 `## CORS, security headers, TLS, rate limiting, logging`
Each a tight rule + one snippet, deep-dive deferred:
- **CORS**: never `allow_origins=["*"]` with `allow_credentials=True` (illegal combo + dangerous); explicit origin allowlist. FastAPI `CORSMiddleware` GOOD/BAD.
- **Headers**: canonical set — CSP (no `'unsafe-inline'`/`'unsafe-eval'` default; nonce/hash path noted), HSTS (`max-age=63072000; includeSubDomains; preload` only when all subdomains HTTPS), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` / `frame-ancestors 'none'`, `Referrer-Policy`. One Next.js `next.config.ts` headers block + one FastAPI middleware.
- **Rate limiting**: per-IP + per-identity, stricter on auth/OTP/search. Note in-memory limiter ≠ multi-instance safe (use Redis). One snippet.
- **Logging without PII**: redact tokens/passwords/PAN/email; log `user_id` not `email`; structured (`slog` / `structlog`); never log request bodies on auth routes.

### H2 `## Secrets & supply chain (the part that gets you breached)`
Rules + pointer to `references/secrets-and-supply-chain.md`:
- Env/secret-manager, never repo; `.env` gitignored; client bundles leak — only `NEXT_PUBLIC_*` is public, everything else server-only (BAD: secret read in a Client Component).
- Pin + lockfile committed; install with `--frozen`/`npm ci`/`go mod verify`.
- Audit per stack: `pip-audit`, `npm audit --omit=dev` / `osv-scanner`, `govulncheck`, `dart pub outdated`.
- Rotation on exposure + `gitleaks` history scan; SBOM (`syft`) + provenance note.

### H2 `## Anti-patterns / rationalizations → STOP`
The signature Good/Bad **rationalization table** (matches house style of `risco-project-harness`). ~12 rows. Examples:
| Rationalization | Reality |
|---|---|
| "It's behind auth, so IDOR doesn't matter." | Authenticated ≠ authorized. Check object ownership every request. |
| "The frontend already validates / hides the button." | Client checks are UX. Re-authorize and re-validate on the server. Server Actions and API routes are public endpoints. |
| "I'll sanitize with a blacklist of bad chars." | Allowlist + parameterize/encode. Blacklists are bypassable. |
| "JWT in localStorage is fine, it's just an access token." | XSS steals it instantly. Use `HttpOnly` cookies; short TTLs. |
| "`allow_origins=['*']` with credentials is convenient." | Browser rejects it and it's dangerous. Explicit origin allowlist. |
| "npm audit shows criticals but they're transitive." | Transitive is still in your bundle. Pin/override or replace. |
| "I'll log the payload to debug, remove it later." | "Later" never comes; PII/secrets leak to logs. Redact now. |
| "We'll add rate limiting after launch." | Auth/OTP endpoints get brute-forced on day one. |
| "It's an internal URL fetch, SSRF isn't a risk." | Internal is exactly the SSRF target (metadata, RDS). Allowlist hosts. |
| "Error stack to the client speeds debugging." | It leaks internals to attackers. Generic to client, detail to logs. |
| "Secrets in `.env.example` are placeholders, real ones are fine in CI YAML." | Use the secret store; never inline real secrets in CI files. |
| "Argon2 is overkill, SHA-256 is fast." | Fast = brute-forceable. Use Argon2id/bcrypt. |

### H2 `## verify.sh — the gate`
2–4 lines: what it runs, that it's the user's to run in *their* repo, exits non-zero on high/critical. Points to §4 of this spec / the script's header.

### H2 `## Quick reference`
Compact cheat-sheet table: `Concern → tool/flag → one-liner` (gitleaks, semgrep, pip-audit, npm audit, govulncheck, Argon2id params, cookie flag string, CSP starter, CORS rule). The "I forget the exact flag" table.

### H2 `## See Also`
Links to sibling skills:
- Stack skills that reference this one (FastAPI / Next.js / Go / Flutter skills) — "they defer security to this skill".
- The agent/Claude-Code config security concern (separate; for `.claude/`, hooks, MCP, sandboxing).
- `risco-project-harness` (secrets land in `01-TOOLS/<PROVIDER>/.env`, gitignored — reinforce the never-in-repo rule).
- `references/*.md` enumerated with one-line "go here when…".

---

## 3. `references/` files — outline + key code

### `references/threat-modeling.md` (~220–280 lines)
PR-sized, lightweight STRIDE — not enterprise ceremony.
- **When to threat-model** (new boundary, new auth surface, money/PII) vs skip (copy-edit, internal refactor).
- **STRIDE in one table**: Spoofing/Tampering/Repudiation/Info-disclosure/DoS/Elevation → the question to ask + the typical control, mapped to this stack.
- **Trust boundaries & DFD, text-based**: how to draw a 5-box data-flow in a PR description (Client → Edge → API → DB → 3rd-party) and mark boundaries with `‖`. A worked ASCII DFD for a "user uploads an avatar" feature.
- **Abuse cases**: turn each user story into "…and an attacker does X". 6 worked examples (login → credential stuffing; upload → polyglot/SVG-XSS; search → enumeration/ReDoS; webhook → forgery/replay; password reset → token leak/host header; export → IDOR mass-extraction).
- **The PR-sized template** (copy-pasteable markdown block): Assets / Entry points / Trust boundaries / STRIDE hits / Decided controls / Residual risk. Plus a 1-paragraph "good enough" stopping rule.
- **Worked example end-to-end**: threat-model of a FastAPI "create invoice + download signed URL" feature, producing the filled template.

### `references/owasp-by-stack.md` (~420–500 lines) — the heaviest file
Every OWASP 2021 category, each with a **vulnerable→fixed** example in **Python (FastAPI)**, **Go**, and **TS (Next.js)**. Structure per category: 2-line "what/why exploitable" → 3 Bad/Good pairs.
1. **A01 Broken Access Control / IDOR & missing function-level authz** — ownership-scoped queries; Server Action re-auth; deny-by-default middleware (Go). Mass-assignment guard (Pydantic `extra="forbid"`, explicit field map, Go struct allowlist).
2. **A02 Cryptographic Failures** — TLS enforced; Argon2id hashing; AES-GCM/`cryptography` Fernet for data-at-rest; no MD5/SHA1 for passwords; secure random (`secrets`, `crypto.randomBytes`, `crypto/rand`) not `random`/`math/rand`.
3. **A03 Injection** — SQL (SQLAlchemy 2.0 bound params vs f-string; Go `database/sql` `$1`; Next.js Prisma/`postgres.js` tagged template vs concatenation); NoSQL (operator-injection in Mongo filters); **command injection** (`subprocess` list-args + `shell=False`; Go `exec.Command` no shell; never interpolate into shell); path traversal (canonicalize + base-dir check).
4. **A04 Insecure Design** — rate-limit + lockout on auth; idempotency keys on payments; signed/expiring URLs vs guessable IDs; secure-by-default flags. Example: password-reset done right (single-use, hashed, short-TTL token; host-header-independent link).
5. **A05 Security Misconfiguration** — debug off in prod (`FastAPI(debug=False)`, `NODE_ENV`, no Go panic stack to client); CORS allowlist; security headers; directory listing/verbose errors off; default creds.
6. **A06 Vulnerable & Outdated Components** — pin + lockfile; `pip-audit`/`npm audit`/`govulncheck` examples with output interpretation; override/replace a vulnerable transitive dep (npm `overrides`, `pip` constraints, `go mod` replace).
7. **A07 Identification & Auth Failures** — covered deeper in authn-authz, here: brute-force/credential-stuffing defense, weak session fixation (regenerate session id on login/privilege change), MFA hook.
8. **A08 Software & Data Integrity (supply chain)** — lockfile integrity, CI provenance, don't `curl | bash`, verify checksums, SRI for any third-party `<script>`; pointer to secrets-and-supply-chain.
9. **A09 Logging & Monitoring Failures** — log authz failures + auth events with `user_id`, no PII/secrets; structured logging (`structlog`/`slog`); alerting note.
10. **A10 SSRF** — user-controlled outbound fetch (FastAPI `httpx`, Go `http.Client`, Next.js `fetch` in route handler): BAD = fetch arbitrary user URL; GOOD = scheme+host allowlist, resolve DNS and block private/link-local/metadata ranges (169.254.169.254, 10/8, 127/8, ::1), disable redirects to internal, timeout. Full code per stack — this is the highest-value modern category.

### `references/authn-authz.md` (~280–360 lines)
- **Sessions vs JWT** trade-off matrix (revocation, scale, mobile, XSS/CSRF exposure) + "pick this when".
- **OAuth2 / OIDC**: authorization-code + PKCE flow explained; FastAPI as resource server verifying access tokens (JWKS fetch+cache, `aud`/`iss`/`exp` checks, algorithm pinning — never `alg: none`, never accept `HS*` when expecting `RS*`); Next.js with a provider (Auth.js v5 / `next-auth`) — server-side session, callbacks for authz.
- **RBAC vs ABAC**: role table + permission check vs attribute/policy check; FastAPI dependency `require_role("admin")` and a per-object ABAC check; Go middleware.
- **Token lifetimes & refresh**: short access (5–15 min), rotating refresh with reuse-detection, server-side revocation list; logout invalidates refresh.
- **Cookies done right**: `__Host-` prefix, `HttpOnly`, `Secure`, `SameSite`, full Set-Cookie examples in FastAPI/Next.js/Go.
- **CSRF defense**: when it's needed (cookie auth), double-submit token + Origin/Referer check; SameSite as defense-in-depth; bearer-token APIs don't need CSRF tokens but must not also accept the cookie.
- **Password hashing**: Argon2id params (`time_cost`, `memory_cost`, `parallelism`) with concrete numbers; verify + rehash-on-login-if-params-changed; bcrypt fallback.
- **MFA notes**: TOTP (`pyotp`) enrollment + verification, recovery codes (hashed), step-up auth for sensitive actions.
- Flutter note: store tokens in `flutter_secure_storage` (Keychain/Keystore), never `SharedPreferences`; cert-pinning pointer.

### `references/secrets-and-supply-chain.md` (~260–340 lines)
- **Env vs vaults**: 12-factor env for dev; secret manager (Vault / cloud SM / Doppler) for prod; how Next.js exposes only `NEXT_PUBLIC_*`; FastAPI `pydantic-settings` `BaseSettings`; Go `os.Getenv` + fail-fast on missing.
- **Never in repo**: `.gitignore` patterns, `gitleaks` (pre-commit hook + history scan + CI), what to do when a secret *is* committed (rotate first, then scrub history — order matters).
- **Rotation**: cadence, on-exposure runbook, invalidate sessions/tokens after rotation.
- **Dependency pinning & lockfiles**: `uv`/`pip-tools` + hashes, `package-lock.json`/`pnpm-lock.yaml` committed + `npm ci`, `go.sum` + `go mod verify`, `pubspec.lock`.
- **Audit tooling**: exact commands + how to read output + how to fix/override per ecosystem (pip-audit, npm audit / osv-scanner, govulncheck reachability advantage, dart).
- **SBOM & provenance**: `syft` to generate CycloneDX/SPDX; `cosign`/SLSA provenance one-paragraph; SRI for CDN scripts.
- **CI security gates** (the payoff): a GitHub Actions job running gitleaks + semgrep + the per-stack auditors, failing on high/critical — essentially `verify.sh` wrapped in CI, plus Dependabot/renovate config note.

---

## 4. `scripts/verify.sh` — exact contract

Header comment: usage, that it runs in the **user's project root**, what "pass" means.

Boilerplate: `#!/usr/bin/env bash` + `set -euo pipefail`; ANSI color helpers (`warn` yellow, `fail` red, `ok` green); a `FAILED=0` accumulator; `command -v` guard helper that prints a yellow "skip: <tool> not installed (install: <hint>)" and returns non-fatally.

**Detection + run order:**
1. **Secrets — `gitleaks`**: if present, `gitleaks detect --no-banner --redact` (and `gitleaks git` history if in a repo). Findings → `FAILED=1`. Missing → warn+skip.
2. **SAST — `semgrep`**: run **only if** a config exists (`.semgrep.yml`/`.semgrep/`/`semgrep.yml`) OR fall back to `--config=auto` guarded behind an env opt-in (`SECURE_CODING_SEMGREP_AUTO=1`) to avoid surprise network calls; severity ERROR → `FAILED=1`, WARNING → warn only. Missing → skip.
3. **Per-stack dependency audit — detect by manifest, run all that match:**
   - `pyproject.toml`/`requirements*.txt` → `pip-audit` (and `uv pip audit` if `uv` present). High/critical → `FAILED=1`.
   - `package.json` → prefer `osv-scanner` if present, else `npm audit --omit=dev --audit-level=high`. High/critical → `FAILED=1`. (Detect pnpm/yarn lockfile and use the matching audit when available.)
   - `go.mod` → `govulncheck ./...`. Any finding → `FAILED=1`.
   - `pubspec.yaml` → `dart pub outdated --mode=null-safety` informational + warn (no CVE feed → never fails the build).
4. **Summary**: print counts; `exit $FAILED` (non-zero only on real high/critical findings; skips never fail).

**Behavior rules (stated in header):** idempotent, no writes to the repo, no auto-fix, network calls only where the tool inherently needs them (and semgrep-auto gated behind opt-in). After authoring: `chmod +x scripts/verify.sh`. **Do NOT execute it in the skills repo** (not a target-stack project).

---

## 5. Quality differentiators (why this beats the ECC equivalents)

1. **Three-language vulnerable→fixed parity.** ECC's `django-security`/`laravel-security` cover one framework each and `security-review` is JS/Supabase-flavored. This skill gives a correct Bad/Good pair in **FastAPI, Go, and Next.js for every OWASP category** — the agent never has to translate.
2. **Current stack + pinned versions, not generic 2021 advice.** Pydantic v2 (`extra="forbid"`), SQLAlchemy 2.0 bound params, Next.js 15 App Router / Server Actions as public endpoints, React 19, Go 1.22 `ServeMux` + `slog`, Argon2id with concrete params, `__Host-` cookies, `osv-scanner`/`govulncheck`. ECC skills predate or omit these.
3. **Exploitability ranking baked in.** Imports the `security-bounty-hunter` in-scope/skip discipline so the agent reports reachable, user-controlled findings first instead of a flat checklist — fixes the "noise dump" failure mode of `security-review`'s 16-item checklist.
4. **SSRF and modern injection get first-class, full-code treatment.** ECC barely mentions SSRF; here A10 ships per-stack private-range/DNS-rebinding allowlist code — the category that actually pays out today.
5. **A real, stack-detecting `verify.sh` gate.** ECC `security-scan` shells out to one proprietary tool (`agentshield`, for `.claude/` config). This gate runs gitleaks + semgrep + the correct per-stack auditor on the *application* code, skips-not-fails on missing tools, and exits non-zero only on high/critical — runnable in CI as-is.
6. **PR-sized threat modeling that an agent will actually do.** A copy-paste STRIDE/DFD/abuse-case template with a "good enough" stopping rule and a fully worked example — versus ECC, which has no threat-modeling content at all.
7. **Sharp scope boundary.** Explicitly separates *application* security (this skill) from *agent/`.claude/` config* security (the ECC `the-security-guide` / `security-scan` space), so the two compose instead of overlapping — and points to the agent-security concern in See Also.
8. **House-style rationalizations→STOP table** tuned to the exact excuses an LLM makes mid-task ("it's behind auth", "the frontend validates", "transitive so it doesn't count"), matching `risco-project-harness` quality and giving the agent a self-interrupt.
