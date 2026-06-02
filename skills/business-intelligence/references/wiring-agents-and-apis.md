# Wiring agents and APIs

Offloaded depth from SKILL.md §"Wire the agent." How an LLM/agent consumes the semantic layer so it selects governed metrics instead of guessing SQL. The accuracy case is in SKILL.md (dbt 2026 benchmark: layer-grounded 98-100% vs raw text-to-SQL 84-90%).

## The pattern: agent → metrics tool → governed SQL

The agent never holds warehouse credentials and never sees raw tables. It calls a metrics tool whose inputs are the four primitives. The layer compiles the request to SQL, runs it, and returns the result.

```text
user question
  -> agent decomposes to: metric + dimensions + grain + filters
  -> agent calls metrics tool (MCP / metrics API) with those four parts
  -> semantic layer compiles to governed SQL, runs on the warehouse
  -> result + the metric definition used returned to the agent
  -> agent explains the answer in business terms
```

MCP is the emerging transport: the semantic layer is exposed as a tool server, the agent picks from the catalog of governed metrics and dimensions, and the layer returns results. Cube ships an AI API / MCP support for exactly this; expose the catalog as tools so metric selection is the only path.

## Query shapes by engine

### Cube — REST

```json
{
  "measures": ["orders.gross_revenue"],
  "dimensions": ["products.product_category"],
  "timeDimensions": [
    { "dimension": "orders.order_date", "granularity": "month",
      "dateRange": "last 2 quarters" }
  ],
  "filters": [
    { "member": "customers.region", "operator": "equals", "values": ["EU"] }
  ]
}
```

### Cube — SQL API (governed; the engine, not the agent, expands the metric)

```sql
SELECT product_category, gross_revenue
FROM orders
WHERE region = 'EU'
GROUP BY 1;
```

### dbt Semantic Layer — GraphQL

```graphql
query {
  query(
    metrics: [{ name: "gross_revenue" }]
    groupBy: [{ name: "products__product_category" },
              { name: "orders__order_date", grain: MONTH }]
    where: [{ sql: "{{ Dimension('customers__region') }} = 'EU'" }]
  ) { jsonResult }
}
```

dbt SL also exposes a **JDBC** endpoint with a `semantic_layer` SQL dialect, so BI tools and apps issue metric queries as if they were SQL while the layer compiles the real warehouse SQL. Both GraphQL and JDBC are the supported app-facing surfaces — point the agent at one of them, not at the warehouse.

## Prompt guidance that forces metric selection

Put this in the agent's system prompt / tool description:

- "To answer any data question, you MUST call `query_metrics`. You may not write or execute SQL against the warehouse."
- "Choose `metric` from the provided catalog. If no metric matches, say so and stop — do not invent an aggregate."
- "Express time as a `grain` (day/week/month/quarter) and a date range, never as a hand-written date filter."
- "Return the metric name you used so the number is auditable."

The goal is to make "call the metrics tool" the only available action, so the model's strong-but-imperfect SQL writing is never in the loop for a governed number.

## Guardrails (enforce in the tool, not just the prompt)

- **Deny raw-table access.** The agent's credentials reach the metrics API only — no direct warehouse connection. A prompt rule is not a control; the missing credential is.
- **Validate dimensions exist.** Reject a request whose `group_by` or `filter` names a dimension not declared on the metric. Return the valid options so the agent can retry.
- **Reject ungoverned aggregates.** If a request smuggles a raw expression instead of a catalog metric, refuse.
- **Return the definition used.** Every answer carries the metric name and grain so a human can audit it later and so two answers to the same question are provably identical.
- **Bound the blast radius.** Apply row-level security / tenant filters in the layer, not in the agent, so the agent cannot widen its own access.
