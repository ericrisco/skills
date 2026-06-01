# DESIGN SPEC — skill `nextjs`

Title: **Next.js App Router (RSC, server actions) + React + TS**
Origin: `risco`. Audience: an LLM coding agent editing a real Next.js app in a polyglot
workspace (FastAPI/Python, Next.js, Go, Flutter, Postgres). Tone: directive, dense,
copy-pasteable, Good/Bad contrasts.

---

## 0. Research baseline (folded into the skill — versions stated explicitly)

Confirmed via web (June 2026):

- **Next.js stable line: 16.x** (16.2.6 on 2026-05-31). The task names "Next.js 15"; the
  skill targets **Next.js 15 App Router as the documented baseline** and treats
  **Next.js 16 / Cache Components as the current evolution**, both stable. SKILL.md must
  prevent the agent from misflagging correct v16 code.
- **Caching model split — this is the #1 correctness trap and the skill leads with it:**
  - **Next.js 15 model** ("caching without cache components"): `fetch` is **uncached by
    default**; opt into caching with `fetch(url, { cache: 'force-cache' })` or
    `next: { revalidate, tags }`; GET Route Handlers and Client Router Cache uncached by
    default; `unstable_cache`, `revalidateTag`, `revalidatePath`, `React.cache` for
    request memoization.
  - **Next.js 16 model** (`cacheComponents: true` in `next.config.ts`): everything dynamic
    by default; opt in with the **`use cache`** directive (file/component/function),
    `cacheLife()` profiles, `cacheTag()`, `updateTag()`/`revalidateTag()`,
    `use cache: private`, `use cache: remote`. Implements PPR (static shell + streamed
    dynamic) as default behaviour. `use cache` was experimental in v15.0, enabled in v16.0.
  - **Rule the skill enforces:** detect which model the repo uses (presence of
    `cacheComponents` / `use cache` / `ppr` in config) before prescribing or reviewing
    caching. Never mix advice.
- **React 19 stable** (App Router on v15; v16 App Router uses React 19.2 canary). New hooks:
  `use()` (reads Promise/Context, can be conditional), `useActionState` (replaces
  `useFormState`, adds `isPending`), `useFormStatus`, `useOptimistic` (auto-revert on error),
  `ref` as a prop (no `forwardRef`), `<Context>` as provider, document metadata hoisting.
- **React Compiler stable** (`reactCompiler: true` promoted from experimental in v16). When
  enabled, manual `useMemo`/`useCallback`/`React.memo` become review-only noise.
- **Turbopack** is the default dev (and prod build) bundler in v16; `next build --turbopack`.
- **Middleware filename:** `middleware.ts` on v15; **`proxy.ts`** on v16 (do NOT flag
  `proxy.ts` as misnamed). Middleware/proxy is **routing, NOT a security boundary**.
- **Auth:** Auth.js v5 (`next-auth@5`, exported `auth()` helper). Defense-in-depth: middleware
  for coarse redirects + **explicit `auth()` check in every Server Action, Route Handler, and
  a Data Access Layer (DAL)**. Server Actions are public POST endpoints; middleware never
  protects them.
- **Testing:** Vitest 3 + React Testing Library + `@testing-library/user-event` + MSW 2
  (`http`/`HttpResponse`). RSC async components are not fully renderable in jsdom → unit-test
  extracted data/logic functions; cover RSC pages and Server Actions wiring with Playwright e2e.
- **Security:** XSS via `dangerouslySetInnerHTML`, CSRF on Server Actions (SameSite + Origin),
  `NEXT_PUBLIC_*` leakage, SSRF in Route Handlers/`fetch`, CSP via `proxy.ts`/headers with
  nonce. Cross-link sibling `secure-coding` skill.
- **Performance:** `next/image`, `next/font` (zero-layout-shift, self-host), `next/dynamic`,
  `optimizePackageImports`, `@next/bundle-analyzer`, PPR/streaming, Core Web Vitals
  (LCP/CLS/INP — INP replaced FID).

Sources to cite inline in references (not as a wall): nextjs.org/blog/next-15,
nextjs.org/blog/next-16, the `use cache` / `cacheComponents` / `cacheLife` docs,
react.dev/blog react-19, authjs.dev session-management/protecting.

---

## 1. Purpose & precise trigger

