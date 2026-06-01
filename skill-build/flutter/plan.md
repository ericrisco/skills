# IMPLEMENTATION PLAN — skill `flutter`

> Source of truth: `/Volumes/EXTERN/DEV/skills/skill-build/flutter/spec.md`.
> Build target root: `/Volumes/EXTERN/DEV/skills/skills/flutter/`.
> Stack to write against (state versions explicitly in prose): **Flutter 3.44 / Dart 3.12**, **Riverpod 3.0**, **go_router 17.2.x** + `go_router_builder`, **freezed 3.x** / `json_serializable`, **dio 5.x**, **mocktail 1.x**, Material 3.
> Audience: an LLM coding agent working inside a real repo. Write directive, dense, copy-pasteable. ECC is the floor.
> This is a writing plan. The implementer follows it verbatim with no further decisions.

---

## 0. File list (exact paths, create in this order)

1. `/Volumes/EXTERN/DEV/skills/skills/flutter/SKILL.md` (~380 lines, budget 250–450)
2. `/Volumes/EXTERN/DEV/skills/skills/flutter/references/architecture-and-state.md` (~480 lines, 200–500)
3. `/Volumes/EXTERN/DEV/skills/skills/flutter/references/ui-and-navigation.md` (~470 lines, 200–500)
4. `/Volumes/EXTERN/DEV/skills/skills/flutter/references/testing.md` (~430 lines, 200–500)
5. `/Volumes/EXTERN/DEV/skills/skills/flutter/references/performance.md` (~360 lines, 200–500)
6. `/Volumes/EXTERN/DEV/skills/skills/flutter/scripts/verify.sh` (executable, `chmod +x`, DO NOT run here)

Create the directories first:
```bash
mkdir -p /Volumes/EXTERN/DEV/skills/skills/flutter/references
mkdir -p /Volumes/EXTERN/DEV/skills/skills/flutter/scripts
```

Global rules for ALL markdown files:
- Exactly one H1 per file (the title).
- Every fenced code block has a language tag (`dart`, `bash`, `yaml`, `text`, `json`).
- Good/Bad contrasts use `// BAD` and `// GOOD` inline comments (Dart) or `# BAD`/`# GOOD` (bash/yaml).
- Reference links between files are relative: `references/architecture-and-state.md`, `../SKILL.md`, `scripts/verify.sh`.
- No placeholders, no `TODO`, no `etc.`. Every code block must compile in context.

---

## 1. `SKILL.md` — full section-by-section spec

### Frontmatter (exact)
```yaml
---
name: flutter
description: Use when building, structuring, testing or optimizing a Flutter app (Dart 3, Riverpod 3 / Bloc, go_router, Material 3, freezed, widget & golden tests). Triggers: creating a Flutter feature, choosing state management, wiring navigation/auth guards, modeling async/error state, JSON/dio data layer, killing widget rebuilds/jank, or writing widget/golden/integration tests. Stack: Flutter 3.44 / Dart 3.12.
origin: risco
---
```

### H1
`# Flutter & Dart app architecture`

### Sections in order

**1. `## What this skill is`** (one paragraph, ~6 lines)
- One sentence: opinionated default stack — feature-first + layered, Riverpod 3 codegen, typed go_router, freezed models, dio data layer, `Result`/`Failure` error modeling, Material 3.
- One sentence: escape hatches — Bloc/Cubit instead of Riverpod, raw `http`/`get_it` allowed; pick one per app.
- State pinned versions explicitly: Flutter 3.44, Dart 3.12, Riverpod 3.0, go_router 17.2.x, freezed 3.x, dio 5.x.

**2. `## When to use / When NOT to use`** (two bullet lists)
- When to use (4 bullets): new feature/screen; choosing/refactoring state management; routing/DI/theming/data-layer setup; reviewing Dart for null-safety/sealed/async-gap/rebuild discipline; perf/jank; test scaffolding.
- When NOT to use (4 bullets): Compose Multiplatform / native Android-Kotlin / SwiftUI → Compose/native skill; pure Dart server/CLI with no widget tree → general Dart, skip UI/nav/perf refs; FastAPI/Go/Next.js siblings in the monorepo → respective skill, this skill only touches the `pubspec.yaml` subproject; single-file throwaway sample → note it, don't impose layering.

