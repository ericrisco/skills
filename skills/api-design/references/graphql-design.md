# GraphQL design

When you chose GraphQL (many client shapes, deep graphs, over-fetch is real), design the schema as the contract. Framework-neutral.

## Schema & nullability

- **Model the domain graph, not your tables.** Types are nouns with relationships; let clients traverse instead of you minting endpoints.
- **Nullability is a contract.** A non-null field (`String!`) means the resolver must always produce it — and if it errors, GraphQL nulls the *nearest nullable parent*, which can blank a whole subtree. Make a field non-null only when it truly cannot be absent; default to nullable for anything fetched from a flaky downstream.
- **Use enums for closed sets** and add values additively (clients should tolerate unknown enum values).
- **Evolve additively; deprecate with `@deprecated(reason: ...)`** instead of removing — GraphQL has no URL version to fall back on.

## Pagination: Relay Connections

Use the de-facto standard rather than a bespoke shape, so client tooling (Apollo/Relay) works out of the box.

```graphql
type ProjectConnection {
  edges: [ProjectEdge!]!
  pageInfo: PageInfo!
}

type ProjectEdge {
  node: Project!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  endCursor: String
}

type Query {
  projects(first: Int!, after: String): ProjectConnection!
}
```

- `first` + `after` paginate forward; `last` + `before` backward.
- `cursor` is opaque — clients pass `endCursor` back as `after`; they never construct it.

## Mutations & error model

- **One input object per mutation, one payload type out** — keeps mutations evolvable: `createProject(input: CreateProjectInput!): CreateProjectPayload!`.
- **Model expected, business-level failures as data, not as protocol errors.** A union or a payload with `userErrors { field, message }` lets clients handle validation without parsing the transport `errors[]`.

```graphql
type CreateProjectPayload {
  project: Project
  userErrors: [UserError!]!
}
```

## The HTTP-200 error model (the big operational difference)

GraphQL returns **HTTP 200 even when a field errored.** Failures appear in a top-level `errors[]` array alongside partial `data`:

```json
{
  "data": { "project": null },
  "errors": [
    { "message": "Project not found", "path": ["project"], "extensions": { "code": "NOT_FOUND" } }
  ]
}
```

Consequences you must design for:
- **Monitoring cannot rely on HTTP 5xx.** Alerting must inspect the `errors[]` payload and `extensions.code`, not the status line. Wire this before launch or outages go invisible.
- **Clients must check `errors[]` on every response**, even a 200. Treating 200 as success silently swallows failures.
- **Standardize `extensions.code`** (e.g. `NOT_FOUND`, `FORBIDDEN`, `VALIDATION`) so clients and dashboards branch on a stable machine value — the GraphQL analogue of an RFC 9457 `type`.

This single difference, not the query syntax, is what makes GraphQL operationally distinct from REST. Decide it explicitly.
