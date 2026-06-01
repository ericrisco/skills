# IMPLEMENTATION PLAN — skill `nextjs`

This is a verbatim writing plan. The implementer subagent follows it top-to-bottom with no
further design decisions. Source of truth is `spec.md` in this folder; this plan operationalizes
it. Target: an LLM coding agent editing a real Next.js App Router app in a polyglot workspace
(FastAPI/Python, Next.js, Go, Flutter, Postgres). Tone: directive, dense, copy-pasteable,
Good/Bad contrasts. Versions are stated explicitly throughout (Next.js 15 baseline + Next.js 16
Cache Components, React 19 / 19.2, TypeScript 5.6+, Vitest 3, MSW 2, Playwright 1.4x, Auth.js v5).

---

## 0. File list (exact paths)

Create exactly these files under `/Volumes/EXTERN/DEV/skills/skills/nextjs/`:

```
/Volumes/EXTERN/DEV/skills/skills/nextjs/SKILL.md
/Volumes/EXTERN/DEV/skills/skills/nextjs/references/react.md
/Volumes/EXTERN/DEV/skills/skills/nextjs/references/data-and-caching.md
/Volumes/EXTERN/DEV/skills/skills/nextjs/references/testing.md
/Volumes/EXTERN/DEV/skills/skills/nextjs/references/performance.md
/Volumes/EXTERN/DEV/skills/skills/nextjs/references/security.md
/Volumes/EXTERN/DEV/skills/skills/nextjs/scripts/verify.sh
```

Create the `references/` and `scripts/` directories first:

```bash
mkdir -p /Volumes/EXTERN/DEV/skills/skills/nextjs/references /Volumes/EXTERN/DEV/skills/skills/nextjs/scripts
```

No other files. No `examples/`, no `assets/`. Do NOT run `verify.sh` (this repo is not a Next.js
project).

---

## 1. `SKILL.md` (target 360–430 lines, ONE H1)

### Frontmatter (exact)

```yaml
---
name: nextjs
description: "Use when building, reviewing, testing, securing, or optimizing a Next.js App Router app (Next.js 15/16, React Server Components, \"use client\"/\"use server\", server actions, route handlers, layouts, streaming/Suspense, the App Router caching model, TypeScript, Auth.js, Vitest/Playwright, CSP/security headers). Triggers on `app/` directory work, `next.config.ts`, `proxy.ts`/`middleware.ts`, server actions, route handlers, `use cache`, `useActionState`, RSC boundary questions, hydration errors, and Next.js perf/Core Web Vitals."
origin: risco
---
```

### Section order and content

Write these H2 sections in this exact order. Every code fence MUST have a language tag. Use
`tsx`/`ts`/`bash`/`yaml`/`json` appropriately. Keep SKILL.md tight — push long worked examples to
`references/`. Where a section says "pointer", write one sentence + a relative link like
`references/data-and-caching.md`.

#### `# Next.js App Router — RSC, Server Actions, React 19, TypeScript`

One-line purpose under the H1:
> Build, review, test, secure, and optimize Next.js App Router apps with correct handling of
> both the Next.js 15 (uncached-by-default) and Next.js 16 (`use cache`) caching models.

#### `## When to use / When NOT to use`

Two tight bullet lists, lifted/condensed from spec §1:
- When to use: editing/creating files under `app/`; Server vs Client decisions; server actions /
  route handlers; `useActionState`+zod forms; caching/revalidation; auth/middleware/CSP; hydration
  mismatches, waterfalls, bundle bloat; Vitest/Playwright tests for Next.js code.
- When NOT to use (with the redirect target each): Pages Router (`pages/`) → defer to Pages docs;
  pure React SPA (Vite/CRA) → generic React skill; React Native; non-Next backend (FastAPI/Go) →
  sibling backend skills; generic React-shape questions → keep brief, point to `references/react.md`.

#### `## First: detect the project's version & caching model`

THE gate. Bold lead sentence: **Run this before prescribing or reviewing any caching, middleware,
or React-Compiler behavior. Never mix v15 and v16 advice.**

Numbered detection block (4 steps):
1. Read `package.json` → `next` version.
2. Read `next.config.{ts,js,mjs}` for `cacheComponents`, `ppr`, `reactCompiler`, `experimental`.
3. `proxy.ts` at root ⇒ v16; `middleware.ts` ⇒ v15 (or v16 not yet migrated).
4. `cacheComponents: true` OR any `"use cache"` in the tree ⇒ **Cache Components model** (opt-in
   caching). Otherwise ⇒ **v15 model** (uncached `fetch` by default, `revalidate`/`tags`).

Bold rule line: **Do not flag `proxy.ts`, `use cache`, or `cacheComponents` as errors — they are
correct on Next.js 16.**

Then this table (write exactly):