**3. `## Decision rules`** (markdown table — the spine)
Header: `| Situation | Do this | Not that |`. Rows (write all 8):
1. Ephemeral UI state (checkbox, slider, anim) | `setState` / `ValueNotifier` locally | a global provider
2. Shared / async state | Riverpod `@riverpod` `Notifier`/`AsyncNotifier` | scattered `setState` across pages
3. Team already on Bloc | Cubit (simple) / Bloc (event-sourced) | mixing Bloc + Riverpod in one app
4. Multi-state async | `AsyncValue` / sealed state | `bool isLoading` + `bool isError` flags
5. Navigation | one typed go_router | mixing `Navigator.push` with declarative routes
6. Errors at domain boundary | `Result<T, Failure>` / sealed | leaking `DioException` / raw `throw` to UI
7. Models / DTOs | `@freezed` immutable classes | hand-written mutable classes
8. Cross-feature data | repository behind an interface | widgets calling `dio`/DB directly

**4. `## Project layout`** (fenced `text` tree + one rule)
Write this exact tree:
```text
lib/
  main.dart                 # bootstrap (shared)
  main_dev.dart             # flavored entrypoint -> runApp(const App(flavor: Flavor.dev))
  main_prod.dart
  app.dart                  # MaterialApp.router + ProviderScope wiring
  src/
    features/
      cart/
        presentation/       # widgets, screens, Riverpod consumers
        domain/             # entities, repository interfaces, Result/Failure (zero Flutter imports)
        data/               # DTOs, dio data sources, repository impls
    common/
      router/               # typed go_router + guards
      theme/                # ColorScheme.fromSeed, ThemeExtension tokens
      network/              # dio client + interceptors
      errors/               # Result, Failure sealed types
      widgets/              # shared reusable widgets
```
One-line rule below the tree: dependencies point inward — `presentation → domain ← data`; `domain/` has **zero Flutter imports**.
Pointer: `See references/architecture-and-state.md for the full layering contract and a worked cart feature.`

**5. `## Dart 3.12 idioms`** (dense, each a Good/Bad or a single canonical block)
Write these blocks in order. Keep each tight (5–14 lines):
- Null safety: `// BAD final n = user!.name;` vs `// GOOD final n = user?.name ?? 'Unknown';` plus `if (user case User(:final name)?) ...` pattern and a `switch` expression over a nullable.
- `late`: BAD `late String id;` vs OK `late final AnimationController _c;` initialized in `initState`.
- Records + destructuring: `final (user, count) = await (repo.user(), repo.count()).wait;` (Dart 3 record `.wait` concurrency). Note: parallel, not sequential.
- Sealed + exhaustive switch: `sealed class JobState {}` with `final class` variants + `Widget build => switch (state) {...}` showing impossible-state elimination.
- async-gap guard: `await ...; if (!context.mounted) return;` in a `State`, and `if (!ref.mounted) return;` inside a Notifier. Also `unawaited(analytics.log(...));`.
- Streams: `StreamBuilder` in build, NOT manual `.listen()` in build (one-line BAD).
- Extension types: `extension type UserId(String value) {}` for zero-cost ID type-safety; show a function that can't accept a raw `String` by mistake.
- Isolates: `final parsed = await Isolate.run(() => heavyParse(jsonBig));` for CPU-bound work off the UI thread.
Pointer: error modeling → `references/architecture-and-state.md`; isolates deep dive → `references/performance.md`.

**6. `## State management: Riverpod 3 (default)`** (code-first, current)
- `@riverpod` function provider (`Future<List<Product>> products(Ref ref)`).
- `@riverpod class CartNotifier extends _$CartNotifier` with `List<CartItem> build()` and an `add`/`remove`.
- `AsyncNotifier` example: `Future<User> build()` + a method using `state = const AsyncLoading(); state = await AsyncValue.guard(() => ...)`.
- UI: `switch (ref.watch(p)) { AsyncData(:final value) => ..., AsyncError(:final error) => ..., _ => loading }`.
- One block on `ref.watch` vs `ref.read` (callbacks only) vs `ref.listen` (side-effects); `ref.watch(p.select((s) => s.field))` for scoped rebuilds.
- `ref.mounted` guard after await inside a notifier (new in v3).
- Prose one-liner: v3 unifies Notifier/AsyncNotifier APIs, merges autoDispose/family, single `Ref` type, adds automatic retry w/ backoff, `Mutation` for side-effects, `@Riverpod(keepAlive: true)`. Legacy `StateProvider`/`ChangeNotifierProvider` live in `package:riverpod/legacy.dart` — do not use in new code.
- `ProviderScope` at root.
Pointer: codegen setup, AsyncNotifier mutations, `Mutation`, persist, DI graph → `references/architecture-and-state.md`. Testing → `references/testing.md`.

