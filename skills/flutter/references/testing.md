# Testing the full pyramid (deep dive)

Back to [`../SKILL.md`](../SKILL.md).

Unit, repository, Bloc, widget, golden, and integration tests with runnable code, plus
coverage. Targets **Flutter 3.44 / Dart 3.12**, **Riverpod 3.0**, **mocktail 1.x**. The
non-negotiable rule: **every async state transition has a test** — loading → data and
loading → error, separately.

## Setup

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mocktail: ^1.0.0
  bloc_test: ^10.0.0
```

`test/` mirrors `lib/src/` one-to-one: `lib/src/features/cart/domain/cart.dart` →
`test/features/cart/domain/cart_test.dart`. Golden images live beside the test that produces
them, in a `goldens/` subfolder. Built-in `matchesGoldenFile` needs no extra package; the
optional `golden_toolkit` only helps with multi-device builders and font loading.

## Unit tests

Pure domain logic needs no Flutter binding:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cart total sums quantity * unitPrice', () {
    final cart = Cart(id: '1', total: 0, items: const [
      CartItem(id: 'a', name: 'Pen', quantity: 2, unitPrice: 1.5),
      CartItem(id: 'b', name: 'Pad', quantity: 1, unitPrice: 4.0),
    ]);
    final total = cart.items.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice);
    expect(total, 7.0);
  });
}
```

Test an `AsyncNotifier` with the v3 `ProviderContainer.test()` helper, which auto-disposes:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCartRepository extends Mock implements CartRepository {}

void main() {
  late MockCartRepository repo;

  setUpAll(() => registerFallbackValue(const Ok<Cart, Failure>(_emptyCart)));
  setUp(() => repo = MockCartRepository());

  test('loads cart on build', () async {
    when(repo.getCart).thenAnswer((_) async => const Ok(_emptyCart));

    final container = ProviderContainer.test(
      overrides: [cartRepositoryProvider.overrideWithValue(repo)],
    );

    final cart = await container.read(cartControllerProvider.future);
    expect(cart.id, _emptyCart.id);
    verify(repo.getCart).called(1);
  });

  test('addItem transitions loading -> data', () async {
    when(repo.getCart).thenAnswer((_) async => const Ok(_emptyCart));
    when(() => repo.addItem(any())).thenAnswer((_) async => const Ok(_fullCart));

    final container = ProviderContainer.test(
      overrides: [cartRepositoryProvider.overrideWithValue(repo)],
    );

    await container.read(cartControllerProvider.future);
    final transitions = <AsyncValue<Cart>>[];
    container.listen(cartControllerProvider, (_, next) => transitions.add(next));

    await container.read(cartControllerProvider.notifier).addItem('x');

    expect(transitions.first, isA<AsyncLoading<Cart>>());
    expect(transitions.last, isA<AsyncData<Cart>>());
  });
}

const _emptyCart = Cart(id: 'c1', total: 0, items: []);
const _fullCart = Cart(id: 'c1', total: 9, items: [
  CartItem(id: 'x', name: 'Mug', quantity: 1, unitPrice: 9),
]);
```

`mocktail` essentials: subclass `Mock implements`; call `registerFallbackValue` for any type
used inside an `any()` matcher; stub with `when(...).thenAnswer(...)`; assert calls with
`verify(...).called(n)`.

Fakes over mocks: for a repository, an in-memory `FakeCartRepository implements CartRepository`
with a real `Map` is more robust than a mock — it survives refactors and exercises real call
sequences. Reserve mocks for verifying *interaction counts* (was the analytics call made
once?).

## Repository test

Mock `Dio` and cover both the success and the error mapping path:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late CartRepositoryImpl repo;

  setUp(() {
    dio = MockDio();
    repo = CartRepositoryImpl(CartRemoteDataSource(dio), InMemoryCartCache());
  });

  test('getCart maps 200 to Ok', () async {
    when(() => dio.get<Map<String, dynamic>>('/cart')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/cart'),
        statusCode: 200,
        data: const {'id': 'c1', 'total_amount': 0.0, 'items': <dynamic>[]},
      ),
    );

    final result = await repo.getCart();
    expect(result, isA<Ok<Cart, Failure>>());
    expect((result as Ok).value.id, 'c1');
  });

  test('getCart maps 401 to Err(AuthFailure)', () async {
    when(() => dio.get<Map<String, dynamic>>('/cart')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/cart'),
        response: Response(requestOptions: RequestOptions(path: '/cart'), statusCode: 401),
      ),
    );

    final result = await repo.getCart();
    expect(result, isA<Err<Cart, Failure>>());
    expect((result as Err).failure, isA<AuthFailure>());
  });
}
```

## Bloc test

