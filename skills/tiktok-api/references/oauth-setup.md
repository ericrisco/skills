# OAuth v2 setup, scopes, audit gate, and token lifecycle

Everything needed to go from "no app" to "an authed, self-refreshing TikTok client."
There is **no official TikTok SDK** — all calls are raw REST.

## 1. Register the app and enable products

1. Create a developer app in the TikTok for Developers portal.
2. Add **products** the job needs — each is a separate toggle:
   - **Login Kit** — the OAuth v2 flow (required for everything).
   - **Content Posting API** — to publish/upload video.
   - **Display API** — to read your own profile + basic video counters.
3. **Business insights are separate.** Watch time, completion, and impression sources
   come from the **TikTok API for Business**, enabled through the business portal /
   business account access — not the standard developer-app product toggles.
4. Set an exact **redirect URI** (must match byte-for-byte at authorize + exchange time).

## 2. The three gates (the part that surprises people)

| Gate | Controls | How you pass it |
| --- | --- | --- |
| Content Posting **audit** | Public posting for arbitrary users | Submit app for review; until then **SELF_ONLY + test users only** |
| Display **scope** | Reading your own video counts | Request `video.list`; user authorizes it |
| Business **portal** access | Watch time / completion / impression sources | Enable business account access separately |

Unaudited apps can only post **privately** (`privacy_level: "SELF_ONLY"`) and only to a
limited set of registered test users. This is the #1 "works in dev, breaks in prod"
failure — public posting for real users requires the audit to pass first.

## 3. Scope catalog

| Scope | Grants |
| --- | --- |
| `user.info.basic` | open_id, display name, avatar |
| `video.list` | Read your own videos + basic counters (Display API) |
| `video.publish` | Direct Post to the public feed (audit-gated) |
| `video.upload` | Upload to drafts/inbox for the user to finalize |

Request least privilege. A read-only daily-pull cron needs only `video.list`
(+ `user.info.basic`); add `video.publish` only on the path that actually posts.

## 4. Authorize → exchange

Send the user to the authorize URL:

```text
https://www.tiktok.com/v2/auth/authorize/
  ?client_key=<CLIENT_KEY>
  &scope=video.publish,video.list,user.info.basic
  &response_type=code
  &redirect_uri=<EXACT_REDIRECT_URI>
  &state=<csrf_token>
  &code_challenge=<S256>&code_challenge_method=S256   # PKCE recommended
```

Exchange the returned `code` for tokens:

```python
import requests, os
r = requests.post("https://open.tiktokapis.com/v2/oauth/token/", data={
    "client_key": os.environ["TIKTOK_CLIENT_KEY"],
    "client_secret": os.environ["TIKTOK_CLIENT_SECRET"],
    "grant_type": "authorization_code",
    "code": code,
    "redirect_uri": REDIRECT_URI,
    "code_verifier": pkce_verifier,        # if you used PKCE
}, headers={"Content-Type": "application/x-www-form-urlencoded"})
tok = r.json()
# { access_token, expires_in: 86400, refresh_token, refresh_expires_in: 31536000, open_id, scope }
```

## 5. Token lifecycle — the load-bearing rule

- **Access token: 24 hours** (`expires_in: 86400`).
- **Refresh token: 365 days** (`refresh_expires_in: 31536000`); refresh needs no
  user re-consent and **rotates** the refresh token each time.

Therefore:

- A daily cron MUST refresh the access token **every run** (see the `access_token()`
  helper in SKILL.md §2) and **persist the new refresh_token** returned each time.
- An account left idle past **365 days** silently dies at the refresh-token boundary —
  the only fix is re-running the OAuth consent flow.

## 6. PULL_FROM_URL domain verification

`PULL_FROM_URL` publishing requires the source domain or URL-prefix to be verified in
the portal before any init succeeds:

- Add the domain/URL-prefix in the portal; complete **DNS TXT signature** or
  **URL-prefix** verification.
- The source URL must be **HTTPS**, **no redirects**, and download within the
  **1-hour** timeout.
- An unverified domain returns `url_ownership_unverified` on every init.

## 7. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `scope_not_authorized` | Scope not granted or app not approved for it | Re-consent with the scope; check app approval |
| `access_token_invalid` | 24h access token expired or wrong token | Refresh before the call; never hardcode |
| Only `SELF_ONLY` posts succeed | App not audited | Submit for audit; use test users meanwhile |
| `url_ownership_unverified` | PULL_FROM_URL domain not verified | Verify domain/URL-prefix (DNS TXT) |
| Refresh returns an error after long idle | 365-day refresh token expired | Re-run the authorize → exchange flow |
| Redirect mismatch at exchange | `redirect_uri` differs from the registered one | Match it byte-for-byte |