**Purpose (one line in frontmatter `description`, trigger-rich, starts with "Use when"):**
> Use when building, reviewing, testing, securing, or optimizing a Next.js App Router app
> (Next.js 15/16, React Server Components, `"use client"`/`"use server"`, server actions,
> route handlers, layouts, streaming/Suspense, the App Router caching model, TypeScript,
> Auth.js, vitest/Playwright, CSP/security headers). Triggers on `app/` directory work,
> `next.config.ts`, `proxy.ts`/`middleware.ts`, server actions, route handlers, `use cache`,
> `useActionState`, RSC boundary questions, hydration errors, and Next.js perf/Core Web Vitals.

**When to use:** editing/creating files under `app/`; deciding Server vs Client Component;
writing server actions or route handlers; wiring forms with `useActionState`+zod; configuring
caching/revalidation; adding auth/middleware/CSP; diagnosing hydration mismatches, waterfalls,
or bundle bloat; writing vitest/Playwright tests for Next.js code.

**When NOT to use:** Pages Router (`pages/`) projects → note the difference, defer to Next.js
Pages docs; pure React-without-Next (Vite/CRA SPA) → use a generic React skill; React Native;
non-Next backend work (FastAPI/Go) → sibling backend skills. Generic React component-shape
questions with no Next.js/RSC dimension → keep it brief and point to `references/react.md`.

---

## 2. SKILL.md outline (every heading + delivery note + concrete examples)

Target length **~360–430 lines**. One H1. YAML frontmatter: `name: nextjs`,
`description:` (the trigger string above), `origin: risco`.

### `# Next.js App Router — RSC, Server Actions, React 19, TypeScript`
One-line purpose statement.

### `## When to use / When NOT to use`
Two tight bullet lists (from §1).

### `## First: detect the project's version & caching model`
THE gate. A 4-line decision block the agent runs before prescribing anything:
- read `package.json` `next` version; read `next.config.{ts,js}` for `cacheComponents`,
  `ppr`, `reactCompiler`, `experimental`.
- `proxy.ts` present ⇒ v16; `middleware.ts` ⇒ v15.
- `cacheComponents: true` or any `use cache` ⇒ **Cache Components model** (opt-in caching).
  Otherwise ⇒ **v15 model** (uncached fetch by default, `revalidate`/`tags`).
- "Do not flag `proxy.ts`, `use cache`, or `cacheComponents` as errors — they are correct
  on v16." Small table: signal → model → which caching API to use.

### `## The boundary: Server vs Client Components`
The core mental model. Decision rules + the four boundary laws.
- Good/Bad: default = Server Component (async, can touch DB/secrets, ships zero JS); add
  `"use client"` only for state/effects/event handlers/browser APIs.
- Boundary laws: Server→Client pass **serializable** props or `children`; never `import` a
  Server Component into a Client Component (compose via `children`); `"use client"` marks a
  module + everything it imports as client; keep `"use client"` leaves small and push it down.
- Code: a Server page rendering a small `"use client"` island; the `children` composition
  pattern to keep a client shell wrapping server content.

### `## "use server": Server Actions`
What they are, the security imperative, the canonical shape.
- Code: `actions.ts` with `"use server"`, zod parse, **`auth()` check first**, mutation,
  `revalidateTag`/`revalidatePath`, typed return `{ ok } | { error }`.
- BANNER rule (bold): **every Server Action authenticates and authorizes itself** — it is a
  public POST endpoint; middleware does not protect it. Cross-ref security.md.
- Two invocation modes: `<form action={fn}>` and imperative from a client handler inside
  `startTransition`.

### `## Route Handlers (`route.ts`)`
When to use a Route Handler vs a Server Action (webhooks, public JSON API, non-form clients,
streaming responses, OAuth callbacks) vs **not** (internal mutations → prefer Server Actions).
- Code: typed `GET`/`POST` with `Request`/`NextResponse`, zod body validation, auth check,
  `Response.json`. Note v15 GET handlers uncached by default; `export const dynamic`,
  `export const runtime = 'edge' | 'nodejs'`.

### `## Layouts, templates, loading & error boundaries`
File-convention map + when each runs.
- Bullet/table: `layout.tsx` (persists, no remount), `template.tsx` (remounts per nav),
  `loading.tsx` (Suspense fallback for the segment), `error.tsx` (`"use client"` boundary with
  `reset`), `not-found.tsx`, `global-error.tsx`.
- Code: an `error.tsx` (client, `reset()`), a `loading.tsx`, and a streamed page using explicit
  `<Suspense>` around a slow async child to paint the shell first.

