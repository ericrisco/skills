# Swift Testing — depth

Load this for traits, parameterized matrices, async-event testing, and testing `@MainActor @Observable` models or SwiftData. The SKILL body has the skeleton; this is the rest.

## Suites & traits

A `@Suite` groups tests and can carry traits its tests inherit.

```swift
@Suite("Checkout", .tags(.payments))
struct CheckoutTests {
    @Test(.enabled(if: AppConfig.paymentsEnabled)) func charges() { /* ... */ }
    @Test(.timeLimit(.minutes(1)))                 func slowPath() async { /* ... */ }
    @Test(.disabled("flaky on CI — FB12345"))      func legacy() { /* ... */ }
}
```

Common traits:

| Trait | Effect |
| --- | --- |
| `.tags(.foo)` | Group/filter tests across suites |
| `.enabled(if:)` / `.disabled(_:)` | Conditional run, with a reason string |
| `.timeLimit(.minutes(n))` | Fail if the test exceeds the limit |
| `.serialized` | Run a suite's tests in order, not in parallel |
| `.bug("URL", "id")` | Link a test to a tracker ticket |

By default tests run **in parallel and in-process**. Mark a suite `.serialized` only when tests share mutable global state you cannot isolate.

## Parameterized matrices

```swift
// One argument set
@Test(arguments: [0, 1, 100]) func nonNegative(_ n: Int) { #expect(n >= 0) }

// Two zipped collections (paired, not cartesian)
@Test(arguments: zip(["a", "bb"], [1, 2]))
func length(_ s: String, _ len: Int) { #expect(s.count == len) }

// Cartesian product: pass two arguments collections
@Test(arguments: [1, 2], ["x", "y"])
func combos(_ n: Int, _ s: String) { /* runs 4 cases */ }
```

## Async events with `confirmation`

For callback/notification-style work that should fire a known number of times:

```swift
@Test func emitsThreeEvents() async {
    await confirmation("got events", expectedCount: 3) { confirm in
        let stream = makeStream()
        for await _ in stream.prefix(3) { confirm() }
    }
}
```

WWDC25 additions: **attachments** (attach files/data to a failing test's report) and **exit tests** (assert that a process traps/exits — for testing precondition failures).

## `#expect` vs `#require`

- `#expect(cond)` — soft. Records a failure and keeps running. Use for independent assertions.
- `try #require(cond)` — hard. Throws and stops the test. Use to unwrap optionals or guard preconditions the rest of the test depends on:

```swift
let row = try #require(rows.first)   // stop here if empty
#expect(row.id == 1)
```

## Testing a `@MainActor @Observable` model

Annotate the test (or suite) `@MainActor` so it shares isolation with the model:

```swift
@MainActor @Suite struct FeedTests {
    @Test func loadsItems() async throws {
        let feed = Feed()
        try await feed.load()
        #expect(!feed.items.isEmpty)
    }
}
```

## Testing SwiftData with an in-memory container

Never touch the on-disk store in tests. Build a throwaway container:

```swift
@MainActor @Test func insertsWorkout() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Workout.self, configurations: config)
    let context = container.mainContext
    context.insert(Workout(name: "Run", minutes: 30))
    let all = try context.fetch(FetchDescriptor<Workout>())
    #expect(all.count == 1)
}
```

## XCTest coexistence / migration

Both frameworks live in the same test target. Migrate logic tests; leave the rest.

| XCTest | Swift Testing | Keep in XCTest? |
| --- | --- | --- |
| `XCTAssert`, `XCTAssertEqual` | `#expect(...)` | No — migrate |
| `XCTUnwrap` | `try #require(...)` | No — migrate |
| `setUp`/`tearDown` | `init`/`deinit` of the suite type | No — migrate |
| `XCTestExpectation` | `confirmation { }` | No — migrate |
| `XCUIApplication` (UI automation) | — | **Yes** — XCTest only |
| `XCTMetric` / `measure {}` (performance) | — | **Yes** — XCTest only |

Run everything from one command: `xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 17'`.
