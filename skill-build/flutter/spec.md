# DESIGN SPEC — skill `flutter`

> Title: **Flutter & Dart app architecture**
> Skill id: `flutter` · origin: `risco`
> Audience: an LLM coding agent working inside the user's real repo (FastAPI/Next.js/Go/**Flutter**/Postgres). Directive, dense, copy-pasteable.
> Verified-current stack (researched 2026-06): **Flutter 3.44 / Dart 3.12**, **Riverpod 3.0** (Notifier/AsyncNotifier unified, legacy import path, mutations, auto-retry, `ref.mounted`, offline persist), **go_router 17.2.x** + `go_router_builder` (mixin `with $RouteName`, `@TypedGoRoute`, `$extra`), **freezed 3.x / json_serializable**, **dio 5.x**, **mocktail 1.x**, **flutter Material 3** (M3 default). Calibrated against ECC `dart-flutter-patterns`, `flutter-dart-code-review`, `compose-multiplatform-patterns`; house style from `risco-project-harness`.

---

## 1. Purpose & precise trigger

**Purpose (one line):** Build, structure, test and optimize Flutter apps with idiomatic Dart 3.12, a feature-first + layered architecture, Riverpod 3 (or Bloc), typed go_router, Material 3, and a real test/perf gate.

**Trigger description (frontmatter, must start with "Use when"):**
> "Use when building, structuring, testing or optimizing a Flutter app (Dart 3, Riverpod 3 / Bloc, go_router, Material 3, freezed, widget & golden tests). Triggers: creating a Flutter feature, choosing state management, wiring navigation/auth guards, modeling async/error state, JSON/dio data layer, killing widget rebuilds/jank, or writing widget/golden/integration tests. Stack: Flutter 3.44 / Dart 3.12."

**When to use:**
- New Flutter feature/screen; choosing or refactoring state management; setting up routing, DI, theming, data layer.
- Reviewing Dart for null-safety, sealed/pattern, immutability, async-gap, rebuild discipline.
- Performance/jank investigation; flavors; test scaffolding (unit/widget/golden/integration).

**When NOT to use:**
- Compose Multiplatform / native Android-Kotlin / SwiftUI UI work → that is the Compose/native skill, not this one.
- Pure Dart **server/CLI** with no Flutter widget tree → general Dart applies but skip UI/nav/perf references.
- Backend (FastAPI/Go) or web (Next.js) work in the same monorepo → use the respective skill; this skill only covers the `pubspec.yaml` subproject.
- Single-file throwaway sample where architecture is overkill — note it, don't impose layering.

---

## 2. SKILL.md outline (target ~380 lines; long material pushed to references/)

Frontmatter: `name: flutter`, trigger-rich `description` (above), `origin: risco`. One H1: `# Flutter & Dart app architecture`.

### `## What this skill is`
One paragraph: opinionated default stack (feature-first + layered, Riverpod 3 codegen, typed go_router, freezed, dio, Result errors) + the escape hatches (Bloc, raw http). States the pinned versions explicitly.

### `## When to use / When NOT to use`
Two tight bullet lists mirroring §1. Includes the cross-stack note (only touches the Flutter subproject, never the FastAPI/Next/Go siblings).

### `## Decision rules` (the spine — a decision table)
Markdown table: *Situation → Do this → Not that*. Rows: ephemeral UI state → `setState`/`ValueNotifier`, not a global provider; shared/async state → Riverpod `@riverpod` Notifier/AsyncNotifier; team already on Bloc → Cubit/Bloc, don't mix; multi-state async → `AsyncValue`/sealed, not bool flags; navigation → one router (typed go_router), never mix `Navigator.push` with declarative; errors → `Result`/sealed at domain boundary, exceptions only at edges; models → freezed; cross-feature data → repository behind an interface.

### `## Project layout` (feature-first + layered)
A fenced `text` tree: `lib/src/features/<feature>/{presentation,domain,data}` + `lib/src/common/{router,theme,network,errors,widgets}` + `main.dart` / `app.dart` / flavored entrypoints (`main_dev.dart`, `main_prod.dart`). One-line rule: dependencies point inward (presentation→domain←data); domain has zero Flutter imports. Pointer → `references/architecture-and-state.md`.

