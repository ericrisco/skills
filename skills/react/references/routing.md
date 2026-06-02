# Client-side routing — React Router v7 (library mode) & TanStack Router

SPA routing only. If you see `@react-router/dev` (React Router **framework mode**, the Remix successor with SSR), that is out of scope — treat it like `../nextjs/SKILL.md`-shape work.

## React Router v7 — library mode

```tsx
import { createBrowserRouter, RouterProvider } from "react-router";

const router = createBrowserRouter([
  {
    path: "/",
    element: <RootLayout />,        // renders <Outlet/> for children
    errorElement: <RouteError />,
    children: [
      { index: true, element: <Home /> },
      { path: "users", lazy: () => import("./routes/users") },        // code-split chunk
      { path: "users/:id", lazy: () => import("./routes/user-detail") },
      { path: "*", element: <NotFound /> },
    ],
  },
]);

export function App() {
  return <RouterProvider router={router} />;
}
```

- **Nested routes** share a layout via `<Outlet/>`; each child is its own URL segment.
- **`lazy`** makes each route a separate bundle chunk — the single biggest SPA bundle win.
- **`errorElement`** catches thrown errors / loader rejections for that subtree.

### Client loaders

A `lazy` route module can export a `loader` to fetch before render. In an SPA, prefer driving loaders through the TanStack Query client so the data stays in one cache:

```ts
// routes/user-detail.tsx
export async function loader({ params }: { params: { id: string } }) {
  return queryClient.ensureQueryData({
    queryKey: ["users", "detail", params.id],
    queryFn: () => api.getUser(params.id),
  });
}
export function Component() {
  const { id } = useParams();
  const { data } = useSuspenseQuery({ queryKey: ["users", "detail", id!], queryFn: () => api.getUser(id!) });
  return <Profile user={data} />;
}
```

### Protected route wrapper

```tsx
function RequireAuth({ children }: { children: React.ReactNode }) {
  const user = useAuth();
  const loc = useLocation();
  if (!user) return <Navigate to="/login" replace state={{ from: loc }} />;
  return children;
}
// { path: "settings", element: <RequireAuth><Settings/></RequireAuth> }
```

### Search params ARE state

Filters, tabs, pagination belong in the URL so they're shareable and survive reload. Do not duplicate them into `useState`.

```tsx
const [params, setParams] = useSearchParams();
const page = Number(params.get("page") ?? "1");
const setPage = (p: number) =>
  setParams((prev) => { prev.set("page", String(p)); return prev; });
```

## TanStack Router — the type-safe alternative

Pick it when route params and search-param schemas must be fully typed end-to-end.

```tsx
const route = createRoute({
  getParentRoute: () => rootRoute,
  path: "/users/$userId",
  validateSearch: (s) => userSearchSchema.parse(s), // typed, validated search params
  loader: ({ params }) => queryClient.ensureQueryData(userQuery(params.userId)),
  component: UserDetail,
});
// useParams() / useSearch() are fully typed from the route tree
```

- Type-safe `Link`, `useParams`, `useSearch` derived from the route tree.
- First-class loaders and built-in integration with the TanStack Query cache.

## Choosing

| Need                                         | Use                          |
| -------------------------------------------- | ---------------------------- |
| Familiar API, large ecosystem                | React Router v7 library mode |
| Fully typed params + validated search params | TanStack Router              |
| SSR / streaming / server actions             | not here → `../nextjs/SKILL.md` |