```markdown
| Signal in repo                                  | Model            | Caching API to use                              |
| ----------------------------------------------- | ---------------- | ----------------------------------------------- |
| `cacheComponents: true` or any `"use cache"`    | Cache Components (v16) | `"use cache"` + `cacheLife()` + `cacheTag()`/`updateTag()` |
| `middleware.ts`, no `cacheComponents`           | v15 baseline     | `fetch(..., { next: { revalidate, tags } })`, `unstable_cache`, `revalidateTag` |
| `proxy.ts` present                              | v16 routing      | middleware logic lives in `proxy.ts` (NOT a security boundary) |
| `reactCompiler: true`                           | Compiler on      | drop manual `useMemo`/`useCallback`/`React.memo` (review-only) |
```

#### `## The boundary: Server vs Client Components`

Lead: default is a Server Component; opt into client only for interactivity.

Bullet — the four boundary laws:
- Server → Client: pass **serializable** props or `children`.
- Never `import` a Server Component into a Client Component; compose via `children`.
- `"use client"` marks a module **and its whole import subtree** as client.
- Keep `"use client"` leaves small; push the directive **down** the tree.

Code snippet 1 (`tsx`, Good): a Server page (`async`, awaits `params` Promise, reads DB) rendering
a small `"use client"` island. Demonstrate: default server async component + a tiny client button.

Code snippet 2 (`tsx`, Good/Bad pair): the `children` composition pattern — Bad = `import ServerThing`
into a `"use client"` file (comment: breaks build / forces client); Good = client shell takes
`children` and the server content is passed from a server parent.

#### `## "use server": Server Actions`

Bold banner line: **Every Server Action is a public POST endpoint. It MUST authenticate and
authorize itself. Middleware/proxy does NOT protect it.**

Code snippet (`ts`, Good): `actions.ts` with `"use server"` at top, a zod schema, `auth()` check
first (return `{ status: 'error' }` if no session), `safeParse(Object.fromEntries(formData))`,
mutation, `revalidateTag('...')`, typed discriminated-union return
`{ status: 'ok'; data } | { status: 'error'; message }`. Use a realistic example (e.g. updating a
project name) so types are concrete.

Bullets — two invocation modes:
- `<form action={updateProject}>` (progressive enhancement).
- imperative from a client handler wrapped in `startTransition(() => updateProject(fd))`.

One-sentence pointer to `references/security.md` and `references/data-and-caching.md`.

#### `## Route Handlers (`route.ts`)`

Decision bullet — use a Route Handler for: webhooks, public JSON API, OAuth callbacks, streaming
responses, non-form clients. Use a **Server Action instead** for internal form mutations.

Code snippet (`ts`, Good): a `route.ts` with typed `GET` and `POST`, `NextRequest`/`NextResponse`,
zod body validation on POST, `auth()` check, `Response.json(...)` / `NextResponse.json(...)`. Add a
comment noting `export const dynamic`, `export const runtime = 'nodejs' | 'edge'`, and that GET
handlers are **uncached by default on v15**.

#### `## Layouts, templates, loading & error boundaries`

Table (file → behavior):

```markdown
| File              | Role / when it runs                                              |
| ----------------- | ---------------------------------------------------------------- |
| `layout.tsx`      | Wraps a segment; persists across navigation, does NOT remount    |
| `template.tsx`    | Like layout but remounts on every navigation (fresh state)       |
| `loading.tsx`     | Instant Suspense fallback for the segment while it streams        |
| `error.tsx`       | `"use client"` error boundary for the segment, gets `reset()`    |
| `not-found.tsx`   | Rendered by `notFound()` and unmatched routes                    |
| `global-error.tsx`| Replaces the root layout when the root throws                    |
```

Code snippet 1 (`tsx`, Good): an `error.tsx` — note the `"use client"` directive, props
`{ error: Error & { digest?: string }; reset: () => void }`, a retry button calling `reset()`.

Code snippet 2 (`tsx`, Good): a page using explicit `<Suspense fallback={...}>` around a slow async
child so the shell paints first.

#### `## Routing: groups, parallel, intercepting, dynamic, metadata`

Compact bullets, one line each, with the file-name convention:
- Route groups `(marketing)/` — organize without affecting the URL.
- Dynamic `[id]`, catch-all `[...slug]`, optional `[[...slug]]`.
- **`params` and `searchParams` are Promises on v15+ — `await` them.**
- Parallel routes `@modal` + `default.tsx`.
- Intercepting `(.)photo` — modal-on-navigation.
- `generateMetadata` (async) + `generateStaticParams`.

Good/Bad snippet (`tsx`): Bad = `function Page({ params }: { params: { id: string } })` reading
`params.id` directly; Good = `async function Page({ params }: { params: Promise<{ id: string }> })`
with `const { id } = await params;`. Comment: forgetting `await` is the top v15-migration bug.

#### `## Caching & data fetching (both models)`

Lead sentence: which block applies is decided by the detection gate above. Deep dive →
`references/data-and-caching.md`.

