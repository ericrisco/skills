# Runes — full semantics, advanced variants, and Svelte 4→5 migration

Current as of June 2026: Svelte 5.56.x. Reading a rune registers a dependency; writing one schedules an update.

## State variants

- `$state(v)` — reactive cell. Objects/arrays become deep proxies, so in-place mutation (`arr.push`, `obj.k = v`) is tracked. No need to reassign.
- `$state.raw(v)` — non-proxied. The reference is reactive only on *reassignment* (`x = newValue`); mutations are not tracked. Use for large immutable structures or values you always replace wholesale (cheaper, no proxy overhead).
- `$state.snapshot(x)` — a static, non-proxied deep clone of a `$state` proxy. Use when passing state to code that doesn't expect a proxy (`structuredClone`, external libs, `console.log` a clean object).

```svelte
<script>
  let big = $state.raw({ rows: [] });        // reassign to update
  big = { rows: [...big.rows, newRow] };      // tracked

  let user = $state({ name: 'Ana' });
  const plain = $state.snapshot(user);        // detached copy
</script>
```

## Derived variants

- `$derived(expr)` — for a single expression.
- `$derived.by(() => { … })` — for multi-statement computations; return the value. Same laziness and dependency tracking; deps are whatever you read *synchronously* inside.

```svelte
<script>
  let nums = $state([1, 2, 3]);
  let total = $derived.by(() => {
    let s = 0;
    for (const n of nums) s += n;
    return s;
  });
</script>
```

A `$derived` is read-only by default but *can* be temporarily overridden by assignment (optimistic UI); it reverts when a dependency changes.

## Effect variants

- `$effect(fn)` — runs after the DOM updates. Return a function for cleanup (runs before re-run and on destroy). Only re-runs for deps read *synchronously* during the run; values read inside `await`/`setTimeout` are not tracked.
- `$effect.pre(fn)` — runs *before* the DOM updates (e.g. measure scroll before layout changes).
- `$effect.root(fn)` — creates an effect scope outside the component lifecycle; returns a dispose function. For manually-managed effects (e.g. in a store module).
- `$effect.tracking()` — boolean: are we inside a tracking context right now? Useful in shared utilities.
- `untrack(fn)` — read state without registering it as a dependency. Breaks unwanted loops.

```svelte
<script>
  import { untrack } from 'svelte';
  let a = $state(0), log = $state([]);
  $effect(() => {
    const cur = a;                       // tracked dep
    untrack(() => log.push(cur));        // reading/writing log is NOT a dep → no loop
  });
</script>
```

Rule of thumb: if an effect's body is "set state B from state A", delete it and use `$derived`. Reserve `$effect` for genuine side effects — DOM APIs, subscriptions, analytics, third-party widgets.

## Props, binding, debugging

- `$props()` — destructure inputs: `let { a, b = 1, ...rest } = $props()`. Rename reserved words: `let { class: klass } = $props()`.
- `$props.id()` — a unique, SSR-stable id for the component instance (good for `for`/`aria-describedby` pairing).
- `$bindable(default)` — marks a prop as two-way: `let { value = $bindable('') } = $props()`, parent does `<Child bind:value />`.
- `$inspect(...values)` — dev-only; logs when tracked values change. `$inspect(x).with(fn)` for a custom handler. Stripped in production.
- `$host()` — inside a custom element, the host DOM node (for dispatching native events).

## Snippets and events (replacing slots / dispatchers)

- Slots → **snippets**: `{#snippet name(args)} … {/snippet}` defined, rendered with `{@render name(args)}`. Children passed to a component arrive as the `children` snippet prop: `let { children } = $props()` then `{@render children()}`.
- `createEventDispatcher` is deprecated → pass **callback props**: `let { onsave } = $props()` and call `onsave(payload)`.
- DOM events lose the colon: `on:click` → `onclick`, `on:input` → `oninput`.

## Svelte 4 → 5 migration map

| Svelte 4 | Svelte 5 (runes) |
| --- | --- |
| `let count = 0;` (reactive top-level) | `let count = $state(0);` |
| `$: doubled = count * 2;` | `let doubled = $derived(count * 2);` |
| `$: { sideEffect(count); }` | `$effect(() => { sideEffect(count); });` |
| `export let title;` | `let { title } = $props();` |
| `export let title = 'x';` | `let { title = 'x' } = $props();` |
| `<slot />` | `{@render children()}` (+ `let { children } = $props()`) |
| named `<slot name="head" />` | named snippet prop + `{@render head()}` |
| `on:click={fn}` | `onclick={fn}` |
| `createEventDispatcher()` + `dispatch('save', x)` | callback prop `onsave` + `onsave(x)` |
| `bind:value` on a prop (auto) | declare `$bindable()` on that prop in the child |
| store `$count` in template | still valid; or migrate to a `.svelte.js` rune module |

The `npx sv migrate svelte-5` codemod automates most of this; review the diff — it cannot always tell a computed `$:` from a side-effect `$:`.

## Fine-grained reactivity gotchas

- A `$state` array assigned from a `$derived` does not auto-track its source — derive the array directly.
- Destructuring a `$state` object (`let { x } = state`) snapshots `x`; it stops tracking. Read `state.x` where you need reactivity, or use `$derived(() => state.x)`.
- `Map`/`Set`/`Date` need `svelte/reactivity` (`SvelteMap`, `SvelteSet`, `SvelteDate`) to be reactive; plain ones are not proxied.
- Passing a `$state` proxy to a non-Svelte library can confuse it — pass `$state.snapshot(x)`.