### `## Dart 3.12 idioms` (dense, Good/Bad)
Copy-pasteable blocks, each with a BAD/GOOD contrast:
- Sound null safety: pattern `if (x case final v?)` and `?.`/`??` over `!`; `late` only for guaranteed-before-first-access.
- Records + destructuring for multi-return `(User, int)`; `Future.wait` via record `.wait`.
- Sealed/final classes + exhaustive `switch` expressions (impossible-state elimination).
- `freezed` immutable model with `copyWith`/`fromJson` (3.x syntax: `sealed`/`abstract` class, `@freezed`).
- async/await with **`context.mounted` guard after every await**; `unawaited()` for fire-and-forget.
- Streams via `StreamBuilder`/`ref`, not manual `.listen()` in build.
- Extension types (zero-cost wrappers, e.g. `extension type UserId(String value)`) for ID type-safety.
- Isolates: `Isolate.run(() => heavyParse(json))` for CPU-bound work off the UI thread.
Deep dives → `references/architecture-and-state.md` (error modeling) and `references/performance.md` (isolates).

### `## State management: Riverpod 3 (default)`
The recommended path, code-first and **current**:
- `@riverpod` function provider, `@riverpod` class `Notifier`/`AsyncNotifier` (unified API — note autoDispose/family merged in v3; `Ref` is now a single type).
- `AsyncValue` switch (`data/loading/error`) in UI; `ref.watch` vs `ref.read` vs `ref.listen`; `.select()` for scoped rebuilds.
- `ref.mounted` guard after await inside notifiers (new in v3).
- One-line on v3 extras: automatic retry w/ backoff, `Mutation` for side-effects, `@Riverpod(keepAlive: true)`. Legacy `StateProvider`/`ChangeNotifierProvider` → `package:riverpod/legacy.dart`, do not use in new code.
- `ProviderScope` at root; testing via `ProviderContainer.test()` / overrides (forward-ref to testing.md).
Deeper (codegen setup, AsyncNotifier mutations, persist, DI graph) → `references/architecture-and-state.md`.

### `## State management: Bloc/Cubit (the alternative)`
When the team is on Bloc: Cubit for simple, Bloc(event→state) for complex/event-sourced; sealed state; `BlocBuilder`/`BlocSelector`/`BlocListener`; `BlocProvider` DI; never bloc-to-bloc dependency (share a repository). One Good/Bad. Decision line: **pick one per app, never both.** Deep → `references/architecture-and-state.md`.

### `## UI & navigation (essentials)`
Condensed, the rest in reference:
- Extract widgets to **classes not `_build*()` methods**; `const` everywhere; keys (`ValueKey` in lists, avoid `UniqueKey` in build).
- Material 3 theming from `ColorScheme.fromSeed` + `Theme.of(context)` tokens; **no hardcoded colors/sizes**.
- Typed go_router skeleton: `@TypedGoRoute<HomeRoute>` + `class HomeRoute extends GoRouteData with $HomeRoute`, `redirect`/`refreshListenable` auth guard, `StatefulShellRoute.indexedStack` for bottom nav. One-line `const HomeRoute().go(context)` typed navigation.
Deep (slivers, adaptive/responsive, deep links, nested nav, design tokens) → `references/ui-and-navigation.md`.

### `## Data layer`
dio client with `BaseOptions` + auth interceptor + **one-shot 401 refresh guard**; repository behind an interface returning `Result<T, Failure>` (not raw throws to UI); freezed/json_serializable DTOs mapped to domain entities; caching note. Good/Bad: repository returns `Result`, never leaks `DioException` to widgets. Deep → `references/architecture-and-state.md`.

### `## Testing (gate)`
Short: unit (pure domain + notifiers via `ProviderContainer`), widget (`ProviderScope` overrides + `mocktail` fakes, `pump`/`pumpAndSettle` discipline), golden (`matchesGoldenFile`, deterministic fonts), `integration_test`. One block each, plus the rule "every async state transition has a test." Deep → `references/testing.md`.

### `## Performance (essentials)`
`const` + `RepaintBoundary` + scoped consumers; `ListView.builder` for long lists; `cacheWidth`/`cacheHeight` + cached network images; DevTools timeline / "Track widget rebuilds"; flavors. Deep → `references/performance.md`.

### `## Production checklist`
Compact bullet list: `FlutterError.onError` + `PlatformDispatcher.instance.onError` + `ErrorWidget.builder` wired to Crashlytics/Sentry; secrets via `--dart-define`/`--dart-define-from-file`, secure storage for tokens (Keychain/EncryptedSharedPreferences), never plaintext; HTTPS only; strict `analysis_options.yaml` (`strict-casts/inference/raw-types` + lints); l10n via ARB; a11y (48px targets, semantics, contrast).

