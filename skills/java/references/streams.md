# Streams, Optional, Collectors (deep)

Targets Java 21+; Gatherers are Java 24+ (final). The SKILL body has the essentials; this is
the catalog and the decision table.

## Collector catalog

| Need | Collector |
| --- | --- |
| Immutable list | `Stream.toList()` (16+) |
| Mutable list | `Collectors.toList()` |
| Set | `Collectors.toSet()` |
| Map | `Collectors.toMap(k, v)` (throws on dup key — pass a merge fn to allow) |
| Group | `Collectors.groupingBy(classifier, downstream)` |
| Partition (boolean) | `Collectors.partitioningBy(predicate)` |
| Count / sum / avg | `counting()`, `summingLong(fn)`, `averagingDouble(fn)` |
| Join strings | `Collectors.joining(", ", "[", "]")` |
| Two collectors at once | `Collectors.teeing(c1, c2, merger)` |
| Post-process result | `Collectors.collectingAndThen(c, finisher)` |
| Reduce within a group | `Collectors.reducing(...)` or `mapping(fn, downstream)` |

```java
// teeing: min and max in one pass.
record MinMax(int min, int max) {}
MinMax mm = nums.stream().collect(Collectors.teeing(
    Collectors.minBy(Integer::compare),
    Collectors.maxBy(Integer::compare),
    (lo, hi) -> new MinMax(lo.orElseThrow(), hi.orElseThrow())));
```

```java
// toMap with a merge function to survive duplicate keys (otherwise IllegalStateException).
Map<String, Payment> latest = payments.stream()
    .collect(Collectors.toMap(Payment::id, p -> p, (a, b) -> b.newer(a) ? b : a));
```

## Custom collector

```java
// Collect into a domain accumulator when no built-in fits.
Collector<Payment, ?, Ledger> toLedger = Collector.of(
    Ledger::new,                 // supplier
    Ledger::add,                 // accumulator
    Ledger::merge);              // combiner (used only for parallel streams)
Ledger l = payments.stream().collect(toLedger);
```

## flatMap, mapMulti, Gatherers

```java
// flatMap: one element -> a stream of elements.
List<Item> items = orders.stream().flatMap(o -> o.items().stream()).toList();

// mapMulti (16+): push 0..n results imperatively — cheaper than flatMap when you fan out little.
List<String> tags = posts.stream()
    .<String>mapMulti((post, sink) -> post.tags().forEach(sink))
    .toList();
```

`Gatherers` (Java 24+, final) generalize intermediate ops — windowing, scanning, stateful
folds — that `map`/`filter` cannot express:

```java
// Sliding windows of size 3.
List<List<Integer>> windows = Stream.of(1,2,3,4,5)
    .gather(Gatherers.windowSliding(3))
    .toList();   // [[1,2,3],[2,3,4],[3,4,5]]
```

## Optional discipline

```java
// Good: chain, then resolve at the edge.
String name = repo.find(id).map(User::name).orElseGet(() -> "anonymous");
User u = repo.find(id).orElseThrow(() -> new NotFound(id));

// Bad: isPresent + get is just a null check in disguise.
Optional<User> o = repo.find(id);
if (o.isPresent()) { return o.get().name(); } else { return "anonymous"; }
```

Rules: never `Optional` as a field or parameter; never `Optional.of(maybeNull)` (use
`ofNullable`); for "no results" return an empty collection, not `Optional<List>`.

## Parallel streams: rarely, and measure

`stream().parallel()` only helps when the work is CPU-bound, the source splits cheaply
(arrays, `ArrayList`, `IntStream.range`), the per-element cost is high, and the operations are
stateless and associative. It *hurts* for I/O (it shares the common ForkJoinPool — use virtual
threads instead, see `concurrency.md`), for small inputs, and for ordered/short-circuit ops.
Default to sequential; reach for parallel only with a benchmark showing it wins.

## Stream vs loop decision

| Situation | Use |
| --- | --- |
| Transform/filter/aggregate a collection into a value | Stream |
| Side effects (I/O, mutate external state) | Loop (a `forEach` mutating outside is a loop in disguise) |
| Early `break` / `return` on a condition | Loop (or `findFirst`/`anyMatch` if it fits) |
| Index-coupled logic (`a[i]` with `a[i-1]`) | Loop |
| Deeply nested `flatMap`/`groupingBy` that no one can read | Loop with a clear accumulator |
| One-pass min+max / two aggregates | Stream with `teeing` |
