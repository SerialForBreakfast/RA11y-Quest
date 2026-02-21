// MARK: - VoiceOverStateProvider

/// Abstraction over system VoiceOver state.
///
/// Exposes the current running state and an `AsyncStream` that emits the new
/// value whenever VoiceOver is toggled, enabling reactive UI updates and
/// mid-session detection (see `TICKET-M2-VOStateChangeMidGame`).
///
/// ## Concurrency
/// `isVoiceOverRunning` is safe to call from any context.
/// `stateChanges` yields on the main actor in the live implementation;
/// callers must not assume a specific executor.
///
/// ## Testability
/// Inject `StubVoiceOverStateProvider` in unit tests to control both
/// the current value and simulated state-change events.
public protocol VoiceOverStateProvider: Sendable {

    /// Whether VoiceOver is currently active.
    var isVoiceOverRunning: Bool { get }

    /// Yields the updated `isVoiceOverRunning` value each time VoiceOver is toggled.
    ///
    /// The stream never completes under normal operation.
    /// Each subscriber receives its own independent stream from the moment of subscription.
    var stateChanges: AsyncStream<Bool> { get }
}

// MARK: - StubVoiceOverStateProvider

/// Deterministic `VoiceOverStateProvider` for use in unit tests and SwiftUI previews.
///
/// Accepts a fixed `isVoiceOverRunning` value and an optional `stateChanges` stream.
/// By default the stream never emits, which is correct for tests that only check
/// the current-state routing decision.
///
/// To test mid-session VO-off detection, inject a custom `AsyncStream` that yields
/// `false` at the desired point.
public struct StubVoiceOverStateProvider: VoiceOverStateProvider {

    public let isVoiceOverRunning: Bool

    /// State-change stream delivered to the subscriber.
    /// Defaults to a stream that never yields, suitable for routing-decision tests.
    public let stateChanges: AsyncStream<Bool>

    /// - Parameters:
    ///   - isVoiceOverRunning: Fixed value returned for the current state check.
    ///   - stateChanges: Optional stream for simulating VoiceOver toggle events.
    public init(
        isVoiceOverRunning: Bool,
        stateChanges: AsyncStream<Bool> = AsyncStream { _ in }
    ) {
        self.isVoiceOverRunning = isVoiceOverRunning
        self.stateChanges = stateChanges
    }
}
