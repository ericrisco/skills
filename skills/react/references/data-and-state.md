# Data & state — TanStack Query v5 + client state

The SPA rule: **server data lives in the TanStack Query cache, client data lives in `useState`/store/URL.** Never put fetched data in `useState` synced by `useEffect`.

## Query-key factory

Keep keys consistent so invalidation hits exactly what you mean. A small factory beats stringly-typed keys scattered across files.

```ts
export const userKeys = {
  all: ["users"] as const,
  list: (filters: UserFilters) => [...userKeys.all, "list", filters] as const,
  detail: (id: string) => [...userKeys.all, "detail", id] as const,
};
```

## useQuery

```tsx
const { data, isPending, isError, error, refetch } = useQuery({
  queryKey: userKeys.list(filters),
  queryFn: () => api.listUsers(filters),
  staleTime: 60_000,        // fresh for 1 min → no refetch on remount/focus within window
  gcTime: 5 * 60_000,        // unused cache evicted after 5 min
  placeholderData: (prev) => prev, // keep prior page visible while the next loads (pagination)
});
```

- `staleTime` is the single biggest lever against over-fetching. Default `0` means refetch on every mount/focus.
- Render states explicitly: `isPending` (no data yet) → spinner; `isError` → message + retry; else data.

## Mutations: invalidate vs setQueryData

```tsx
const qc = useQueryClient();

// Simplest correct pattern: invalidate, let the query refetch the truth.
const create = useMutation({
  mutationFn: api.createUser,
  onSuccess: () => qc.invalidateQueries({ queryKey: userKeys.all }),
});

// When you already have the server's response, write it directly (one less round-trip).
const update = useMutation({
  mutationFn: api.updateUser,
  onSuccess: (saved) => qc.setQueryData(userKeys.detail(saved.id), saved),
});
```

Rule of thumb: **invalidate** when the server is the source of truth and a refetch is cheap; **`setQueryData`** when the mutation already returns the canonical object.

## Optimistic update (delete with rollback)

```tsx
const remove = useMutation({
  mutationFn: api.deleteUser,
  onMutate: async (id: string) => {
    await qc.cancelQueries({ queryKey: userKeys.all });      // stop in-flight refetches
    const prev = qc.getQueryData<User[]>(userKeys.list(filters));
    qc.setQueryData<User[]>(userKeys.list(filters),
      (old) => old?.filter((u) => u.id !== id) ?? []);        // optimistic write
    return { prev };                                           // context for rollback
  },
  onError: (_e, _id, ctx) => {
    if (ctx?.prev) qc.setQueryData(userKeys.list(filters), ctx.prev); // rollback
  },
  onSettled: () => qc.invalidateQueries({ queryKey: userKeys.all }),  // reconcile with server
});
```

The trio is non-negotiable: `onMutate` (snapshot + write), `onError` (restore the snapshot), `onSettled` (refetch the truth).

## useSuspenseQuery + boundaries

Move loading/error out of the component body.

```tsx
function Users() {
  const { data } = useSuspenseQuery({ queryKey: userKeys.all, queryFn: api.listUsers });
  return <List items={data} />; // data is never undefined here
}

<ErrorBoundary fallback={<Failed />}>
  <Suspense fallback={<Skeleton />}>
    <Users />
  </Suspense>
</ErrorBoundary>
```

This is also the correct promise source for a bare `use()` call — the cache owns a stable promise, so render doesn't loop.

## Infinite & prefetch

```tsx
const q = useInfiniteQuery({
  queryKey: userKeys.all,
  queryFn: ({ pageParam }) => api.listUsers({ cursor: pageParam }),
  initialPageParam: null,
  getNextPageParam: (last) => last.nextCursor ?? undefined,
});

// Warm the cache before navigation (e.g. on hover):
await qc.prefetchQuery({ queryKey: userKeys.detail(id), queryFn: () => api.getUser(id) });
```

## Client state — Zustand with narrow selectors

```ts
const useCart = create<CartState>((set) => ({
  items: [],
  add: (item) => set((s) => ({ items: [...s.items, item] })),
}));

// Bad: subscribes to the whole store → re-renders on any change
const store = useCart();
// Good: subscribe to one slice → re-renders only when count changes
const count = useCart((s) => s.items.length);
```

## Context — wide reads, low write frequency

```tsx
const ThemeContext = createContext<Theme>("light");
// React 19: the context value IS the provider
<ThemeContext value={theme}>{children}</ThemeContext>
```

Do not put rapidly-changing values (mouse position, form keystrokes) in context — every consumer re-renders. Use a store with selectors instead.

## Bad → Good catalog

```tsx
// Bad: derived state mirrored into useState + effect
const [total, setTotal] = useState(0);
useEffect(() => setTotal(items.reduce((s, i) => s + i.price, 0)), [items]);
// Good
const total = items.reduce((s, i) => s + i.price, 0);
```

```tsx
// Bad: fetch on mount with effect (race + no cache + Strict-Mode double-fire)
useEffect(() => { fetch(url).then(r => r.json()).then(setData); }, [url]);
// Good
const { data } = useQuery({ queryKey: [url], queryFn: () => fetch(url).then(r => r.json()) });
```

```tsx
// Bad: resetting child state on prop change with an effect
useEffect(() => setDraft(initial), [initial]);
// Good: remount the subtree with a key
<Editor key={initial.id} initial={initial} />
```
