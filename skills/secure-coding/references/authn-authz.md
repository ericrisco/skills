# Authentication & authorization

Pick the session model, verify tokens correctly, authorize per-object, hash
with Argon2id, and store tokens where XSS can't reach them. Versions: FastAPI
≥0.115 / Python 3.12+, Auth.js v5 (`next-auth@5`) on Next.js 15, Go 1.22+,
Dart 3 / Flutter stable.

## Sessions vs JWT — pick this when

| Dimension | Server-side session | JWT (access + refresh) |
|---|---|---|
| Revocation | Instant — delete the server row | Needs a denylist; access token valid until `exp` |
| Scale | Shared store (Redis) or sticky | Stateless; nothing to look up |
| Mobile / native | Cookie handling is awkward | Natural — send as a bearer header |
| XSS exposure | `HttpOnly` cookie is unreadable by JS | `localStorage` is stealable by any XSS |
| CSRF | Needs a CSRF token (cookie auto-sent) | Bearer header is immune (not auto-sent) |

Bottom line: **server-side session is the default for first-party web.** Use
JWT for stateless/native clients — short access (5–15 min) + rotating refresh
with reuse detection + a revocation story.

## OAuth2 / OIDC

Use the authorization-code flow **with PKCE** (the code challenge defeats
interception of the authorization code). FastAPI as a **resource server**
verifies the access token: fetch and cache the JWKS, check `aud`/`iss`/`exp`,
and **pin the algorithm** — reject `alg:none` and reject HS256 when you expect
RS256 (an attacker who knows your public key could forge HS256 otherwise).

```python
# GOOD — verify with explicit algorithms, audience, issuer (PyJWT).
import jwt
from jwt import PyJWKClient
from fastapi import Depends, HTTPException, Request

_jwks = PyJWKClient("https://issuer.example.com/.well-known/jwks.json")

def get_current_user(request: Request) -> User:
    token = request.headers.get("authorization", "").removeprefix("Bearer ").strip()
    try:
        signing_key = _jwks.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],                 # pinned; rejects alg:none + HS*
            audience="api://my-service",
            issuer="https://issuer.example.com/",
            options={"require": ["exp", "iat", "aud", "iss"]},
        )
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="invalid token")
    return load_user(claims["sub"])
```

```ts
// GOOD (Next.js 15, Auth.js v5) — server-side session guard in a Route Handler.
import { auth } from "@/auth";

export async function GET() {
  const session = await auth();
  if (!session) return new Response("unauthorized", { status: 401 });
  return Response.json({ user: session.user.id });
}
```

## RBAC vs ABAC

