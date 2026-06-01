# React 19 discipline for the Next.js App Router

React 19 (App Router on Next.js 15; React 19.2 on Next.js 16) inside RSC. This file is the deep
dive behind the "React 19 in the App Router" section of `SKILL.md`. Every rule below is written
for an agent editing real components: directive, with `// Good` / `// Bad` contrasts.

## Hooks discipline

- Call hooks at the **top level only** — never inside conditions, loops, or after an early return.
  (`use(promise)` is the one hook that may be called conditionally.)
- Clean up every subscription, interval, listener, and observer in the effect's return function.
- Use the **functional updater** `setX(prev => …)` when the new state derives from the old one.
- Default to **no memoization**. Add `useMemo`/`useCallback` only after a measured problem. With
  `reactCompiler: true`, manual memoization is noise — remove it during review.
- Extract a custom hook only when the same stateful sequence appears in **2+ components**.

```tsx
"use client";
import { useEffect, useState } from "react";

export function useDebounce<T>(value: T, delayMs = 300): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(id); // cleanup runs before the next effect + on unmount
  }, [value, delayMs]);
  return debounced;
}
```

## Server vs Client deep dive

The import-graph rule: `"use client"` marks a module **and everything it imports** as client. A
Server Component cannot be `import`ed into that subtree — compose it in via `children` or props.

```tsx
// Bad: importing a Server Component into a client module pulls it client / breaks the build
"use client";
import { UserStats } from "./user-stats"; // async, reads the DB → error
export function Sidebar() {
  return <UserStats />;
}
```

```tsx
// Good: client shell accepts server content as `children`, and a Server Action as a prop
"use client";
import { useTransition } from "react";

export function Sidebar({ children, onRefresh }: { children: React.ReactNode; onRefresh: () => Promise<void> }) {
  const [isPending, startTransition] = useTransition();
  return (
    <aside>
      {children}
      <button disabled={isPending} onClick={() => startTransition(() => onRefresh())}>
        Refresh
      </button>
    </aside>
  );
}
// server parent:  <Sidebar onRefresh={refreshStats}><UserStats /></Sidebar>
```

`use(promise)` unwraps a Promise passed from a Server Component, suspending until it resolves.

```tsx
// server parent passes a Promise (does NOT await it) so the client can stream it
import { Suspense } from "react";
import { Comments } from "./comments";

export default function Page() {
  const commentsPromise = fetch("https://api.example.com/comments").then((r) => r.json());
  return (
    <Suspense fallback={<p>Loading comments…</p>}>
      <Comments commentsPromise={commentsPromise} />
    </Suspense>
  );
}
```

```tsx
"use client";
import { use } from "react";

export function Comments({ commentsPromise }: { commentsPromise: Promise<{ id: string; body: string }[]> }) {
  const comments = use(commentsPromise); // suspends here until resolved
  return (
    <ul>
      {comments.map((c) => (
        <li key={c.id}>{c.body}</li>
      ))}
    </ul>
  );
}
```

## State location decision tree

Most pages need neither Context nor a global store — server-derived data belongs in an RSC.

```
Where does this state live?
├── Used by one component only            → useState (local)
├── Parent + a few descendants            → lift to the nearest common parent, pass props
├── Distant + low-frequency change        → Context (theme / auth / locale)
│   (theme, current user, i18n)
├── High-frequency + shared widely        → external store (Zustand / Jotai)
└── Derived from the server / persisted   → RSC fetch (server) or TanStack Query (client)
```

## Forms with React 19

`useActionState` wires a Server Action to a form and returns `[state, action, isPending]`. Map
field errors back to inputs with `aria-invalid` + `aria-describedby`. The submit button is a
**separate child component** so it can call `useFormStatus()`.