### `## Routing features: groups, parallel, intercepting, dynamic, metadata`
Compact reference with one example each.
- Route groups `(marketing)`; dynamic `[id]`/`[...slug]`; **`params`/`searchParams` are
  Promises in v15+** → `await params`; parallel routes `@modal` + `default.tsx`; intercepting
  `(.)photo` for modal-on-navigation; `generateMetadata` async + `generateStaticParams`.
- Good/Bad: forgetting to `await params` (a top v15 migration bug).

### `## Caching & data fetching (both models)`
The dense crux; deep dive pushed to `references/data-and-caching.md`.
- **v15 model** block: uncached fetch; `{ next: { revalidate: 3600, tags: ['x'] } }`;
  `revalidateTag`/`revalidatePath`; `unstable_cache`; `React.cache` for request memoization;
  `dynamic`/`revalidate`/`fetchCache` route segment config.
- **v16 Cache Components** block: `cacheComponents: true`; `"use cache"` at file/fn/component;
  `cacheLife('hours')`; `cacheTag('products')` + `updateTag`; constraints (no `cookies()`/
  `headers()`/`searchParams` inside `use cache` — pass as args); PPR static shell + stream.
- Good/Bad: `cookies()` inside `use cache` (build hang) → read outside, pass value.
- Pointer to references for optimistic UI, `useActionState`+zod forms, mutation patterns.

### `## React 19 in the App Router (essentials)`
Just the Next-relevant deltas; full discipline in `references/react.md`.
- `useActionState(fn, initial)` returns `[state, action, pending]`; `useFormStatus()` for
  child submit buttons; `useOptimistic`; `use(promise)` to unwrap a Promise prop passed from
  an RSC; `ref` as prop / `<Context value>` provider. Note React Compiler: if enabled, drop
  manual memoization.

### `## TypeScript discipline`
- `strict: true` + `noUncheckedIndexedAccess`; typed routes (`typedRoutes`/`experimental.typedRoutes`);
  **zod-inferred end-to-end types** (`z.infer`) shared by action input, form, and DB layer;
  discriminated-union action result `{ status: 'ok'; data } | { status: 'error'; message }`;
  typed `searchParams`/`params` as `Promise<…>`.
- Good/Bad: `any` formData vs `z.parse(Object.fromEntries(formData))`.

### `## Auth (Auth.js v5) — defense in depth`
- Three layers: `proxy.ts`/middleware (coarse redirect, NOT security), `auth()` in every
  Server Action & Route Handler, a **Data Access Layer** that re-checks session before any
  read/write. Secure cookies (`httpOnly`, `secure`, `sameSite: 'lax'`). Pointer to security.md.
- Code: minimal `auth.ts` config + a guarded server action + a `getCurrentUser()` DAL with
  `React.cache`.

### `## Security (embedded, deep dive → references/security.md)`
Checklist the agent applies on every review:
- No raw `dangerouslySetInnerHTML` without sanitize; CSRF (Server Actions check Origin/Host,
  SameSite cookies); **never put secrets in `NEXT_PUBLIC_*`**; SSRF — validate/allowlist URLs
  in Route Handlers before `fetch`; CSP with nonce via `proxy.ts`; auth on every action.
- "See Also: `secure-coding`."

### `## Performance (deep dive → references/performance.md)`
- `next/image` (width/height or `fill`, `priority` for LCP), `next/font` (self-host, no CLS),
  `next/dynamic` for heavy client islands, `optimizePackageImports`, `@next/bundle-analyzer`,
  PPR/streaming, parallel `Promise.all` to kill waterfalls, Core Web Vitals targets
  (LCP < 2.5s, CLS < 0.1, INP < 200ms).

### `## Anti-patterns → STOP (rationalizations table)`
Markdown table `Rationalization → Reality`. ~10 rows. Examples:
- "The Client Component already checks the user, the action is safe" → No. Actions are public
  POST endpoints; authenticate inside the action.
- "`fetch` caches by default so I'll skip revalidate" → No (v15): fetch is uncached by default;
  this is the v13/14 mental model.
- "I'll read `cookies()` inside `use cache` for convenience" → No: build hangs / errors; read
  outside, pass as argument.
- "`proxy.ts` looks misnamed, I'll rename to `middleware.ts`" → No: correct on v16; renaming
  breaks middleware.
- "Just `import` the Server Component into this `"use client"` file" → No: compose via
  `children`.
