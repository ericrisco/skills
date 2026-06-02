# Performance — measure, then fix the real bottleneck

Never optimize from a hunch. Profile, find the component that actually re-renders or the chunk that's actually heavy, fix that.

## 1. Profile first

- **React DevTools Profiler**: record an interaction, read the flamegraph. "Why did this render?" (Profiler settings) names the prop/state/context that triggered each render.
- Bundle size: `npx vite-bundle-visualizer` or `rollup-plugin-visualizer` to see what's actually shipped.
- Field metrics: LCP < 2.5s, INP < 200ms, CLS < 0.1. Generic CWV measurement detached from React → `../performance/SKILL.md`.

## 2. `key` correctness (the silent state bug)

Index keys are fine for static lists. The moment a list can **reorder, insert, or delete**, an index key makes React reuse the wrong DOM/state — inputs keep old values, the wrong row animates, checkboxes stick to the wrong item.

```tsx
// Bad: index key on a mutable list → wrong row state after delete/reorder
{users.map((u, i) => <Row key={i} user={u} />)}
// Good: stable identity
{users.map((u) => <Row key={u.id} user={u} />)}
```

## 3. Virtualize long lists

Past ~50–100 rows the DOM node count, not React, is the cost. Render only the visible window.

```tsx
import { useVirtualizer } from "@tanstack/react-virtual";

const v = useVirtualizer({
  count: rows.length,
  getScrollElement: () => parentRef.current,
  estimateSize: () => 48,
  overscan: 8,
});
// render only v.getVirtualItems(), positioned by item.start
```

## 4. Code-split

```tsx
const Chart = lazy(() => import("./Chart")); // separate chunk, loaded on demand
<Suspense fallback={<Spinner />}><Chart data={data} /></Suspense>
```

Vite emits a separate chunk for every dynamic `import()`. Split at route boundaries first, then heavy leaf components (charts, editors, maps).

## 5. React Compiler vs manual memo

When the **React Compiler** is enabled (Vite plugin / `babel-plugin-react-compiler`), it auto-memoizes components and values — **delete** manual `useMemo`/`useCallback`/`React.memo`; they're dead weight and noise.

```ts
// vite.config.ts
export default defineConfig({
  plugins: [react({ babel: { plugins: ["babel-plugin-react-compiler"] } })],
});
```

If the compiler is **not** on, memoize only what the Profiler proved expensive — not everything.

## 6. Narrow store selectors → re-render map

A component re-renders when a value it *subscribes to* changes. With Zustand, subscribe to the smallest slice:

```ts
// Bad: re-renders on any store change
const { count } = useCart();
// Good: re-renders only when the count changes
const count = useCart((s) => s.items.length);
```

Same principle for context: a high-write context re-renders every consumer, so high-frequency values belong in a store with selectors, not context.

## 7. Suspense for perceived speed

Wrap independent data regions in their own `<Suspense>` so each reveals as its query resolves instead of blocking the whole screen on the slowest fetch. Pair `useSuspenseQuery` (see `data-and-state.md`) with per-region boundaries.
