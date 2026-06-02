# SvelteKit data loading, mutations, remote functions, and hooks

Current as of June 2026: SvelteKit 2.61.x.

## Universal vs server `load`

| | Universal (`+page.ts`, `+layout.ts`) | Server (`+page.server.ts`, `+layout.server.ts`) |
| --- | --- | --- |
| Runs on | server during SSR **and** browser on client nav | server only |
| Can touch | public APIs, `$env/static/public`, `fetch` | DB clients, secrets, `$env/static/private`, filesystem, cookies |
| Return value | any JS value (functions, classes ok) | must be serializable (devalue: Dates, Maps, etc. — no functions/classes) |
| Can stream | no | yes (top-level promises) |

If both exist for the same route, the server `load` runs first and its data is passed to the universal `load` via the `data` argument.

```ts
// +layout.server.ts
import type { LayoutServerLoad } from './$types';
export const load: LayoutServerLoad = async ({ locals }) => ({ user: locals.user });
```

## `parent()` and dependency tracking

```ts
import type { PageLoad } from './$types';
export const load: PageLoad = async ({ parent, fetch }) => {
  const { user } = await parent();          // merge in ancestor load data
  const res = await fetch(`/api/feed/${user.id}`);
  return { feed: await res.json() };
};
```

- `depends('app:feed')` registers a custom invalidation key; `depends` also auto-tracks any `fetch(url)` and accessed `params`/`url`.
- Re-run: `invalidate('app:feed')` (custom key), `invalidate('/api/feed')` (URL), `invalidate(url => url.pathname.startsWith('/api'))` (predicate), or `invalidateAll()`.

## Streaming

Return a non-awaited promise at the top level of a **server** `load`; the page shell renders immediately and the data resolves later.

```ts
// +page.server.ts
export const load = async () => ({
  meta: await getMeta(),          // awaited — blocks the response
  slowList: getSlowList(),        // promise — streamed
});
```

```svelte
{#await data.slowList}
  <Spinner />
{:then list}
  …
{:catch err}
  <p>{err.message}</p>
{/await}
```

## Form actions

Live in `+page.server.ts`. The default action is `<form method="POST">`; named actions use `action="?/login"` and `export const actions = { login, logout }`.

```ts
import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';

export const actions: Actions = {
  default: async ({ request }) => {
    const data = await request.formData();
    const title = String(data.get('title') ?? '').trim();
    if (!title) return fail(422, { title, error: 'Title required' }); // returned as `form`
    await save({ title });
    throw redirect(303, '/done');
  },
};
```

`fail(status, data)` returns serializable data to the page's `form` prop (keep the user's input so the form repopulates). `redirect` and `error` are thrown, not returned.

### `use:enhance`

Bare `use:enhance` gives no-reload submit + automatic `form`/`data` update + focus management. Customize without losing the defaults:

```svelte
<script lang="ts">
  import { enhance } from '$app/forms';
  let submitting = $state(false);
</script>

<form method="POST" use:enhance={() => {
  submitting = true;
  return async ({ update }) => {
    await update();        // apply the default result handling
    submitting = false;
  };
}}>
  <button disabled={submitting}>Save</button>
</form>
```

## Remote functions (EXPERIMENTAL)

Available since SvelteKit 2.27, iterated through 2.61. API is subject to change. Opt in with **both** flags — `kit.experimental.remoteFunctions` enables the feature, and `compilerOptions.experimental.async` enables the top-level `await` it relies on. Omit either and remote functions stay off:

```js
// svelte.config.js
export default {
  kit: { experimental: { remoteFunctions: true } },
  compilerOptions: { experimental: { async: true } },
};
```

Functions live in `*.remote.ts`. Four kinds:

```ts
// data.remote.ts
import { query, form, command, prerender } from '$app/server';

export const getPosts = query(async () => db.post.all());          // cached server read
export const getPost  = query('unchecked', async (id: string) => db.post.find(id)); // with arg

export const createPost = form(async (data: FormData) => {          // progressive, parses FormData
  const title = String(data.get('title') ?? '');
  return db.post.create({ title });
});

export const like = command(async (id: string) => db.post.like(id)); // mutation, requires JS

export const docs = prerender(async () => loadStaticDocs());        // build-time
```

In a component, `query`/`prerender` return an awaitable with reactive state (`getPosts().current`, `.loading`, `.error`); `form` exposes props to spread onto a `<form>`; `command` is called imperatively (no form, JS required). Prefer plain form actions unless you specifically need imperative mutations or co-located queries.

## Hooks

```ts
// hooks.server.ts
import type { Handle, HandleFetch } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  event.locals.user = await getUser(event.cookies.get('session'));
  return resolve(event);
};

export const handleFetch: HandleFetch = async ({ request, fetch }) => {
  // rewrite/relabel outbound fetch (e.g. internal URL, auth header)
  return fetch(request);
};
```

`handle` wraps every request (auth, headers, `locals`). `handleFetch` intercepts `fetch` calls made inside `load`. `handleError` shapes uncaught errors before they reach `+error.svelte`.

## Errors and redirects

- `error(404, 'Not found')` (thrown) → renders the nearest `+error.svelte` with `page.error`.
- `redirect(303, '/login')` (thrown) → HTTP redirect; use 303 after a POST.
- A `load` that throws an unexpected error triggers `handleError` then `+error.svelte`.
