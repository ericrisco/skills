# MCP servers — decide, build, secure

The Model Context Protocol lets an MCP **client** (Claude Desktop/Code, Cursor, your own
agent) discover and call tools, read resources, and use prompts hosted by an MCP
**server**. Build one only when reuse across clients justifies the cost; otherwise native
in-process tools (see `tools-and-rag.md`) are simpler and cheaper. Versions and signatures
move — confirm against the current SDK docs before shipping.

## MCP vs native tools

| Situation | Choose |
|---|---|
| Tools live in the same process/repo as the agent | **Native tools** — direct function calls, no transport, no extra schema tokens |
| One agent, one deployment, no external consumers | **Native tools** |
| Tools must be reused by multiple clients / teams | **MCP** |
| Tools run out-of-process or need their own deploy lifecycle | **MCP** |
| You want a third-party client (Claude Desktop, Cursor) to use your tools | **MCP** |
| Tools wrap a system with its own auth/network boundary | **MCP** |

MCP is not free: every tool's schema is re-sent to the model (token cost — ties to
context-budget), there's a transport hop (latency), and you now operate a server
(deploy, auth, monitoring). Pay that only for genuine cross-client reuse.

## Concepts

- **Tools** — actions the model invokes (search, mutate, compute). Side-effecting; validate
  inputs, return structured results.
- **Resources** — read-only data the client fetches by URI (`config://app`,
  `file:///logs/today`). No side effects.
- **Prompts** — parameterized prompt templates the client can surface to users.

Lifecycle: client connects over a transport → negotiates capabilities → lists
tools/resources/prompts → calls them on demand. Note (spec `2025-11-25`; stateless-core RC
`2026-07-28`; verify before quoting): the RC makes the protocol core **stateless**, adding
Extensions, Tasks, and MCP Apps — design servers to avoid per-connection state so they
forward-port cleanly and scale horizontally.

## Python server (FastMCP)

The `mcp` Python SDK ships FastMCP: decorators register tools/resources/prompts; Pydantic
types on the signature become the input schema automatically.

```python
# server.py — run with: python server.py   (stdio transport)
from __future__ import annotations

from typing import Literal

from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field

mcp = FastMCP("invoices")

# In-memory stand-in for a real store; replace with a DB session in production.
_INVOICES: dict[str, dict] = {}


class CreateInvoice(BaseModel):
    customer_id: str = Field(min_length=1, description="Customer id, e.g. 'cus_42'.")
    amount_cents: int = Field(gt=0, le=10_000_000, description="Amount in cents (> 0).")
    currency: Literal["EUR", "USD"] = "EUR"


@mcp.tool()
def create_invoice(args: CreateInvoice) -> dict:
    """Create an invoice. Returns the new invoice id and status."""
    inv_id = f"inv_{args.customer_id}_{len(_INVOICES) + 1}"
    _INVOICES[inv_id] = {"customer_id": args.customer_id, "amount_cents": args.amount_cents,
                         "currency": args.currency, "status": "open"}
    return {"id": inv_id, "status": "open"}


@mcp.resource("invoice://{invoice_id}")
def read_invoice(invoice_id: str) -> str:
    """Read-only lookup of an invoice by id."""
    inv = _INVOICES.get(invoice_id)
    if inv is None:
        raise ValueError(f"unknown invoice: {invoice_id}")   # surfaced as a structured error
    return f"Invoice {invoice_id}: {inv['amount_cents']} {inv['currency']} ({inv['status']})"


@mcp.prompt()
def dunning_email(invoice_id: str) -> str:
    """Template a polite payment-reminder email for an overdue invoice."""
    return (f"Write a concise, friendly reminder that invoice {invoice_id} is overdue. "
            f"Offer a payment link and a contact for questions.")


if __name__ == "__main__":
    mcp.run()  # stdio; for HTTP use mcp.run(transport="streamable-http")
```

## TypeScript server

The repo runs Next.js, so the TS SDK matters. The current registration API is
`registerTool(name, { description, inputSchema }, handler)` with **Zod** schemas
(`inputSchema` must be a `z.object(...)`). Imports below use the stable
`@modelcontextprotocol/sdk` subpath form; the v2 split packages
(`@modelcontextprotocol/server`, `@modelcontextprotocol/node`) expose the same API under
new paths — verify against the SDK version in your `package.json`.

