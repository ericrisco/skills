# Data fetching & caching — the two App Router models

Deep dive behind the "Caching & data fetching" section of `SKILL.md`. **Detect the model first**
(see the SKILL gate). Never mix v15 and v16 advice. Sources: nextjs.org/blog/next-15,
nextjs.org/blog/next-16, the `use cache` / `cacheComponents` / `cacheLife` docs.

## Mental model first

Four caches sit between your code and the response:

- **Request memoization** — `fetch`/`React.cache` dedupes identical calls within a single render.
- **Data cache** — persists fetch results across requests/deploys (server-side).
- **Full-route cache** — caches the rendered HTML + RSC payload of a static route at build/revalidate.
- **Client router cache** — caches RSC payloads in the browser for back/forward navigation.

| Concern         | v15 baseline                                       | v16 Cache Components                            |
| --------------- | -------------------------------------------------- | ----------------------------------------------- |
| Default `fetch` | Uncached                                           | Dynamic; cache only inside `"use cache"`        |
| Opt-in cache    | `{ next: { revalidate, tags } }`, `unstable_cache` | `"use cache"` + `cacheLife()` + `cacheTag()`    |
| Invalidate      | `revalidateTag` / `revalidatePath`                 | `updateTag` (immediate) / `revalidateTag` (SWR) |
| Request dedupe  | `React.cache`                                      | `React.cache`                                   |
| Static/dynamic  | route segment config (`dynamic`, `revalidate`)     | PPR by default (static shell + streamed holes)  |

## v15 model in full

`fetch` is uncached by default — the v13/14 "cached by default" mental model is wrong here.

```ts
// 1. uncached — re-fetched on every request
const live = await fetch("https://api.example.com/now").then((r) => r.json());

// 2. explicitly cache forever (until revalidated)
const config = await fetch("https://api.example.com/config", {
  cache: "force-cache",
}).then((r) => r.json());

// 3. time-based revalidation + tags for on-demand invalidation
const posts = await fetch("https://api.example.com/posts", {
  next: { revalidate: 3600, tags: ["posts"] },
}).then((r) => r.json());
```

Route segment config controls a whole route's rendering:

```ts
// app/feed/page.tsx — top-level exports configure the segment
export const dynamic = "force-dynamic"; // "auto" | "force-dynamic" | "error" | "force-static"
export const revalidate = 3600; // ISR window in seconds
export const fetchCache = "default-cache"; // override per-route fetch caching
export const runtime = "nodejs"; // or "edge"
```

Request dedupe and non-`fetch` caching:

```ts
import { cache } from "react";
import { unstable_cache } from "next/cache";
import { db } from "@/lib/db";

// React.cache: one call per request even if invoked from multiple components
export const getUser = cache(async (id: string) => db.user.findUnique({ where: { id } }));

// unstable_cache: persist a non-fetch result across requests, tagged + time-bounded
export const getPosts = unstable_cache(
  async () => db.post.findMany({ orderBy: { createdAt: "desc" } }),
  ["posts-list"], // key parts
  { tags: ["posts"], revalidate: 60 },
);
```

```ts
// invalidate from a Server Action
"use server";
import { revalidateTag, revalidatePath } from "next/cache";

export async function publishPost(id: string) {
  // ... auth + mutation ...
  revalidateTag("posts"); // clears every fetch/unstable_cache tagged "posts"
  revalidatePath("/feed"); // clears a specific route
}
```

Reading `cookies()`, `headers()`, or `searchParams` opts a route into **dynamic rendering** — it can
no longer be statically cached.

## v16 Cache Components in full

Enable in config; then opt into caching with the `"use cache"` directive.

```ts
// next.config.ts
import type { NextConfig } from "next";
const config: NextConfig = {
  cacheComponents: true, // everything dynamic by default; cache is opt-in
};
export default config;
```

