# n8n workflow JSON — schema, example, import, verification

When n8n is the chosen platform, your checkable artifact is a workflow JSON the user imports. This is the shape `scripts/verify.sh` validates.

## Required top-level shape

```json
{
  "name": "Stripe payment → Notion → Slack",
  "nodes": [],
  "connections": {},
  "settings": { "errorWorkflow": "<error-workflow-id-or-name>" }
}
```

- **`nodes`** — non-empty array. Each node has `id`, `name`, `type` (e.g. `n8n-nodes-base.webhook`), `typeVersion`, `position`, and `parameters`. Exactly one node is a trigger (its `type` ends in `webhook`, `Trigger`, `cron`, etc.).
- **`connections`** — object mapping a source node name → its outputs → the downstream nodes. An empty object is valid JSON but means nothing is wired; a real flow has entries.
- **`settings.errorWorkflow`** — points at the Error Workflow (see `error-handling.md`). Without it, failures don't alert.
- **Credentials** — nodes reference a credential by id/name from the n8n credential store via a `credentials` object. **Never** inline an API key or token in `parameters`.

## Minimal trigger → action → error example

```json
{
  "name": "Webhook → Notion (with dedup + retry)",
  "nodes": [
    {
      "id": "1", "name": "Webhook", "type": "n8n-nodes-base.webhook",
      "typeVersion": 2, "position": [0, 0],
      "parameters": { "httpMethod": "POST", "path": "stripe-payment" }
    },
    {
      "id": "2", "name": "Dedup lookup", "type": "n8n-nodes-base.if",
      "typeVersion": 2, "position": [240, 0],
      "parameters": {}
    },
    {
      "id": "3", "name": "Create Notion row", "type": "n8n-nodes-base.notion",
      "typeVersion": 2, "position": [480, 0],
      "parameters": { "resource": "databasePage", "operation": "create" },
      "retryOnFail": true, "maxTries": 4, "waitBetweenTries": 2000,
      "credentials": { "notionApi": { "id": "5", "name": "Notion account" } }
    }
  ],
  "connections": {
    "Webhook": { "main": [[{ "node": "Dedup lookup", "type": "main", "index": 0 }]] },
    "Dedup lookup": { "main": [[{ "node": "Create Notion row", "type": "main", "index": 0 }]] }
  },
  "settings": { "errorWorkflow": "Global error alerter" }
}
```

The trigger is the `webhook` node (not polling). `retryOnFail`/`maxTries`/`waitBetweenTries` live on the external-API node. Credentials are referenced by store id/name. `settings.errorWorkflow` names the separate Error Workflow.

## How the user imports it

1. n8n → **Workflows → Import from File** (or paste via *Import from Clipboard*).
2. Open each node with a `credentials` reference and pick/create the matching credential in the store.
3. Activate the workflow; copy the Webhook node's production URL into the upstream provider.

## What verify.sh checks

`scripts/verify.sh` runs read-only over any `*.json` in the target path and asserts each one: parses as JSON, has a non-empty `nodes` array, has a `connections` object, and has at least one trigger node (a node whose `type` ends in `webhook`/`Trigger`/`cron` or `trigger`). It makes no network calls and needs no credentials. With no JSON files present it exits 0 (nothing to check is not a failure).