```typescript
// server.ts — install: npm i @modelcontextprotocol/sdk zod
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { randomUUID } from "node:crypto";
import { z } from "zod";

const invoices = new Map<string, { amountCents: number; currency: string; status: string }>();

export function buildServer(): McpServer {
  const server = new McpServer({ name: "invoices", version: "1.0.0" });

  server.registerTool(
    "create_invoice",
    {
      title: "Create invoice",
      description: "Create an invoice. Returns the new invoice id and status.",
      inputSchema: z.object({
        customerId: z.string().min(1).describe("Customer id, e.g. 'cus_42'."),
        amountCents: z.number().int().positive().max(10_000_000).describe("Amount in cents (> 0)."),
        currency: z.enum(["EUR", "USD"]).default("EUR"),
      }),
    },
    async ({ customerId, amountCents, currency }) => {
      const id = `inv_${customerId}_${invoices.size + 1}`;
      invoices.set(id, { amountCents, currency, status: "open" });
      return { content: [{ type: "text", text: JSON.stringify({ id, status: "open" }) }] };
    },
  );

  server.registerResource(
    "invoice",
    "invoice://{invoiceId}",
    { description: "Read-only invoice lookup by id." },
    async (uri) => {
      const id = uri.href.replace("invoice://", "");
      const inv = invoices.get(id);
      if (!inv) throw new Error(`unknown invoice: ${id}`);
      return { contents: [{ uri: uri.href, text: `Invoice ${id}: ${inv.amountCents} ${inv.currency}` }] };
    },
  );

  return server;
}

// stdio entrypoint (local clients: Claude Desktop/Code)
async function mainStdio(): Promise<void> {
  const server = buildServer();
  await server.connect(new StdioServerTransport());
}

// Streamable HTTP entrypoint (remote clients) — one stateless transport per request
import express from "express";

export function httpApp() {
  const app = express();
  app.use(express.json());
  app.post("/mcp", async (req, res) => {
    const server = buildServer();
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: () => randomUUID() });
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  });
  return app;
}

if (process.argv[2] === "stdio") {
  mainStdio().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
```

## Transports

- **stdio** — the server is a subprocess of a local client (Claude Desktop/Code). Simplest;
  no network surface; one client per process. Use for local dev tools and desktop
  integrations.
- **Streamable HTTP** — a single MCP HTTP endpoint for remote clients (Cursor, cloud,
  your own agent service). Scales horizontally; this is the direction the stateless-core RC
  pushes. Use for shared/team servers.
- **SSE** — legacy only; support it solely for backward compatibility with old clients.

Capability discovery: the RC formalizes a `.well-known` advertisement so clients can find a
server's capabilities without a manual config — prefer it once your client supports it.

## Security

An MCP server is an attack surface; the model drives its inputs.

- **Auth on HTTP transport** — require OAuth or a bearer token; reject unauthenticated
  requests at the edge. stdio inherits the local user's trust; HTTP does not.
- **Input validation** — every tool validates with Pydantic/Zod before acting (the examples
  above do). Never trust model-supplied ids, paths, or SQL.
- **No raw stack traces to the model** — return a structured error message; a traceback leaks
  internals and wastes context.
- **Rate limiting** — per-client limits on tool calls; expensive tools get their own cap.
- **Egress controls** — allowlist the hosts/commands a tool may reach (see sandboxing in
  `tools-and-rag.md`).
- **Tool allowlisting** — expose only the tools a given client needs; don't ship one server
  with every capability.
- **Confused-deputy risk** — the server acts with its *own* credentials on behalf of a
  model that may be steered by untrusted input. Use **least-privilege tokens** scoped to
  exactly what each tool needs, and require human approval for high-risk actions.

```typescript
// Bearer-token gate for the HTTP transport (add before transport.handleRequest)
app.use("/mcp", (req, res, next) => {
  const token = req.header("authorization")?.replace("Bearer ", "");
  if (token !== process.env.MCP_TOKEN) {
    res.status(401).json({ error: "unauthorized" });
    return;
  }
  next();
});
```

## Testing & debugging

- **MCP Inspector** — the official interactive client for poking a server during
  development: `npx @modelcontextprotocol/inspector python server.py`. Lists tools/resources
  and lets you call them by hand.
- **Contract test** — automate the round-trip: connect, list tools, call one, assert the
  shape. Run it in CI.

```python
# test_server.py — pytest + the in-process FastMCP client
import pytest
from mcp.server.fastmcp import FastMCP

from server import mcp  # the FastMCP instance


@pytest.mark.anyio
async def test_create_and_read_round_trip():
    async with mcp.client() as client:          # in-process client; no transport needed
        tools = await client.list_tools()
        assert "create_invoice" in {t.name for t in tools.tools}

        created = await client.call_tool("create_invoice",
            {"args": {"customer_id": "cus_42", "amount_cents": 500, "currency": "EUR"}})
        inv_id = created.structuredContent["id"]

        # idempotency / read-back: the resource reflects the created invoice
        res = await client.read_resource(f"invoice://{inv_id}")
        assert "500 EUR" in res.contents[0].text
```

## Packaging

Pin the SDK and the spec version you target so upgrades are deliberate:

```json
{
  "name": "invoices-mcp",
  "version": "1.0.0",
  "mcp": { "specVersion": "2025-11-25" },
  "dependencies": {
    "@modelcontextprotocol/sdk": "1.x",
    "zod": "3.x"
  }
}
```

Client-registration snippet (Claude Desktop/Code `mcpServers` config) for the stdio server:

```json
{
  "mcpServers": {
    "invoices": {
      "command": "python",
      "args": ["/abs/path/to/server.py"],
      "env": { "DATABASE_URL": "postgresql+asyncpg://app:secret@db/app" }
    }
  }
}
```

## See also

- `tools-and-rag.md` — native tools, Pydantic/Zod validation, and sandboxing the server reuses.
- `provider-abstraction.md` — when the agent calling this MCP server stays provider-agnostic.
</content>
