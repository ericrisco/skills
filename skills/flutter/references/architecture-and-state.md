# Architecture, DI & state management (deep dive)

Back to [`../SKILL.md`](../SKILL.md).

How data and control flow through a Flutter app: layering rules, `Result`/`Failure` error modeling, the repository pattern, DI, and both state solutions (Riverpod 3 default, Bloc alternative) in depth. Targets **Dart 3.12 / Flutter 3.44**, **Riverpod 3.0**, **freezed 3.x**.

## Layering contract

Three layers per feature; dependencies point inward (`presentation → domain ← data`).

| Layer | Owns | May import | Must NOT import |
| --- | --- | --- | --- |
| presentation | screens, widgets, Riverpod consumers / Blocs | `flutter`, `domain` | `data`, `dio` |
| domain | entities, repository interfaces, `Result`/`Failure`, use cases | pure Dart only | `flutter`, `dio`, `data` |
| data | DTOs, data sources, repository impls, mappers | `domain`, `dio`, `json` | `flutter` widgets |

Hard rule: `domain/` imports neither `package:flutter` nor `package:dio` — pure Dart that compiles in a server/CLI context. Data implements the domain's interfaces; presentation consumes its entities; presentation and data never know about each other.

Full `cart` feature on disk:

```text
lib/src/features/cart/
  presentation/
    cart_screen.dart            # ConsumerWidget, reads cart_controller
    cart_controller.dart        # @riverpod AsyncNotifier<Cart>
  domain/
    cart.dart                   # @freezed entity
    cart_item.dart              # @freezed entity
    cart_repository.dart        # abstract interface class CartRepository
    failure.dart                # sealed class Failure (shared, or in common/errors)
  data/
    cart_dto.dart               # @JsonSerializable DTO + toDomain()
    cart_remote_data_source.dart# wraps dio
    cart_repository_impl.dart   # implements CartRepository, maps to Result
```

## Domain entities & DTOs

Entities are freezed immutable value types. In **freezed 3.x** a data class uses `class … with _$Name` + a `const factory`; unions use `sealed`/`abstract`. Entities carry no JSON concern — wire shape stays in the DTO.

```dart
// domain/cart.dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'cart.freezed.dart';

@freezed
class Cart with _$Cart {
  const factory Cart({required String id, required List<CartItem> items, required double total}) = _Cart;
}
```

```dart
// domain/cart_item.dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'cart_item.freezed.dart';

@freezed
class CartItem with _$CartItem {
  const factory CartItem({
    required String id,
    required String name,
    required int quantity,
    required double unitPrice,
  }) = _CartItem;
}
```

The DTO is a separate data-layer type mirroring the API JSON exactly, including snake_case keys:

```dart
// data/cart_dto.dart
import 'package:json_annotation/json_annotation.dart';
import '../domain/cart.dart';
import '../domain/cart_item.dart';
part 'cart_dto.g.dart';

@JsonSerializable(explicitToJson: true)
class CartDto {
  const CartDto({required this.id, required this.items, required this.total});
  factory CartDto.fromJson(Map<String, dynamic> json) => _$CartDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CartDtoToJson(this);

  final String id;
  final List<CartItemDto> items;
  @JsonKey(name: 'total_amount')
  final double total;
}

@JsonSerializable()
class CartItemDto {
  const CartItemDto({required this.id, required this.name, required this.quantity, required this.unitPrice});
  factory CartItemDto.fromJson(Map<String, dynamic> json) => _$CartItemDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CartItemDtoToJson(this);

  final String id;
  final String name;
  final int quantity;
  @JsonKey(name: 'unit_price')
  final double unitPrice;
}
```

The mapper is an explicit data-layer extension, never on the entity:

```dart
// data/cart_dto.dart (continued)
extension CartDtoX on CartDto {
  Cart toDomain() =>
      Cart(id: id, items: items.map((i) => i.toDomain()).toList(), total: total);
}

extension CartItemDtoX on CartItemDto {
  CartItem toDomain() =>
      CartItem(id: id, name: name, quantity: quantity, unitPrice: unitPrice);
}
```

Why DTO ≠ entity: the wire format is owned by the backend and changes on its schedule (renamed key, new envelope, number-as-string). If the UI binds to the DTO, every wire change ripples into widgets. The mapper is the single boundary that absorbs those changes, keeping the entity stable.

## Result / Failure error modeling

Exceptions are caught and converted to values **only in the data layer**. Above it, errors travel as a sealed `Result`, so the type system forces every caller to handle both paths.

```dart
// common/errors/result.dart
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

extension ResultX<S, F> on Result<S, F> {
  T fold<T>(T Function(S value) onOk, T Function(F failure) onErr) => switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final failure) => onErr(failure),
      };

  Result<T, F> mapOk<T>(T Function(S value) transform) => switch (this) {
        Ok(:final value) => Ok(transform(value)),
        Err(:final failure) => Err(failure),
      };

  S? get valueOrNull => switch (this) { Ok(:final value) => value, Err() => null };
}
```

`Failure` is a sealed hierarchy; every variant carries a user-facing message:

