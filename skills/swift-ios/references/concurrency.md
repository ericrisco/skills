# Swift 6 strict concurrency — migration & diagnostics

Load this when the user hits data-race diagnostics, is migrating a target to the Swift 6 language mode, or needs `actor`/`Sendable`/`AsyncStream` patterns. The SKILL body covers the common path; this is the depth.

## Enabling the Swift 6 language mode (per target, staged)

Do it one target at a time. Flip language mode globally and you drown in diagnostics with no way to triage.

1. **Stage with upcoming-feature flags first** (still in Swift 5 mode). In Build Settings add `SWIFT_UPCOMING_FEATURE_*` or, in SwiftPM, `.enableUpcomingFeature(...)`. Useful ones: `StrictConcurrency`, `InferSendableFromCaptures`, `DisableOutwardActorInference`. Resolve the warnings these surface.
2. **Then set `SWIFT_VERSION = 6`** on that target. Remaining warnings become errors.
3. Repeat per target, leaf modules first.

```swift
// Package.swift — staged adoption for one target
.target(
    name: "Core",
    swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .defaultIsolation(MainActor.self)   // SE-0466, see below
    ]
)
```

## SE-0466 default actor isolation + Approachable Concurrency

For UI-centric apps, set **Default Actor Isolation = MainActor** (build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, or `.defaultIsolation(MainActor.self)` in a SwiftPM target). Unannotated declarations become main-actor-isolated by default — the app is effectively single-threaded until you explicitly opt out with `nonisolated`. This removes the bulk of false-positive data-race warnings.

"Approachable Concurrency" is the umbrella build setting that, alongside this, also flips `InferIsolatedConformances` and `NonisolatedNonsendingByDefault`. Turn it on for new UI apps; turn it off and isolate manually for library code that must stay actor-agnostic.

Opt a hot, pure-compute path back off the main actor:

```swift
nonisolated func parse(_ data: Data) throws -> Model { /* no UI, no shared state */ }
```

## The canonical diagnostics

### "Non-Sendable type 'X' crossing actor boundary"

A value that is not safe to share is being passed between isolation domains.

```swift
// Bad — class with mutable state sent into a Task on another actor
final class Box { var value = 0 }
func use(_ b: Box) { Task.detached { print(b.value) } }   // Box is not Sendable

// Good — make it a value type, or an immutable/Sendable type
struct Box: Sendable { let value: Int }
```

If the type is genuinely safe but the compiler can't prove it (e.g. it guards its own state with a lock), conform with `@unchecked Sendable` — and only then. `@unchecked` is a promise *you* are now responsible for.

### "Main actor-isolated property cannot be referenced from a nonisolated context"

You touched main-isolated state from somewhere not on the main actor.

```swift
// Bad
@MainActor @Observable final class VM { var name = "" }
func log(_ vm: VM) { print(vm.name) }          // nonisolated function reads main state

// Good — make the access main-isolated, or await it
@MainActor func log(_ vm: VM) { print(vm.name) }
// or from async code:
func log(_ vm: VM) async { print(await vm.name) }
```

### "Capture of 'self' with non-Sendable type in a `@Sendable` closure"

A `Task.detached`/`@Sendable` closure captured a non-Sendable `self`.

```swift
// Bad
func refresh() { Task.detached { await self.reload() } }

// Good — Task {} inherits the actor; self stays on its actor, no crossing
func refresh() { Task { await self.reload() } }
```

## `actor` patterns

Use an `actor` for shared mutable state that is **not** UI. Its methods are implicitly async from outside; access is serialized.

```swift
actor ImageCache {
    private var store: [URL: Data] = [:]
    func data(for url: URL) -> Data? { store[url] }
    func set(_ data: Data, for url: URL) { store[url] = data }
}
```

**Reentrancy**: an actor can suspend at an `await` and run another call before the first resumes. Re-check invariants *after* every `await` inside an actor method — do not assume state is unchanged across a suspension point.

## Bridging callbacks with `AsyncStream`

Turn a delegate/callback API into an `AsyncSequence`:

```swift
func locations() -> AsyncStream<CLLocation> {
    AsyncStream { continuation in
        let delegate = LocationDelegate { continuation.yield($0) }
        continuation.onTermination = { _ in delegate.stop() }
        delegate.start()
    }
}
// for await loc in locations() { ... }   // ends when the task is cancelled
```

## Structured parallelism & cancellation

```swift
// Fan out with async let
async let a = fetchProfile()
async let b = fetchPosts()
let (profile, posts) = try await (a, b)

// Dynamic fan-out with a group, cancellation-aware
try await withThrowingTaskGroup(of: Item.self) { group in
    for id in ids { group.addTask { try await fetch(id) } }
    var out: [Item] = []
    for try await item in group { out.append(item) }   // throws cancel propagation
    return out
}

// In a loop, cooperate with cancellation
for url in urls {
    try Task.checkCancellation()
    _ = try await download(url)
}
```

Prefer SwiftUI's `.task {}` for view-lifetime async work — it cancels automatically when the view disappears, so you rarely store a `Task` handle yourself.
