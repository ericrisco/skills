# Versioning & evolution

Default posture: **evolve additively, version rarely.** A version is a fork of your client base — earn it.

## Breaking vs non-breaking matrix

| Change | Breaking? | Notes |
|---|---|---|
| Add a new optional response field | No | clients ignore unknown fields if you told them to |
| Add a new endpoint | No | nothing existing changes |
| Add a new optional query/body param | No | old requests still valid |
| Add a new enum value | No* | *only if clients were told to tolerate unknown values; otherwise breaking |
| Loosen a validation rule | No | previously-rejected input now accepted |
| Remove or rename a field | **Yes** | clients reading it break |
| Change a field's type or format | **Yes** | `string` → `object`, date format change, etc. |
| Make an optional field required | **Yes** | old requests start failing |
| Tighten validation (narrower accepted range) | **Yes** | previously-valid input now rejected |
| Change a status code for a case | **Yes** | client branching breaks |
| Change an error `type` URI for a case | **Yes** | clients branch on `type` |
| Change pagination/cursor semantics | **Yes** | in-flight pagination breaks |

Design hint: tell clients up front to **ignore unknown fields and tolerate unknown enum values** ("must-ignore" / robustness rule). That single contract clause turns many would-be breaking changes into additive ones.

## Three versioning mechanisms

| Mechanism | Example | Pros | Cons |
|---|---|---|---|
| **URL path** | `/v1/projects` | visible, cacheable, browser-testable, expected by most clients | version leaks into every URL; "v" is coarse-grained |
| **Header / media type** | `Accept: application/vnd.acme.v2+json` | clean URLs, content-negotiated | harder to test/cache, easy to forget, opaque to humans |
| **Query param** | `/projects?version=2` | trivial to add | pollutes URLs, easy to omit, muddies caching |

**Default to URL path for public APIs.** Reserve header/media-type versioning for internal APIs where tooling controls the header. Don't mix mechanisms.

## Deprecation & sunset workflow

1. Ship the successor (new field/endpoint/version) additively.
2. Mark the old surface deprecated in responses:

```http
Deprecation: true
Sunset: Sat, 31 Oct 2026 23:59:59 GMT
Link: <https://api.acme.com/v2/projects>; rel="successor-version"
```

3. Document the migration and the sunset date; notify known integrators.
4. Hold the deprecated surface working until the `Sunset` date — give clients real time (months, not days, for public APIs).
5. After sunset, return `410 Gone` for the removed surface (not `404`) so clients learn it was intentional.

Keep the deprecation window generous and the messaging programmatic — clients should learn from headers, not from breakage.