### `## Anti-patterns → STOP` (rationalizations table)
Markdown table `Rationalization | Reality`. Rows (≥10): "I'll just `user!` here" → use `?.`/pattern, bang crashes prod; "`_buildHeader()` is fine" → extract to a `const` widget class; "bool `isLoading`+`isError` is simpler" → impossible states; "I'll `setState` at the top of the page" → scope it / use `.select()`; "global provider for this checkbox" → ephemeral = local; "mix `Navigator.push` with go_router for this one screen" → one router; "use `context` after `await`, it's fine" → guard `context.mounted`/`ref.mounted`; "hardcode `Colors.blue` just here" → `colorScheme`; "`ListView(children:[...])` for the feed" → `.builder`; "catch (e) everything" → `on`-typed, never catch `Error`; "ship raw `DioException.toString()` to the user" → map to `Failure`; "`print()` for logging" → `dart:developer log()`; "use legacy `StateProvider`" → Riverpod 3 Notifier; "`pumpAndSettle` will fix the flaky test" → it hangs on infinite animations, use explicit `pump(Duration)`.

### `## Quick reference` (cheat-sheet table)
Table: *Concern → Default API → Reference file*. Rows: model→`@freezed`; sync state→`Notifier`/`Cubit`; async state→`AsyncNotifier`/`AsyncValue`; DI→`@riverpod` providers/`get_it`; routing→typed `go_router`; errors→`Result`/sealed; http→`dio`+interceptor; long list→`ListView.builder`; off-thread→`Isolate.run`; unit test→`ProviderContainer.test()`; widget test→`ProviderScope` override; golden→`matchesGoldenFile`; verify→`scripts/verify.sh`.

### `## See Also`
Sibling skills: `risco-project-harness` (workspace `01-TOOLS`/`02-DOCS`, flavor secrets), and the FastAPI/Next/Go backend skills the Flutter app talks to. Plus the four `references/*` and `scripts/verify.sh`.

---

## 3. references/ files

### 3a. `references/architecture-and-state.md` (~480 lines)
Focus: architecture + DI + error modeling + both state solutions in depth.
- **Layering contract**: presentation/domain/data responsibilities; the dependency rule; full feature folder example for a `cart` feature with file list.
- **Domain entities & DTOs**: freezed 3.x entity, json_serializable DTO, explicit `DtoX.toDomain()` mapper. Why DTO≠entity.
- **Result/Either error modeling**: a hand-rolled `sealed class Result<S, F>` with `Ok`/`Err`, `when`/`map`/`fold`, plus a `sealed class Failure` (network/auth/validation/unexpected) and where exceptions are caught and converted (data layer only). Good/Bad showing UI consuming `Result`, not try/catch.
- **Repository pattern**: abstract `CartRepository` interface in domain, `CartRepositoryImpl(this._dio, this._cache)` in data, returning `Result`.
- **DI**: Riverpod provider graph (`@riverpod CartRepository cartRepository(Ref ref) => ...`) as primary; `get_it` registration alternative (singleton/factory/lazySingleton) with a note on when get_it beats providers (non-widget bootstrap).
- **Riverpod 3 deep**: codegen setup (`riverpod`, `riverpod_annotation`, `riverpod_generator`, `build_runner`, `custom_lint`+`riverpod_lint` in `analysis_options.yaml`); `@riverpod` function vs class; `AsyncNotifier` with `AsyncValue.guard`; family-as-constructor-arg (v3); `ref.onDispose`, `ref.keepAlive`, `ref.invalidate`; `.select()`; `Mutation` example for form submit; `ref.mounted`; offline `persist()` note. The build_runner watch command.
- **Bloc deep**: full `AuthCubit` + an event-driven `Bloc` with sealed events/states, `emit.forEach` for streams, `BlocObserver` wired to error reporting, hydrated_bloc note for persistence. When Bloc > Riverpod (event sourcing, explicit transitions, large team conventions).
- **Choosing table**: Riverpod vs Bloc across criteria (boilerplate, codegen, DI built-in, testability, learning curve, side-effects).