```ts
// app/account/actions.ts
"use server";
import { z } from "zod";
import { auth } from "@/auth";
import { db } from "@/lib/db";

const ProfileSchema = z.object({
  name: z.string().min(1, "Name is required"),
  email: z.string().email("Enter a valid email"),
});

export type ProfileState = {
  status: "idle" | "ok" | "error";
  message?: string;
  fieldErrors?: Partial<Record<keyof z.infer<typeof ProfileSchema>, string>>;
};

export async function updateProfile(_prev: ProfileState, formData: FormData): Promise<ProfileState> {
  const session = await auth();
  if (!session?.user) return { status: "error", message: "Not authenticated" };

  const parsed = ProfileSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    const fe = parsed.error.flatten().fieldErrors;
    return {
      status: "error",
      fieldErrors: { name: fe.name?.[0], email: fe.email?.[0] },
    };
  }
  await db.user.update({ where: { id: session.user.id }, data: parsed.data });
  return { status: "ok", message: "Saved" };
}
```

```tsx
"use client";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { updateProfile, type ProfileState } from "./actions";

const initial: ProfileState = { status: "idle" };

function SubmitButton() {
  const { pending } = useFormStatus(); // reads the parent <form> state
  return <button disabled={pending}>{pending ? "Saving…" : "Save"}</button>;
}

export function ProfileForm() {
  const [state, action] = useActionState(updateProfile, initial);
  return (
    <form action={action}>
      <label htmlFor="name">Name</label>
      <input id="name" name="name" aria-invalid={!!state.fieldErrors?.name} aria-describedby="name-err" />
      {state.fieldErrors?.name && <p id="name-err" role="alert">{state.fieldErrors.name}</p>}

      <label htmlFor="email">Email</label>
      <input id="email" name="email" type="email" aria-invalid={!!state.fieldErrors?.email} aria-describedby="email-err" />
      {state.fieldErrors?.email && <p id="email-err" role="alert">{state.fieldErrors.email}</p>}

      <SubmitButton />
      {state.status === "ok" && <p role="status">{state.message}</p>}
    </form>
  );
}
```

Go **controlled** when the value drives other UI or you format per keystroke; otherwise uncontrolled
+ `FormData` is simpler. Reach for **React Hook Form / TanStack Form** when you have multi-step
flows, dynamic field arrays, or cross-field validation.

## useOptimistic

`useOptimistic` shows the predicted state immediately and **auto-reverts when the action throws**.

```tsx
"use client";
import { useOptimistic, useRef } from "react";
import { addTodo } from "./actions";

type Todo = { id: string; text: string; pending?: boolean };

export function TodoList({ todos }: { todos: Todo[] }) {
  const formRef = useRef<HTMLFormElement>(null);
  const [optimistic, addOptimistic] = useOptimistic(todos, (state, text: string) => [
    ...state,
    { id: crypto.randomUUID(), text, pending: true },
  ]);

  return (
    <>
      <ul>
        {optimistic.map((t) => (
          <li key={t.id} style={{ opacity: t.pending ? 0.5 : 1 }}>
            {t.text}
          </li>
        ))}
      </ul>
      <form
        ref={formRef}
        action={async (fd) => {
          const text = String(fd.get("text") ?? "");
          addOptimistic(text); // optimistic insert; reverts automatically if addTodo throws
          formRef.current?.reset();
          await addTodo(text);
        }}
      >
        <input name="text" aria-label="New todo" required />
        <button>Add</button>
      </form>
    </>
  );
}
```

## Suspense + Error Boundaries

Place boundaries **near the data**, not at the app root. In the App Router, `error.tsx` is the
segment error boundary; for in-tree client boundaries use `react-error-boundary`. **Boundaries do
NOT catch event-handler or async (non-render) errors** — handle those with try/catch and state.

```tsx
"use client";
import { Suspense } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { Report } from "./report";

export function ReportPanel() {
  return (
    <ErrorBoundary fallback={<p role="alert">Report failed to load.</p>}>
      <Suspense fallback={<p>Loading report…</p>}>
        <Report />
      </Suspense>
    </ErrorBoundary>
  );
}
```

