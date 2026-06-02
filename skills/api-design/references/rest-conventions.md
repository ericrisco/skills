# REST conventions

Depth behind the SKILL. Framework-neutral. Adopt as house style and keep it consistent across every endpoint.

## Status-code map — when each

| Code | Meaning | Use when |
|---|---|---|
| 200 OK | success + body | GET, or a PUT/PATCH that returns the updated resource |
| 201 Created | created | POST created a resource — include `Location: /collection/{id}` |
| 202 Accepted | accepted, not done | async work queued — return a status/poll URL |
| 204 No Content | success, no body | DELETE, or PUT/PATCH that returns nothing |
| 304 Not Modified | cache hit | conditional GET with `If-None-Match` and ETag matched |
| 400 Bad Request | malformed | body/params unparseable or syntactically wrong |
| 401 Unauthorized | unauthenticated | missing/invalid credentials — re-auth may help |
| 403 Forbidden | unauthorized | authenticated but lacks permission/scope |
| 404 Not Found | absent | resource doesn't exist (or is hidden from this caller) |
| 405 Method Not Allowed | wrong verb | path exists, method doesn't — set `Allow` header |
| 409 Conflict | state collision | duplicate, version mismatch, concurrent edit |
| 412 Precondition Failed | stale write | `If-Match` ETag no longer matches |
| 415 Unsupported Media Type | bad content-type | server can't process the sent representation |
| 422 Unprocessable Content | semantic invalid | parses fine, fails business validation |
| 429 Too Many Requests | rate limited | include `Retry-After` |
| 500 Internal Server Error | server fault | unexpected — never leak the stack |
| 503 Service Unavailable | temporarily down | maintenance/overload — `Retry-After` if known |

Rule of thumb: client mistakes are 4xx, server faults are 5xx. Never blame the client for your bug, never hide your bug behind a 200.

## Query grammar (filter / sort / sparse fieldsets)

Keep one grammar across all list endpoints so clients learn it once.

```http
GET /projects?status=active&owner=u_42&sort=-created_at,title&fields=id,title,status&limit=50
```

- **Filter** by field name as a query key: `?status=active`. For operators, namespace them: `?created_at[gte]=2026-01-01`. Pick one operator syntax and never mix.
- **Sort** with a comma list; `-` prefix = descending: `?sort=-created_at,title`.
- **Sparse fieldsets** let clients trim payloads: `?fields=id,title`. Whitelist allowed fields server-side.
- **Reserve** `limit`, `cursor` (or `offset`), `sort`, `fields`, `q` (free-text search) so they never collide with resource fields.

## Content negotiation

- Default to `application/json`. Honor `Accept`; return `406 Not Acceptable` if you can't satisfy it.
- Validate `Content-Type` on writes; `415` if unsupported.
- Version via media type only if you chose header versioning (see versioning reference); otherwise keep it simple.

## Rate-limit headers

Expose limits so well-behaved clients self-throttle:

```http
RateLimit-Limit: 1000
RateLimit-Remaining: 12
RateLimit-Reset: 1735689600
Retry-After: 30
```

On 429 always send `Retry-After`. Prefer the IETF `RateLimit-*` fields; the older `X-RateLimit-*` names are still common in the wild.

## HATEOAS — pragmatic stance

Full hypermedia (links driving all client navigation) is rarely worth it for typical JSON APIs; clients hardcode URLs anyway. Useful subset: include a `Location` on 201, a `Link` header for pagination/successor-version, and self/next links in list envelopes when it costs little. Don't build a hypermedia framework no client will follow.