**7. `## State management: Bloc/Cubit (the alternative)`** (~25 lines)
- One sentence: Cubit for simple, Bloc (event→state) for complex/event-sourced.
- One canonical `AuthCubit extends Cubit<AuthState>` with sealed `AuthState` + `BlocBuilder` switch.
- One Good/Bad: never bloc-to-bloc dependency — share a repository (`// BAD CartBloc(this.authBloc)` vs `// GOOD CartBloc(this.cartRepo)`).
- Decision line in bold: **pick one per app, never both.**
Pointer: full event-driven Bloc, `BlocObserver`, `hydrated_bloc` → `references/architecture-and-state.md`.

**8. `## UI & navigation (essentials)`** (~30 lines)
- Bullet: extract widgets to **classes not `_build*()` methods**; `const` everywhere; `ValueKey` in lists, never `UniqueKey` in build.
- Material 3 block: `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: ..., brightness: ...))`; read tokens via `Theme.of(context)`; one-line BAD `Colors.blue` vs GOOD `colorScheme.primary`.
- Typed go_router skeleton: `@TypedGoRoute<HomeRoute>(path: '/')` + `class HomeRoute extends GoRouteData with $HomeRoute { Widget build(...) }`; `GoRouter(routes: $appRoutes, redirect: ..., refreshListenable: ...)`; typed nav `const DetailRoute(id: '7').go(context);`.
Pointer: slivers, adaptive/responsive, deep links, nested nav, `StatefulShellRoute`, design tokens, a11y → `references/ui-and-navigation.md`.

**9. `## Data layer`** (~25 lines)
- dio block: `Dio(BaseOptions(baseUrl:..., connectTimeout:..., receiveTimeout:...))` + auth interceptor reading token from secure storage + **one-shot 401 refresh guard** (`extra['_isRetry']`).
- Repository Good/Bad: `// GOOD Future<Result<Cart, Failure>> getCart()` returns mapped `Result`; `// BAD` leaks `DioException` to widgets.
- One line: freezed/json_serializable DTOs mapped via `DtoX.toDomain()`; DTO ≠ entity.
Pointer: full repository + `Result`/`Failure` + caching → `references/architecture-and-state.md`.

**10. `## Testing (gate)`** (~25 lines)
- Unit block: `ProviderContainer.test()` + `container.read`, listen to transitions.
- Widget block: `pumpWidget(ProviderScope(overrides: [...], child: MaterialApp(...)))` + `mocktail` fake.
- Golden one-liner: `expectLater(find.byType(X), matchesGoldenFile('goldens/x.png'));` deterministic fonts.
- Rule in bold: **every async state transition has a test (loading → data, loading → error).**
- `pumpAndSettle` warning one-liner: hangs on infinite animations — use explicit `pump(Duration(...))`.
Pointer: full pyramid, repository tests, blocTest, golden determinism, coverage → `references/testing.md`.

**11. `## Performance (essentials)`** (~20 lines)
- Bullets: `const` + extract-to-class; `RepaintBoundary` around independently-animating subtrees; `ListView.builder` for long lists; `cacheWidth`/`cacheHeight` + cached network images; `.select()`/`BlocSelector` scoped consumers; profile in `flutter run --profile`, DevTools "Track Widget Rebuilds".
Pointer: rebuild/paint/jank workflow, isolates, build flavors → `references/performance.md`.

**12. `## Production checklist`** (compact bullets)
- `FlutterError.onError` + `PlatformDispatcher.instance.onError` + `ErrorWidget.builder` wired to Crashlytics/Sentry.
- Secrets via `--dart-define` / `--dart-define-from-file`; tokens in secure storage (Keychain / EncryptedSharedPreferences), never plaintext.
- HTTPS only.
- Strict `analysis_options.yaml`: `strict-casts`/`strict-inference`/`strict-raw-types` + `flutter_lints`/`very_good_analysis`.
- l10n via ARB; a11y (48px targets, `Semantics`, contrast ≥ 4.5:1).
- No `print()` → `dart:developer` `log()`.