- "Put the API key in `NEXT_PUBLIC_API_KEY` so the client can call it" → No: it ships to the
  browser; proxy through a Route Handler/Server Action.
- "Add `useMemo` everywhere for perf" → No (React Compiler / measure first).
- "`await params` is unnecessary" → No on v15+: `params`/`searchParams` are Promises.
- "Middleware protects my dashboard, so the data fetch is safe" → No: middleware is not a
  security boundary; check in the DAL.
- "Snapshot-test the RSC page" → No: test data fns + Playwright e2e.

### `## Quick reference`
One compact table: task → API/file → note. Rows: new mutation → Server Action; public JSON →
Route Handler; per-request dedupe → `React.cache`; cache cross-request (v15) →
`unstable_cache`/`fetch tags`; cache (v16) → `use cache`+`cacheTag`; invalidate →
`revalidateTag`/`updateTag`/`revalidatePath`; loading UI → `loading.tsx`/`<Suspense>`; error
UI → `error.tsx`; form → `useActionState`+zod; optimistic → `useOptimistic`; client island →
`"use client"` leaf; secrets → server only; image → `next/image priority`; protect route →
middleware + DAL.

### `## Verify`
One block: run `bash scripts/verify.sh` from the project root; explain it runs eslint, `tsc
--noEmit`, vitest, and `next build`, skipping any tool not installed.

### `## References` + `## See Also`
- `references/react.md`, `references/data-and-caching.md`, `references/testing.md`,
  `references/performance.md`, `references/security.md`.
- See Also: `secure-coding`; sibling backend skills (FastAPI/Go) for the API the frontend
  calls; `risco-project-harness` for workspace conventions.

---

## 3. references/ files — outline + key code per file

Each 200–500 lines, language-tagged fences, Good/Bad contrasts, both caching models flagged
where relevant.

### `references/react.md` (~320 lines) — React 19 discipline for the App Router
- **Hooks discipline:** top-level only; cleanup every subscription; functional updaters;
  default = no memoization (React Compiler note).
- **Server vs Client deep dive:** the import-graph rule; passing Server Actions / `children`
  across the boundary; `use(promise)` to unwrap an RSC-passed Promise in a Client Component
  with a `<Suspense>` parent.
- **State location decision tree** (one component → useState; lift; Context for low-freq;
  external store for high-freq; server state via RSC/TanStack Query).
- **Forms with React 19:** full `useActionState` + zod example; `useFormStatus` submit button
  as a separate child component; controlled vs uncontrolled guidance; when to reach for React
  Hook Form / TanStack Form.
- **`useOptimistic`** full example (add-to-list with auto-revert on action error).
- **Suspense + Error Boundaries:** place boundaries near data; `error.tsx` is the App Router
  boundary; `react-error-boundary` for in-tree client boundaries; boundaries don't catch event
  handler/async errors.
- **`useTransition` / `useDeferredValue`** for non-urgent updates and expensive filtered lists.
- **Composition recipes:** children slots, named slots, compound components via Context,
  hook-over-render-prop.
- **Context scope:** split contexts by change frequency to avoid cascades; `<Context value>`
  provider syntax (React 19).
- **Anti-patterns:** derived state in `useEffect`; `useEffect`+`fetch` for app data; defining
  components inside components; `{count && …}` (renders `0`) → ternary.

### `references/data-and-caching.md` (~400 lines) — the two caching models, mutations, forms
- **Mental model first:** request memoization vs data cache vs full-route cache vs router
  cache; how v15 (implicit-off) and v16 (explicit `use cache`) differ. A comparison table.
- **v15 model in full:** uncached `fetch`; `{ cache: 'force-cache' }`;
  `{ next: { revalidate, tags } }`; route segment config (`export const dynamic`,
  `revalidate`, `fetchCache`, `runtime`); `React.cache` request dedupe; `unstable_cache(fn,
  keys, { tags, revalidate })`; `revalidateTag`/`revalidatePath` from a Server Action;
  `cookies()`/`headers()` opt a route into dynamic.
- **v16 Cache Components in full:** enable `cacheComponents: true`; `"use cache"` at
  file/component/function; `cacheLife('minutes'|'hours'|custom)`; `cacheTag` + `updateTag`;
  constraints table (no request APIs inside `use cache`; pass args; closure capture becomes
  cache key); `use cache: private` / `use cache: remote` one-liners; PPR shell + stream;
  the build-hang trap (dynamic Promise into `use cache`) with the fix.