### 3b. `references/ui-and-navigation.md` (~470 lines)
Focus: widgets, Material 3, responsive, go_router.
- **Widget composition**: class-vs-method (with the element-reuse/const rationale), `const` propagation, keys taxonomy (`ValueKey`/`ObjectKey`/`GlobalKey` sparingly/never `UniqueKey` in build), slot-based reusable widgets (`Widget? leading`, `WidgetBuilder`).
- **Material 3 theming & tokens**: `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor:..., brightness:...), useMaterial3: true)`, light/dark, a `ThemeExtension<AppTokens>` for custom spacing/radii design tokens, reading via `Theme.of(context).extension<AppTokens>()`. Good/Bad: tokens vs magic numbers.
- **Responsive/adaptive**: `LayoutBuilder` + breakpoints constants, `MediaQuery.sizeOf` (specific aspect), `SafeArea`, adaptive widgets, `Flexible`/`Expanded`/`FittedBox` to prevent overflow.
- **Slivers**: `CustomScrollView` with `SliverAppBar`/`SliverList.builder`/`SliverGrid`, when slivers beat nested scrollables.
- **go_router typed (current API)**: full setup — `@TypedGoRoute<T>` route classes `with $RouteName`, `build`/`redirect` overrides, `$extra` for non-serializable objects, `TypedGoRoute` children, the generated `$appRoutes`. `GoRouter(routes: $appRoutes, redirect: ..., refreshListenable: GoRouterRefreshStream(authStream), onException: ...)`. Auth guard centralized in top-level `redirect`. `StatefulShellRoute.indexedStack` with `StatefulShellBranch`es for persistent bottom-nav state. Deep links (`app_links` + path config for Android `intent-filter`/iOS associated domains, validate/sanitize before nav). Nested navigation + an analytics `NavigatorObserver`. Typed navigation `const DetailRoute(id: '7').go(context)`.
- **Accessibility block**: `Semantics`, `semanticLabel` on images, `MergeSemantics`, 48px targets, text scaling, contrast.