**v15 model** sub-bullets + one `ts` snippet showing: uncached `fetch(url)`;
`fetch(url, { next: { revalidate: 3600, tags: ['products'] } })`; `revalidateTag('products')` from an
action; `React.cache` for request dedupe; mention `unstable_cache` and route segment config
(`export const revalidate = 3600`).

**v16 Cache Components** sub-bullets + one `ts` snippet showing: `"use cache"` at the top of a data
function, `cacheLife('hours')`, `cacheTag('products')`, invalidation via `updateTag('products')`.

Good/Bad snippet (`ts`): Bad = `cookies()`/`headers()`/`searchParams` read **inside** a `"use cache"`
function (comment: build hang / error); Good = read the request value **outside**, pass it as an
argument to the cached function.

One-line pointer to references for optimistic UI, `useActionState`+zod forms, and full mutation
patterns.

#### `## React 19 in the App Router (essentials)`

Bullets — Next-relevant deltas only (full discipline in `references/react.md`):
- `useActionState(fn, initial)` → `[state, action, isPending]` (replaces `useFormState`).
- `useFormStatus()` for a child submit button.
- `useOptimistic(state, reducer)` — auto-reverts on action error.
- `use(promise)` — unwrap an RSC-passed Promise inside a Client Component under `<Suspense>`.
- `ref` as a normal prop (no `forwardRef`); `<Context value={...}>` as provider.
- **React Compiler on (`reactCompiler: true`) ⇒ drop manual memoization.**

Tiny `tsx` snippet: a `useActionState` form wired to the Server Action from earlier, with
`isPending` disabling the button and `state.message` rendered in `role="alert"`.

#### `## TypeScript discipline`

Bullets:
- `strict: true` + `noUncheckedIndexedAccess: true`.
- Typed routes (`typedRoutes: true` / `experimental.typedRoutes`).
- **zod-inferred end-to-end types** (`z.infer`) shared across action input, form, and DB layer.
- Discriminated-union action result `{ status: 'ok'; data } | { status: 'error'; message }`.
- `params`/`searchParams` typed as `Promise<...>`.

Good/Bad snippet (`ts`): Bad = `const data: any = Object.fromEntries(formData)`; Good =
`const schema = z.object({...}); type Input = z.infer<typeof schema>; const r = schema.safeParse(...)`.

#### `## Auth (Auth.js v5) — defense in depth`

Bold lead: **Three layers, and the middleware layer is NOT one of the security layers.**
- `proxy.ts`/`middleware.ts`: coarse redirect only (NOT security).
- `auth()` check inside **every** Server Action and Route Handler.
- A **Data Access Layer (DAL)** that re-checks the session before any read/write.
- Secure cookies: `httpOnly`, `secure`, `sameSite: 'lax'`.

Code snippet (`ts`, Good): minimal `auth.ts` (`NextAuth({...})` exporting `auth`, `handlers`,
`signIn`, `signOut`) + a `getCurrentUser()` DAL wrapped in `React.cache` that throws/redirects when
there is no session. Pointer to `references/security.md`.

#### `## Security (deep dive → references/security.md)`

Checklist bullets the agent applies on every review:
- No `dangerouslySetInnerHTML` without sanitization (DOMPurify server-side).
- CSRF: Server Actions verify `Origin`/`Host`; SameSite cookies; never expose mutations as
  unauthenticated GET. Mention `serverActions.allowedOrigins`.
- **Never put secrets in `NEXT_PUBLIC_*`** — it ships to the browser; proxy via Route Handler.
- SSRF: allowlist host/scheme before `fetch` in Route Handlers; block internal/metadata ranges.
- CSP with a nonce via `proxy.ts`/headers.
- Auth on every action (cross-link to the Auth section).

End line: "See Also: `secure-coding`."

#### `## Performance (deep dive → references/performance.md)`

Bullets:
- `next/image` — always width/height or `fill`+sized parent; `priority` on the LCP image; `sizes`.
- `next/font` — self-host, `display: 'swap'`, subset → zero CLS + no extra round-trip.
- `next/dynamic` for heavy client islands; `optimizePackageImports`; `@next/bundle-analyzer`.
- Kill waterfalls with parallel `Promise.all` / split sibling fetches into parallel children.
- PPR / streaming; reserve space to avoid CLS.
- Core Web Vitals targets: **LCP < 2.5s, CLS < 0.1, INP < 200ms** (INP replaced FID).

#### `## Anti-patterns → STOP`

Markdown table, exactly these ~10 rows (`Rationalization | Reality`):

