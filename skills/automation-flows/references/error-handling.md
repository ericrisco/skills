# Error handling & dedup — per-platform deep dive

This expands section 3–4 of `../SKILL.md`. Read it when you are actually wiring the failure path, not before choosing a platform.

## n8n

### Error Workflow + Error Trigger
1. Create a second workflow. Its first node is the **Error Trigger** node — it does not run on its own, only when a monitored workflow fails.
2. After the Error Trigger, add a notification node (Slack, Send Email) and/or a log row (append to a sheet/DB). The Error Trigger output carries `execution.id`, `execution.url`, the failed node name, and the error message — put those in the alert so it's actionable.
3. On the **main** workflow, set this Error Workflow under **Settings → Error Workflow** (serialized as `settings.errorWorkflow` in the exported JSON).

### Per-node resilience
- **Retry On Fail** (node Settings toggle): set **Max Tries 3–5** and a **Wait Between Tries** (e.g. 1000–5000 ms). Use on every node that hits an external API.
- **Continue On Fail** (toggle): the node emits an error object instead of halting the run. Use when one bad item in a batch should be skipped/branched, not fatal. Branch on the error output with an IF node.

### Manual exponential backoff
n8n's built-in retry is **linear** (fixed wait). For exponential backoff, build it:

```text
[HTTP Request] --(on error / Continue On Fail)--> [IF: attempts < max]
   --true--> [Set: attempt = attempt + 1]
          --> [Wait: 2 ^ attempt seconds]   # 2s, 4s, 8s, 16s...
          --> back to [HTTP Request]
   --false--> [Error path: alert + give up]
```

Cap the attempts (e.g. 5) and the max wait so a hard-down API can't loop forever.

## Make

Attach a handler by right-clicking the risky module → **Add error handler**.

| Handler | Effect | Use when |
| --- | --- | --- |
| **Break** | Pause the run, send it to **Incomplete Executions**; auto-retry per the scenario's retry settings | Default for production — no data loss, recoverable |
| **Resume** | Replace the failed module's output with a hard-coded value and continue | A sane fallback exists (default tag, empty result) |
| **Ignore** | Skip the failure, continue the route | The step is non-critical (a nice-to-have notification) |
| **Commit** | End the run immediately, marked success | You've already done the important work |
| **Rollback** | End marked error and try to revert prior modules | You need all-or-nothing — but **not all modules support revert**, so verify, or you leave partial state |

Always put a **Filter before** any external-API module to drop malformed data before it triggers an error in the first place. Tune the scenario's **auto-retry** settings (attempts + interval) for the Incomplete Executions queue.

## Zapier

- **Autoreplay** — account-wide setting that auto-replays failed steps, up to **5 retries** per step. Caveat: once a Zap is **published with its own custom error handling**, Autoreplay turns OFF for that Zap, so you own the retry logic from then on.
- **Filters** — gate the Zap so it only continues when fields are present and the right shape. Use as a guard right after the trigger and before any irreversible action.
- **Paths** — if/then branching. Add an explicit fallback Path for the error/edge case so the Zap degrades gracefully instead of erroring out.
- **Sub-Zaps** — extract shared logic; keep each Zap small to keep task billing and debugging sane.

## Dedup / idempotency patterns

Why: webhooks are delivered **at-least-once** and retries replay events. A non-idempotent action (charge, email, insert) must be guarded by a stable key — the provider's **event id** or your **external id**.

- **n8n** — before the write, a lookup node (DB query, or an HTTP GET against your store) on the event id; route through an IF so "already seen" exits. After a successful write, persist the id.
- **Make** — use a **Data store**. `Get a record` by event id → `Filter: record not found` → do the write → `Add/Replace a record` with the id. The data store is the dedup ledger.
- **Zapier** — **Storage by Zapier**: `Get Value` by event id → Filter `does not exist` → action → `Set Value` of the id. Or look up a row in a sheet/DB keyed on the id.

Always: **check the key before the write, persist the key after the write.** If the write isn't naturally idempotent and your store write can fail independently, prefer a single upsert keyed on the id where the target app supports it.
