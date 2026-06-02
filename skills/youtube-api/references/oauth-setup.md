# OAuth setup — GCP project to a refreshable YouTube token

YouTube uses **user OAuth 2.0**. A human owns the channel; your code holds a refresh token that acts on their behalf. There is no service-account path for owning/uploading to a channel.

## Step 1 — GCP project + enable both APIs

In the Google Cloud console:

1. Create or select a project.
2. APIs & Services → Library → enable **YouTube Data API v3**.
3. Enable **YouTube Analytics API** (same library). Forgetting this produces `403 ... API has not been used in project ... or it is disabled` the first time you call Analytics.

## Step 2 — OAuth consent screen → "In production"

1. APIs & Services → OAuth consent screen.
2. User type **External** (unless you are inside a Workspace org).
3. Add your scopes (see catalog below) and at least one test user *if* you stay in Testing.
4. **Publish the app — set status to "In production."**

Why this matters: while the app is in **Testing**, refresh tokens **expire after 7 days**. A cron that authed fine on Monday throws `invalid_grant` the next Monday. Publishing to production yields long-lived refresh tokens. For a personal script that never lists more than 100 users you do not need Google verification to flip to production; you only need verification for sensitive/restricted scopes shown to the public, but the token-lifetime fix applies the moment you publish.

## Step 3 — Create the OAuth client

| App type | When | Redirect |
| --- | --- | --- |
| **Desktop app** | Local/personal script, cron on your own box | loopback (`run_local_server`) — no redirect URI to register |
| **Web application** | Hosted service with a callback URL | register the **exact** redirect URI, e.g. `https://app.example.com/oauth/callback` |

Download the client JSON (`client_secret.json`). **Gitignore it.** It is not a public identifier — combined with a refresh token it is full channel access.

## Scope catalog (request least privilege)

| Scope | Grants |
| --- | --- |
| `https://www.googleapis.com/auth/youtube.upload` | upload videos only |
| `https://www.googleapis.com/auth/youtube.force-ssl` | manage: edit/update/delete videos, set thumbnails |
| `https://www.googleapis.com/auth/youtube` | full management (avoid unless you truly need it) |
| `https://www.googleapis.com/auth/yt-analytics.readonly` | read non-monetary analytics |
| `https://www.googleapis.com/auth/yt-analytics-monetary.readonly` | read revenue/monetary metrics |

For the upload + edit + stats loop, the right set is `youtube.upload` + `youtube.force-ssl` + `yt-analytics.readonly`. Add the monetary scope only when you actually pull `estimatedRevenue`.

## Token persistence + refresh

The credential object refreshes its short-lived access token automatically *as long as you persist the refresh token*. See SKILL.md §2 for the Python (`google_auth_oauthlib` + `Credentials.from_authorized_user_file`) and Node (`OAuth2` + the `tokens` event) snippets. Always write the refreshed credential back to disk/secret store; in Node, only the first consent returns `refresh_token`, so capture it then.

## Troubleshooting

| Error | Cause | Fix |
| --- | --- | --- |
| `invalid_grant` after ~7 days | App in Testing | Publish consent screen to "In production"; re-consent once |
| `unauthorized_client` | Wrong client type, or scope not added to consent screen | Match Desktop/Web to your flow; add the scope and re-consent |
| `access_denied` | User not added as test user (Testing mode) or denied consent | Add test user, or publish; re-run flow |
| `redirect_uri_mismatch` | Web client redirect not registered exactly | Register the literal callback URL, including scheme + path |
| `403 insufficient permissions` | Token lacks the scope the call needs | Add scope, delete stored token, re-consent |
