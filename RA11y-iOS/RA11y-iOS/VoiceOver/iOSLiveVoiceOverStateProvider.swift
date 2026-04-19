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
/// `UIAccessibility.isVoiceOverRunning` is MainActor-isolated in current SDKs; this
/// type implements `VoiceOverStateProvider` (synchronous `Bool`) by reading on the
/// main queue when invoked from a non-main context, preserving the protocol contract.
/// `stateChanges` yields on the main actor; callers running on background contexts
/// must handle the transfer appropriately.
/// The struct defaults to `@MainActor` isolation; the `isVoiceOverRunning` getter is
/// `nonisolated` so `VoiceOverStateProvider` conformance remains usable from
/// nonisolated call sites (e.g. `GameStartDecision.evaluate`).
public struct iOSLiveVoiceOverStateProvider: VoiceOverStateProvider {

    public init() {}

    // MARK: - VoiceOverStateProvider

    public nonisolated var isVoiceOverRunning: Bool {
        Self.readVoiceOverStateSynchronously()
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

// MARK: - Main-queue VoiceOver read

extension iOSLiveVoiceOverStateProvider {

    /// Reads `UIAccessibility.isVoiceOverRunning` on the main actor (UIKit’s required
    /// context), using a synchronous main-queue hop when the caller is off the main thread.
    private nonisolated static func readVoiceOverStateSynchronously() -> Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                UIAccessibility.isVoiceOverRunning
            }
        }
        var value = false
        DispatchQueue.main.sync {
            value = MainActor.assumeIsolated {
                UIAccessibility.isVoiceOverRunning
            }
        }
        return value
    }
}