## useTransition / useDeferredValue

`startTransition` marks a non-urgent update so the input stays responsive; `useDeferredValue`
lets an expensive list lag behind a fast-changing value.

```tsx
"use client";
import { useDeferredValue, useMemo, useState, useTransition } from "react";

export function Filter({ items }: { items: string[] }) {
  const [query, setQuery] = useState("");
  const [isPending, startTransition] = useTransition();
  const deferred = useDeferredValue(query);
  const filtered = useMemo(
    () => items.filter((i) => i.toLowerCase().includes(deferred.toLowerCase())),
    [items, deferred],
  );

  return (
    <>
      <input
        aria-label="Filter"
        onChange={(e) => startTransition(() => setQuery(e.target.value))}
      />
      <ul aria-busy={isPending}>
        {filtered.map((i) => (
          <li key={i}>{i}</li>
        ))}
      </ul>
    </>
  );
}
```

## Composition recipes

```tsx
// children slot
function Card({ children }: { children: React.ReactNode }) {
  return <div className="card">{children}</div>;
}

// named slots
function Layout({ header, body }: { header: React.ReactNode; body: React.ReactNode }) {
  return (
    <>
      <header>{header}</header>
      <main>{body}</main>
    </>
  );
}
```

```tsx
// compound components via Context — <Tabs> sharing active state with its children
"use client";
import { createContext, useContext, useState } from "react";

const TabsCtx = createContext<{ active: string; setActive: (id: string) => void } | null>(null);

function Tabs({ defaultTab, children }: { defaultTab: string; children: React.ReactNode }) {
  const [active, setActive] = useState(defaultTab);
  return <TabsCtx value={{ active, setActive }}>{children}</TabsCtx>; // React 19 provider syntax
}

function Tab({ id, label }: { id: string; label: string }) {
  const ctx = useContext(TabsCtx);
  if (!ctx) throw new Error("Tab must be used inside <Tabs>");
  return (
    <button aria-selected={ctx.active === id} onClick={() => ctx.setActive(id)}>
      {label}
    </button>
  );
}
```

Prefer a **custom hook** over a render prop: expose `useTabs()` instead of `<Tabs>{(s) => …}</Tabs>`
when consumers only need the values, not the markup.

## Context scope

Split contexts by change frequency so a fast-changing value does not re-render consumers of a
slow-changing one.

```tsx
"use client";
import { createContext } from "react";

// low-frequency: theme rarely changes
export const ThemeCtx = createContext<"light" | "dark">("light");
// separate context for the cursor position (high-frequency) — never merge these two
export const CursorCtx = createContext<{ x: number; y: number }>({ x: 0, y: 0 });
```

## Anti-patterns

- **Derived state in `useEffect`** → derive during render.

  ```tsx
  // Bad
  const [full, setFull] = useState("");
  useEffect(() => setFull(`${first} ${last}`), [first, last]);
  // Good
  const full = `${first} ${last}`;
  ```

- **`useEffect` + `fetch` for app data** → fetch in a Server Component (RSC) or use TanStack Query.

  ```tsx
  // Bad: client waterfall, no SSR
  useEffect(() => { fetch("/api/me").then((r) => r.json()).then(setUser); }, []);
  // Good: render the data on the server in an async Server Component, or useQuery on the client
  ```

- **Defining components inside components** → they remount and lose state every render; hoist them out.
- **`{count && <Badge/>}`** renders a literal `0` when `count === 0` → use a ternary or `count > 0 && …`.

  ```tsx
  // Bad: shows "0"
  {count && <Badge />}
  // Good
  {count > 0 ? <Badge /> : null}
  ```

## See Also

- `data-and-caching.md` — where server data comes from (both models) and the full zod form.
- `testing.md` — how to test these hooks and forms.
- The React Compiler note in `performance.md` — when to drop manual memoization.