### 3c. `references/testing.md` (~430 lines)
Focus: the full test pyramid with runnable code.
- **Setup**: dev_deps (`flutter_test`, `mocktail`, `riverpod`'s test utils, `golden_toolkit` or built-in golden, `integration_test`), folder `test/` mirroring `lib/src/`.
- **Unit**: pure domain function; an `AsyncNotifier` tested with `ProviderContainer.test()` + `container.read`, listening to state transitions; `mocktail` `when/verify`, `registerFallbackValue`, fakes-over-mocks guidance.
- **Repository test**: mock `Dio`, assert `Result.Ok`/`Err` mapping incl. error path.
- **Bloc test**: `blocTest` loading→success and loading→error.
- **Widget tests**: `pumpWidget(ProviderScope(overrides:[...], child: MaterialApp(...)))`; `pump` vs `pumpAndSettle` discipline (explicit `pump(Duration)` for indeterminate animations, warning that `pumpAndSettle` hangs on infinite animations); finders (`byType/text/byKey`); `tester.tap` + rebuild; testing async/error UI states.
- **Golden tests**: `matchesGoldenFile`, deterministic setup (load real fonts / `TestWidgetsFlutterBinding`, fixed surface size, `await tester.runAsync` for images), multi-device golden via builder, update workflow `flutter test --update-goldens`. CI gotcha: render differences across platforms → run goldens on a pinned image/`--tags golden`.
- **integration_test**: `IntegrationTestWidgetsFlutterBinding`, a full login→home flow, running on device/`flutter test integration_test`.
- **Coverage**: `flutter test --coverage` → `coverage/lcov.info`, filtering generated files (`*.g.dart`,`*.freezed.dart`) with `lcov --remove`, target 80% on domain/state.

### 3d. `references/performance.md` (~360 lines)
Focus: rebuilds, paint, jank, build flavors.
- **Rebuild minimization**: `const` constructors, extract-to-class, scoped consumers + `.select()`/`BlocSelector`/`buildWhen`, `ValueListenableBuilder` for leaf state, `AnimatedBuilder` `child:` escape hatch. Good/Bad page rebuild example.
- **Paint**: `RepaintBoundary` around independently-animating subtrees; avoid `Opacity`/`ClipRRect` in animations (use `FadeTransition`/pre-clipped assets); `IntrinsicHeight/Width` cost note.
- **Lists & images**: `ListView.builder`/`SliverList.builder`, `itemExtent`/`prototypeItem` for fixed rows, pagination, `addAutomaticKeepAlives` caution; `cacheWidth`/`cacheHeight` decode-at-size, `cached_network_image` with placeholder/error, `precacheImage`.
- **Off-thread**: `Isolate.run` / `compute` for JSON parse & image processing; `dart:ui` `ImageFilter` cost.
- **Profiling**: run in **profile mode** (`flutter run --profile`); DevTools Performance/Timeline, "Track Widget Rebuilds", raster vs UI thread reading, `Timeline.startSync`/`finishSync` custom events, `--profile`+`--trace-skia`; jank checklist (>16ms frames, shader jank → `--purge-persistent-cache` / impeller note).
- **Build flavors**: `--flavor` + `--dart-define-from-file=config/dev.json`, Android `productFlavors`, iOS schemes/xcconfig, flavored `main_dev.dart`/`main_prod.dart` entrypoints reading `String.fromEnvironment`. Release build sizes (`--analyze-size`, `--split-debug-info`, `--obfuscate`).

---

## 4. verify.sh contract

Path: `skills/flutter/scripts/verify.sh`. Executable (`chmod +x`). **Do not run in this repo** (not a Flutter project). Idempotent; END USER runs it inside their Flutter project root.

- Shebang `#!/usr/bin/env bash`; `set -euo pipefail`.
- Top usage comment: what it does, how to run (`bash scripts/verify.sh` from a Flutter app root), and that missing tools are skipped (yellow) not failed.
- Helper: `warn()` prints yellow `[skip]`; `have()` = `command -v`. Detect `flutter`/`dart` once.
- **Guard**: if no `pubspec.yaml` in `$PWD`, print yellow warning "not a Flutter/Dart project — skipping" and `exit 0` (so it's safe to run anywhere).
- **Tool order (each guarded by detection; missing → warn+skip, never fail):**
  1. `dart format --output=none --set-exit-if-changed .` — formatting gate (fails on unformatted).
  2. `dart analyze --fatal-infos` — static analysis (fails on any info/warning/error).
  3. If `build_runner` is a dependency (grep `pubspec.yaml`), run `dart run build_runner build --delete-conflicting-outputs` so generated files are current before tests; skip with note if absent.
  4. `flutter test --coverage` — runs unit+widget+golden; **fails** on test failure. If `flutter` absent but `dart` present (pure Dart pkg), fall back to `dart test`.
- **Skip vs fail rule:** a tool that is **not installed** → yellow warning, continue, do **not** affect exit code. A tool that **runs and reports problems** → non-zero exit (propagated by `set -e` / explicit capture). Track an `errors` counter so all gates run and the script exits non-zero if any real failure occurred (don't bail on the first so the user sees every problem — capture exit codes, `exit 1` at end if any failed).
- Final line: green "all checks passed" or red summary of which gate(s) failed.

---

## 5. Quality differentiators (why this beats the ECC equivalents)

1. **Current, version-pinned APIs ECC predates**: Riverpod **3.0** (unified Notifier/AsyncNotifier, family-as-constructor-arg, `ref.mounted`, `Mutation`, auto-retry, `legacy.dart` import) and go_router **17.x** typed routes with the **`with $RouteName`** mixin + `$extra` — ECC's `dart-flutter-patterns` shows Riverpod 2 `@riverpod` and string-based GoRouter only.
2. **Decision-rule spine + rationalizations→STOP table** in the house `risco` style — ECC `dart-flutter-patterns` is example-list-shaped with no explicit decision table or anti-pattern STOP gate; ECC `flutter-dart-code-review` is a checklist, not actionable build guidance.
3. **One skill, both build + review**: folds the review checklist's correctness rules (async-gap, sealed-state, const, keys, security) directly into directive build guidance, so the agent applies them while writing, not only when reviewing.
4. **End-to-end error modeling**: explicit `Result`/`Failure` sealed types with the exact catch-and-map boundary (data layer only) and UI consuming `Result` — ECC mentions sealed states but never wires a Result type through repository→UI.
5. **Real, runnable verify.sh gate** matching `dart format --set-exit-if-changed; dart analyze --fatal-infos; flutter test --coverage`, with build_runner codegen step and graceful tool-skip — neither ECC skill ships an executable project gate.
6. **Testing depth that's actually correct**: `ProviderContainer.test()` (v3), `pumpAndSettle`-hangs-on-infinite-animation warning, deterministic golden setup (fonts/surface/`runAsync` for images) and the CI cross-platform golden gotcha — beyond ECC's quick-reference snippets.
7. **Performance that names the tools**: profile-mode requirement, DevTools "Track Widget Rebuilds", raster-vs-UI-thread, Impeller/shader jank, `--analyze-size`/`--split-debug-info`, and build flavors with `--dart-define-from-file` — ECC's perf is a review checklist, not a hunting workflow.
8. **Dart 3.12 idioms ECC omits**: extension types for typed IDs, `Isolate.run` for off-thread parse, records `.wait` concurrency, freezed 3.x `sealed`/`abstract` syntax.

---

## 6. File manifest (to build next)
- `skills/flutter/SKILL.md` (~380 lines)
- `skills/flutter/references/architecture-and-state.md` (~480)
- `skills/flutter/references/ui-and-navigation.md` (~470)
- `skills/flutter/references/testing.md` (~430)
- `skills/flutter/references/performance.md` (~360)
- `skills/flutter/scripts/verify.sh` (executable, chmod +x, not run here)
