# OWASP Top 10 (2021) — vulnerable→fixed per stack

Each category opens with a 2-line "what / why exploitable", then Bad/Good
pairs. Where a category is most acute in one language we lead with that one but
always give at least Python + one other. A01, A03, and A10 get all three
(Python / Go / TS) because they are the highest-paying, most stack-agnostic
classes. Versions assumed: Python 3.12+, Pydantic v2, SQLAlchemy 2.0,
FastAPI ≥0.115, Next.js 15 App Router / React 19, Zod ≥3.23, Go 1.22+
(`http.ServeMux`, `log/slog`), PostgreSQL 16.

## A01 — Broken Access Control / IDOR

What: a row or function is reachable by a caller who should not see it.
Why exploitable: the id is in the URL/body and the server trusts authentication
("they're logged in") instead of checking authorization ("do they own *this*").

### Python (FastAPI + SQLAlchemy 2.0)

```python
# BAD — any authenticated user can read any document by id.
@router.get("/documents/{doc_id}")
def get_doc(doc_id: int, db: Session = Depends(get_db)):
    return db.get(Document, doc_id)

# GOOD — ownership-scoped query; 404 (not 403) on miss to prevent enumeration.
from fastapi import Depends, HTTPException
from sqlalchemy import select

@router.get("/documents/{doc_id}")
def get_doc(
    doc_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DocumentOut:
    doc = db.execute(
        select(Document).where(
            Document.id == doc_id,
            Document.owner_id == user.id,
        )
    ).scalar_one_or_none()
    if doc is None:
        raise HTTPException(status_code=404, detail="Not found")
    return DocumentOut.model_validate(doc)
```

### Go (1.22 `ServeMux`, `slog`)

```go
// BAD — path id goes straight to the query; no ownership check.
mux.HandleFunc("GET /documents/{id}", func(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")
    var body string
    _ = db.QueryRowContext(r.Context(), "SELECT body FROM documents WHERE id=$1", id).Scan(&body)
    _, _ = w.Write([]byte(body))   // returned to ANY caller
})

// GOOD — userID from the authenticated context; scoped query; 404 on miss.
mux.HandleFunc("GET /documents/{id}", func(w http.ResponseWriter, r *http.Request) {
    userID, ok := r.Context().Value(userKey).(int64)
    if !ok {
        http.Error(w, "unauthorized", http.StatusUnauthorized)
        return
    }
    id := r.PathValue("id")
    var body string
    err := db.QueryRowContext(r.Context(),
        "SELECT body FROM documents WHERE id=$1 AND owner_id=$2", id, userID,
    ).Scan(&body)
    if err == sql.ErrNoRows {
        slog.Warn("authz_miss", "user", userID, "doc", id)
        http.Error(w, "not found", http.StatusNotFound)
        return
    }
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }
    _, _ = w.Write([]byte(body))
})
```

### TS (Next.js 15 App Router — Route Handler / Server Action)

```ts
// BAD — returns the row from the id, assuming a session exists.
// Next.js 15: params is a Promise — await it (sync access is a removed-shim path).
export async function GET(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const doc = await db.document.findUnique({ where: { id } });
  return Response.json(doc);
}

// GOOD — auth() guard + ownership scope + notFound() on miss.
import { auth } from "@/auth";
import { notFound } from "next/navigation";

export async function GET(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const session = await auth();
  if (!session) notFound();
  const doc = await db.document.findFirst({
    where: { id, ownerId: session.user.id },
  });
  if (!doc) notFound();
  return Response.json(doc);
}
```

> **Server Actions are public POST endpoints.** Re-authorize inside the action
> body on every call. Conditionally rendering the button or hiding the form is
> UX only — an attacker calls the action directly.

### Mass-assignment guard

```python
# Pydantic v2 — reject unknown fields; never bind owner_id/role from the body.
from pydantic import BaseModel, ConfigDict

class DocumentCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str
    body: str
    # owner_id is set from current_user server-side, never from the request.
```

