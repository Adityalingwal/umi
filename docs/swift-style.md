# Swift style

Rules for Swift and SwiftUI code that no linter or compiler setting checks.

1. Never make a compiler error or warning go away without fixing its cause. That means no `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency`, `MainActor.assumeIsolated`, cast through `Any`, changed build setting, or `swiftlint:disable`; and no `DispatchQueue.main.async` or `Task { @MainActor in }` added only to quiet an isolation error. Fix the isolation. If one of these really is the right answer, stop and report which one and why.
2. Existing code that breaks these rules is legacy, not an example to copy.
3. New observable models are `@Observable` classes. Models that outlive a window (voice session, capture, overlay state) are created once at app start and passed down; a view owns, in a `private` `@State` property, only state that should die with that view. Children get values, `@Binding` or `@Bindable`; shared models go through `@Environment`.
4. `body` only describes the view: no I/O, heavy work or business logic in `body`, a view's `init`, `onAppear` or a `@State` default. Views call model methods; they do not contain the steps. A model's `init` only stores values and starts nothing (no audio, capture, network, timers, observers); work starts from an explicit method the owner calls (`.task`, or app start).
5. Split a view when a part has its own job or changes on its own, into a separate `View` struct, not a computed property.
6. No closure-built `Binding(get:set:)` passed to child views. Bind with `$model.property` through `@Bindable`; if the value needs converting, put a computed property on the model and bind to that.
7. View-tied async work uses `.task`/`.task(id:)`. Any other long-lived `Task` is stored by an owner that cancels it; a looping task captures `self` weakly so the owner can still be freed. Cancellation (`CancellationError`, `URLError.cancelled`) is caught on its own and neither shown nor logged as a failure.
8. `async` does not move work off the main actor. Slow synchronous work (image encoding, file reads and writes, parsing large data) goes in a `nonisolated` type inside an `async` function marked `@concurrent`. Use an API's own `async` form when it has one. Do not use `Task.detached` or `DispatchQueue` for this.
9. Code is main-actor by default. A type that is created or used off the main actor (a value passed to background work, or the background worker itself) is declared `nonisolated` and is `Sendable`. Prefer structs and enums for these; use an `actor` only for real shared mutable state.
10. A callback that a framework calls on its own thread (audio tap, screen-capture output, any delegate not documented as main-thread) lives in a `nonisolated` type or is a `@Sendable` closure. Inside it, copy what you need into a `Sendable` value and hand it to the main actor explicitly (`await` or an `AsyncStream`); never touch UI or model state directly.
11. `fatalError` only for a state the app cannot recover from, with a comment saying why crashing beats recovering. Ordinary failures (network, decode, permission) never crash.
12. Never drop an error silently: no empty `catch`, and `try?` only where a missing value is the expected, complete answer (and for `Task.sleep`). The one exception is cancellation (rule 7). Services throw domain errors; the UI turns them into user text.
13. Plain `throws`. Use `throws(SomeError)` only when the ticket asks for it.
14. `struct` by default; a `class` is `final`; everything is as `private` as it can be.
15. Model states as enums so impossible states cannot be written.
16. A protocol only when a second real type or a test fake exists. Non-view types get dependencies through `init`; views get shared models through `@Environment`. No `static let shared` of your own; Apple's shared objects (`NSApp`, `FileManager.default`) are passed in where a test needs to replace them.
17. Names follow Apple's Swift API Design Guidelines: role names, `is`/`has` Booleans that read as assertions, and uniform case for acronyms by position (`userID`, `imageURL`, but `urlSession`, `id`). One value keeps one name.
18. SwiftUI first. Windows that float above other apps (panels, the pointer overlay) are AppKit `NSPanel`s whose content is SwiftUI in an `NSHostingView`; pass shared models into each hosted root view with `.environment`. The menu bar item is an AppKit `NSStatusItem`. Keep AppKit code to creating and placing windows; no UI logic there.
19. Log only through `Logger` (subsystem = bundle id, category = feature); no `print` or `NSLog`. Never mark a value `privacy: .public` unless it is a fixed, non-user value (a state name, a count, an error code).
20. Don't raise the deployment target to make code compile; gate newer APIs with `#available`.