```markdown
| Rationalization                                           | Reality / STOP                                                            |
| -------------------------------------------------------- | ------------------------------------------------------------------------ |
| "The client already checks the user, the action is safe" | Server Actions are public POST endpoints — authenticate inside the action |
| "`fetch` caches by default, skip `revalidate`"           | v15: `fetch` is uncached by default; that's the v13/14 mental model       |
| "Read `cookies()` inside `use cache` for convenience"    | Build hangs/errors; read outside, pass the value as an argument           |
| "`proxy.ts` looks misnamed, rename to `middleware.ts`"   | Correct on v16; renaming breaks middleware execution                      |
| "Just `import` the Server Component into this client file"| Compose via `children`; importing forces it client / breaks the build     |
| "Put the API key in `NEXT_PUBLIC_API_KEY`"               | It ships to the browser; proxy through a Route Handler/Server Action       |
| "Add `useMemo` everywhere for perf"                      | Measure first; with React Compiler manual memoization is noise            |
| "`await params` is unnecessary"                          | v15+: `params`/`searchParams` are Promises — you must `await`             |
| "Middleware protects my dashboard, the data fetch is safe"| Middleware is not a security boundary; check in the DAL                    |
| "Snapshot-test the RSC page"                             | Async Server Components aren't jsdom-renderable; test data fns + Playwright|
```

#### `## Quick reference`

One compact table (`Task | API / file | Note`):

```markdown
| Task                          | API / file                                  | Note                                  |
| ----------------------------- | ------------------------------------------- | ------------------------------------- |
| New mutation                  | Server Action (`"use server"`)              | auth + zod inside                     |
| Public JSON / webhook         | Route Handler (`route.ts`)                  | uncached GET on v15                   |
| Per-request dedupe            | `React.cache(fn)`                           | one query per render                  |
| Cache cross-request (v15)     | `fetch tags` / `unstable_cache`             | opt-in                                |
| Cache (v16)                   | `"use cache"` + `cacheTag`                  | opt-in, `cacheLife()`                 |
| Invalidate                    | `revalidateTag` / `updateTag` / `revalidatePath` | from an action                   |
| Loading UI                    | `loading.tsx` / `<Suspense>`                | stream the shell                      |
| Error UI                      | `error.tsx`                                 | `"use client"`, gets `reset()`        |
| Form                          | `useActionState` + zod                      | `isPending`, `role="alert"`           |
| Optimistic UI                 | `useOptimistic`                             | auto-revert on error                  |
| Client island                 | `"use client"` leaf                         | keep small, push down                 |
| Secrets                       | server-only env (`import 'server-only'`)    | never `NEXT_PUBLIC_*`                 |
| Image                         | `next/image` + `priority`                   | LCP image                             |
| Protect route                 | middleware redirect + DAL `auth()`          | DAL is the real boundary              |
```

#### `## Verify`

One short block: run `bash scripts/verify.sh` from the Next.js project root. It runs ESLint,
`tsc --noEmit`, Vitest, and `next build`, skipping any tool not installed. Safe to re-run
(read-only, no installs).

#### `## References`

Bullet list of the five reference files with a one-line description each:
- `references/react.md` — React 19 discipline for the App Router (hooks, boundaries, forms, state).
- `references/data-and-caching.md` — both caching models, mutations, end-to-end zod forms.
- `references/testing.md` — Vitest 3 + RTL + MSW 2 + Playwright; RSC testing reality.
- `references/performance.md` — Core Web Vitals, images, fonts, bundles, streaming.
- `references/security.md` — auth, CSRF, XSS, CSP, env leakage, SSRF.

#### `## See Also`

Bullets: `secure-coding` (generic security; this skill complements, does not duplicate); the
sibling backend skills `fastapi` and `go` for the API the frontend calls; `postgresdb` for the data
layer; `risco-project-harness` for workspace conventions. Use relative links of the form
`../secure-coding/SKILL.md`.

---

## 2. `references/react.md` (target 280–360 lines)

ONE H1: `# React 19 discipline for the Next.js App Router`. Then these H2 sub-sections in order.
Every fence tagged `tsx`/`ts`. Use Good/Bad (write them as `// Good` / `// Bad` comments).

1. `## Hooks discipline` — bullets: top-level only, never conditional; cleanup every subscription/
   interval/listener; functional updater `setX(p => ...)` when new state depends on old; default =
   no memoization; extract a custom hook only when the same sequence appears in 2+ components. One
   `tsx` `useDebounce<T>` example with cleanup.
2. `## Server vs Client deep dive` — the import-graph rule restated; a Good/Bad pair showing passing
   a Server Action + `children` across the boundary vs importing a Server Component into a client
   file. Then a `use(promise)` example: an RSC passes `dataPromise` as a prop, a `"use client"`
   child calls `const data = use(dataPromise)` under a `<Suspense>` parent.