```go
// Go — decode into an allowlist struct that has no owner_id / role field.
type docCreate struct {
    Title string `json:"title"`
    Body  string `json:"body"`
}
dec := json.NewDecoder(r.Body)
dec.DisallowUnknownFields()
var in docCreate
if err := dec.Decode(&in); err != nil { /* 400 */ }
```

```ts
// Zod — .strict() rejects extra keys; map only the allowed ones.
const DocCreate = z.object({ title: z.string(), body: z.string() }).strict();
const data = DocCreate.parse(await req.json());
await db.document.create({ data: { ...data, ownerId: session.user.id } });
```

## A02 — Cryptographic Failures

What: passwords or data at rest protected with fast/broken primitives or
predictable randomness. Why exploitable: MD5/SHA-1 hashes crack offline at
billions/sec; `random`/`Math.random` tokens are guessable.

```python
# BAD — fast hash, trivially brute-forced; predictable token.
import hashlib, random
pw_hash = hashlib.sha256(password.encode()).hexdigest()
token = str(random.randint(0, 10**9))

# GOOD — Argon2id for passwords; CSPRNG for tokens.
from argon2 import PasswordHasher
import secrets

ph = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=4)  # 64 MiB
pw_hash = ph.hash(password)
token = secrets.token_urlsafe(32)
```

```go
// GOOD (Go) — Argon2id and crypto/rand; never math/rand for secrets.
import ("crypto/rand"; "golang.org/x/crypto/argon2")
salt := make([]byte, 16); _, _ = rand.Read(salt)
key := argon2.IDKey([]byte(password), salt, 3, 64*1024, 4, 32)
```

```ts
// GOOD (TS) — crypto.randomBytes, never Math.random for tokens.
import { randomBytes } from "node:crypto";
const token = randomBytes(32).toString("base64url");
```

Data at rest: AES-GCM (an AEAD with integrity), e.g. `cryptography`'s
`AESGCM`/`Fernet`. Enforce TLS everywhere; never MD5/SHA-1 for passwords.

## A03 — Injection

What: user input is concatenated into a query, shell command, or path. Why
exploitable: the parser can't tell data from code — `'; DROP TABLE` /
`$(rm -rf)` / `../../etc/passwd` all execute.

### SQL — parameterize, never interpolate

```python
# BAD — f-string SQL is injectable.
db.execute(text(f"SELECT * FROM users WHERE email = '{email}'"))
# GOOD — SQLAlchemy 2.0 bound parameters.
from sqlalchemy import select
db.execute(select(User).where(User.email == email))
```

```go
// BAD — Sprintf into the query string.
db.QueryContext(ctx, fmt.Sprintf("SELECT id FROM users WHERE email='%s'", email))
// GOOD — placeholders; the driver binds values.
db.QueryContext(ctx, "SELECT id FROM users WHERE email=$1", email)
```

```ts
// BAD — string concatenation in raw SQL.
sql.unsafe(`SELECT * FROM users WHERE email = '${email}'`);
// GOOD — postgres.js tagged template parameterizes interpolations.
await sql`SELECT * FROM users WHERE email = ${email}`;
// (Prisma client methods are parameterized; avoid $queryRawUnsafe.)
```

### Command injection — no shell, pass args as a list

```python
# BAD — shell=True with interpolation runs arbitrary commands.
subprocess.run(f"convert {infile} {outfile}", shell=True)
# GOOD — argument vector, no shell.
subprocess.run(["convert", infile, outfile], shell=False, check=True)
```

```go
// BAD — sh -c with a concatenated string.
exec.CommandContext(ctx, "sh", "-c", "convert "+infile+" "+outfile)
// GOOD — program + explicit args, no shell.
exec.CommandContext(ctx, "convert", infile, outfile)
```

Never build a shell string from user input.

### Path traversal — canonicalize + require base-dir containment

```python
# BAD — user name escapes the base dir via ../.
open(base_dir + "/" + user_name)
# GOOD — resolve and require containment in base.
from pathlib import Path
base = Path(base_dir).resolve()
target = (base / user_name).resolve()
if not target.is_relative_to(base):
    raise ValueError("path traversal")
