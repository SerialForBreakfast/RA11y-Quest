import UIKit
import RA11yCore

// MARK: - iOSLiveVoiceOverStateProvider

/// Production `VoiceOverStateProvider` backed by `UIAccessibility`.
///
/// Reads the current VoiceOver state synchronously from `UIAccessibility.isVoiceOverRunning`
/// and streams state changes by observing `voiceOverStatusDidChangeNotification` via
/// an `AsyncSequence`-based `NotificationCenter` API (iOS 15+).
///
/// ## Usage
/// Instantiate once and inject via constructor or environment into any component
/// that needs to gate on VoiceOver state (hub, game coordinator, interstitial).
///
/// ```swift
/// let provider = iOSLiveVoiceOverStateProvider()
/// let decision = GameStartDecision.evaluate(kind: .findAndFocus, provider: provider)
/// ```
///
/// ## Concurrency
/// `isVoiceOverRunning` is thread-safe per Apple documentation.
/// `stateChanges` yields on the main actor; callers running on background contexts
/// must handle the transfer appropriately.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
public struct iOSLiveVoiceOverStateProvider: VoiceOverStateProvider {

    public init() {}

    // MARK: - VoiceOverStateProvider

    public var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    /// Emits the updated `isVoiceOverRunning` value on every VoiceOver toggle.
    ///
    /// Each call returns a new independent stream. The internal `Task` is cancelled
    /// automatically when the stream's continuation is terminated (e.g., when the
    /// subscriber is deallocated or the consuming `Task` is cancelled).
    public var stateChanges: AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                let notifications = NotificationCenter.default.notifications(
                    named: UIAccessibility.voiceOverStatusDidChangeNotification
                )
                for await _ in notifications {
                    continuation.yield(UIAccessibility.isVoiceOverRunning)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