3. `## State location decision tree` — a fenced ``` (no language) ASCII tree: one component →
   `useState`; parent+few descendants → lift; distant + low-frequency (theme/auth/locale) →
   Context; high-frequency shared → external store (Zustand/Jotai); server-derived → RSC fetch /
   TanStack Query. One line: most pages need neither context nor a global store.
4. `## Forms with React 19` — the full worked example: a zod schema, a `"use server"` action using
   `useActionState`, field-level errors mapped to inputs with `aria-invalid`/`aria-describedby`, a
   `useFormStatus` submit button as a **separate child component** (`tsx`). Then a paragraph:
   controlled when the value drives other UI / formats per keystroke; reach for React Hook Form /
   TanStack Form for multi-step / dynamic field arrays / cross-field validation.
5. `## useOptimistic` — full add-to-list example (`tsx`) with auto-revert on action error; comment
   explaining the revert behavior.
6. `## Suspense + Error Boundaries` — place boundaries near data; `error.tsx` is the App Router
   boundary; `react-error-boundary` for in-tree client boundaries; **boundaries do NOT catch event-
   handler or async errors**. One `tsx` snippet nesting `<ErrorBoundary><Suspense>...`.
7. `## useTransition / useDeferredValue` — `tsx` snippet: `startTransition` for a non-urgent filter
   update; `useDeferredValue` for an expensive filtered list with `useMemo` keyed on the deferred
   value.
8. `## Composition recipes` — `children` slot, named slots, compound components via Context
   (`<Tabs>`), and "prefer a hook over a render prop". Short `tsx` snippets each.
9. `## Context scope` — split contexts by change frequency to avoid cascades; `<Context value>`
   provider syntax (React 19). Small `tsx` showing two contexts.
10. `## Anti-patterns` — bullets with one-line `tsx` Bad → Good each: derived state in `useEffect`
    (derive during render); `useEffect`+`fetch` for app data (use RSC / TanStack Query); defining
    components inside components; `{count && <X/>}` renders `0` → use a ternary.

End with a `## See Also` line linking `data-and-caching.md`, `testing.md`, and the React Compiler
note in `performance.md`.

---

## 3. `references/data-and-caching.md` (target 360–460 lines)

ONE H1: `# Data fetching & caching — the two App Router models`. H2 order:

1. `## Mental model first` — the four caches: request memoization, data cache, full-route cache,
   client router cache. One sentence each. Then this comparison table:

```markdown
| Concern            | v15 baseline                                  | v16 Cache Components                          |
| ------------------ | --------------------------------------------- | --------------------------------------------- |
| Default `fetch`    | Uncached                                      | Dynamic; cache only inside `"use cache"`      |
| Opt-in cache       | `{ next: { revalidate, tags } }`, `unstable_cache` | `"use cache"` + `cacheLife()` + `cacheTag()` |
| Invalidate         | `revalidateTag` / `revalidatePath`            | `updateTag` / `revalidateTag`                 |
| Request dedupe     | `React.cache`                                 | `React.cache`                                 |
| Static/dynamic     | route segment config (`dynamic`, `revalidate`)| PPR by default (static shell + streamed holes)|
```

2. `## v15 model in full` — worked `ts` examples for: uncached `fetch`; `{ cache: 'force-cache' }`;
   `{ next: { revalidate: 3600, tags: ['posts'] } }`; route segment config block
   (`export const dynamic = 'force-dynamic'`, `export const revalidate = 3600`,
   `export const fetchCache`, `export const runtime`); `React.cache(getUser)`; `unstable_cache(fn,
   ['key'], { tags: ['posts'], revalidate: 60 })`; note `cookies()`/`headers()` opt a route into
   dynamic rendering.
3. `## v16 Cache Components in full` — `ts`: enable `cacheComponents: true` in `next.config.ts`;
   `"use cache"` at file / component / function level; `cacheLife('minutes' | 'hours')` and a custom
   profile; `cacheTag('products')` + `updateTag('products')`; a constraints table:

```markdown
| Inside `"use cache"` you may NOT…        | Do this instead                          |
| ---------------------------------------- | ---------------------------------------- |
| call `cookies()` / `headers()`           | read outside, pass the value as an arg    |
| read `searchParams`                      | pass the parsed value as an arg           |
| close over a request-scoped Promise      | await/resolve it outside, pass the result |
```

   Plus one-liners on `"use cache: private"` and `"use cache: remote"`, and a note that PPR streams
   dynamic holes inside an otherwise-cached shell. Then a **build-hang trap** Good/Bad `ts` pair
   (dynamic Promise into `use cache` → fix by resolving outside).
4. `## Mutations via Server Actions` — `ts`: the read → mutate → `revalidateTag`/`updateTag` →
   typed-result pattern; pair with optimistic UI (cross-link `react.md`).
5. `## Forms end-to-end` — ONE complete runnable example (`ts` + `tsx`): zod schema → `z.infer`
   shared type → Server Action with `safeParse` returning a discriminated union with a
   `fieldErrors` map → a client form via `useActionState` mapping `fieldErrors` to inputs with
   `aria-invalid`/`aria-describedby` → an optimistic update. This is the load-bearing example;
   make it correct and complete.