target.open("rb")
```

```go
// GOOD (Go) — Clean + prefix check against the resolved base.
clean := filepath.Join(base, name) // Join already applies filepath.Clean
if !strings.HasPrefix(clean, filepath.Clean(base)+string(os.PathSeparator)) {
    http.Error(w, "bad path", http.StatusBadRequest)
    return
}
// CAVEAT: filepath.Clean is purely lexical — a symlink inside base can still
// point outside it. If the tree may contain attacker-controlled symlinks,
// resolve them too: real, err := filepath.EvalSymlinks(clean); then re-run the
// prefix check on `real` against an EvalSymlinks'd base. On Go 1.24+,
// os.Root / os.OpenRoot confines opens to the directory and refuses escapes.
```

### NoSQL / operator injection (Mongo-style)

```ts
// BAD — { email: req.body.email } where email is { "$ne": null } returns all.
// GOOD — reject object-typed values and $-prefixed keys before querying.
function assertScalar(v: unknown): asserts v is string | number {
  if (typeof v === "object" || v === null) throw new Error("bad filter value");
}
```

## A04 — Insecure Design

What: the feature is missing a control by design, not by bug. Why exploitable:
brute force, double-charge replays, and id enumeration need no "vulnerability",
just usage. Controls: rate-limit + lockout on auth (A07); idempotency keys on
payment writes (a `UNIQUE` constraint on `idempotency_key` turns a replayed POST
into a no-op); signed/expiring URLs instead of guessable sequential ids.

**Password reset done right** (the flagship): single-use, store the **hash** of
the token, short TTL, link built from a configured base URL.

```python
# GOOD — issue: store only the hash; email a link from a configured base URL.
import hashlib, secrets
from datetime import datetime, timedelta, timezone

raw = secrets.token_urlsafe(32)
db.add(PasswordReset(
    user_id=user.id,
    token_hash=hashlib.sha256(raw.encode()).hexdigest(),
    expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
    used=False,
))
db.commit()
link = f"{settings.public_base_url}/reset?token={raw}"  # NOT request.headers["host"]
send_email(user.email, link)
# On redeem: look up by sha256(token), require not used and not expired,
# set used=True in the same transaction, then invalidate the user's sessions.
```

## A05 — Security Misconfiguration

What: debug mode, verbose errors, default creds, or permissive CORS shipped to
prod. Why exploitable: stack traces leak internals; `*`+credentials and open
admin panels hand attackers a foothold.

```python
# GOOD — app config and a panic-equivalent: never leak internals to the client.
app = FastAPI(debug=False)  # no --reload in prod

@app.exception_handler(Exception)
async def unhandled(request, exc):
    logger.exception("unhandled", path=request.url.path)  # detail to logs
    return JSONResponse(status_code=500, content={"detail": "Internal error"})
```

```go
// GOOD — recover from panics; log detail, return a generic 500.
defer func() {
    if rec := recover(); rec != nil {
        slog.Error("panic", "err", rec)
        http.Error(w, "internal error", http.StatusInternalServerError)
    }
}()
```

Also: `NODE_ENV=production`; CORS allowlist (never `*` with credentials);
directory listing off; no default creds; security headers present (see the
headers block in `SKILL.md`).

## A06 — Vulnerable & Outdated Components

What: a dependency (often transitive) has a known CVE. Why exploitable: the
vulnerable code ships in your bundle whether you call it directly or not.

```bash
# Per ecosystem. Read each line as package@version -> advisory id + fixed-in;
# fix = upgrade to fixed-in, or override/replace if it's transitive.
pip-audit
npm audit --omit=dev --audit-level=high
osv-scanner --lockfile=pnpm-lock.yaml
govulncheck ./...   # reports ONLY vulns your code actually calls (reachability)
```

Override a vulnerable **transitive** dependency: npm `"overrides": {"lib":"1.2.4"}`
in `package.json`; pip a `constraints.txt` pin (`pip install -r req.txt -c
constraints.txt`); Go `replace lib v1.2.3 => lib v1.2.4` in `go.mod`. Full
commands, "how to read", and SBOM/provenance live in
`secrets-and-supply-chain.md`.

## A07 — Identification & Authentication Failures

What: weak login flow — no brute-force defense, session id not rotated, error
messages reveal which accounts exist. Why exploitable: credential stuffing and
session fixation need only a login form.

- **Brute-force/credential-stuffing defense:** per-IP + per-identity rate limit,
  lockout after N failures, generic `"invalid credentials"` (no user
  enumeration — same message and timing whether or not the email exists).
- **Session fixation:** regenerate the session id on login and on any privilege
  change, so a pre-auth id an attacker planted can't be reused.

```python
# GOOD (FastAPI + starsessions/itsdangerous-style store): rotate on login.
async def login(request: Request, creds: LoginIn) -> None:
    user = authenticate(creds.email, creds.password)   # raises 401 on mismatch
    await request.session.regenerate_id()   # new server-side session id
    request.session["uid"] = user.id
