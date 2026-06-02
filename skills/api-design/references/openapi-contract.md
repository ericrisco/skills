# OpenAPI 3.1 contract

The contract is the artifact. Capture a REST design as an **OpenAPI 3.1** document — a real, lintable file that a framework skill generates server stubs and clients from, and that `scripts/verify.sh` checks.

Why 3.1: it aligns with JSON Schema 2020-12, so your request/response schemas are reusable JSON Schema, and it adds `webhooks` and richer `$ref` handling over 3.0.

## Minimal skeleton

```yaml
openapi: 3.1.0
info:
  title: Projects API
  version: 1.0.0
servers:
  - url: https://api.acme.com/v1
paths:
  /projects:
    get:
      summary: List projects
      parameters:
        - { name: cursor, in: query, schema: { type: string } }
        - { name: limit, in: query, schema: { type: integer, maximum: 100, default: 50 } }
      responses:
        "200":
          description: A page of projects
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ProjectPage" }
        default:
          $ref: "#/components/responses/Problem"
    post:
      summary: Create a project
      parameters:
        - { name: Idempotency-Key, in: header, schema: { type: string } }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/ProjectCreate" }
      responses:
        "201":
          description: Created
          headers:
            Location: { schema: { type: string } }
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Project" }
        "422": { $ref: "#/components/responses/Problem" }
        default: { $ref: "#/components/responses/Problem" }
components:
  responses:
    Problem:
      description: RFC 9457 problem details
      content:
        application/problem+json:
          schema: { $ref: "#/components/schemas/Problem" }
  schemas:
    Problem:
      type: object
      properties:
        type: { type: string, format: uri }
        title: { type: string }
        status: { type: integer }
        detail: { type: string }
        instance: { type: string }
      required: [type, title, status]
    ProjectPage:
      type: object
      properties:
        data: { type: array, items: { $ref: "#/components/schemas/Project" } }
        next_cursor: { type: [string, "null"] }
        has_more: { type: boolean }
      required: [data, has_more]
```

## Conventions that keep it clean

- **One reusable `Problem` schema and `Problem` response**, referenced by every error case — enforces the single RFC 9457 envelope.
- **A `default` response on every operation** so unexpected statuses still resolve to the problem shape.
- **Every list operation carries `cursor` + `limit`** params — verify.sh warns when a list path lacks them.
- **No verbs in path keys** — verify.sh flags `/get*`, `/create*`, `/delete*` segments.
- **`info.version` is the contract version**, distinct from the URL `/v1` major; bump it on any non-breaking addition too.

## Handoff

Give the framework skill this file. It becomes the source of truth: FastAPI/NestJS/Go/Node tooling can generate models, route stubs, and validation from it, and clients can generate SDKs. Keep the OpenAPI doc updated *before* the code changes — design-first, not code-first.
