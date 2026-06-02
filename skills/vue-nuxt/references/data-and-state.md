# Data fetching & SSR-safe state

Companion to the SKILL "data-fetching boundary" and "SSR-safe state" sections.

## `useFetch` / `useAsyncData` option matrix

Both return `{ data, error, status, refresh, execute, clear }` and run **once on the server**,
serializing the result into the page payload for hydration. `useFetch(url, opts)` is sugar over
`useAsyncData(autoKey, () => $fetch(url, opts))`.

| Option | Effect |
|---|---|
| `key` | shared/deduped result; same key → same `data`/`error`/`status` ref across components; auto-cleaned on last unmount |
| `lazy: true` | resolve after navigation instead of blocking it; `status` goes `pending` → `success` |
| `server: false` | skip the server fetch; fetch only on the client (pairs well with `lazy`) |
| `immediate: false` | don't fetch until you call `execute()`/`refresh()` |
| `transform: (d) => ...` | reshape the response before it is stored (also shrinks payload) |
| `pick: ['a','b']` | keep only these top-level fields → smaller payload |
| `watch: [refA]` / reactive `key` | refetch when a watched ref / a `ref`/`computed`/getter key changes |
| `default: () => ...` | value for `data` before the first resolve |
| `dedupe: 'cancel' \| 'defer'` | how concurrent calls with the same key behave |
| `getCachedData: (key, nuxtApp, ctx) => ...` | serve cached data; `ctx.cause` tells you why (initial/refresh/watch) |

**Nuxt 4 specifics:** `data` is a `shallowRef` by default (replace the whole value to update, don't
deep-mutate); `getCachedData` receives a `{ cause }` context; Nuxt 4.2 supports passing an
`AbortController` `signal` for cancellation.

```vue
<script setup lang="ts">
const page = ref(1)
const { data, status, error, refresh } = await useFetch('/api/products', {
  key: 'products',
  query: { page },                 // reactive query → refetch when page changes
  transform: (r: ProductsDto) => r.items,
  pick: ['items'],
  lazy: true,
})
function reload() { refresh() }                 // re-run this one
</script>
```

Invalidate across the app with `refreshNuxtData('products')` (or no arg to refresh all). `clear()`
resets `data`/`error` to defaults.

## Custom `$fetch` instance (`$api`)

Centralize base URL, auth header, and error handling once. Register it as a Nuxt plugin and reuse
everywhere; it is SSR-aware and forwards cookies on the server.

```ts
// plugins/api.ts
export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig()
  const api = $fetch.create({
    baseURL: config.public.apiBase,
    onRequest({ options }) {
      const token = useCookie('token').value
      if (token) options.headers.set('Authorization', `Bearer ${token}`)
    },
    onResponseError({ response }) {
      if (response.status === 401) navigateTo('/login')
    },
  })
  return { provide: { api } }
})
// use: const { $api } = useNuxtApp()
//      const { data } = await useAsyncData('me', () => $api('/me'))
```

## Pinia setup stores + SSR hydration

`@pinia/nuxt` auto-imports stores from `app/stores/`. The setup-store style is the idiomatic
Composition form; Nuxt serializes store state into the payload and rehydrates it on the client — no
manual `state` transfer.

```ts
// app/stores/cart.ts
export const useCartStore = defineStore('cart', () => {
  const items = ref<Item[]>([])
  const total = computed(() => items.value.reduce((s, i) => s + i.price, 0))
  async function load() {
    items.value = await $fetch('/api/cart')   // call inside an action, not module scope
  }
  function add(i: Item) { items.value.push(i) }
  return { items, total, load, add }
})
```

For server-resolved store state, populate it from a component's `useAsyncData`/`callOnce` so it is
filled during SSR and hydrated, not refetched on the client.

**Pinia Colada** is the data-fetching layer for Pinia (query cache, invalidation, mutations) — an
alternative to hand-rolling `useAsyncData` caching when you want React-Query-style ergonomics in a
Vue/Nuxt app. Add it only if the app's data needs justify a cache layer.

## `useState` patterns

```ts
// composables/useCounter.ts — shared, SSR-safe, hydrated
export const useCounter = () => useState('counter', () => 0)

// one-time server work, deduped across components and not re-run on client:
const { data } = await useAsyncData('settings', () => $fetch('/api/settings'))
// or for side-effecting init that must run once: await callOnce(() => store.load())
```

Keep `useState` for small shared values; promote to a Pinia store once you need actions, getters,
and multiple consumers with logic.

## Optimistic UI

Update the local ref immediately, fire the mutation, roll back on error.

```ts
async function toggleLike(post: Post) {
  const prev = post.liked
  post.liked = !prev                              // optimistic
  try { await $fetch(`/api/posts/${post.id}/like`, { method: 'POST' }) }
  catch (e) { post.liked = prev; throw e }        // rollback
}
```

## Error & pending states

Drive UI from `status` (`'idle' | 'pending' | 'success' | 'error'`), not from `data == null`.
Render `error` with a retry that calls `refresh()`. For route-level failures, `throw createError({
statusCode, fatal: true })` to render the error page.