```dart
// common/errors/failure.dart
sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error. Check your connection.']);
}
final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Your session expired. Sign in again.']);
}
final class ValidationFailure extends Failure {
  const ValidationFailure(this.field, [String message = 'Invalid input.']) : super(message);
  final String field;
}
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong.']);
}
```

The data layer is the only place that catches `DioException`/`FormatException` and converts them to `Err`; the UI consumes the `Result` with `fold` — **never `try/catch` in a widget**:

```dart
// GOOD — UI folds; no try/catch, no impossible state.
final result = await ref.read(cartRepositoryProvider).getCart();
final widget = result.fold(
  (cart) => CartView(cart: cart),
  (failure) => ErrorView(message: failure.message),
);
```

The catch-and-map itself lives in the repository impl below.

## Repository pattern

The interface lives in the domain (pure Dart); the data-layer impl is the catch-and-map boundary and owns caching.

```dart
// domain/cart_repository.dart  (imports: errors/{failure,result}, cart)
abstract interface class CartRepository {
  Future<Result<Cart, Failure>> getCart();
  Future<Result<Cart, Failure>> addItem(String productId);
}
```

```dart
// data/cart_repository_impl.dart  (imports: dio, errors/{failure,result}, domain/*, cart_dto, cart_remote_data_source)
class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl(this._remote, this._cache);
  final CartRemoteDataSource _remote;
  final CartCache _cache;

  @override
  Future<Result<Cart, Failure>> getCart() async {
    try {
      final dto = await _remote.fetchCart();
      final cart = dto.toDomain();
      await _cache.write(cart);
      return Ok(cart);
    } on DioException catch (e) {
      // Read-through cache: serve stale data on a network miss when we have it.
      final cached = await _cache.read();
      if (cached != null) return Ok(cached);
      return Err(e.response?.statusCode == 401 ? const AuthFailure() : const NetworkFailure());
    } on FormatException {
      return const Err(UnexpectedFailure('Malformed cart payload.'));
    }
  }

  @override
  Future<Result<Cart, Failure>> addItem(String productId) async {
    try {
      final cart = (await _remote.addItem(productId)).toDomain();
      await _cache.write(cart);
      return Ok(cart);
    } on DioException {
      return const Err(NetworkFailure());
    }
  }
}
```

The cache is a thin swappable interface (in-memory, `shared_preferences`, drift):

```dart
// data/cart_cache.dart
abstract interface class CartCache {
  Future<Cart?> read();
  Future<void> write(Cart cart);
}
```

## Dependency injection

Riverpod is the default container: the provider graph wires the impls and is trivially overridable in tests.

```dart
// data/cart_providers.dart
@riverpod
CartRemoteDataSource cartRemoteDataSource(Ref ref) => CartRemoteDataSource(ref.watch(dioProvider));

@riverpod
CartRepository cartRepository(Ref ref) =>
    CartRepositoryImpl(ref.watch(cartRemoteDataSourceProvider), ref.watch(cartCacheProvider));
```

`get_it` is the alternative when DI must happen **before** `runApp` or outside the widget tree (async plugin init, a CLI entrypoint):

```dart
final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();              // async bootstrap
  getIt
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerLazySingleton<Dio>(buildDio)                          // built on first use
    ..registerLazySingleton<CartRepository>(() => CartRepositoryImpl(getIt(), getIt()))
    ..registerFactory<CartController>(() => CartController(getIt())); // new instance each call
}
```

Prefer providers — graph, automatic disposal, and override-in-test for free. Reach for `get_it` only for pre-`runApp` async/non-widget bootstrap, then expose the result through a provider.

## Riverpod 3 deep

### Codegen setup

```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^3.0.0

dev_dependencies:
  riverpod_generator: ^3.0.0
  build_runner: ^2.4.0
  custom_lint: ^0.7.0
  riverpod_lint: ^3.0.0
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

Regenerate while developing: `dart run build_runner watch --delete-conflicting-outputs`.

### Function provider vs class Notifier

A `@riverpod` function is a derived/async read with no public mutations; a `@riverpod class` exposes methods that update `state`:

```dart
@riverpod
Future<List<Product>> products(Ref ref) =>
    ref.watch(productRepositoryProvider).getAll();

@riverpod
class CartController extends _$CartController {
  @override
  Future<Cart> build() async =>
      (await ref.read(cartRepositoryProvider).getCart()).fold((c) => c, (f) => throw f);

  Future<void> addItem(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await ref.read(cartRepositoryProvider).addItem(id);
      return res.fold((c) => c, (f) => throw f);
    });
  }
}
```

`AsyncValue.guard` captures the data or any thrown `Failure` into `AsyncData`/`AsyncError`, so the UI never sees a raw exception — the `Failure` lands in `AsyncError.error`.

### Family as a constructor argument (v3)

In Riverpod 3 family parameters are plain function/constructor arguments — no `.family`. Call it as `ref.watch(productProvider('42'))`:

```dart
@riverpod
Future<Product> product(Ref ref, String id) =>
    ref.watch(productRepositoryProvider).byId(id);
