---
name: typescript
description: "Use when writing, reviewing, or fixing TypeScript type code (.ts/.tsx/.d.ts), modeling data with generics/unions/branded types, or configuring tsconfig and the build toolchain - the language and type system itself, not any runtime or framework. Triggers: \"make this generic preserve the literal type\", \"why won't this narrow / why won't TypeScript narrow this union\", \"type X is not assignable to type Y, fix the type not cast it\", \"set up a strict tsconfig with project references\", \"convert these magic strings into a discriminated union with exhaustiveness\", \"bundler vs nodenext moduleResolution\", \"configura el tsconfig en modo estricto y elimina los any\", \"por qué no estrecha el tipo\". NOT the Node runtime, fs/streams/http server (that is nodejs); NOT React/Next component wiring (that is react/nextjs); NOT ORM schema type-gen (that is drizzle-orm)."
tags: [typescript, types, generics, tsconfig, type-safety]
recommends: [nodejs, secure-coding, drizzle-orm]
origin: risco
---

# Idiomatic TypeScript types

Express data and contracts precisely in the TypeScript type system, and configure the
compiler so the types actually hold.

Targets **TypeScript 5.9** (current stable, Q1 2026): redesigned `tsc --init` defaults
(`module: nodenext`, `target: esnext`, `moduleDetection: force`, strict on), `import defer`
for deferred module evaluation, expandable editor hovers. The **TypeScript 7 native
compiler** (`tsgo`, the Go port) is in preview as `@typescript/native-preview` and
type-checks roughly 10x faster (VS Code's 1.5M LOC: 89s -> 8.74s) — adopt it for fast
local checks; stable 7.0 lands early 2026.

This is a *language* skill: the type system plus the compiler config. It is the canonical
authority for "how do I express this in TS and make `tsc` honor it", independent of any
runtime or framework.

## When to use / When NOT to use

**Use when:**

- Authoring or fixing type code: generics, constraints, overloads, conditional/mapped/
  template-literal types, utility types, narrowing, `.d.ts` declarations.
- Modeling data: discriminated unions, `satisfies`, branded/nominal types, exhaustiveness.
- Setting up or hardening `tsconfig.json`: strict flags, `moduleResolution`, project
  references, path aliases, declaration emit, `isolatedModules`/`verbatimModuleSyntax`.
- Diagnosing type errors: "why won't this narrow", "X is not assignable to Y", inference
  failures, `any`/`unknown` leakage, variance surprises.
- Choosing the build toolchain: `tsc` vs `tsgo` (TS7), `tsx`, bundler vs nodenext resolution.

**When NOT to use (delegate):**

- Node runtime/server code — event loop, `fs`, streams, `http` server, `process`, env -> `nodejs`.
- React/Next/Nest component or framework typing *in framework context* -> `react` / `nextjs` /
  `nestjs` (the type-level mechanics still come from here; the framework wiring does not).
- ORM schema-to-type generation (Drizzle/Prisma) -> `drizzle-orm` / `prisma-orm`.
- REST/contract shape design (status codes, resource naming) -> `api-design`.
- Test runner / coverage / E2E setup -> `testing-web` / `e2e-testing`.
- Language-agnostic injection/authz/threat review -> `secure-coding`.
- Python typing -> `python`; Go -> `go`.

## Boundary: language vs runtime vs framework

Three layers, three owners. **Language + compiler config lives here** (`tsconfig`, generics,
narrowing). **Runtime behavior** (how a stream backpressures, how the event loop schedules)
is `nodejs`. **Framework idioms** (component props, route maps, server-component typing) are
`react`/`nextjs`/`nestjs` — those *borrow* this skill's type mechanics but own their wiring.
A `tsconfig` question is here; a "stream backpressure" question is `nodejs`; a "type my
`useReducer` state" question is `react`.

## Decision rules

Apply these on every TypeScript edit:

1. **Prefer inference; annotate boundaries.** Let TS infer locals and returns; annotate
   function parameters, public APIs, and `.d.ts`. Why: redundant annotations drift from
   reality and suppress the better inferred type.
2. **`unknown`, never `any`.** `any` disables checking and leaks; `unknown` forces a narrow
   before use. Why: `any` silently poisons every downstream type it touches.
3. **`import type` for type-only imports**, with `verbatimModuleSyntax: true`. Why: it
   prevents emitting type-only imports as runtime `require`s and lets esbuild/swc transpile
   each file alone.
4. **Model state as discriminated unions, not optional-field bags.** A literal discriminant
   makes illegal states unrepresentable. Why: `{ data?: T; error?: E; loading?: bool }`
   permits `loading && error` — a union does not.
5. **`satisfies` for config objects, not a type annotation.** Why: annotation widens the
   value to the type (you lose literal keys); `satisfies` validates *without* widening, and
   catches discriminant typos at the construction site.
6. **Narrow, don't cast.** Reach for type guards, `in`, `typeof`, discriminant checks before
   `as`. Why: `as` asserts a claim the compiler cannot verify — it is a silenced error.
7. **`as` is a last resort, and only `as <narrower>` or `as unknown as T` at true I/O
   boundaries.** Why: `as` to a *wider* or unrelated type is almost always a real bug hidden.
8. **One `tsconfig` base, extended per package.** A shared `tsconfig.base.json` holds strict
   flags; each package `extends` it and sets only `outDir`/`rootDir`/references. Why: a single
   giant config can't express per-package module targets and breaks project references.
9. **Turn on `noUncheckedIndexedAccess`.** Why: `arr[i]` and `record[key]` are `T | undefined`
   in reality — without this flag TS lies and you get runtime `undefined`.
10. **Make unions exhaustive with a `never` guard.** A `default: const _: never = x` in
    every switch over a union turns "added a case, forgot a branch" into a compile error.

## The type-system toolbox

### Generics + constraints, and `const` type parameters

Constrain type parameters so callers get errors at the call site, and use a `const` type
parameter (TS 5.0+) to preserve literal inference without `as const` everywhere:

```ts
// Bad: unconstrained T, and the literal "a"|"b" widens to string.
function pick<T>(obj: T, key: string) { return (obj as any)[key]; }

// Good: K is constrained to obj's keys; const T keeps the literal union.
function pick<const T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}
const r = pick({ a: 1, b: "x" } as const, "b"); // r: "x", not string
```

### `unknown` over `any` at every boundary

```ts
// Bad: any flows everywhere, no error ever fires downstream.
function parse(json: string): any { return JSON.parse(json); }

// Good: unknown forces a narrow before the value is trusted.
function parse(json: string): unknown { return JSON.parse(json); }
const data = parse(input);
if (typeof data === "object" && data && "id" in data) { /* now narrowed */ }
```

### `satisfies` for config validation without widening

```ts
type Route = { path: string; method: "GET" | "POST" };

// Bad: annotation widens — routes.home.method is "GET" | "POST", and a typo in
// a key would only surface far away.
const a: Record<string, Route> = { home: { path: "/", method: "GET" } };

// Good: satisfies validates each entry AND keeps literal types.
const routes = {
  home: { path: "/", method: "GET" },
} satisfies Record<string, Route>;
routes.home.method; // "GET" (narrow), and "GE" would error right here
```

### Discriminated unions + exhaustive `never`

The discriminant must be a **literal** type (not `string`), and you must check it **before**
destructuring — destructuring first throws away the narrowing.

```ts
type State =
  | { status: "loading" }
  | { status: "ok"; data: string }
  | { status: "error"; message: string };

// Bad: destructured before the check — `data`/`message` are typed as the union.
function render({ status, data, message }: State) { /* no narrowing */ }

// Good: switch on the literal discriminant, exhaustive never guard at the end.
function render(s: State): string {
  switch (s.status) {
    case "loading": return "...";
    case "ok": return s.data;
    case "error": return s.message;
    default: { const _exhaustive: never = s; return _exhaustive; }
  }
}
```

Add a `"deleted"` member to `State` and the `default` branch fails to compile — that is the
point.

### Branded (nominal) types

TS is structural, so a `UserId` and a raw `string` are interchangeable unless you brand them:

```ts
type UserId = string & { readonly __brand: "UserId" };
const asUserId = (s: string): UserId => s as UserId; // brand only at the validated boundary
function load(id: UserId) { /* a bare string is now a compile error */ }
```

### Utility types cheat row

`Partial<T>` `Required<T>` `Readonly<T>` `Pick<T,K>` `Omit<T,K>` `Record<K,V>`
`Exclude<U,M>` `Extract<U,M>` `NonNullable<T>` `ReturnType<F>` `Parameters<F>`
`Awaited<T>` `NoInfer<T>` (TS 5.4+, blocks a type param from inferring at one site).

### Mapped / conditional / template-literal one-liners

```ts
type Mutable<T> = { -readonly [K in keyof T]: T[K] };          // strip readonly
type Nullable<T> = { [K in keyof T]: T[K] | null };            // mapped transform
type Unwrap<T> = T extends Promise<infer U> ? U : T;           // conditional + infer
type EventName<T extends string> = `on${Capitalize<T>}`;       // template literal
```

Deep recipes (recursive types, declaration merging, variance/`in`-`out`, assertion functions,
overloads) live in [references/type-system.md](references/type-system.md).

## tsconfig: strict base

Copy-paste base. Every package `extends` this and overrides only paths/references:

```jsonc
{
  "compilerOptions": {
    "strict": true,                    // the whole strict family, non-negotiable
    "noUncheckedIndexedAccess": true,  // arr[i] / rec[k] are T | undefined
    "verbatimModuleSyntax": true,      // explicit import type; safe single-file transpile
    "isolatedModules": true,           // each file transpilable alone (esbuild/swc/babel)
    "skipLibCheck": true,              // don't type-check node_modules .d.ts (speed)
    "resolveJsonModule": true,         // import data.json with types
    "target": "esnext",
    "module": "nodenext",              // or "esnext" + "moduleResolution": "bundler"
    "moduleResolution": "nodenext",
    "moduleDetection": "force",
    "noEmit": true                     // a bundler/tsc -b emits; the base just checks
  }
}
```

### moduleResolution: bundler vs nodenext

| Aspect | `bundler` | `nodenext` |
| --- | --- | --- |
| Use when | Vite / Next / Remix / esbuild build the code | Code runs directly in Node (no bundler) |
| Relative import extensions | omit (`./util`) | required (`./util.js`) |
| `package.json` `exports`/`imports` | resolved | resolved |
| `module` setting | `esnext`/`preserve` | `nodenext` |
| Emits runnable JS itself | no (the bundler does) | yes |

Pick `bundler` when a bundler owns resolution; pick `nodenext` for libraries and scripts
that Node executes directly. Field-by-field reference and the full matrix are in
[references/build-and-monorepo.md](references/build-and-monorepo.md).

## Monorepo & build

Use **project references** so packages type-check independently and in dependency order. A
shared `tsconfig.base.json` holds the strict flags; each package extends it, sets
`composite: true`, `outDir`/`rootDir`, and lists upstream packages under `references`. Build
the graph with `tsc -b` (or `tsgo -b`).

For declaration emit and publishing a library, set `declaration: true`,
`declarationMap: true`, and an `exports` map in `package.json`. For fast local checks prefer
`tsgo` (TS7 preview: `npx @typescript/native-preview`); run scripts with `tsx` instead of
`ts-node`. Depth, build-order graph, path aliases, and the `tsgo` adoption steps are in
[references/build-and-monorepo.md](references/build-and-monorepo.md).

## Anti-patterns

| Anti-pattern | Why it bites | Do instead |
| --- | --- | --- |
| `any` as an escape hatch | disables all checking and spreads silently downstream | `unknown` + narrow, or a precise type / generic |
| `as` to silence "not assignable" | asserts a claim TS can't verify — hides the real bug | fix the type, or narrow with a guard/`in`/`typeof` |
| `enum` for a small fixed set | emits runtime code, awkward with `isolatedModules`, no literal subtyping | union of string literals (`"a" \| "b"`) + `as const` |
| Destructure before the discriminant check | narrowing is lost; fields become the full union | check `obj.kind` first, then read fields |
| Skipping `noUncheckedIndexedAccess` | `arr[i]`/`rec[k]` typed as `T` but are `undefined` at runtime | enable it; handle the `\| undefined` |
| `Function` / bare `object` / `{}` types | accept almost anything, no call-signature safety | a precise signature, or `Record<string, unknown>` |
| No exhaustive `never` guard on unions | a new union member compiles with a missing branch | `default: const _: never = x` in every switch |
| One giant `tsconfig` for a monorepo | can't express per-package targets; breaks references | `tsconfig.base.json` + per-package `extends` |
| `// @ts-ignore` | swallows the error even after the line is fixed, masking new ones | `// @ts-expect-error` (errors if the line later type-checks) |
| Default-importing in a CJS-emit file under `verbatimModuleSyntax` | blocked / wrong emit | use `export =`/named, or set the right `module` |

## Project grounding

When working inside a real workspace, record this project's tsconfig and strictness choices
(resolution mode, which strict flags are on, the build tool) in the project wiki via
[../harness/SKILL.md](../harness/SKILL.md) — so the next session does not re-derive them.
