# UI & navigation (deep dive)

Back to [`../SKILL.md`](../SKILL.md).

Widget composition, Material 3 theming and design tokens, responsive/adaptive layout,
slivers, the **typed go_router** API (go_router 17.2.x + `go_router_builder`), and
accessibility. All code targets **Flutter 3.44 / Dart 3.12**, Material 3.

## Widget composition

Extract subtrees to **widget classes**, never to `_build*()` helper methods.

```dart
// BAD — a private method returning a Widget. The whole parent rebuilds these,
// they can't be const, and the framework can't reuse their Element.
Widget _buildHeader(BuildContext context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
    );

// GOOD — a StatelessWidget class with a const constructor.
class _PageHeader extends StatelessWidget {
  const _PageHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      );
}
```

Why classes win: a `const _PageHeader('x')` is canonicalized — Flutter sees the same instance
across rebuilds and skips its subtree entirely. Methods can't be `const`, give the framework
no rebuild boundary, define no natural `RepaintBoundary` granularity, and break hot-reload
state. The class also slots cleanly into `RepaintBoundary` and is independently testable.

`const` propagation stops rebuilds at the boundary:

```dart
// BAD — new instances every frame.
Padding(padding: EdgeInsets.all(16), child: Icon(Icons.home));
// GOOD — const subtree is never rebuilt.
const Padding(padding: EdgeInsets.all(16), child: Icon(Icons.home));
```

Keys taxonomy — use the right one, and never `UniqueKey` in `build`:

| Key | Use for | Avoid |
| --- | --- | --- |
| `ValueKey` | list/grid item identity (preserve state across reorder) | when items have no stable id |
| `ObjectKey` | identity based on a data object, not a single field | when a `ValueKey` on an id works |
| `GlobalKey` | reaching widget state across the tree (`Form`, measuring) | as a default — it's expensive, use sparingly |
| `UniqueKey` | forcing a fresh element on purpose (rare) | **NEVER in `build`** — forces a rebuild every frame |

Slot-based reusable widgets take `Widget`/`WidgetBuilder` slots, not booleans:

```dart
class AppCard extends StatelessWidget {
  const AppCard({super.key, this.leading, required this.body, this.actions = const []});

  final Widget? leading;
  final WidgetBuilder body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) leading!,
              body(context),
              if (actions.isNotEmpty)
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ),
        ),
      );
}
```

## Material 3 theming & design tokens

Build light and dark schemes from one seed; `useMaterial3` is the default in 3.44 but state
it for clarity.

```dart
ThemeData buildTheme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: brightness,
      ),
      extensions: const [AppSpacing.standard],
    );

final lightTheme = buildTheme(Brightness.light);
final darkTheme = buildTheme(Brightness.dark);
```

App-specific tokens (spacing, radii) belong in a `ThemeExtension`, so they live in the theme
and `lerp` smoothly across light/dark transitions:

```dart
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({required this.sm, required this.md, required this.lg});

  static const standard = AppSpacing(sm: 8, md: 16, lg: 24);

  final double sm;
  final double md;
  final double lg;

  @override
  AppSpacing copyWith({double? sm, double? md, double? lg}) =>
      AppSpacing(sm: sm ?? this.sm, md: md ?? this.md, lg: lg ?? this.lg);

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
    );
  }
}
```

Read tokens through the theme, never as literals:

```dart
final spacing = Theme.of(context).extension<AppSpacing>()!;
final titleStyle = Theme.of(context).textTheme.titleLarge;

// GOOD — semantic tokens.
Padding(padding: EdgeInsets.all(spacing.md), child: Text('Hi', style: titleStyle));
// BAD — magic numbers + hardcoded color break dark mode and the design system.
Padding(padding: const EdgeInsets.all(16), child: Text('Hi', style: TextStyle(color: Colors.blue, fontSize: 22)));
```

## Responsive & adaptive

Define breakpoints once, switch layout on available width (not raw device size):

```dart
abstract final class Breakpoints {
  static const double compact = 600;
  static const double medium = 840;
}

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.destinations, required this.body});

  final List<NavigationDestination> destinations;
  final Widget body;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= Breakpoints.medium;
          if (wide) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(icon: d.icon, label: Text(d.label)),
                    ],
                    selectedIndex: 0,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: SafeArea(child: body)),
                ],
              ),
            );
          }
          return Scaffold(
            body: SafeArea(child: body),
            bottomNavigationBar: NavigationBar(destinations: destinations),
          );
        },
      );
}
```

Use the dimension-specific `MediaQuery` accessors so a widget rebuilds only when *that* aspect
changes:

```dart
final size = MediaQuery.sizeOf(context);            // GOOD — only on size change
final padding = MediaQuery.paddingOf(context);      // GOOD — only on padding change
// final mq = MediaQuery.of(context);               // BAD  — rebuilds on ANY MediaQuery change
```

Prevent overflow with `Flexible`/`Expanded` in rows/columns and `FittedBox` for must-fit text:

