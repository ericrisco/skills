# Graceful shutdown — complete server.ts

Copy-pasteable. Threads an `AbortController` so in-flight long ops are cancelled, gates readiness so the load balancer stops routing before drain, and keeps a force-exit backstop so a stuck connection can't hang the deploy. Sources: AbortController guides (AppSignal 2025-02-12, BetterStack), Node SIGTERM semantics (accessed 2026-06-02).

## Why a readiness gate, not just `server.close()`

`server.close()` stops accepting *new* connections but in-flight requests keep going. If the load balancer is still routing new traffic at you while you close, those new connections are refused. So you flip `/readyz` to 503 *first*, give the LB a moment to deregister, then close. `/healthz` stays 200 the whole time — the process is alive, just draining.

```ts
// server.ts
import { buildApp } from "./app.ts";
import { config } from "./config/env.ts";
import { logger } from "./logger.ts";
import { closePool } from "./repositories/pool.ts";

let ready = true;
const controller = new AbortController(); // pass controller.signal into fetch/DB/long ops

const app = buildApp();
app.get("/healthz", (_req, res) => res.json({ status: "up" }));        // liveness
app.get("/readyz", (_req, res) =>                                       // readiness
  ready ? res.json({ status: "ready" }) : res.status(503).json({ status: "draining" }),
);

const server = app.listen(config.PORT, () =>
  logger.info({ port: config.PORT }, "listening"),
);

let shuttingDown = false;
async function shutdown(signal: string) {
  if (shuttingDown) return;            // ignore a second signal
  shuttingDown = true;
  logger.info({ signal }, "shutting down");

  ready = false;                       // 1. /readyz → 503, LB deregisters

  const backstop = setTimeout(() => {  // 5. backstop: never hang the deploy
    logger.error("drain timed out, forcing exit");
    process.exit(1);
  }, 10_000);
  backstop.unref();

  server.close(async () => {           // 2. stop accepting; wait for in-flight
    controller.abort();                // 3. cancel long-running ops
    await closePool();                 // 4. release DB/other resources
    clearTimeout(backstop);
    logger.info("clean exit");
    process.exit(0);
  });
}

process.on("SIGTERM", () => void shutdown("SIGTERM"));
process.on("SIGINT", () => void shutdown("SIGINT"));

// last-resort: log and exit, never keep running on a detached failure
process.on("unhandledRejection", (reason) => {
  logger.error({ reason }, "unhandled rejection");
  void shutdown("unhandledRejection");
});
```

## Threading the signal into work

The `AbortController` only helps if operations actually receive `controller.signal`:

```ts
// in a repository / service
const res = await fetch(url, { signal: controller.signal });
// or compose a per-request deadline with a shutdown abort:
const signal = AbortSignal.any([controller.signal, AbortSignal.timeout(5_000)]);
```

`AbortSignal.timeout(ms)` returns an auto-aborting signal; `AbortSignal.any([...])` aborts when any input aborts — so the op dies on either the 5s deadline or process shutdown.
