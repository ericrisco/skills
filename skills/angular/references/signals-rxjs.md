# Signals vs RxJS — when to use which, and how to bridge

Signals and RxJS coexist in modern Angular. Signals are the default for UI state and
synchronous derivation; RxJS still owns asynchronous *streams* of events over time.

## Decision matrix

| You have… | Use | Why |
|-----------|-----|-----|
| A piece of UI state read in a template | `signal()` | Pull-based, glitch-free, drives zoneless CD directly |
| A value derived from other state | `computed()` | Memoized, lazy, no manual subscription |
| One async fetch tied to inputs | `httpResource()` / `resource()` | Gives `value/isLoading/error/reload`, auto-refetch, no leak |
| A stream over time (websocket, key events, intervals) | RxJS `Observable` | Signals are values-now, not events-over-time |
| Debounce / throttle / retry / cancel-in-flight | RxJS (`debounceTime`, `switchMap`, `retry`) | These are stream operators; signals have no time dimension |
| A writable copy that resets when a source changes | `linkedSignal()` | Purpose-built; avoids an effect-to-sync anti-pattern |

Rule of thumb: **state → signals, events → observables.** When in doubt, start with a signal;
escalate to RxJS only when you need an operator that models time.

## Interop

`toSignal()` and `toObservable()` are the two bridges (`@angular/core/rxjs-interop`).

```typescript
import { toSignal, toObservable, takeUntilDestroyed } from '@angular/core/rxjs-interop';

// Observable -> Signal: subscribe is managed for you; unsubscribes on destroy.
private search = signal('');
results = toSignal(
  toObservable(this.search).pipe(
    debounceTime(300),
    switchMap(q => this.api.search(q)),  // switchMap cancels the prior request
  ),
  { initialValue: [] as Result[] },
);
```

- `toSignal(obs$, { initialValue })` — read `results()` in the template; the subscription is
  cleaned up automatically when the injection context is destroyed.
- `toObservable(sig)` — turn a signal into a stream so you can apply operators. It emits on the
  microtask queue, not synchronously.
- `takeUntilDestroyed()` — for the rare hand-rolled subscription, this completes it when the
  component/service is destroyed. Use it instead of a manual `Subscription` + `ngOnDestroy`.

## effect() pitfalls

`effect()` is for side effects, not derivation. Common ways it goes wrong:

```typescript
// Pitfall 1 — infinite loop: an effect that writes a signal it also reads.
effect(() => this.count.set(this.count() + 1)); // re-runs forever

// Pitfall 2 — using an effect to derive state. Use computed() instead.
effect(() => this.total.set(this.qty() * this.price())); // double-fires, hidden graph
// Fix:
total = computed(() => this.qty() * this.price());

// Pitfall 3 — wanting to write without creating a dependency: wrap in untracked().
effect(() => {
  const id = this.userId();           // tracked dependency
  untracked(() => this.log.push(id)); // read/write here is NOT a dependency
});
```

- An effect runs once on creation and again whenever any signal it *reads* changes.
- Reading a signal inside `untracked(() => …)` does not register it as a dependency.
- If you find yourself calling `.set()` from inside an effect to feed the template, you almost
  certainly want `computed()` or `linkedSignal()`.

## resource() / httpResource() patterns

```typescript
// Dependent fetch: the resource re-runs when team() changes.
team = signal('eng');
users = httpResource<User[]>(() => `/api/users?team=${this.team()}`);

// Mutate then refresh:
async addUser(u: User) {
  await firstValueFrom(this.http.post('/api/users', u));
  this.users.reload();
}

// Loading / error in the template:
// @if (users.isLoading()) { <app-spinner/> }
// @else if (users.error()) { <p>Failed</p> }
// @else { @for (u of users.value(); track u.id) { … } }
```

- A `resource()` cancels the previous load when its `params` change (it passes an `AbortSignal`
  to the loader) — use it for `fetch` cancellation without writing RxJS.
- `httpResource()` is GET-oriented and reactive. For POST/PUT/DELETE keep `HttpClient` and call
  `reload()` after the mutation.