6. `## Client cache layer (TanStack Query)` — when to add it on top of RSC: client mutations,
   infinite scroll, cross-component client cache. Short `tsx` `useQuery` example; one line: rely on
   RSC by default, reach for TanStack Query when the data lives client-side.

End with `## See Also` → `react.md`, `security.md`, `testing.md`.

---

## 4. `references/testing.md` (target 320–400 lines)

ONE H1: `# Testing Next.js — Vitest 3, RTL, MSW 2, Playwright`. H2 order:

1. `## Stack & config` — `ts` `vitest.config.ts` with `environment: 'jsdom'`, `setupFiles`,
   v8 coverage with thresholds; `ts` `vitest.setup.ts` importing `@testing-library/jest-dom/vitest`;
   a note on mocking `next/navigation` and `next/headers` in unit tests.
2. `## RTL behavior testing` — query priority (role/label first, `getByTestId` last);
   `userEvent.setup()` once per test; async `findBy`/`waitFor`; a `test-utils.tsx` provider wrapper.
   One `tsx` form-submission test.
3. `## MSW 2` — `ts` `setupServer` using `http`/`HttpResponse`, `onUnhandledRequest: 'error'`,
   `beforeAll/afterEach/afterAll`; a per-test `server.use(...)` override returning a 500.
4. `## Testing Server Actions` — `ts`: extract the pure logic; call the action with a `FormData`,
   mock `auth()` and the DB (`vi.mock`), assert the typed result AND that `revalidateTag` was called
   (`vi.mock('next/cache')`). Caveat: `"use server"` files run server-side — test the function, not
   a rendered tree.
5. `## Testing Route Handlers` — `ts`: import `GET`/`POST`, call with `new Request(url, {...})`,
   assert `res.status` and `await res.json()`; mock auth and deps.
6. `## RSC caveat` — bold: async Server Components are NOT reliably renderable in jsdom. Unit-test
   the data functions they call; cover rendered pages with Playwright e2e.
7. `## Playwright e2e` — `ts` `playwright.config.ts` with
   `webServer: { command: 'next build && next start', url, reuseExistingServer: !process.env.CI }`;
   a real flow test (`login → submit a form action → assert the revalidated UI`); `page.route` for
   network stubbing; an `@axe-core/playwright` a11y smoke.
8. `## Coverage targets & commands` — a small table (utilities ≥90%, hooks ≥85%, presentational
   ≥80%, container ≥70%, pages → e2e) and a `bash` block with `vitest run`, `vitest run --coverage`,
   `playwright test`.

End with `## Anti-patterns` (bullets: `container.querySelector`, asserting render counts, mocking
React, ignoring `act()` warnings, snapshotting RSC pages) and a `## See Also` line.

---

## 5. `references/performance.md` (target 300–380 lines)

ONE H1: `# Next.js performance — Core Web Vitals, images, fonts, bundles, streaming`. H2 order:

1. `## Core Web Vitals map` — table:

```markdown
| Metric | Target  | Primary levers                                          |
| ------ | ------- | ------------------------------------------------------- |
| LCP    | < 2.5s  | `next/image priority`, kill waterfalls, resource hints  |
| CLS    | < 0.1   | image dimensions, `next/font`, reserve Suspense space   |
| INP    | < 200ms | smaller bundles, fewer re-renders, defer 3rd-party JS   |
```

2. `## Waterfalls` — `ts` Good/Bad: sequential `await` vs `Promise.all`; start-early/await-late;
   cheap sync checks before `await`; split sibling fetches into parallel child components; `<Suspense>`
   to stream. (Mirror the Vercel-derived patterns but rewritten.)
3. `## Images` — `tsx`: `next/image` with width/height; `fill` + sized parent; `priority` on the LCP
   image; `sizes`; `images.remotePatterns` allowlist in `next.config.ts`.
4. `## Fonts` — `tsx`: `next/font/google` and `next/font/local`, `display: 'swap'`, `subsets`,
   applied via `className`; one line on why this kills CLS and a round-trip.
5. `## Bundle` — `ts`/`tsx`: `optimizePackageImports` in config; direct imports over barrels;
   `next/dynamic(() => import(...), { ssr: false })`; `@next/bundle-analyzer` wiring;
   `next/script` strategies (`afterInteractive`, `lazyOnload`).
6. `## PPR / streaming` — static shell + dynamic holes; reserve space to avoid CLS; short `tsx`.
7. `## Edge vs Node runtime` — bullets: edge = low latency, limited APIs; node = full APIs. When to
   pick which.
8. `## React Compiler` — note: with `reactCompiler: true`, demote manual `useMemo`/`useCallback`/
   `React.memo` to review-only.
9. `## Measurement` — read `next build` first-load JS output; Lighthouse / `web-vitals`; Chrome
   DevTools performance trace pointer; the `chrome-devtools-mcp` skill as an option.