- **Mutations via Server Actions:** read→mutate→`revalidateTag`/`updateTag`→return typed
  result; optimistic UI pairing.
- **Forms end-to-end:** zod schema → `z.infer` shared type → `useActionState` action with
  `safeParse` → field-level errors mapped back to inputs (`aria-invalid`/`aria-describedby`)
  → optimistic update. One complete, runnable form.
- **Client cache layer:** when to add TanStack Query on top (client mutations, infinite
  scroll, cross-component cache) vs rely on RSC.

### `references/testing.md` (~360 lines) — vitest + RTL + Playwright + MSW
- **Stack & config:** Vitest 3 config (`environment: 'jsdom'`, `setupFiles`, v8 coverage
  thresholds); `vitest.setup.ts` with `@testing-library/jest-dom`; the
  `next/navigation`/`next/headers` mock note.
- **RTL behavior testing:** query priority (role/label first, testId last); `userEvent.setup()`;
  async `findBy`/`waitFor`; `test-utils.tsx` provider wrapper.
- **MSW 2:** `setupServer` with `http`/`HttpResponse`, `onUnhandledRequest: 'error'`,
  per-test `server.use` override for error paths.
- **Testing Server Actions:** extract the pure logic; call the action with a `FormData`,
  mock `auth()`/the DB, assert the typed result and that `revalidateTag` was called; the
  caveat that `"use server"` files run server-side.
- **Testing Route Handlers:** import `GET`/`POST`, call with a `new Request(...)`, assert
  `Response` status/json; mock auth and dependencies.
- **RSC caveat:** async Server Components are not reliably renderable in jsdom → unit-test the
  data functions they call; verify rendered output with Playwright e2e.
- **Playwright e2e:** `playwright.config.ts` with `webServer: { command: 'next build && next
  start' }`; a real flow (login → mutate via form action → assert revalidated UI); network
  stubbing via `page.route`; a11y smoke with `@axe-core/playwright`.
- **Coverage targets table** + commands (`vitest run`, `--coverage`, `playwright test`).

### `references/performance.md` (~340 lines) — CWV, images, fonts, bundles, streaming
- **Core Web Vitals map:** LCP/CLS/INP targets; which lever fixes which metric.
- **Waterfalls:** parallel `Promise.all`; start-early/await-late; cheap sync checks before
  `await`; split sibling fetches into parallel child components; `<Suspense>` to stream.
- **Images:** `next/image` always with dimensions or `fill`+sized parent; `priority` on the
  LCP image; `sizes` for responsive; remote `images` config allowlist.
- **Fonts:** `next/font/google` / `next/font/local` self-hosted, `display: 'swap'`, subset —
  eliminates CLS and a network round-trip.
- **Bundle:** `optimizePackageImports`; direct imports over barrels; `next/dynamic` (`ssr:
  false` for client-only heavy libs); `@next/bundle-analyzer` setup; `next/script`
  strategies for third-party.
- **PPR / streaming:** static shell + dynamic holes; reserve space to avoid CLS.
- **Edge vs Node runtime** trade-offs for latency.
- **React Compiler** note: with it on, demote manual memoization to review-only.
- **Measurement:** `next build` output reading (first-load JS), Lighthouse/`web-vitals`,
  Chrome DevTools performance trace pointer.

### `references/security.md` (~320 lines) — XSS, CSRF, CSP, env, SSRF, auth
- **Auth on every server action / route handler / DAL** (the load-bearing rule) with the
  guarded-action and DAL `React.cache` pattern.
- **CSRF:** Server Actions are POST to the same origin; rely on SameSite cookies + verify
  `Origin`/`Host` (Next does built-in checks; add `serverActions.allowedOrigins`); never
  expose mutations as unauthenticated GET.
- **XSS:** avoid `dangerouslySetInnerHTML`; if unavoidable, sanitize (DOMPurify on server);
  never interpolate user input into `<script>`/URLs.
- **Env exposure:** `NEXT_PUBLIC_*` ships to the browser — table of "server-only" vs
  "public"; `import 'server-only'` guard on secret modules; proxy third-party APIs through a
  Route Handler.
- **SSRF:** Route Handlers/`fetch` that take a user URL must allowlist host/scheme, block
  internal ranges/metadata endpoints, disable redirects to internal hosts.
