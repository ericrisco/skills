# Reactivity deep dive (Vue 3.5)

Companion to the SKILL "Composition API & reactivity core" section. Read it when a binding stops
updating, an async effect races, or you are extracting a non-trivial composable.

## `ref` vs `reactive` — pick `ref`

- `ref` boxes any value behind `.value`; survives destructuring (you carry the box), works for
  primitives, and reads uniformly. Templates auto-unwrap top-level refs.
- `reactive` returns a deep Proxy of an object. It cannot hold primitives, breaks on destructure,
  and a whole-object reassignment (`state = {...}`) detaches every consumer.
- Rule: default to `ref`; reach for `reactive` only for a grouped object you never destructure and
  never reassign.

## Reactivity caveats

```ts
import { reactive, toRefs, toRef, ref } from 'vue'

const state = reactive({ a: 1, b: 2 })
const { a } = state           // ✗ detached primitive
const { a: aRef } = toRefs(state)  // ✓ aRef.value linked
const bRef = toRef(state, 'b')     // ✓ single-key ref

// Reassigning a reactive loses every existing reference:
let s = reactive({ n: 1 })
// s = reactive({ n: 2 })     // ✗ old consumers keep the stale proxy
s.n = 2                        // ✓ mutate in place
```

A `ref` of an object is deeply reactive by default. For large structures use `shallowRef`
(reactivity only on `.value` replacement) or `shallowReactive` (only top-level keys) and replace
the whole value to trigger updates.

## `watch` vs `watchEffect` + cleanup

- `watch(src, cb)` — lazy, gives `(new, old)`, explicit source; pass `{ immediate: true }` to run
  once eagerly, `{ deep: true }` to track nested mutations of a `ref<object>`, `{ flush: 'post' }`
  to run after DOM update.
- `watchEffect(fn)` — runs immediately, auto-tracks whatever it reads, re-runs on any change. No
  old value.
- Always cancel stale async work so an out-of-order response can't overwrite a newer one:

```ts
import { watch, onWatcherCleanup } from 'vue'

watch(query, async (q) => {
  const ctrl = new AbortController()
  onWatcherCleanup(() => ctrl.abort())   // 3.5: works without the cb arg
  const res = await fetch(`/api/search?q=${q}`, { signal: ctrl.signal })
  results.value = await res.json()
})
```

## Effect scope

`effectScope()` groups computed/watch effects so you can dispose them together — useful inside a
composable that must tear down on demand. Effects created in `setup`/`onMounted` are auto-scoped to
the component; effects created in a detached context (a singleton, a timer callback) are NOT and
will leak unless you own a scope.

```ts
import { effectScope } from 'vue'
const scope = effectScope()
scope.run(() => { watch(/* ... */) })
// later:
scope.stop()
```

## Composable patterns

A composable is a function named `useX` that uses Composition API internals and returns refs.
Rules:

- Call composables synchronously at the top of `setup` (or inside another composable), never inside
  conditionals/loops — the same lifecycle constraint as React hooks.
- Return refs (or readonly refs), not unwrapped values, so callers keep reactivity.
- Accept refs/getters as input and normalize with `toValue()` so the composable works whether the
  caller passes a raw value, a `ref`, or a getter.
- No top-level module side effects — that runs once per server process and leaks across requests.

```ts
// composables/useMouse.ts
import { ref, onMounted, onUnmounted } from 'vue'
export function useMouse() {
  const x = ref(0), y = ref(0)
  const update = (e: MouseEvent) => { x.value = e.pageX; y.value = e.pageY }
  onMounted(() => window.addEventListener('mousemove', update))   // browser-only, safe in onMounted
  onUnmounted(() => window.removeEventListener('mousemove', update))
  return { x, y }
}
```

Composable, not mixin: mixins merge option objects invisibly and collide on names; composables are
explicit, typed, and tree-shakeable.

## Typed provide / inject

Use an `InjectionKey<T>` so both ends are typed and you avoid string drift.

```ts
// keys.ts
import type { InjectionKey, Ref } from 'vue'
export const ThemeKey: InjectionKey<Ref<'light' | 'dark'>> = Symbol('theme')

// provider
provide(ThemeKey, theme)
// consumer
const theme = inject(ThemeKey)              // Ref<'light'|'dark'> | undefined
const theme2 = inject(ThemeKey, ref('light'))  // with default
```

Provide a readonly ref + a mutator function when consumers should not write directly.

## `defineModel` advanced

```vue
<script setup lang="ts">
const model = defineModel<string>()                       // v-model
const count = defineModel<number>('count', { default: 0 })// named: v-model:count
const [name, modifiers] = defineModel<string>('name', {   // access v-model modifiers
  set: (v) => modifiers.capitalize ? v.toUpperCase() : v,
})
</script>
```

`defineModel` compiles to the prop + `update:` emit pair; reading/writing `.value` is the
two-way binding. Multiple named models on one component are fine.

## Render functions / JSX

`<script setup>` covers nearly everything. Drop to `h()` render functions or JSX (`@vitejs/plugin-vue-jsx`)
only for highly dynamic component shapes a template can't express cleanly — a table that builds
columns from data, a recursive tree renderer. Prefer templates otherwise: they get better
compiler optimization (static hoisting, patch flags) and, in 3.6, Vapor compilation.