```

```go
// GOOD (Go, gorilla/sessions): rotate the session id at login.
session.Options.MaxAge = 0           // expire the old id
_ = session.Save(r, w)               // issue a fresh id, then set uid
session.Values["uid"] = userID
_ = session.Save(r, w)
```

MFA enrollment/verification lives in `authn-authz.md`.

## A08 — Software & Data Integrity (supply chain)

What: code or data is trusted without verifying its origin. Why exploitable: a
poisoned dependency, unsigned binary, or CDN compromise runs in your context.

- **Lockfile integrity:** `npm ci` / `pnpm i --frozen-lockfile`; `go mod verify`
  confirms module checksums against `go.sum`.
- **No `curl … | bash`:** download, `sha256sum -c`, then run. SRI for any
  third-party `<script>` so the browser refuses a tampered file.

```html
<!-- GOOD — Subresource Integrity pins the exact file hash. -->
<script src="https://cdn.example.com/lib.js"
        integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC"
        crossorigin="anonymous"></script>
```

## A09 — Logging & Monitoring Failures

What: security events aren't logged, or logs leak PII/secrets. Why exploitable:
breaches go undetected, and the logs themselves become the leak.

```python
# GOOD (structlog) — log the event keyed on user_id; redact secrets; no bodies.
import structlog
log = structlog.get_logger()
log.warning("authz_miss", user_id=user.id, object="document", object_id=doc_id)
log.info("login_fail", user_id=user.id)   # never log password or full email
```

```go
// GOOD (slog) — structured fields, user_id not PII.
slog.Warn("authz_miss", "user_id", userID, "object", "document", "id", id)
```

Log auth events + authz failures with `user_id` (not PII); never log auth-route
bodies; alert on spikes of `authz_miss` / `login_fail`.

## A10 — SSRF (Server-Side Request Forgery)

What: the server fetches a user-supplied URL. Why exploitable: the attacker
points it at internal services or the cloud metadata endpoint to steal
credentials. Highest-value modern category — block by IP, not just hostname.
Forbidden ranges: `169.254.169.254` (metadata), `10.0.0.0/8`, `172.16.0.0/12`,
`192.168.0.0/16`, `127.0.0.0/8`, `::1`, `fc00::/7`, `fe80::/10`.

### Python (`httpx`)

```python
# BAD — fetches whatever URL the user gave us:  r = httpx.get(user_url)
# GOOD — https-only, resolve DNS, reject EVERY returned IP, then DIAL the
# validated IP literal so DNS cannot rebind between check and connect.
# `sni_hostname` keeps TLS/SNI + certificate validation bound to the real host.
import ipaddress, socket, httpx
from urllib.parse import urlparse

def _blocked(ip) -> bool:  # ip: IPv4Address | IPv6Address
    return (ip.is_private or ip.is_loopback or ip.is_link_local
            or ip.is_reserved or ip.is_multicast or ip.is_unspecified)

