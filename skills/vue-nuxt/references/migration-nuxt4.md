# Migration: Nuxt 3 → Nuxt 4, and Vue 3.4 → 3.5

Companion to the SKILL "detect version" table. Nuxt 4.0 shipped July 2025; the 4.x line is current
stable. Nuxt 5 + Nitro 3 are in active development — treat any "Nuxt 5" claim as pre-release.

## The `app/` srcDir move (headline change)

Nuxt 4 moves application code under `app/` (`srcDir: 'app/'`). New default layout:

```
app/
  components/   composables/   pages/   layouts/   stores/   utils/   middleware/
  app.vue   error.vue   app.config.ts
server/         # Nitro: api/, routes/, middleware/, plugins/, utils/
shared/         # code shared between app and server (auto-imported in both)
public/   modules/   layers/   nuxt.config.ts
```

Why: cleaner separation of client vs server code, faster file watching, and the `shared/` folder
for genuinely isomorphic utilities. A Nuxt 3 repo with root `components/`/`pages/` still works, but
new code should follow the `app/` layout.

## Opting in / compatibility

```ts
// nuxt.config.ts — stay on legacy behavior while migrating
export default defineNuxtConfig({
  future: { compatibilityVersion: 4 },   // opt into v4 behavior on the v3→v4 bridge
  // or pin srcDir explicitly while you move files:
  // srcDir: 'app/',
})
```

Run the upgrade with `npx nuxi upgrade` and use `npx codemod@latest nuxt/4/migration-recipe` (or
the official migration guide) to move files and rewrite imports. Migrate folder-by-folder; the
bridge lets old and new layouts coexist during the move.

## Data-fetching deltas in Nuxt 4

- **Shared keys**: `useFetch`/`useAsyncData` with the same `key` now share one `data`/`error`/
  `status` ref across all callers, auto-cleaned when the last consumer unmounts. Audit code that
  relied on per-call isolation.
- **`data` is a `shallowRef`** by default — replace the whole value to trigger an update; deep
  mutation no longer re-renders. If you genuinely need deep reactivity, opt out with
  `{ deep: true }`.
- **`getCachedData`** now receives a `{ cause }` context (`'initial' | 'refresh:manual' |
  'refresh:hook' | 'watch'`) so you can vary caching by trigger.
- Reactive keys (`ref`/`computed`/getter) refetch on change — previously you wired `watch` manually.
- Nuxt 4.2 adds `AbortController` signal support for request cancellation.

## Other notable changes

- Singleton data layer and consistent `useAsyncData`/`useFetch` keys reduce duplicate fetches.
- Deprecated/renamed APIs flagged by `nuxi upgrade`; check the warnings and the official migration
  guide rather than guessing.
- `@pinia/nuxt` auto-imports stores from `app/stores/` (was `stores/`).

## Vue 3.4 → 3.5 deltas (what Nuxt 4 builds on)

Vue 3.5 is stable and the version Nuxt 4 ships against. Adopt:

- **Reactive Props Destructure stabilized** — `const { count = 0 } = defineProps<{count?: number}>()`
  stays reactive; the compiler rewrites references to `props.count`. Clean default syntax, no
  `withDefaults`.
- **`useTemplateRef('name')`** — typed template DOM refs without a manually-named `ref`.
- **`useId()`** — SSR-stable unique ids for label/input pairs (no hydration mismatch).
- **`<Teleport defer>`** — teleport to a target that mounts later in the same render.
- **`onWatcherCleanup()`** — register watcher teardown without the callback's cleanup arg.
- **Reactivity refactor** — ~56% lower memory and faster large-array iteration; `shallowRef`/
  `shallowReactive` remain the lever for very large structures.

From 3.4: **`defineModel()`** is stable — use it instead of the `props` + `emit('update:x')` pair.

## Looking ahead (do not adopt as default)

Vue 3.6 (beta in 2026) previews **Vapor Mode** — a compile-time, virtual-DOM-free render strategy
opted into per component via `<script setup vapor>`, targeting mid-2026 stable. It is opt-in and
preview-grade; keep production components on the standard renderer until Vapor is stable and the
ecosystem (libraries, dev tools) supports it.