```ts
// lib/products.ts — "use cache" at the function level
// Next.js 16: cacheLife / cacheTag / updateTag are STABLE — no unstable_ prefix.
import { cacheLife, cacheTag } from "next/cache";
import { db } from "@/lib/db";

export async function getProducts() {
  "use cache";
  cacheLife("hours"); // built-in profile: seconds | minutes | hours | days | weeks | max
  cacheTag("products");
  return db.product.findMany();
}
```

> **15 → 16 transitional note only.** On the Next.js 15 *experimental* Cache Components preview these
> were aliased: `import { unstable_cacheLife as cacheLife, unstable_cacheTag as cacheTag } from "next/cache"`.
> On Next.js 16 they are stable — drop the `unstable_` aliases. If you still see the aliased form in a
> repo, it is a leftover from the 15 preview, not the current API.

```ts
// custom cacheLife profile (registered in next.config.ts under experimental, or inline object)
cacheLife({ stale: 60, revalidate: 300, expire: 3600 }); // seconds
```

`updateTag` and `revalidateTag` are **not** interchangeable on v16 — they have different timing:

| Verb              | Timing                                                          | Where it runs                  |
| ----------------- | -------------------------------------------------------------- | ------------------------------ |
| `updateTag(tag)`  | **Immediate** expiry; the same request reads its own fresh write (read-your-writes). | **Server Actions only**        |
| `revalidateTag(tag, profile)` | **Stale-while-revalidate**: serves stale now, refreshes in the background. On v16 it takes a second `cacheLife` profile argument; the single-arg form is deprecated. | Server Actions or Route Handlers |

```ts
// invalidate from a mutation
"use server";
import { updateTag, revalidateTag } from "next/cache";

export async function restock() {
  // ... auth + mutation ...
  updateTag("products"); // user must see their own change on this very response
}

export async function nightlyReprice() {
  // ... mutation ...
  revalidateTag("products", "hours"); // ok to serve stale briefly; refresh in background
}
```

| Inside `"use cache"` / `"use cache: remote"` you may NOT… | Do this instead                           |
| --------------------------------------------------------- | ----------------------------------------- |
| call `cookies()` / `headers()`                            | read outside, pass the value as an arg    |
| read `searchParams`                                       | pass the parsed value as an arg           |
| close over a request-scoped Promise                       | await/resolve it outside, pass the result |

**Exception — `"use cache: private"`.** This variant *may* read `cookies()`, `headers()`, and
`searchParams` directly. Its result is cached **only in the browser's memory** (never stored on the
server, not persisted across reloads), so it is safe for per-user data. Use it when moving the
request access outside and passing arguments is impractical; otherwise prefer plain `"use cache"`
with arguments. `"use cache: remote"` stores the entry in the shared/remote cache and follows the
same request-API restrictions as plain `"use cache"`. PPR streams the dynamic holes inside an
otherwise-cached static shell, so the shell paints instantly.

```ts
// Bad: a dynamic, request-scoped Promise captured inside "use cache" hangs the build
async function getDashboardBad(sessionPromise: Promise<Session>) {
  "use cache";
  const session = await sessionPromise; // ✗ closing over request-scoped work
  return db.metrics.forUser(session.userId);
}

// Good: resolve the dynamic value OUTSIDE, pass the plain id in
async function getDashboard(userId: string) {
  "use cache";
  cacheTag(`metrics:${userId}`);
  return db.metrics.forUser(userId);
}
// caller (request-scoped): const s = await auth(); const data = await getDashboard(s.user.id);
```

## Mutations via Server Actions

The canonical shape: authenticate → validate → mutate → invalidate → return a typed result.