**13. `## Anti-patterns → STOP`** (table — write all 14 rows)
Header: `| Rationalization | Reality |`. Rows:
1. "I'll just `user!` here" | bang crashes in prod; use `?.`/`??` or `if-case` pattern.
2. "`_buildHeader()` is fine" | extract to a `const` widget class — enables element reuse + const propagation.
3. "`bool isLoading` + `bool isError` is simpler" | allows impossible states; use `AsyncValue`/sealed.
4. "I'll `setState` at the top of the page" | rebuilds the whole subtree; scope it or `.select()`.
5. "global provider for this checkbox" | ephemeral UI state = local `setState`/`ValueNotifier`.
6. "mix `Navigator.push` with go_router for one screen" | one router; mixing breaks deep links + back stack.
7. "use `context` after `await`, it's fine" | guard `context.mounted` / `ref.mounted`; stale context crashes.
8. "hardcode `Colors.blue` just here" | use `colorScheme`; breaks dark mode + theming.
9. "`ListView(children: [...])` for the feed" | use `.builder`; concrete builds all children eagerly.
10. "`catch (e)` everything" | use `on`-typed clauses; never catch `Error` (it's a bug).
11. "ship raw `DioException.toString()` to the user" | map to `Failure` with a localized message.
12. "`print()` for logging" | use `dart:developer` `log()` — has levels, can be filtered.
13. "use legacy `StateProvider`" | Riverpod 3 `Notifier`; legacy is `package:riverpod/legacy.dart` only.
14. "`pumpAndSettle` will fix the flaky test" | hangs on infinite animations; use explicit `pump(Duration)`.

**14. `## Quick reference`** (table)
Header: `| Concern | Default API | Reference |`. Rows: model → `@freezed` → architecture-and-state.md; sync state → `Notifier`/`Cubit` → architecture-and-state.md; async state → `AsyncNotifier`/`AsyncValue` → architecture-and-state.md; DI → `@riverpod` providers / `get_it` → architecture-and-state.md; routing → typed `go_router` → ui-and-navigation.md; errors → `Result`/sealed → architecture-and-state.md; http → `dio` + interceptor → architecture-and-state.md; long list → `ListView.builder` → performance.md; off-thread → `Isolate.run` → performance.md; unit test → `ProviderContainer.test()` → testing.md; widget test → `ProviderScope` override → testing.md; golden → `matchesGoldenFile` → testing.md; verify → `scripts/verify.sh` → scripts/verify.sh.

**15. `## See Also`** (bullet list)
- `references/architecture-and-state.md` — layering, DI, Result/Failure, Riverpod 3 & Bloc deep dives.
- `references/ui-and-navigation.md` — widgets, Material 3 tokens, responsive, typed go_router, a11y.
- `references/testing.md` — unit/widget/golden/integration + coverage.
- `references/performance.md` — rebuilds, paint, jank, isolates, build flavors.
- `scripts/verify.sh` — run inside your Flutter project to gate format/analyze/codegen/tests.
- Sibling skills: `risco-project-harness` (workspace `01-TOOLS`/`02-DOCS`, flavor secrets); the FastAPI / Go / Next.js skills for the backends this app talks to.

Keep SKILL.md within 250–450 lines. If over, trim prose (not code) and push detail to references.

---

## 2. `references/architecture-and-state.md` — sub-sections + exact code

H1: `# Architecture, DI & state management (deep dive)`
Add a one-line "Back to `../SKILL.md`" link under the H1.

### Order + content

**1. `## Layering contract`**
- Table: `| Layer | Owns | May import | Must NOT import |` for presentation / domain / data.
- The dependency rule restated. `domain/` imports neither Flutter nor dio.
- A `text` tree of the full `cart` feature with concrete filenames: `cart_screen.dart`, `cart_controller.dart` (presentation); `cart.dart`, `cart_item.dart`, `cart_repository.dart`, `failure.dart` (domain); `cart_dto.dart`, `cart_remote_data_source.dart`, `cart_repository_impl.dart` (data).

**2. `## Domain entities & DTOs`**
- freezed 3.x entity (`@freezed class Cart with _$Cart`) with `part` directives. Note 3.x: use `sealed`/`abstract` for unions; plain `class` with `_$` mixin for data classes.
- json_serializable DTO `@JsonSerializable() class CartDto` with `fromJson`/`toJson` and a `@JsonKey(name: 'created_at')` example.
- Explicit mapper: `extension CartDtoX on CartDto { Cart toDomain() => Cart(...); }`.
- One paragraph: why DTO ≠ entity (wire shape changes shouldn't ripple into UI; mapping is the boundary).

**3. `## Result / Failure error modeling`**
- Hand-rolled sealed type:
```dart
sealed class Result<S, F> {
  const Result();
}
final class Ok<S, F> extends Result<S, F> {
  const Ok(this.value);
  final S value;
}
final class Err<S, F> extends Result<S, F> {
  const Err(this.failure);
  final F failure;
}
```
- Add `T fold<T>(T Function(S) onOk, T Function(F) onErr)` and a `mapOk`.
- `sealed class Failure` with variants: `NetworkFailure`, `AuthFailure`, `ValidationFailure(this.field)`, `UnexpectedFailure`, each carrying a `message`.
- Good/Bad: data layer catches `DioException`/`FormatException` and returns `Err(NetworkFailure(...))`; UI does `result.fold(onOk: ..., onErr: ...)` — never `try/catch` in the widget.
- Rule: exceptions are caught and converted **only** in the data layer.

**4. `## Repository pattern`**
- Abstract interface in domain: `abstract interface class CartRepository { Future<Result<Cart, Failure>> getCart(); }`.
- Impl in data: `class CartRepositoryImpl implements CartRepository { CartRepositoryImpl(this._remote, this._cache); ... }` with a `try`/`on DioException`/`on FormatException` mapping to `Failure`.
- Caching note: read-through cache, return cached on `NetworkFailure` if available.

**5. `## Dependency injection`**
- Riverpod primary: `@riverpod CartRepository cartRepository(Ref ref) => CartRepositoryImpl(ref.watch(cartRemoteDataSourceProvider), ref.watch(cartCacheProvider));`.
- `get_it` alternative: `getIt.registerLazySingleton<CartRepository>(() => CartRepositoryImpl(...));` with `registerFactory`/`registerSingleton` noted.
- One paragraph: when get_it beats providers (non-widget bootstrap, pre-`runApp` async init), otherwise prefer providers for graph + override-in-test.

**6. `## Riverpod 3 deep`**
- Codegen setup block (`yaml`): dev_dependencies `riverpod_generator`, `build_runner`, `custom_lint`, `riverpod_lint`; deps `flutter_riverpod`, `riverpod_annotation`. Show `analysis_options.yaml` enabling `custom_lint` analyzer plugin.
- build_runner commands (`bash`): `dart run build_runner watch --delete-conflicting-outputs`.
- `@riverpod` function vs `@riverpod class`.
- `AsyncNotifier` with `AsyncValue.guard`:
```dart
@riverpod
class CartController extends _$CartController {
  @override
  Future<Cart> build() => _load();

  Future<void> addItem(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(cartRepositoryProvider);
      final res = await repo.addItem(id);
      return res.fold((c) => c, (f) => throw f);
    });
  }
}
```
- family-as-constructor-arg (v3): `@riverpod Future<Product> product(Ref ref, String id) => ...;` and class form with constructor params.
- `ref.onDispose`, `ref.keepAlive`, `ref.invalidate(p)`.
- `.select()` example.
- `Mutation` for a form submit (v3 side-effect API) — one block showing the mutation triggers an async op and exposes its own pending/error.
- `ref.mounted` after await.
- One line on offline `persist()` (v3 experimental persistence).

**7. `## Bloc deep`**
- Full event-driven `Bloc`: `sealed class CartEvent`, `sealed class CartState`, `class CartBloc extends Bloc<CartEvent, CartState>` with `on<CartItemAdded>` handlers and `emit.forEach` for a stream subscription.
- `BlocObserver` wired to error reporting (`onError` → Crashlytics).
- `hydrated_bloc` one-paragraph note for persistence.
- "When Bloc > Riverpod" paragraph: explicit event sourcing, audited transitions, large-team convention, separation of intent (event) from state.

**8. `## Choosing: Riverpod vs Bloc`** (table)
Header `| Criterion | Riverpod 3 | Bloc 9 |`. Rows: boilerplate; codegen; built-in DI; testability; learning curve; side-effects API; event sourcing. Conclude: default Riverpod; Bloc when the team/domain wants explicit event→state.

Aim 200–500 lines.

---

## 3. `references/ui-and-navigation.md` — sub-sections + exact code

H1: `# UI & navigation (deep dive)`
Back-link to `../SKILL.md`.

### Order + content

**1. `## Widget composition`**
- Class-vs-method Good/Bad (BAD `_buildHeader()` returning a Widget; GOOD `class _PageHeader extends StatelessWidget` with `const` constructor). Rationale paragraph: element reuse, const propagation, `RepaintBoundary` granularity, hot-reload stability.
- `const` propagation Good/Bad.
- Keys taxonomy table: `| Key | Use for | Avoid |` — `ValueKey` (list item identity), `ObjectKey` (identity by object), `GlobalKey` (cross-tree state access, sparingly), `UniqueKey` (NEVER in build — forces rebuild each frame).
- Slot-based reusable widget: `class AppCard extends StatelessWidget` with `final Widget? leading; final WidgetBuilder body; final List<Widget> actions;`.

**2. `## Material 3 theming & design tokens`**
- `ThemeData` light + dark from `ColorScheme.fromSeed(seedColor: ..., brightness: ...)`, `useMaterial3: true`.
- `ThemeExtension<AppSpacing>` custom tokens (`final double sm, md, lg;` + `copyWith` + `lerp`), registered in `ThemeData.extensions`.
- Reading: `Theme.of(context).extension<AppSpacing>()!.md` and `Theme.of(context).textTheme.titleLarge`.
- Good/Bad: tokens/`colorScheme` vs magic numbers/`Colors.blue`.

**3. `## Responsive & adaptive`**
- Breakpoint constants (`class Breakpoints { static const compact = 600.0; static const medium = 840.0; }`).
- `LayoutBuilder` switching layout by `constraints.maxWidth`.
- `MediaQuery.sizeOf(context)` (specific aspect, not `MediaQuery.of`).
- `SafeArea`, `Flexible`/`Expanded`/`FittedBox` to prevent overflow.
- `NavigationRail` (wide) vs `NavigationBar` (compact) adaptive example.

**4. `## Slivers`**
- `CustomScrollView` with `SliverAppBar.large`, `SliverList.builder`, `SliverGrid`.
- One paragraph: when slivers beat nested scrollables (single scroll context, collapsing headers, mixed-axis content).

**5. `## Typed go_router (current API)`**
- pubspec note (`yaml`): `go_router: ^17.2.0`, dev `go_router_builder`, `build_runner`.
- Route classes:
```dart
part 'app_router.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/',
  routes: [TypedGoRoute<DetailRoute>(path: 'detail/:id')],
)
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

class DetailRoute extends GoRouteData with $DetailRoute {
  const DetailRoute({required this.id, this.$extra});
  final String id;
  final Product? $extra;
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DetailScreen(id: id, product: $extra);
}
```
- `GoRouter` assembly: `GoRouter(routes: $appRoutes, refreshListenable: ..., redirect: ..., onException: ...)`.
- Centralized auth guard in top-level `redirect` reading an auth provider/stream; `GoRouterRefreshStream(authStream)`.
- `StatefulShellRoute.indexedStack` with `StatefulShellBranch`es for persistent bottom-nav state (typed via `TypedStatefulShellRoute`).
- Deep links: `app_links` package; Android `intent-filter` + iOS associated domains note; **validate/sanitize the path before navigating**.
- Analytics `NavigatorObserver` subclass logging `didPush`.
- Typed navigation: `const DetailRoute(id: '7').go(context);` and `.push(context)`.

**6. `## Accessibility`**
- `Semantics(label: ...)`, `semanticLabel` on `Image`, `MergeSemantics`, `ExcludeSemantics` for decorative.
- 48×48 min targets; respect text scaling (no fixed-height text rows); contrast ≥ 4.5:1; color never sole state indicator.

Aim 200–500 lines.

---

## 4. `references/testing.md` — sub-sections + exact code

H1: `# Testing the full pyramid (deep dive)`
Back-link to `../SKILL.md`.

### Order + content

**1. `## Setup`**
- dev_dependencies (`yaml`): `flutter_test`, `mocktail: ^1.0.0`, `bloc_test`, `integration_test` (sdk), `golden_toolkit` (optional) — note built-in golden works without it.
- Folder rule: `test/` mirrors `lib/src/`; goldens in `test/.../goldens/`.

**2. `## Unit tests`**
- Pure domain function test.
- `AsyncNotifier` test with `ProviderContainer.test()` (v3 helper) + `addTearDown(container.dispose)`; read state, await, assert `AsyncData`; capture transitions with `container.listen`.
- `mocktail`: `class MockCartRepository extends Mock implements CartRepository {}`, `registerFallbackValue`, `when(() => ...).thenAnswer(...)`, `verify(() => ...).called(1)`.
- "Fakes over mocks" paragraph: prefer in-memory fakes for repositories; mocks for verifying interaction counts.

**3. `## Repository test`**
- Mock `Dio`, stub `get` to return a `Response`, assert `Ok` mapping; stub a `DioException` and assert `Err(NetworkFailure)`. Cover both paths.

**4. `## Bloc test`**
- `blocTest<CartBloc, CartState>` for loading→success and loading→error using `expect: () => [isA<CartLoading>(), isA<CartLoaded>()]`.

**5. `## Widget tests`**
- `pumpWidget(ProviderScope(overrides: [cartControllerProvider.overrideWith(() => FakeCartController())], child: const MaterialApp(home: CartScreen())))`.
- `pump` vs `pumpAndSettle` discipline block: explicit `await tester.pump(const Duration(milliseconds: 300))` for indeterminate animations; **warning callout**: `pumpAndSettle` hangs on infinite animations (spinners) — never call it on a screen with a `CircularProgressIndicator` still spinning.
- Finders: `find.byType`, `find.text`, `find.byKey`.
- `await tester.tap(find.byKey(const Key('add')))` then `pump`, assert rebuild.
- Testing async/error UI: override controller to emit `AsyncError`, assert error widget shown.

**6. `## Golden tests`**
- `expectLater(find.byType(CartCard), matchesGoldenFile('goldens/cart_card.png'));`.
- Deterministic setup: load real fonts in a `flutter_test_config.dart` (`loadAppFonts()` from golden_toolkit, or manual `FontLoader`), fixed surface `tester.view.physicalSize`/`devicePixelRatio`, `await tester.runAsync` for network/decoded images.
- Multi-device golden via a device-list helper.
- Update workflow (`bash`): `flutter test --update-goldens`.
- CI gotcha callout: text/font rendering differs across platforms → run goldens on a pinned CI image or tag them `flutter test --tags golden` and only gate on the canonical platform.

**7. `## integration_test`**
- `IntegrationTestWidgetsFlutterBinding.ensureInitialized();`.
- Full login → home flow: pump the real `App`, enter text, tap, `pumpAndSettle`, assert home route.
- Run (`bash`): `flutter test integration_test`.

**8. `## Coverage`**
- `flutter test --coverage` → `coverage/lcov.info`.
- Filter generated files (`bash`): `lcov --remove coverage/lcov.info '*.g.dart' '*.freezed.dart' '*.config.dart' -o coverage/lcov.info`.
- Target: 80% on domain + state; UI coverage via widget/golden.

Aim 200–500 lines.

---

## 5. `references/performance.md` — sub-sections + exact code

H1: `# Performance: rebuilds, paint, jank & flavors (deep dive)`
Back-link to `../SKILL.md`.

### Order + content

**1. `## Rebuild minimization`**
- `const` constructors + extract-to-class (Good/Bad page where only the counter rebuilds).
- Scoped consumers: `ref.watch(p.select((s) => s.field))`, `BlocSelector`, `buildWhen`.
- `ValueListenableBuilder` for leaf state; `AnimatedBuilder`/`AnimatedWidget` with the `child:` escape hatch (child built once, not per frame).

**2. `## Paint`**
- `RepaintBoundary` around independently-animating subtrees (with the trade-off note: extra layer, use only where it pays).
- Avoid `Opacity`/`ClipRRect` in animations → use `FadeTransition`/pre-clipped assets.
- `IntrinsicHeight`/`IntrinsicWidth` cost note (extra layout pass).

**3. `## Lists & images`**
- `ListView.builder` / `SliverList.builder`; `itemExtent` or `prototypeItem` for fixed-height rows (skips layout); pagination pattern; `addAutomaticKeepAlives: false` caution.
- `Image.asset(..., cacheWidth: 200, cacheHeight: 200)` decode-at-size; `cached_network_image` with `placeholder`/`errorWidget`; `precacheImage` for above-the-fold.

**4. `## Off-thread work`**
- `Isolate.run(() => jsonDecode(big))` and `compute(parseProducts, raw)` for JSON parse / image processing.
- Note `dart:ui` `ImageFilter`/blur cost.

**5. `## Profiling workflow`**
- **Run in profile mode**: `flutter run --profile` (debug numbers are meaningless).
- DevTools Performance / Timeline; enable "Track Widget Rebuilds"; read raster vs UI thread.
- `Timeline.startSync('parse'); ...; Timeline.finishSync();` custom events; `flutter run --profile --trace-skia`.
- Jank checklist: frames > 16ms (60Hz) / > 8ms (120Hz); shader compilation jank → Impeller (default on iOS/Android in 3.44) eliminates most; legacy fallback `--purge-persistent-cache`.

**6. `## Build flavors`**
- `--flavor dev --dart-define-from-file=config/dev.json` invocation.
- Flavored entrypoints: `main_dev.dart` → `runApp(const App(flavor: Flavor.dev))`; read config via `String.fromEnvironment('API_URL')`.
- Android `productFlavors` (`build.gradle`) + iOS schemes/xcconfig note.
- A `config/dev.json` (`json`) example with `API_URL`, `SENTRY_DSN`.
- Release size: `flutter build apk --analyze-size`, `--split-debug-info=build/symbols`, `--obfuscate`.

Aim 200–500 lines.

---

## 6. `scripts/verify.sh` — exact bash

Write this file verbatim, then `chmod +x`. DO NOT execute it in this repo.

```bash
#!/usr/bin/env bash
# verify.sh — Flutter/Dart project quality gate.
#
# Run from the root of a Flutter (or pure-Dart) project:
#   bash scripts/verify.sh
#
# Runs, in order: dart format check, dart analyze, build_runner codegen
# (only if build_runner is a dependency), and the test suite with coverage.
#
# Missing tools are SKIPPED with a yellow warning (never fail the run).
# A gate that runs and reports problems causes a non-zero exit. All gates
# run even if an earlier one fails, so you see every problem at once.
set -euo pipefail

YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
RESET=$'\033[0m'

errors=0

warn() { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$1"; }
info() { printf '==> %s\n' "$1"; }
fail() { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$1"; errors=$((errors + 1)); }
have() { command -v "$1" >/dev/null 2>&1; }

# Guard: only meaningful inside a Dart/Flutter project.
if [[ ! -f pubspec.yaml ]]; then
  warn "no pubspec.yaml in $PWD — not a Flutter/Dart project; skipping"
  exit 0
fi

has_dart=false
has_flutter=false
have dart && has_dart=true
have flutter && has_flutter=true

if ! $has_dart && ! $has_flutter; then
  warn "neither 'dart' nor 'flutter' on PATH — install the Flutter SDK; skipping all checks"
  exit 0
fi

# 1. Formatting gate.
if $has_dart; then
  info "dart format (check only)"
  if ! dart format --output=none --set-exit-if-changed .; then
    fail "code is not formatted — run: dart format ."
  fi
else
  warn "dart not found — skipping format check"
fi

# 2. Static analysis gate.
if $has_dart; then
  info "dart analyze --fatal-infos"
  if ! dart analyze --fatal-infos; then
    fail "static analysis reported issues"
  fi
else
  warn "dart not found — skipping analyze"
fi

# 3. Code generation (only if build_runner is a dependency).
if grep -Eq '^\s*build_runner\s*:' pubspec.yaml; then
  if $has_dart; then
    info "build_runner codegen"
    if ! dart run build_runner build --delete-conflicting-outputs; then
      fail "build_runner failed — generated files may be stale"
    fi
  else
    warn "dart not found — skipping build_runner"
  fi
else
  info "build_runner not a dependency — skipping codegen"
fi

# 4. Tests with coverage.
if $has_flutter; then
  info "flutter test --coverage"
  if ! flutter test --coverage; then
    fail "tests failed"
  fi
elif $has_dart; then
  info "dart test (pure-Dart package — no flutter on PATH)"
  if ! dart test; then
    fail "tests failed"
  fi
else
  warn "no test runner available — skipping tests"
fi

# Summary.
if [[ "$errors" -gt 0 ]]; then
  printf '%s%d gate(s) failed.%s\n' "$RED" "$errors" "$RESET"
  exit 1
fi
printf '%sall checks passed.%s\n' "$GREEN" "$RESET"
```

After writing:
```bash
chmod +x /Volumes/EXTERN/DEV/skills/skills/flutter/scripts/verify.sh
```

Notes for the implementer:
- `set -e` is on, but every gate is wrapped in `if ! cmd; then fail ...; fi`, so a failing gate does NOT abort the script — all gates run and `errors` accumulates. Final `exit 1` if any failed.
- Tool detection via `have()` (`command -v`). Missing tool → `warn` + skip, never increments `errors`.
- `pubspec.yaml` guard makes it safe to run in any directory.
- Do NOT run this script in the skills repo (it is not a Flutter project).

---

## 7. Acceptance checks (implementer self-verifies before finishing)

1. All 6 files exist at the exact paths in §0; `references/` and `scripts/` dirs created.
2. `SKILL.md` frontmatter: `name: flutter`, `description` starts with "Use when ", `origin: risco`. Exactly one H1.
3. `SKILL.md` is 250–450 lines. If over, trim prose and confirm detail lives in references.
4. Each `references/*.md` is 200–500 lines, exactly one H1, every code block language-tagged.
5. No placeholders / `TODO` / `etc.` anywhere. Every Dart block is syntactically valid Dart 3.12 in context (correct `part` directives, `const`, `sealed`/`final class`, `@riverpod`, `with $RouteName` mixins).
6. Versions stated explicitly somewhere in SKILL.md: Flutter 3.44, Dart 3.12, Riverpod 3.0, go_router 17.2.x, freezed 3.x, dio 5.x.
7. Riverpod examples use v3 API (`Ref` single type, `ref.mounted`, `AsyncValue.guard`, family-as-arg, `Mutation`, `package:riverpod/legacy.dart` mention) — NOT Riverpod 2 idioms.
8. go_router examples use typed API (`@TypedGoRoute`, `extends GoRouteData with $RouteName`, `$extra`, `$appRoutes`) — NOT string-route-only.
9. Headings consistent: `##` sections, `###` subsections; Good/Bad use `// BAD`/`// GOOD`.
10. `verify.sh` starts with `#!/usr/bin/env bash` + `set -euo pipefail`, has the usage header, detect-or-skip logic, accumulates `errors`, exits non-zero only on real failures, and is executable (`ls -l` shows `x`). NOT executed in this repo.
11. Cross-links resolve: SKILL.md → all 4 references + verify.sh; each reference back-links to `../SKILL.md`; `## See Also` links sibling skills (`risco-project-harness`, backend skills).
12. Anti-patterns table has ≥14 rows; Quick reference table maps concern → API → reference file; Decision rules table has 8 rows.
```