RBAC checks a **role** ("is admin"); ABAC checks an **attribute/policy** ("is
the owner of this object", "is in the same org and the resource is not
locked"). Use RBAC for coarse function-level gates, ABAC for per-object access.

```python
# GOOD — RBAC dependency (function-level) raises 403 on role mismatch.
from fastapi import Depends, HTTPException

def require_role(role: str):
    def dep(user: User = Depends(get_current_user)) -> User:
        if role not in user.roles:
            raise HTTPException(status_code=403, detail="forbidden")
        return user
    return dep

@router.delete("/users/{uid}")
def delete_user(uid: int, _: User = Depends(require_role("admin"))) -> None:
    db.execute(delete(User).where(User.id == uid))

# GOOD — ABAC per-object check (ownership / attribute policy).
def can_edit(user: User, doc: Document) -> bool:
    return doc.owner_id == user.id or (
        "editor" in user.roles and doc.org_id == user.org_id and not doc.locked
    )
```

```go
// GOOD — Go middleware reads the role from the authenticated context.
func RequireRole(role string, next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        roles, _ := r.Context().Value(rolesKey).([]string)
        if !slices.Contains(roles, role) {
            http.Error(w, "forbidden", http.StatusForbidden)
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

## Token lifetimes & refresh rotation

Short access tokens (5–15 min). Rotating refresh tokens: each refresh issues a
new refresh token and invalidates the old one. **Reuse detection**: if an
already-rotated refresh token is presented again, it was replayed — revoke the
entire token family and force re-login. Logout invalidates the refresh token.

```python
# GOOD — rotate + detect reuse (server-side refresh store).
def refresh(presented_jti: str, family_id: str) -> Tokens:
    rec = store.get(presented_jti)
    if rec is None or rec.revoked:
        # Replay of a rotated/revoked token -> kill the whole family.
        store.revoke_family(family_id)
        raise HTTPException(status_code=401, detail="reuse detected")
    store.revoke(presented_jti)                       # old token is now spent
    new_refresh = store.issue(family_id=family_id)    # rotate
    return Tokens(access=mint_access(rec.user_id), refresh=new_refresh)
```

## Cookies done right

Canonical flags: `HttpOnly; Secure; SameSite=Lax` (use `Strict` for sensitive
actions), the `__Host-` prefix (forces `Secure`, `Path=/`, and no `Domain` —
locks the cookie to the exact host), scoped `Path=/`, no `Domain` attribute.

```python
# FastAPI
response.set_cookie(
    key="__Host-session", value=sid,
    httponly=True, secure=True, samesite="lax", path="/",
)
```

```ts
// Next.js 15 — Route Handler or Server Action.
import { cookies } from "next/headers";
(await cookies()).set("__Host-session", sid, {
  httpOnly: true, secure: true, sameSite: "lax", path: "/",
});
```

```go
// Go
http.SetCookie(w, &http.Cookie{
    Name: "__Host-session", Value: sid,
    HttpOnly: true, Secure: true, SameSite: http.SameSiteLaxMode, Path: "/",
})
```

BAD: storing the token in `localStorage` — readable by any XSS payload.

## CSRF defense

Needed for **cookie-authenticated, state-changing** requests (the browser sends
the cookie automatically). Use a double-submit token plus an Origin/Referer
check. SameSite is defense-in-depth, **not** sufficient alone. Bearer-token APIs
don't need CSRF tokens — **but must not also accept the auth cookie**, or
they're back in scope.

```python
# GOOD — double-submit: cookie value must equal the X-CSRF-Token header.
import hmac
def verify_csrf(request: Request):
    cookie = request.cookies.get("csrf")
    header = request.headers.get("x-csrf-token", "")
    if not cookie or not hmac.compare_digest(cookie, header):
        raise HTTPException(status_code=403, detail="csrf")
    origin = request.headers.get("origin", "")
    if origin and origin not in settings.allowed_origins:
        raise HTTPException(status_code=403, detail="bad origin")
```

## Password hashing — Argon2id

Concrete params (tune `memory_cost` up until a hash takes ~0.5s on prod
hardware): `time_cost=3, memory_cost=65536 (64 MiB), parallelism=4`. Verify on
login and rehash transparently when params change. bcrypt with `cost>=12` is an
acceptable fallback. Never SHA-256/MD5.

```python
# GOOD — argon2-cffi: hash, verify, transparent rehash.
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

ph = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=4)

def verify_login(stored_hash: str, password: str) -> bool:
    try:
        ph.verify(stored_hash, password)
    except VerifyMismatchError:
        return False
    if ph.check_needs_rehash(stored_hash):
        save_new_hash(ph.hash(password))   # upgrade params on successful login
    return True
```

Go note: `argon2.IDKey(password, salt, 3, 64*1024, 4, 32)` from
`golang.org/x/crypto/argon2` produces the equivalent Argon2id key.

## MFA

TOTP enrollment + verification with `pyotp`; store recovery codes **hashed**
(same as passwords); require step-up auth (re-verify the second factor) for
sensitive actions like changing email or disabling MFA.

```python
# GOOD — TOTP enroll + verify (pyotp).
import pyotp
secret = pyotp.random_base32()                 # store encrypted per user
uri = pyotp.totp.TOTP(secret).provisioning_uri(name=user.email, issuer_name="MyApp")
# verify with a small window to tolerate clock drift:
ok = pyotp.TOTP(secret).verify(submitted_code, valid_window=1)
```

## Flutter / Dart 3 note

Store tokens in `flutter_secure_storage` (backed by iOS Keychain / Android
Keystore) — **never** `SharedPreferences`, which is plaintext on disk.

```dart
// GOOD — secure storage, not SharedPreferences.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _storage = const FlutterSecureStorage();
Future<void> saveToken(String token) =>
    _storage.write(key: 'refresh_token', value: token);
Future<String?> readToken() => _storage.read(key: 'refresh_token');
```

For high-value apps, add TLS certificate pinning (e.g. via a pinned
`SecurityContext` / `badCertificateCallback` on the HTTP client).

---

See `owasp-by-stack.md` (A01 access control, A07 auth failures) for the
vulnerable→fixed handler code, and `secrets-and-supply-chain.md` for where
signing keys and session secrets are stored.
