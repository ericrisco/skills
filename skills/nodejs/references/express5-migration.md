# Express 4 → 5 migration & middleware order

Express 5.2.x is current and requires Node.js 18+. Source: npm `express`, Express 5 migration guide (accessed 2026-06-02). Use this as the offloaded depth referenced from SKILL.md.

## Breaking changes that bite a backend

| Area | v4 | v5 | Action |
| --- | --- | --- | --- |
| Async errors | a rejected/thrown async handler hangs unless wrapped | auto-forwarded to the 4-arg error middleware | Delete `asyncHandler` wrappers; just `throw` / reject |
| `express.urlencoded` | `extended: true` default | `extended: false` default | Pass `{ extended: true }` explicitly if you relied on rich objects |
| `express.static` dotfiles | `"allow"` for some setups | `dotfiles: "ignore"` default | Set `{ dotfiles: "allow" }` only if you intend to serve `.well-known` etc. |
| Path matching | older path-to-regexp | newer path-to-regexp; some wildcard/optional syntaxes changed | Re-test `:param?`, `*`, and regex routes; name your wildcards |
| Removed/renamed | `res.json(status, obj)`, `app.del`, `req.param(name)` | removed | Use `res.status(s).json(obj)`, `app.delete`, `req.params`/`req.query`/`req.body` |

## Auto async error catch — what it actually guarantees

The framework's own router tests confirm: an `async` handler that rejects, or returns `Promise.reject(err)`, reaches the 4-arg error handler. A value-less `Promise.reject()` is surfaced as an `Error` with message `Rejected promise`. So in v5 you write:

```ts
// v5 — no wrapper
app.get("/users/:id", async (req, res) => {
  const u = await findUser(req.params.id); // throw NotFound → error middleware
  res.json(u);
});
```

```ts
// v4 legacy wrapper — ONLY if you are still on Express 4
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
app.get("/users/:id", asyncHandler(async (req, res) => { /* ... */ }));
```

What auto-catch does NOT cover: a promise you never awaited or returned inside the handler (a floating promise). That still escapes to the process, not the error middleware. Await everything.

## Middleware order (still matters in v5)

Order of registration is order of execution. The error handler is selected by arity (4 args), not by name or position alone — but it only catches what is registered *before* it.

```text
  app.use(express.json())            parsers, security headers
        │
        ▼
  app.use("/users", usersRouter)     routes (may throw → forwarded down)
        │
        ▼
  app.use((req,res) => 404)          fallthrough: nothing matched
        │
        ▼
  app.use((err,req,res,next) => ...) ERROR HANDLER — 4 args, registered LAST
```

A 4-arg function registered *before* the routes is skipped for normal requests and can never catch a route's throw. Put it last, exactly once.
