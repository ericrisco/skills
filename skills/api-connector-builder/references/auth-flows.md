# Auth flows — per-flow walkthroughs

OAuth 2.1 baseline (oauth.net/2.1, accessed 2026-06-02):

- **PKCE is mandatory** for every authorization-code client, public and
  confidential alike.
- **Implicit grant and Resource-Owner-Password grant are removed.** If a vendor's
  docs still show them, do not use them — pick Auth-Code + PKCE or Client
  Credentials instead.
- **Bearer tokens must not travel in query strings.** Header only. Query strings
  leak into access logs, browser history, and `Referer` headers.

## API key in header

Simplest scheme. The vendor issues a static key; you send it on every request.
Store it in env, never source. There is no refresh — rotate manually when it
leaks or on a schedule.

```python
import os, httpx
KEY = os.environ["VENDOR_API_KEY"]
client = httpx.Client(base_url="https://api.vendor.com/v1",
                      headers={"X-API-Key": KEY})  # header name per vendor docs
```

Some vendors want `Authorization: Bearer <key>` instead of a custom header — read
the docs; do not guess the header name.

## Bearer static token (personal access token)

Treat exactly like an API key: long-lived, env-stored, no refresh. The only
difference is the standard `Authorization: Bearer <token>` header.

```typescript
const TOKEN = process.env.VENDOR_PAT!;
const headers = { Authorization: `Bearer ${TOKEN}` };
```

## OAuth2 Client Credentials (machine-to-machine)

No end user is involved — your service authenticates as itself. You hold a
`client_id` + `client_secret`, exchange them for a short-lived access token at the
token endpoint, cache it until it expires, and re-mint on expiry or a 401.

```python
import os, time, httpx

_cache = {"token": None, "exp": 0.0}

def access_token():
    if _cache["token"] and time.time() < _cache["exp"] - 30:  # 30s safety margin
        return _cache["token"]
    r = httpx.post("https://auth.vendor.com/oauth/token", data={
        "grant_type": "client_credentials",
        "client_id": os.environ["VENDOR_CLIENT_ID"],
        "client_secret": os.environ["VENDOR_CLIENT_SECRET"],
        "scope": "read:items",
    }, timeout=10.0)
    r.raise_for_status()
    body = r.json()
    _cache.update(token=body["access_token"], exp=time.time() + body["expires_in"])
    return _cache["token"]
```

## OAuth2 Authorization Code + PKCE (acting for a user)

The user-facing flow. PKCE prevents an intercepted authorization code from being
redeemed by an attacker.

1. Generate a `code_verifier` (43–128 chars, random) and its
   `code_challenge = base64url(sha256(verifier))`.
2. Redirect the user to the authorize endpoint with
   `response_type=code`, `code_challenge`, `code_challenge_method=S256`,
   `redirect_uri`, `scope`, and a random `state`.
3. On callback, verify `state`, then POST `grant_type=authorization_code` with
   the `code` **and the original `code_verifier`** to the token endpoint.
4. Store the resulting refresh token securely; use the access token for calls.

```python
import base64, hashlib, os
verifier = base64.urlsafe_b64encode(os.urandom(64)).rstrip(b"=").decode()
challenge = base64.urlsafe_b64encode(
    hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
# -> send `challenge` (S256) on /authorize, keep `verifier` for the token exchange
```

### Refresh-token rotation (RFC 9700 / OAuth 2.0 Security BCP)

Refresh tokens for public clients must be **sender-constrained or one-time-use**:
every refresh returns a *new* refresh token and invalidates the old one. If the
old token is ever replayed, the server detects the reuse and revokes the whole
chain (a sign of theft). Persist the latest refresh token atomically — a crash
between "got new token" and "saved it" locks you out.

```python
def refresh(refresh_token: str) -> dict:
    r = httpx.post("https://auth.vendor.com/oauth/token", data={
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": os.environ["VENDOR_CLIENT_ID"],
    }, timeout=10.0)
    r.raise_for_status()
    body = r.json()
    save_refresh_token(body["refresh_token"])  # ROTATE: store the new one, drop old
    return body
```

Keep access tokens short-lived (minutes). Never log a raw token — log a partial
(`tok…3f9c`) or a hash if you must correlate across services.

## Device flow (input-constrained devices)

For CLIs, TVs, and devices with no browser. Request a device + user code, show the
user a URL and code to enter on another device, then **poll** the token endpoint
until they approve (respect the `interval`; back off on `slow_down`). Once
granted, you receive access + refresh tokens and rotate them exactly like the
auth-code flow above.

## DPoP (sender-constraining, brief)

DPoP (Demonstrating Proof-of-Possession) binds a token to a client-held key: each
request carries a signed `DPoP` header proving you hold the private key, so a
stolen bearer token alone is useless. If a vendor offers DPoP-bound access tokens,
prefer them for high-value scopes — it is the practical way to satisfy the
"sender-constrained" requirement without mTLS infrastructure.

## Storage rules (all flows)

- Secrets in env vars or a secret manager — never in source, never in
  `localStorage` (XSS-readable) for anything long-lived.
- One credential set per vendor per environment; never share a prod key into dev.
- Rotate on any suspected leak; the flows above make rotation cheap by design.