End with `## See Also` → `react.md`, `data-and-caching.md`.

---

## 6. `references/security.md` (target 280–360 lines)

ONE H1: `# Next.js security — auth, CSRF, XSS, CSP, env, SSRF`. H2 order:

1. `## Auth on every Server Action / Route Handler / DAL` — the load-bearing rule. `ts`: a guarded
   action (`auth()` first, role check, then mutate) + a DAL `getCurrentUser()` wrapped in
   `React.cache` that `redirect('/login')` when there is no session.
2. `## CSRF` — Server Actions are same-origin POST; rely on SameSite cookies + Next's built-in
   Origin/Host check; add `serverActions.allowedOrigins` in `next.config.ts`; never expose a mutation
   as an unauthenticated GET. Short `ts`.
3. `## XSS` — avoid `dangerouslySetInnerHTML`; if unavoidable, sanitize with DOMPurify on the
   server; never interpolate user input into `<script>` or URLs. Good/Bad `tsx`.
4. `## Env exposure` — table of server-only vs public; `import 'server-only'` guard on a secret
   module (`ts`); proxy a third-party API through a Route Handler instead of shipping the key.

```markdown
| Variable form            | Visible in browser? | Use for                          |
| ------------------------ | ------------------- | -------------------------------- |
| `DATABASE_URL`, `API_KEY`| No (server only)    | secrets, DB, server-to-server     |
| `NEXT_PUBLIC_*`          | Yes (inlined)       | public, non-secret config only    |
```

5. `## SSRF` — `ts`: a Route Handler taking a user URL must allowlist host + scheme, block internal/
   metadata ranges (`169.254.169.254`, `localhost`, RFC1918), and disable redirects to internal
   hosts. Good/Bad pair.
6. `## Security headers / CSP` — `ts`: a nonce-based CSP set in `proxy.ts`/`middleware.ts` (generate
   nonce, set `Content-Security-Policy`, pass nonce to `<Script nonce>`), plus
   `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`,
   `frame-ancestors`.
7. `## Cookies` — `httpOnly`, `secure`, `sameSite: 'lax'`; session rotation on privilege change.

End with `## See Also`: "Complements `secure-coding` (generic). This file is the Next.js-specific
layer." Link `../secure-coding/SKILL.md`.

---

## 7. `scripts/verify.sh` (write EXACTLY this, then `chmod +x`)

Write this file verbatim. Do NOT execute it in this repo.

```bash
#!/usr/bin/env bash
set -euo pipefail

# verify.sh — Next.js App Router project gate.
#
# Usage:
#   bash scripts/verify.sh            # run from the Next.js project root
#
# What it does (in order): ESLint -> tsc --noEmit -> Vitest -> next build.
# Each tool is detected; if it is not installed/resolvable, it is skipped with a
# yellow warning (NOT a failure). Exits non-zero only on a real tool failure.
# Safe to re-run: read-only, no writes, no installs, no network.

# --- colors (only when stdout is a TTY) -----------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

failures=0
skips=()

have() { command -v "$1" >/dev/null 2>&1; }
warn() { printf '%s\n' "${YELLOW}SKIP: $1${RESET}"; skips+=("$2"); return 0; }
fail() { printf '%s\n' "${RED}FAIL: $1${RESET}"; failures=$((failures + 1)); }
ok()   { printf '%s\n' "${GREEN}OK: $1${RESET}"; }

# --- resolve a package runner from the lockfile ----------------------------
if [ -f pnpm-lock.yaml ] && have pnpm; then
  RUN="pnpm exec"
elif [ -f yarn.lock ] && have yarn; then
  RUN="yarn"
elif [ -f package-lock.json ] && have npm; then
  RUN="npm exec --"
elif have npx; then
  RUN="npx --no-install"
else
  RUN=""
fi

run_bin() {
  # run_bin <bin-name> <args...> : true if the bin is resolvable and runs
  local bin="$1"; shift
  if have "$bin"; then "$bin" "$@"; return $?; fi
  if [ -x "node_modules/.bin/$bin" ]; then "node_modules/.bin/$bin" "$@"; return $?; fi
  if [ -n "$RUN" ]; then $RUN "$bin" "$@"; return $?; fi
  return 127
}

bin_available() {
  local bin="$1"
  have "$bin" && return 0
  [ -x "node_modules/.bin/$bin" ] && return 0
  return 1
}

# --- 1. ESLint -------------------------------------------------------------
if bin_available eslint; then
  printf '%s\n' "Running ESLint..."
  if run_bin eslint .; then ok "eslint"; else fail "eslint"; fi
elif bin_available next; then
  printf '%s\n' "Running next lint..."
  if run_bin next lint; then ok "next lint"; else fail "next lint"; fi
else
  warn "eslint not resolvable — skipping lint" "eslint"
fi

# --- 2. TypeScript ---------------------------------------------------------
if bin_available tsc && [ -f tsconfig.json ]; then
  printf '%s\n' "Running tsc --noEmit..."
  if run_bin tsc --noEmit; then ok "tsc --noEmit"; else fail "tsc --noEmit"; fi
else
  warn "tsc or tsconfig.json missing — skipping type check" "tsc"
fi

# --- 3. Vitest -------------------------------------------------------------
has_tests=false
if ls vitest.config.* >/dev/null 2>&1; then has_tests=true; fi
if find . -path ./node_modules -prune -o \
     \( -name '*.test.*' -o -name '*.spec.*' \) -print 2>/dev/null | grep -q .; then
  has_tests=true
fi
if bin_available vitest && [ "$has_tests" = true ]; then
  printf '%s\n' "Running vitest run..."
  if run_bin vitest run; then ok "vitest"; else fail "vitest"; fi
else
  warn "vitest or tests not present — skipping unit tests" "vitest"
fi

# --- 4. next build (slow/expensive — last) ---------------------------------
if bin_available next; then
  printf '%s\n' "Running next build... (Turbopack is the default builder on Next.js 16)"
  if run_bin next build; then ok "next build"; else fail "next build"; fi
else
  warn "next not resolvable — skipping build" "next build"
fi

# --- summary ---------------------------------------------------------------
printf '\n'
if [ "${#skips[@]}" -gt 0 ]; then
  printf '%s\n' "${YELLOW}skipped: ${skips[*]}${RESET}"
fi
if [ "$failures" -gt 0 ]; then
  printf '%s\n' "${RED}verify.sh: $failures check(s) failed${RESET}"
  exit 1
fi
printf '%s\n' "${GREEN}verify.sh: all runnable checks passed${RESET}"
exit 0
```

