# Incremental migration — legacy Angular → standalone, signals, zoneless

Migrate a working app in small reversible steps. Each step has an official schematic; run them
one at a time, commit, and verify the app still builds and tests pass before the next.

## Order of operations

1. Update Angular first, then migrate. `ng update @angular/core @angular/cli` runs the
   bundled migrations for the version you land on. Do not migrate APIs on an old major.
2. Standalone components/directives/pipes.
3. Built-in control flow (`*ngIf`/`*ngFor` → `@if`/`@for`).
4. Signal inputs/outputs.
5. Zoneless (last — it has the widest blast radius).
6. Test runner (Karma/Jasmine → Vitest), independently of the above.

## 1. NgModule → standalone

```bash
ng generate @angular/core:standalone
```

Run it three times, choosing each mode in turn:
- *Convert all components, directives and pipes to standalone*
- *Remove unnecessary NgModule classes*
- *Bootstrap the application using standalone APIs* (rewrites `main.ts` to `bootstrapApplication`)

After the last pass you should have an `app.config.ts` with `provideRouter`,
`provideHttpClient`, etc. Delete the now-empty `AppModule`.

## 2. Control flow: *ngIf / *ngFor → @if / @for

```bash
ng generate @angular/core:control-flow
```

This rewrites templates automatically. Review every converted `@for`: the schematic inserts a
`track` expression (often `track $index` as a safe default). Replace `$index` with a stable key
(`track item.id`) wherever items have identity, so the DOM reuses nodes on reorder. Once
converted you can drop `CommonModule` imports that only existed for the directives.

## 3. Decorator inputs/outputs → signals

```bash
ng generate @angular/core:signal-input-migration
ng generate @angular/core:output-migration
ng generate @angular/core:signal-queries-migration   # @ViewChild/@ContentChild -> viewChild()/contentChild()
```

What changes for callers inside the class:
- `this.userId` (a value) becomes `this.userId()` (a signal read). The migration updates
  template and class reads, but check any code that assigned to the field — signal inputs are
  read-only; lift writable state into a separate `signal()` or use `model()` for two-way.
- `@Output() saved = new EventEmitter()` → `saved = output()`, emit with `saved.emit(x)`.

## 4. Zone.js → zoneless go-live checklist

Flip this last, after signals and control flow are in place.

- [ ] Add `provideZonelessChangeDetection()` to the app providers (and to test providers).
- [ ] Remove `provideZoneChangeDetection()` if present.
- [ ] Delete the `zone.js` import from `polyfills`/`main.ts`; remove `zone.js` from
      `package.json` and the `polyfills` entry in `angular.json`.
- [ ] Audit every component for state read in the template that is **not** a signal — under
      zoneless, a plain field mutated outside an event handler will not repaint. Convert it to a
      `signal()`, or ensure the change originates from a tracked source (signal, async pipe,
      template event, router).
- [ ] Replace any `setTimeout`/`Promise`/3rd-party-callback that mutates view state with a
      signal write, or call `ChangeDetectorRef.markForCheck()` from inside it.
- [ ] Search for `ChangeDetectorRef.detectChanges()` "fix-it" calls and the `NgZone.run()`
      escape hatch — both are smells that some state isn't a signal yet.
- [ ] Run the app and click through; watch for views that update only on the *next* unrelated
      interaction (the classic zoneless-miss symptom).

## 5. Karma/Jasmine → Vitest

New Angular 21 projects use Vitest by default. For an existing project, switch the test builder
to the Vitest-based runner in `angular.json` and migrate specs: Jasmine's `spyOn`/`jasmine.
createSpy` map to Vitest's `vi.fn`/`vi.spyOn`, and `expect().toHaveBeenCalled()` etc. are
compatible. Keep `TestBed`; only the runner and the mocking API change. Add
`provideZonelessChangeDetection()` to test module providers and prefer `await
fixture.whenStable()` over manual `detectChanges()` loops.
