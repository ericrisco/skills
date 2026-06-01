# Performance: rebuilds, paint, jank & flavors (deep dive)

Back to [`../SKILL.md`](../SKILL.md).

A hunting workflow, not a checklist: minimize rebuilds, cut unnecessary paint, keep lists and
images cheap, push CPU-bound work off the UI thread, profile in the right mode, and ship
flavored builds. All code targets **Flutter 3.44 / Dart 3.12**. Impeller is the default
renderer on iOS and Android in 3.44 — most legacy shader-compilation jank is gone, but the
rebuild/paint rules below still decide whether you hold 60/120fps.

## Rebuild minimization

The cheapest frame is the one that doesn't rebuild. Two levers do most of the work: `const`
constructors and extracting subtrees to widget classes so only the changing leaf rebuilds.

```dart
// BAD — watch() at the top rebuilds the whole page, including the static header/footer.
class CounterPage extends ConsumerWidget {
  const CounterPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Scaffold(
      body: Column(children: [
        const ExpensiveHeader(),  // rebuilt for nothing
        Text('$count'),
        const ExpensiveFooter(),  // rebuilt for nothing
      ]),
    );
  }
}

// GOOD — the page is const; only the leaf that watches rebuilds.
class CounterPage extends StatelessWidget {
  const CounterPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Column(children: [ExpensiveHeader(), _CounterText(), ExpensiveFooter()]),
      );
}

class _CounterText extends ConsumerWidget {
  const _CounterText();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Text('${ref.watch(counterProvider)}');
}
```

Scope consumers to the exact field they need. Across solutions:

```dart
// Riverpod — rebuild only when the count changes, not on any cart mutation.
final count = ref.watch(cartControllerProvider.select((s) => s.valueOrNull?.items.length ?? 0));

// Bloc — BlocSelector narrows to one derived value.
BlocSelector<CartBloc, CartState, int>(
  selector: (state) => state is CartLoaded ? state.cart.items.length : 0,
  builder: (context, count) => Text('$count'),
);

// Bloc — buildWhen skips rebuilds that don't matter.
BlocBuilder<CartBloc, CartState>(
  buildWhen: (prev, next) => prev.runtimeType != next.runtimeType,
  builder: (context, state) => CartView(state),
);
```

For a single leaf value, `ValueListenableBuilder` rebuilds nothing else:

```dart
final _selected = ValueNotifier<int>(0);

ValueListenableBuilder<int>(
  valueListenable: _selected,
  builder: (context, value, child) => Tab(active: value == index, child: child),
  child: const TabLabel(), // built once, passed through every rebuild
);
```

Animations are the classic rebuild trap — use the `child:` escape hatch so the subtree builds
once and only the transform/opacity re-evaluates per frame:

```dart
// GOOD — Icon is built once; only the rotation re-evaluates each frame.
AnimatedBuilder(
  animation: _controller,
  child: const Icon(Icons.refresh),
  builder: (context, child) => Transform.rotate(angle: _controller.value * 6.28, child: child),
);
```

## Paint

Rebuild and repaint are separate phases — a widget can repaint without rebuilding. Wrap a
subtree that repaints independently (a spinner, a progress ring, a blinking cursor) in a
`RepaintBoundary` so its repaint doesn't dirty its neighbors:

```dart
RepaintBoundary(child: CircularProgressIndicator(value: _progress));
```

Trade-off: a `RepaintBoundary` allocates a separate layer (memory + a compositing step). Add
it only where a subtree genuinely repaints on a different cadence than its siblings — wrapping
everything is a net loss. Confirm with DevTools "Highlight Repaints" before and after.

Avoid `Opacity` and `ClipRRect` *inside animations* — both force an offscreen buffer every
frame. Use the animated/transition variants or pre-clipped assets:

```dart
// BAD — Opacity in an animation re-composites an offscreen layer every frame.
Opacity(opacity: _controller.value, child: child);
// GOOD — FadeTransition animates on the compositor, no per-frame buffer.
FadeTransition(opacity: _controller, child: child);
```

`IntrinsicHeight`/`IntrinsicWidth` force a second layout pass (the framework lays the child out
twice to measure it). Cheap once, expensive in a scrolling list — prefer a fixed extent or
`Flexible` weighting instead.

## Lists & images

`ListView.builder` / `SliverList.builder` build only visible rows; the concrete
`ListView(children: [...])` builds every child eagerly. For fixed-height rows, give the list an
extent so it can skip per-item layout while scrolling:

```dart
ListView.builder(
  itemCount: items.length,
  itemExtent: 72,                 // every row is 72px tall — skip measuring each one
  itemBuilder: (context, i) => ProductRow(key: ValueKey(items[i].id), product: items[i]),
);

// When rows vary but share a representative shape, use prototypeItem instead of itemExtent.
ListView.builder(
  prototypeItem: const ProductRow.placeholder(),
  itemCount: items.length,
  itemBuilder: (context, i) => ProductRow(product: items[i]),
);
```

Paginate large feeds — fetch the next page near the end, don't load 10k rows at once:

```dart
NotificationListener<ScrollEndNotification>(
  onNotification: (notification) {
    final m = notification.metrics;
    if (m.pixels >= m.maxScrollExtent - 600) ref.read(feedControllerProvider.notifier).loadMore();
    return false;
  },
  child: ListView.builder(itemCount: items.length, itemBuilder: _row),
);
```

`addAutomaticKeepAlives: false` drops offscreen row state to save memory — but only when rows
hold no scroll position or form input worth preserving; the default `true` is safer.

Decode images at display size (`cacheWidth`/`cacheHeight`) so a 4K asset doesn't become a
12MB texture for a 200px thumbnail:

```dart
Image.asset('assets/hero.jpg', cacheWidth: 400, cacheHeight: 400);
```

Network images: cache, and always provide placeholder + error widgets:

```dart
CachedNetworkImage(
  imageUrl: product.imageUrl,
  memCacheWidth: 400,
  placeholder: (context, url) => const ColoredBox(color: Colors.black12),
  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
);
```

Warm above-the-fold images before the first frame to avoid a pop-in:

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  precacheImage(const AssetImage('assets/hero.jpg'), context);
}
```

## Off-thread work

Anything CPU-bound longer than a few milliseconds (large JSON parse, image transform, crypto)
blocks the UI isolate and drops frames. Move it with `Isolate.run` (Dart 3) or `compute`:

```dart
// One-shot — the closure runs on a fresh isolate, result is returned.
final products = await Isolate.run(() => _parseProducts(rawJson));

// compute() — top-level/static function + a single argument.
final products = await compute(_parseProducts, rawJson);

List<Product> _parseProducts(String raw) =>
    (jsonDecode(raw) as List).map((e) => ProductDto.fromJson(e).toDomain()).toList();
```

Keep heavy `dart:ui` effects out of animated paths: `ImageFilter.blur` (frosted-glass
`BackdropFilter`) re-renders the blurred region every frame and is one of the most expensive
operations on screen — render it statically, or behind a `RepaintBoundary`, never per scroll
tick.

## Profiling workflow

**Profile in profile mode. Debug-mode numbers are meaningless** — the VM runs unoptimized and
asserts are on:

```bash
flutter run --profile
```

Then in DevTools → Performance:

- Enable **"Track Widget Rebuilds"** to find widgets rebuilding more than they should — the fix
  is almost always a missing `const` or a too-wide `watch`.
- Read the **Timeline**: the **UI thread** runs your Dart (build/layout); the **raster thread**
  rasterizes the layer tree. A long UI bar = expensive build/layout; a long raster bar =
  expensive paint/shaders/blur.
- Wrap suspect code in custom timeline events to see it in the trace:

```dart
import 'dart:developer';

Timeline.startSync('parseFeed');
final feed = parseFeed(raw);
Timeline.finishSync();
```

Jank checklist: a frame budget is **16ms at 60Hz**, **8ms at 120Hz** — anything longer is a
dropped frame. If the raster thread spikes on first display of a new effect, that's
shader-compilation jank; Impeller (default on iOS/Android in 3.44) precompiles and eliminates
most of it. On a legacy Skia build, capture the SkSL with `flutter run --profile --trace-skia`
and, as a last resort, clear a stale shader cache with `--purge-persistent-cache`.

## Build flavors

Run a flavor with a config file instead of scattering `if (kDebugMode)` checks:

```bash
flutter run --flavor dev  --dart-define-from-file=config/dev.json
flutter run --flavor prod --dart-define-from-file=config/prod.json
```

Flavored entrypoints select config at launch:

```dart
// lib/main_dev.dart
void main() => runApp(const App(flavor: Flavor.dev));

// lib/main_prod.dart
void main() => runApp(const App(flavor: Flavor.prod));
```

Read injected config via compile-time `String.fromEnvironment` — values come from the
`--dart-define-from-file` JSON:

```dart
abstract final class Env {
  static const apiUrl = String.fromEnvironment('API_URL');
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');
}
```

```json
{
  "API_URL": "https://api.dev.example.com",
  "SENTRY_DSN": "https://abc@o0.ingest.sentry.io/0"
}
```

Wire the native side once. Android `productFlavors` in `android/app/build.gradle`:

```text
android {
  flavorDimensions += "env"
  productFlavors {
    dev  { dimension "env"; applicationIdSuffix ".dev"; resValue "string", "app_name", "App Dev" }
    prod { dimension "env"; resValue "string", "app_name", "App" }
  }
}
```

iOS uses Xcode schemes + per-flavor `.xcconfig` files (`Dev.xcconfig`, `Prod.xcconfig`)
selected by the `--flavor` flag; commit the schemes so CI can build them.

Release builds: measure size, split debug symbols, and obfuscate so the shipped binary leaks no
Dart identifiers and stays small:

```bash
flutter build apk --release --analyze-size \
  --obfuscate --split-debug-info=build/symbols
```

Keep `config/*.json` out of VCS if they contain secrets (`.gitignore` them, commit a
`config/dev.example.json`); truly secret keys belong behind your backend, never in the app
bundle.