After writing the file:

```bash
chmod +x /Volumes/EXTERN/DEV/skills/skills/nextjs/scripts/verify.sh
```

Do NOT run it.

---

## 8. Acceptance checks (implementer self-verifies before finishing)

Run/verify all of these:

1. **All 7 files exist** at the exact paths in §0. `find /Volumes/EXTERN/DEV/skills/skills/nextjs
   -type f` lists exactly them.
2. **Frontmatter**: SKILL.md frontmatter has `name: nextjs`, the `description` string starts with
   `Use when `, and `origin: risco`. No other frontmatter keys.
3. **One H1 per file**: every `.md` file has exactly one `# ` H1 line. (`grep -c '^# '` returns 1.)
4. **Line budgets**: SKILL.md is 250–450 lines (aim 360–430). Each `references/*.md` is 200–500
   lines. Adjust prose density to land in range — do not pad.
5. **Fenced code tags**: every opening ``` fence has a language tag (`tsx`/`ts`/`bash`/`yaml`/`json`)
   except the single ASCII state-tree fence in `react.md`. No bare ``` opening fences elsewhere.
   Verify fences are balanced (even count of ``` per file).
6. **No placeholders**: zero `TODO`, `FIXME`, `XXX`, `...etc`, `<placeholder>`, or "your code here".
   Every code block is correct and runnable in context.
7. **Code correctness spot-checks**:
   - `params`/`searchParams` typed as `Promise<...>` and `await`ed in every page snippet.
   - Every Server Action snippet calls `auth()` (or a DAL) before mutating.
   - `useActionState` returns `[state, action, isPending]` (3-tuple), not `useFormState`.
   - No `cookies()`/`headers()` read INSIDE a `"use cache"` block (the Good example reads outside).
   - `next/image` snippets always have width/height or `fill`.
   - MSW snippet imports `http`/`HttpResponse` from `msw` (v2 API), not `rest`.
8. **Headings consistent**: H2 sections match the order specified in this plan; no skipped heading
   levels (no H1→H3 jumps).
9. **verify.sh is executable**: `test -x /Volumes/EXTERN/DEV/skills/skills/nextjs/scripts/verify.sh`
   succeeds; first line is `#!/usr/bin/env bash`; second line is `set -euo pipefail`; a usage comment
   block is present. Run `bash -n scripts/verify.sh` (syntax check only — do NOT execute the gate).
10. **See Also links**: SKILL.md `## See Also` links sibling skills via relative paths
    (`../secure-coding/SKILL.md`, `../fastapi/SKILL.md`, `../go/SKILL.md`, `../postgresdb/SKILL.md`,
    `../risco-project-harness/SKILL.md`). Each `references/*.md` ends with a `## See Also` linking at
    least one sibling reference or skill.
11. **Cross-references resolve**: every `references/...md` path mentioned in SKILL.md corresponds to a
    file that was actually created.
12. **Dual-model rule present**: SKILL.md contains the detection gate table and the explicit "Do not
    flag `proxy.ts`, `use cache`, or `cacheComponents` as errors" line.

If any check fails, fix the file and re-verify. Only then report completion.