def safe_get(user_url: str) -> httpx.Response:
    u = urlparse(user_url)
    if u.scheme != "https" or not u.hostname:
        raise ValueError("https URL required")
    port = u.port or 443
    # Resolve once and validate ALL returned addresses (a multi-record answer
    # can pair a safe first record with a private second one).
    infos = socket.getaddrinfo(u.hostname, port, proto=socket.IPPROTO_TCP)
    addrs = [ipaddress.ip_address(info[4][0]) for info in infos]
    if not addrs or any(_blocked(ip) for ip in addrs):
        raise ValueError("blocked address")
    pinned = addrs[0]  # a validated address from the set we just checked
    bracket = f"[{pinned}]" if pinned.version == 6 else str(pinned)
    with httpx.Client(timeout=5.0, follow_redirects=False) as c:
        # Connect to the validated IP literal; pin SNI + Host to the real
        # hostname so certificate verification is performed against it.
        return c.get(
            f"https://{bracket}:{port}{u.path or '/'}",
            headers={"Host": u.hostname},
            extensions={"sni_hostname": u.hostname},
        )
```

### Go (`http.Client`)

```go
// GOOD — DialContext re-checks the IP actually dialed; redirects blocked; timeout.
func blockPrivate(ip net.IP) bool {
    return ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() ||
        ip.Equal(net.ParseIP("169.254.169.254"))
}
client := &http.Client{
    Timeout: 5 * time.Second,
    CheckRedirect: func(*http.Request, []*http.Request) error {
        return http.ErrUseLastResponse // do not follow redirects
    },
    Transport: &http.Transport{
        DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
            host, port, _ := net.SplitHostPort(addr)
            ips, err := net.DefaultResolver.LookupIP(ctx, "ip", host)
            if err != nil { return nil, err }
            for _, ip := range ips {
                if blockPrivate(ip) { return nil, fmt.Errorf("blocked address") }
            }
            return (&net.Dialer{}).DialContext(ctx, network, net.JoinHostPort(ips[0].String(), port))
        },
    },
}
```

### TS (Route Handler `fetch`)

```ts
// GOOD — https-only allowlist, no redirects, hard timeout.
import { lookup } from "node:dns/promises";
import net from "node:net";

const ALLOWED_HOSTS = new Set(["api.partner.com"]);

export async function fetchUserUrl(raw: string): Promise<Response> {
  const u = new URL(raw);                       // throws on malformed input
  if (u.protocol !== "https:") throw new Error("https required");
  if (!ALLOWED_HOSTS.has(u.hostname)) throw new Error("host not allowed");
  // Validate EVERY resolved address, not just the first record.
  const addrs = await lookup(u.hostname, { all: true });
  if (addrs.length === 0) throw new Error("no address");
  for (const { address } of addrs) {
    if (net.isIP(address) && isPrivate(address)) throw new Error("blocked address");
  }
  // NOTE: undici/fetch re-resolves DNS at connect time, so this check is
  // TOCTOU-racy on its own. For untrusted hosts, pin via a custom undici
  // Agent whose `connect` re-validates the dialed IP (mirror the Go dialer).
  return fetch(u, { redirect: "error", signal: AbortSignal.timeout(5000) });
}
```

**DNS-rebinding caveat:** validating the pre-resolution IP is not enough — the
hostname can resolve to a safe IP at check time and a private IP at connect
time. Validate the IP you actually **dial**: the Python example connects to the
validated IP literal (with `sni_hostname` so TLS still verifies the real host),
and the Go example re-checks every IP inside `DialContext`. The TS `fetch`
example checks all records but cannot pin the dialed IP without a custom undici
`Agent` — for untrusted hosts, supply one whose `connect` re-validates the IP,
mirroring the Go dialer.

---

## Index — category → fastest fix

A01 ownership-scoped query + 404 · A02 Argon2id + CSPRNG · A03 parameterize /
arg-list / canonicalize · A04 idempotency key + rate limit · A05 `debug=False`
+ CORS allowlist · A06 audit + override transitive · A07 lockout + rotate
session id · A08 `npm ci`/`go mod verify` + SRI · A09 structured log on
`user_id` · A10 https-only + IP allowlist + pin dialed IP. The "fastest fix per
category" table and the flagship Good/Bad blocks live in `SKILL.md`.