```

### Lifecycle: dispose, keepAlive, invalidate

```dart
@riverpod
Stream<int> ticker(Ref ref) {
  final controller = StreamController<int>();
  final timer = Timer.periodic(const Duration(seconds: 1), (t) => controller.add(t.tick));
  ref.onDispose(() { timer.cancel(); controller.close(); }); // always free resources
  return controller.stream;
}

ref.invalidate(cartControllerProvider); // force a refetch (e.g. from a refresh button)
```

Permanently cache a provider with the annotation, not a manual `keepAlive` link:

```dart
@Riverpod(keepAlive: true)
ApiConfig apiConfig(Ref ref) => const ApiConfig(timeout: Duration(seconds: 30));
```

### Scoped rebuilds with `.select()`

```dart
// Rebuild only when one field changes, not on every state emission.
final count = ref.watch(cartControllerProvider.select((s) => s.valueOrNull?.items.length ?? 0));
```

### `Mutation` for side-effects (v3)

`Mutation` models a one-shot operation (form submit, purchase) with its own pending/error state:

```dart
final checkoutMutation = Mutation<Order>();

class CheckoutButton extends ConsumerWidget {
  const CheckoutButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkoutMutation);
    return FilledButton(
      onPressed: state is MutationPending
          ? null
          : () => checkoutMutation.run(
              ref, (tsx) => tsx.get(checkoutControllerProvider.notifier).submit()),
      child: switch (state) {
        MutationPending() => const CircularProgressIndicator(),
        MutationError(:final error) => Text('Retry — $error'),
        _ => const Text('Place order'),
      },
    );
  }
}
```

### `ref.mounted` after await

A `@riverpod class` can be disposed mid-`await`. Guard before touching `state` or `ref`:

```dart
Future<void> refresh() async {
  final fresh = await ref.read(cartRepositoryProvider).getCart();
  if (!ref.mounted) return;        // disposed while awaiting — bail out
  state = AsyncData(fresh.valueOrNull ?? state.requireValue);
}
```

### Offline persistence

Riverpod 3 ships experimental persistence: `Notifier.persist()` writes state to a key-value store (`shared_preferences`/`sqflite`) and rehydrates on launch. Use it for small, non-sensitive UI state; keep tokens in secure storage, not here.

## Bloc deep

A full event-driven `Bloc` separates intent (events) from state and serializes its transitions:

```dart
sealed class CartEvent {}
final class CartStarted extends CartEvent {}
final class CartItemAdded extends CartEvent {
  CartItemAdded(this.productId);
  final String productId;
}

sealed class CartState {}
final class CartLoading extends CartState {}
final class CartLoaded extends CartState {
  CartLoaded(this.cart);
  final Cart cart;
}
final class CartError extends CartState {
  CartError(this.message);
  final String message;
}

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc(this._repo) : super(CartLoading()) {
    on<CartStarted>(_onStarted);
    on<CartItemAdded>(_onItemAdded);
  }

  final CartRepository _repo;

  Future<void> _onStarted(CartStarted event, Emitter<CartState> emit) async {
    final res = await _repo.getCart();
    emit(res.fold(CartLoaded.new, (f) => CartError(f.message)));
  }

  Future<void> _onItemAdded(CartItemAdded event, Emitter<CartState> emit) async {
    final res = await _repo.addItem(event.productId);
    emit(res.fold(CartLoaded.new, (f) => CartError(f.message)));
  }
}
```

Subscribe to a stream inside a handler with `emit.forEach(stream, onData: ..., onError: ...)`, which auto-cancels when the Bloc closes — never a manual `.listen()` you must remember to cancel.

Wire a `BlocObserver` to error reporting once in `main`:

```dart
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();
  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    crashlytics.recordError(error, stackTrace, fatal: false);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  Bloc.observer = const AppBlocObserver();
  runApp(const App());
}
```

For persistence, `hydrated_bloc` serializes state to disk: extend `HydratedBloc`/`HydratedCubit` and implement `fromJson`/`toJson`; state rehydrates on launch.

When Bloc beats Riverpod: explicit event sourcing (every transition is an auditable event → state pair), large teams wanting one rigid convention, and domains where separating *intent* (event) from *effect* (state change) eases review.

## Choosing: Riverpod vs Bloc

| Criterion | Riverpod 3 | Bloc 9 |
| --- | --- | --- |
| Boilerplate | low (codegen) | higher (event + state + handlers) |
| Codegen | `riverpod_generator` (optional but standard) | none required |
| Built-in DI | yes (provider graph) | no (use `BlocProvider` + get_it) |
| Testability | `ProviderContainer.test()` + overrides | `blocTest` |
| Learning curve | moderate (providers, `Ref`, `AsyncValue`) | moderate (event sourcing model) |
| Side-effects API | `ref.listen`, `Mutation` | `BlocListener` |
| Event sourcing | not first-class | first-class (events are the model) |

Default to Riverpod 3. Choose Bloc when the team is already on it, or when the domain wants explicit, auditable event → state transitions.
