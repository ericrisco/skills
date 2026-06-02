# Reactivity deep dive

Depth most tasks won't need inline. Read this when ownership, disposal, explicit
dependencies, or the 1.9→2.0 migration is actually in play.

## Ownership & disposal

Every reactive computation runs inside an **owner**. When the owner is disposed,
its children, effects, and `onCleanup` callbacks are torn down. Components create
owners automatically; outside a component you must establish one.

```tsx
import { createRoot, getOwner, runWithOwner } from "solid-js";

// Run reactive code outside a component and get an explicit dispose handle.
const dispose = createRoot((dispose) => {
  createEffect(() => console.log(count()));
  return dispose;
});
dispose();   // tears down the effect

// Capture the current owner to re-enter it later (e.g. after an await).
const owner = getOwner();
queueMicrotask(() => runWithOwner(owner, () => createEffect(() => …)));
```

Why it matters: an effect created without an owner (or after an `await` that lost
the owner) never gets cleaned up — a memory/subscription leak. If `onCleanup`
doesn't fire, an owner boundary is the first thing to check.

## Explicit dependencies with `on()`

`createEffect`/`createMemo` track every read by default. Use `on()` to depend on
specific signals and optionally defer the first run.

```tsx
import { on } from "solid-js";

createEffect(on(userId, (id) => fetchUser(id), { defer: true }));
// runs only when userId() changes, skips the initial run
```

## Effect variants

| Primitive | When it runs | Use for |
|---|---|---|
| `createEffect` | after render (queued) | DOM side effects, subscriptions, network |
| `createRenderEffect` | during render, before paint | measuring/writing the DOM before it shows |
| `createComputed` | synchronously, eagerly | low-level chained computations (rare; prefer `createMemo`) |

Prefer `createMemo` for derived values. `createComputed` is eager and easy to
misuse — reach for it only when ordering before paint truly requires it.

## `createSelector`

For "which item is selected?" across a large list, `createSelector` makes
selection O(1) per item instead of O(n) re-checks.

```tsx
const isSelected = createSelector(selectedId);
<For each={items()}>{(item) => <Row active={isSelected(item.id)} />}</For>
```

## Store helpers: `produce` and `reconcile`

```tsx
import { produce, reconcile } from "solid-js/store";

setState(produce((s) => { s.todos.push(newTodo); }));   // mutable-style writes, fine-grained
setState("todos", reconcile(serverTodos));              // diff incoming data, keep stable refs
```

`reconcile` is the right tool after fetching fresh server data into an existing
store: it diffs and patches in place rather than replacing the array, so node
identity (and focus/scroll) survives.

## 1.9 → 2.0 migration notes

Solid 2.0 (beta, `next` npm tag) keeps the same authoring feel but changes the
foundation:

- New reactive core extracted to **`@solidjs/signals`**.
- **`createAsync`** becomes the standard async primitive (over `createResource`),
  paired with `<Suspense>`/`<ErrorBoundary>`; supports concurrent transitions.
- **Automatic batching** — explicit `batch()` is largely unnecessary.
- Immutable, diffable stores; self-healing error boundaries.

Default to 1.9.x APIs for production work. Adopt 2.0 only when the task targets it,
and pin the `next` tag explicitly. SolidStart 2.0.0-alpha tracks Solid 2.0.