`blocTest` asserts the exact emitted sequence for both happy and error paths:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late MockCartRepository repo;
  setUp(() => repo = MockCartRepository());

  blocTest<CartBloc, CartState>(
    'emits [Loading, Loaded] on CartStarted success',
    setUp: () => when(repo.getCart).thenAnswer((_) async => const Ok(_emptyCart)),
    build: () => CartBloc(repo),
    act: (bloc) => bloc.add(CartStarted()),
    expect: () => [isA<CartLoaded>()],
  );

  blocTest<CartBloc, CartState>(
    'emits [Error] on CartStarted failure',
    setUp: () => when(repo.getCart).thenAnswer((_) async => const Err(NetworkFailure())),
    build: () => CartBloc(repo),
    act: (bloc) => bloc.add(CartStarted()),
    expect: () => [isA<CartError>()],
  );
}
```

## Widget tests

Override the controller with a fake, wrap in `ProviderScope` + `MaterialApp`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCartController extends CartController {
  FakeCartController(this._value);
  final Cart _value;
  @override
  Future<Cart> build() async => _value;
}

void main() {
  testWidgets('renders cart items', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [cartControllerProvider.overrideWith(() => FakeCartController(_fullCart))],
      child: const MaterialApp(home: CartScreen()),
    ));

    await tester.pump(); // let the Future resolve one frame
    expect(find.text('Mug'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
```

`pump` vs `pumpAndSettle` discipline. `pump()` advances exactly one frame (or a fixed
duration); `pumpAndSettle()` pumps until no frames are scheduled. **`pumpAndSettle` hangs
forever on infinite animations** — a `CircularProgressIndicator` schedules a frame every
tick, so the future never completes and the test times out. On any screen with an indeterminate
spinner, drive time explicitly:

```dart
// BAD — hangs while the spinner is on screen.
await tester.pumpAndSettle();
// GOOD — advance a known duration past the animation.
await tester.pump(const Duration(milliseconds: 300));
```

Finders: `find.byType(CartCard)`, `find.text('Mug')`, `find.byKey(const Key('add'))`. Drive
interaction then assert the rebuild:

```dart
testWidgets('tapping add increments the badge', (tester) async {
  await tester.pumpWidget(/* ... ProviderScope as above ... */);
  await tester.pump();
  await tester.tap(find.byKey(const Key('add')));
  await tester.pump();
  expect(find.text('1'), findsOneWidget);
});
```

Test the error UI by overriding the controller to surface an `AsyncError`:

```dart
class ErroringCartController extends CartController {
  @override
  Future<Cart> build() async => throw const NetworkFailure();
}

testWidgets('shows error view on failure', (tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [cartControllerProvider.overrideWith(ErroringCartController.new)],
    child: const MaterialApp(home: CartScreen()),
  ));
  await tester.pump();
  expect(find.byType(ErrorView), findsOneWidget);
});
```

## Golden tests

Compare a widget's pixels against a checked-in PNG:

```dart
testWidgets('CartCard golden', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Center(child: CartCard(item: _fullCart.items.first))),
  ));
  await expectLater(find.byType(CartCard), matchesGoldenFile('goldens/cart_card.png'));
});
```

Determinism is everything — goldens flake on fonts, surface size, and async images. Pin all
three. Load real fonts once via `flutter_test_config.dart` (auto-loaded for the whole suite):

```dart
// test/flutter_test_config.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fontData = rootBundle.load('assets/fonts/Inter-Regular.ttf');
  final loader = FontLoader('Inter')..addFont(fontData);
  await loader.load();
  await testMain();
}
```

Fix the surface and let decoded network/asset images finish inside `runAsync`:

```dart
testWidgets('list golden, fixed surface', (tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.runAsync(() async {
    await tester.pumpWidget(const MaterialApp(home: CartScreen()));
    await tester.pumpAndSettle(); // safe here: no infinite animation after images settle
  });

  await expectLater(find.byType(CartScreen), matchesGoldenFile('goldens/cart_screen.png'));
});
```

Multi-device coverage with a small helper:

```dart
Future<void> goldenForDevices(WidgetTester tester, Widget child, String name) async {
  for (final (label, size) in const [('phone', Size(390, 844)), ('tablet', Size(820, 1180))]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.0;
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
    await expectLater(find.byWidget(child), matchesGoldenFile('goldens/${name}_$label.png'));
  }
  addTearDown(tester.view.resetPhysicalSize);
}
```

Update goldens after an intentional visual change:

```bash
flutter test --update-goldens
```

CI gotcha: font and text rendering differ across host platforms (macOS vs Linux), so a golden
generated locally will mismatch on CI. Tag golden tests and gate them on one canonical image
only:

```bash
# tag with @Tags(['golden']) and run on the pinned CI image only:
flutter test --tags golden
```

## integration_test

Drive the real app on a device/emulator:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login -> home flow', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email')), 'ada@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'hunter2');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
```

```bash
flutter test integration_test
```

## Coverage

```bash
flutter test --coverage          # writes coverage/lcov.info
```

Generated files inflate coverage — strip them before reporting:

```bash
lcov --remove coverage/lcov.info \
  '*.g.dart' '*.freezed.dart' '*.config.dart' \
  -o coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html
```

Target 80%+ on `domain/` and state (`*_controller.dart`, Blocs) — that's where the logic
lives. UI coverage comes from widget + golden tests, not from chasing a number on layout code.