```dart
Row(children: [
  const Icon(Icons.label),
  Expanded(child: Text(longTitle, overflow: TextOverflow.ellipsis)),
  FittedBox(child: Text(price)),
]);
```

## Slivers

Mix a collapsing header, a list, and a grid in one scroll context with `CustomScrollView`:

```dart
CustomScrollView(
  slivers: [
    SliverAppBar.large(
      title: const Text('Catalog'),
      floating: true,
      actions: [IconButton(onPressed: onSearch, icon: const Icon(Icons.search))],
    ),
    SliverList.builder(
      itemCount: sections.length,
      itemBuilder: (context, i) => SectionHeader(sections[i]),
    ),
    SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemCount: products.length,
      itemBuilder: (context, i) => ProductTile(products[i]),
    ),
  ],
);
```

Slivers beat nested scrollables when you need a single scroll context (one scrollbar, shared
physics), a collapsing/pinned header, or mixed-axis content (a list above a grid). Nesting a
`ListView` inside a `Column` inside a `ScrollView` causes unbounded-height errors and double
scroll bars — reach for slivers instead.

## Typed go_router (current API)

```yaml
# pubspec.yaml
dependencies:
  go_router: ^17.2.0
dev_dependencies:
  go_router_builder: ^4.0.0
  build_runner: ^2.4.0
```

Route classes are generated from `@TypedGoRoute` annotations; each mixes in `$RouteName`:

```dart
// common/router/app_router.dart
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
  final Product? $extra; // non-serializable object passed in memory, not via URL
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DetailScreen(id: id, product: $extra);
}
```

Assemble the router from the generated `$appRoutes`, with a centralized guard:

```dart
@riverpod
GoRouter router(Ref ref) {
  final authStream = ref.watch(authStateStreamProvider.stream);
  return GoRouter(
    routes: $appRoutes,
    refreshListenable: GoRouterRefreshStream(authStream),
    redirect: (context, state) {
      final loggedIn = ref.read(authControllerProvider).isAuthenticated;
      final goingToLogin = state.matchedLocation == const LoginRoute().location;
      if (!loggedIn && !goingToLogin) return const LoginRoute().location;
      if (loggedIn && goingToLogin) return const HomeRoute().location;
      return null;
    },
    onException: (context, state, router) => router.go(const HomeRoute().location),
  );
}
```

`GoRouterRefreshStream` re-runs `redirect` whenever auth changes:

```dart
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
```

Persistent bottom-nav state uses a typed `StatefulShellRoute.indexedStack`:

```dart
@TypedStatefulShellRoute<MainShellRoute>(
  branches: [
    TypedStatefulShellBranch<FeedBranch>(routes: [TypedGoRoute<FeedRoute>(path: '/feed')]),
    TypedStatefulShellBranch<CartBranch>(routes: [TypedGoRoute<CartRoute>(path: '/cart')]),
  ],
)
class MainShellRoute extends StatefulShellRouteData {
  const MainShellRoute();
  @override
  Widget builder(BuildContext context, GoRouterState state, StatefulNavigationShell shell) =>
      ScaffoldWithNavBar(shell: shell); // each branch keeps its own Navigator stack
}
```

Deep links: configure with the `app_links` package (Android `intent-filter`, iOS associated
domains). **Validate and sanitize the incoming path before navigating** — a deep link is
untrusted input:

```dart
String? sanitizeDeepLink(Uri uri) {
  const allowed = {'/feed', '/cart', '/detail'};
  final base = '/${uri.pathSegments.isEmpty ? '' : uri.pathSegments.first}';
  return allowed.contains(base) ? uri.path : null; // reject anything off the allowlist
}
```

Log navigation with a `NavigatorObserver`:

```dart
class AnalyticsObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    analytics.logScreenView(route.settings.name ?? 'unknown');
  }
}
```

Typed navigation — no magic strings, args are type-checked:

```dart
const DetailRoute(id: '7').go(context);                       // replace
DetailRoute(id: '7', $extra: product).push(context);          // push, pass object in memory
```

## Accessibility

- Label what the framework can't infer; mark decoration as excluded:

```dart
Semantics(label: 'Add to cart', button: true, child: const Icon(Icons.add));
Image.asset('assets/logo.png', semanticLabel: 'Acme logo');
ExcludeSemantics(child: const DecorativeDivider());        // decorative only
MergeSemantics(child: Row(children: [const Icon(Icons.star), const Text('4.8')]));
```

- Minimum 48×48 logical-pixel touch targets (wrap small icons in a sized `InkWell`/`IconButton`).
- Respect text scaling — never hardcode row heights around text; let it grow. Use
  `MediaQuery.textScalerOf(context)` if you must adapt layout.
- Contrast ≥ 4.5:1 for body text; color is never the sole state indicator — pair it with an
  icon or label (e.g. an error shows a red border *and* an error icon *and* text).