- **Security headers / CSP:** set via `proxy.ts`/`middleware.ts` or `next.config` `headers()`;
  nonce-based CSP example wired through to `<Script nonce>`; `Strict-Transport-Security`,
  `X-Content-Type-Options`, `Referrer-Policy`, frame-ancestors.
- **Cookies:** `httpOnly`, `secure`, `sameSite`; session rotation.
- "See Also: `secure-coding`." States it complements, not duplicates, the generic skill.

---

## 4. verify.sh contract

Path: `skills/nextjs/scripts/verify.sh`, `chmod +x` after writing. **Do NOT run it in this
repo** (not a Next.js project).

- Shebang `#!/usr/bin/env bash`; `set -euo pipefail`. Top usage comment: run from the Next.js
  project root; gate for CI/pre-merge; safe to re-run (idempotent, read-only — no writes,
  no installs).
- Resolve a package runner: prefer `pnpm`/`yarn`/`npm` based on lockfile; fall back to `npx`.
  Helper `have()` using `command -v`; yellow `warn()` that prints and `return 0` (skip).
- Steps, in this exact order, each isolated so one skip doesn't abort the rest:
  1. **ESLint** — if `eslint` resolvable (local bin or `next lint` available) → run
     `eslint .` (or `next lint`). Missing → yellow warn + skip.
  2. **TypeScript** — if `tsc` resolvable and a `tsconfig.json` exists → `tsc --noEmit`.
     Missing → warn + skip.
  3. **Vitest** — if `vitest` resolvable AND a config (`vitest.config.*` or `vitest` key) or
     any `*.test.*`/`*.spec.*` exists → `vitest run`. Missing/no tests → warn + skip.
  4. **next build** — if `next` resolvable → `next build` (mention `--turbopack` is default on
     v16). Missing → warn + skip. This is the slow/expensive gate; run it last.
- Aggregate: track a `failures` counter; each real non-zero tool exit increments it and prints
  red `FAIL: <step>`; skips never increment. `exit 1` iff `failures > 0`, else `exit 0` with a
  green "all checks passed (skipped: …)" summary.
- Color via `tput` guarded by `[ -t 1 ]` so it's clean in CI logs. No network calls, no
  `npm install`.

---

## 5. Quality differentiators (why this beats the ECC equivalents)

1. **Dual caching-model awareness baked into a mandatory first step.** ECC's `nextjs-turbopack`
   is 57 lines on bundlers and hand-waves caching to "check the docs." This skill makes the
   agent *detect* v15-implicit-off vs v16 `use cache`/`cacheComponents` before giving any
   caching advice, with both APIs fully worked — directly preventing the most common
   real-world Next.js correctness bug.
2. **Security is first-class and Next-specific, not generic a11y/lint advice.** "Authenticate
   every Server Action / Route Handler + Data Access Layer," SSRF in Route Handlers, CSP nonce
   via `proxy.ts`, and `NEXT_PUBLIC_*` leakage are embedded in SKILL.md and deep-dived —
   ECC's React skills only touch "authenticate Server Actions" in one bullet.
3. **Correct for the *current* stable (Next.js 16 / React 19.2 / React Compiler / Turbopack /
   `proxy.ts`) while still teaching the v15 baseline** — and explicitly tells the agent NOT to
   misflag `proxy.ts`/`use cache`/`cacheComponents`, a failure mode generic skills cause.
4. **End-to-end TypeScript via zod inference** — one `z.infer` type shared across action input,
   form fields, discriminated-union result, and DB layer — versus ECC's loose `Object.fromEntries`
   examples.
5. **Testing that matches RSC reality:** explicit guidance that async Server Components aren't
   jsdom-renderable, so unit-test extracted data fns + Server Actions + Route Handlers and push
   page coverage to Playwright — ECC's `react-testing` predates RSC testing nuance.
6. **Runnable, idempotent `verify.sh` the user runs in their own repo** (eslint → tsc → vitest
   → next build, skip-not-fail on missing tools) — none of the ECC skills ship an executable
   project gate.
7. **Progressive disclosure done right:** a ~400-line directive SKILL.md with a
   rationalizations→STOP table and quick-reference, five focused 300–400-line references, and
   clean sibling cross-links (`secure-coding`, backend skills, harness) — matching house style
   from `risco-project-harness`.
8. **Waterfall + Core Web Vitals (INP, not legacy FID) performance guidance tied to concrete
   Next.js levers** (`next/image priority`, `next/font` self-host, `optimizePackageImports`,
   PPR streaming) rather than abstract React-perf rules.