```ts
// app/posts/actions.ts
"use server";
import { z } from "zod";
import { revalidateTag } from "next/cache";
import { auth } from "@/auth";
import { db } from "@/lib/db";

const TitleSchema = z.object({ id: z.string().uuid(), title: z.string().min(1).max(200) });

type Result =
  | { status: "ok"; data: { id: string; title: string } }
  | { status: "error"; message: string };

export async function renamePost(input: z.infer<typeof TitleSchema>): Promise<Result> {
  const session = await auth();
  if (!session?.user) return { status: "error", message: "Not authenticated" };

  const parsed = TitleSchema.safeParse(input);
  if (!parsed.success) return { status: "error", message: "Invalid input" };

  const post = await db.post.update({
    where: { id: parsed.data.id, authorId: session.user.id },
    data: { title: parsed.data.title },
  });
  revalidateTag("posts"); // v15: stale-while-revalidate. On v16 use updateTag("posts") for
  //                          immediate read-your-writes, or revalidateTag("posts", "hours") for SWR.
  return { status: "ok", data: { id: post.id, title: post.title } };
}
```

Pair this with optimistic UI on the client (`useOptimistic`) — see `react.md`.

## Forms end-to-end

One complete, runnable flow: zod schema → shared `z.infer` type → Server Action returning a
discriminated union with a `fieldErrors` map → a client form via `useActionState` mapping those
errors back to inputs.

```ts
// app/signup/actions.ts
"use server";
import { z } from "zod";
import { db } from "@/lib/db";

export const SignupSchema = z.object({
  email: z.string().email("Enter a valid email"),
  password: z.string().min(8, "At least 8 characters"),
});
export type SignupInput = z.infer<typeof SignupSchema>; // shared by form + DB layer

export type SignupState = {
  status: "idle" | "ok" | "error";
  message?: string;
  fieldErrors?: Partial<Record<keyof SignupInput, string>>;
};

export async function signup(_prev: SignupState, formData: FormData): Promise<SignupState> {
  const parsed = SignupSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    const fe = parsed.error.flatten().fieldErrors;
    return { status: "error", fieldErrors: { email: fe.email?.[0], password: fe.password?.[0] } };
  }
  const exists = await db.user.findUnique({ where: { email: parsed.data.email } });
  if (exists) return { status: "error", fieldErrors: { email: "Already registered" } };

  await db.user.create({ data: parsed.data });
  return { status: "ok", message: "Account created" };
}
```

```tsx
// app/signup/form.tsx
"use client";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { signup, type SignupState } from "./actions";

const initial: SignupState = { status: "idle" };

function Submit() {
  const { pending } = useFormStatus();
  return <button disabled={pending}>{pending ? "Creating…" : "Sign up"}</button>;
}

export function SignupForm() {
  const [state, action] = useActionState(signup, initial);
  return (
    <form action={action}>
      <label htmlFor="email">Email</label>
      <input id="email" name="email" type="email" aria-invalid={!!state.fieldErrors?.email} aria-describedby="email-err" />
      {state.fieldErrors?.email && <p id="email-err" role="alert">{state.fieldErrors.email}</p>}

      <label htmlFor="password">Password</label>
      <input id="password" name="password" type="password" aria-invalid={!!state.fieldErrors?.password} aria-describedby="pw-err" />
      {state.fieldErrors?.password && <p id="pw-err" role="alert">{state.fieldErrors.password}</p>}

      <Submit />
      {state.status === "ok" && <p role="status">{state.message}</p>}
    </form>
  );
}
```

## Client cache layer (TanStack Query)

Rely on RSC by default. Add TanStack Query when data lives client-side: client-initiated mutations
with cache updates, infinite scroll, or a cross-component client cache that must stay in sync.

```tsx
"use client";
import { useQuery } from "@tanstack/react-query";

export function NotificationBell() {
  const { data, isPending } = useQuery({
    queryKey: ["notifications"],
    queryFn: () => fetch("/api/notifications").then((r) => r.json()),
    staleTime: 30_000,
  });
  if (isPending) return <span aria-busy="true" />;
  return <span aria-label={`${data.count} notifications`}>{data.count}</span>;
}
```

## See Also

- `react.md` — `useActionState`, `useOptimistic`, and the form/hook discipline.
- `security.md` — auth checks every mutation must perform before touching data.
- `testing.md` — how to unit-test these Server Actions and the data functions.
