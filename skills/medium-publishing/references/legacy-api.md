# Legacy Medium API — pre-2025-token holders only

> **Closed to new integrations.** As of **2025-01-01** Medium issues no new integration tokens and accepts no new integrations. Only tokens minted before that date still authenticate. Do not attempt to register a new token — it will be refused. This reference is useful **only** if you already hold a pre-2025 token. For everyone else, the publishing path is the web editor + import tool (see `cross-post-and-canonical.md`).

## Auth

All requests use a Bearer integration token:

```
Authorization: Bearer <MEDIUM_INTEGRATION_TOKEN>
Content-Type: application/json
Accept: application/json
```

Base URL: `https://api.medium.com/v1`.

## Resolve the user id

You need your `userId` before posting. Get it from `/me`:

```bash
curl -s -H "Authorization: Bearer $MEDIUM_TOKEN" \
  https://api.medium.com/v1/me
```

```json
{
  "data": {
    "id": "5303d74c64f66366f00cb9b2a94f3251bf5",
    "username": "yourhandle",
    "name": "Your Name",
    "url": "https://medium.com/@yourhandle",
    "imageUrl": "https://cdn-images-1.medium.com/..."
  }
}
```

## Create a post on your profile

`POST /v1/users/{userId}/posts`

```bash
curl -s -X POST \
  -H "Authorization: Bearer $MEDIUM_TOKEN" \
  -H "Content-Type: application/json" \
  https://api.medium.com/v1/users/<userId>/posts \
  -d '{
    "title": "My title",
    "contentFormat": "markdown",
    "content": "# My title\n\nBody in markdown...",
    "canonicalUrl": "https://mysite.com/original-post",
    "tags": ["react", "javascript", "web-development"],
    "publishStatus": "draft",
    "license": "all-rights-reserved"
  }'
```

### Request fields

| Field | Type | Notes |
|---|---|---|
| `title` | string | Story title (also used for the SEO title) |
| `contentFormat` | string | `html` or `markdown`. Markdown here is more permissive than the web editor |
| `content` | string | The body, in the chosen format |
| `canonicalUrl` | string | Set to the **origin** URL for a cross-post — preserves your site's SEO credit |
| `tags` | string[] | Up to 5; extras are dropped |
| `publishStatus` | string | `public` \| `draft` \| `unlisted` |
| `license` | string | e.g. `all-rights-reserved`, `cc-40-by`, `public-domain` |
| `notifyFollowers` | boolean | Whether followers are notified |

### Response (success)

```json
{
  "data": {
    "id": "e6f36a",
    "title": "My title",
    "authorId": "5303d74c64f66366f00cb9b2a94f3251bf5",
    "url": "https://medium.com/@yourhandle/my-title-e6f36a",
    "canonicalUrl": "https://mysite.com/original-post",
    "publishStatus": "draft",
    "tags": ["react", "javascript", "web-development"],
    "license": "all-rights-reserved"
  }
}
```

## Create a post in a publication

`POST /v1/publications/{publicationId}/posts` — same body shape.

A `publishStatus: "draft"` under a publication remains **pending** an editor's action; it is not live until an editor publishes it, and you must be an accepted writer for that publication.

## Why automation plans usually fail in 2026

- New tokens: refused (closed since 2025-01-01).
- Make: the Medium app is legacy — only pre-existing connections work.
- n8n: Medium credentials still listed but cannot be newly configured.

If the user has no pre-2025 token, route them to the import-tool path. Do not build a pipeline that assumes a new token.
