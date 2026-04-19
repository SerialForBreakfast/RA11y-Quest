import Observation
import os
import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSEnchantersTrialView

/// Container for The Enchanter's Trial (Find & Focus) — M5.
///
/// Implements the full 4-level game arc defined in `GameSpec-FindAndFocus.txt`
/// and `GameRules-MVP.txt`:
///
/// - **L0 Prologue**: DM narration + VoiceOver lesson card + gesture guide + "Begin Trial"
/// - **L1 First Attempt**: 3 relics, no timer; confidence builder
/// - **L2 Rising Challenge**: 6 relics, 45 s soft timer
/// - **L3 Timed Trial**: All 8 relics, 20 s hard timer; `GameSession` started here for scoring
///
/// Only L3 creates a `GameSession`. Completion writes the result to storage and
/// navigates to the shared `iOSGameResultView`. Timeout abandons the session and
/// presents a synthesized Defeated result (not stored).
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSEnchantersTrialView: View {

    // MARK: - State

    @State private var viewModel: EnchanterTrialViewModel

    /// Final timed level only: full-screen blackout and gameplay overlays (see `LightsOffMode-Recommendations.txt`).
    private var isLightsOffFinalLevel: Bool { viewModel.phase == .timed }

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router

    // MARK: - Private

    /// Storage reference for loading Lights Off preference (same backing store as the hub toggle).
    private let storage: any StorageComponent

    // MARK: - Init

    /// Creates the Enchanter game container.
    ///
    /// - Parameters:
    ///   - storage: Persistence used for L3 session results during normal gameplay.
    ///   - screenshotScene: Optional deterministic screenshot scene override.
    init(storage: any StorageComponent, screenshotScene: iOSScreenshotScene? = nil) {
        self.storage = storage
        _viewModel = State(
            initialValue: EnchanterTrialViewModel(storage: storage, screenshotScene: screenshotScene)
        )
    }

    // MARK: - Body

    /// The game view uses `.background {}` instead of a ZStack containing the background.
    ///
    /// A `scaledToFill` image inside a ZStack reports its natural scaled width (often wider
    /// than the screen for landscape assets) as its preferred layout size. This inflates the
    /// ZStack's layout, shifts siblings off-centre, and causes content to overflow the screen
    /// horizontally. Using `.background {}` sizes the background to the foreground view,
    /// preventing any layout bleed from the image.
    var body: some View {
        levelContent
            .background {
                if isLightsOffFinalLevel {
                    Color.black
                        .ignoresSafeArea()
                } else {
                    EnchanterBackgroundView()
                        .ignoresSafeArea()
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel.completedResult) { _, result in
                guard let result else { return }
                let announcement = gameSpecificAnnouncement(for: result)
                router.push(.gameResult(result, gameKind: .findAndFocus, gameSpecificAnnouncement: announcement))
            }
            .onChange(of: viewModel.voiceOverDisabledMidGame) { _, disabled in
                if disabled {
                    router.push(.voiceOverInterstitial(kind: .findAndFocus))
                }
            }
            .onDisappear { viewModel.handleViewDisappear() }
    }

    // MARK: - Level Routing

    /// `.transition(.identity)` on each case suppresses the default opacity fade that
    /// SwiftUI applies when a `@ViewBuilder` switch produces a different view type.
    /// Without it, if the `@Observable` machinery delivers a phase mutation as a view
    /// update (e.g. during screenshot bootstrapping), the incoming view fades in from
    /// zero opacity and the screenshot captures it mid-transition.
    @ViewBuilder
    private var levelContent: some View {
        switch viewModel.phase {
        case .prologue:
            EnchanterPrologueView(onBeginTrial: { viewModel.beginTrial() })
                .navigationTitle(String(localized: "simon.explain.title"))
                .accessibilityIdentifier("enchanter.prologue")
                .transition(.identity)
        case .attempt:
            EnchanterAttemptView(
                relics: viewModel.relics,
                targetRelic: viewModel.targetRelic,
                mistakes: viewModel.mistakes,
                statusMessage: viewModel.statusMessage,
                levelComplete: viewModel.levelComplete,
                lightsOffMode: isLightsOffFinalLevel,
                onActivate: { relic in await viewModel.activateRelic(relic) },
                onHint: { viewModel.requestHint() },
                onContinue: { viewModel.advanceToRising() }
            )
            .navigationTitle(String(localized: "simon.l1.title"))
            // Spec: "Enchanter's prompt card reads the target name aloud on screen load."
            .onAppear { viewModel.announceTargetPrompt() }
            .accessibilityIdentifier("enchanter.attempt")
            .transition(.identity)
        case .rising:
            EnchanterRisingView(
                relics: viewModel.relics,
                targetRelic: viewModel.targetRelic,
                mistakes: viewModel.mistakes,
                timeRemaining: viewModel.timeRemaining,
                statusMessage: viewModel.statusMessage,
                levelComplete: viewModel.levelComplete,
                timedOut: viewModel.l2TimedOut,
                lightsOffMode: isLightsOffFinalLevel,
                onActivate: { relic in await viewModel.activateRelic(relic) },
                onHint: { viewModel.requestHint() },
                onContinue: { viewModel.advanceToTimed() },
                onRetry: { viewModel.retryRising() }
            )
            .navigationTitle(String(localized: "simon.l2.title"))
            .onAppear { viewModel.announceTargetPrompt() }
            .accessibilityIdentifier("enchanter.rising")
            .transition(.identity)
        case .timed:
            EnchanterTimedView(
                relics: viewModel.relics,
                targetRelic: viewModel.targetRelic,
                mistakes: viewModel.mistakes,
                timeRemaining: viewModel.timeRemaining,
                statusMessage: viewModel.statusMessage,
                timedOut: viewModel.l3TimedOut,
                lightsOffMode: isLightsOffFinalLevel,
                onActivate: { relic in await viewModel.activateRelic(relic) },
                onHint: { viewModel.requestHint() },
                onRetry: { viewModel.retryTimed() }
            )
            .navigationTitle(String(localized: "simon.l3.title"))
            .onAppear { viewModel.announceTargetPrompt() }
            .accessibilityIdentifier("enchanter.timed")
            .transition(.identity)
        }
    }

    // MARK: - Game-Specific Result Announcements

    /// Returns the localized per-rank flavor string for the Enchanter's Trial.
    ///
    /// These strings are defined in `GameRules-MVP.txt` and appended after the shared
    /// rank summary on the result screen.
    private func gameSpecificAnnouncement(for result: GameResult) -> String {
        switch result.rank {
        case .perfect: return String(localized: "simon.results.legendary")
        case .good:    return String(localized: "simon.results.skilled")
        case .ok:      return String(localized: "simon.results.novice")
        case .failed:  return String(localized: "simon.results.defeated")
        }
    }
}

// MARK: - EnchanterTrialViewModel

/// Observable view model managing the Enchanter's Trial 4-level state machine.
///
/// Owns level phase transitions, relic set composition, mistake tracking, timer logic,
/// VoiceOver threshold announcements, and the L3 `GameSession`/`GameSessionCoordinator`.
///
/// ## Concurrency
/// `@MainActor` isolated for safe SwiftUI observation. The countdown timer runs in a
/// `Task` confined to `@MainActor` to avoid data races on view-observable state.
///
/// Timer task is stored as `nonisolated(unsafe)` so `deinit` (always nonisolated in
/// Swift 6) can call `cancel()`. `Task.cancel()` is itself nonisolated and thread-safe.
@Observable
@MainActor
final class EnchanterTrialViewModel {

    // MARK: - Phase

    enum Phase { case prologue, attempt, rising, timed }

    private(set) var phase: Phase = .prologue

    // MARK: - Shared Level State

    private(set) var relics: [EnchanterRelic] = []
    private(set) var targetRelic: EnchanterRelic = .placeholder
    private(set) var mistakes: Int = 0
    private(set) var statusMessage: String?
    private(set) var levelComplete: Bool = false

    // MARK: - Timer State (L2 + L3)

    /// Remaining seconds for the active level timer. Updated approximately every 0.5 s.
    private(set) var timeRemaining: Double = 0

    private(set) var l2TimedOut: Bool = false
    private(set) var l3TimedOut: Bool = false

    // MARK: - L3 Session State

    /// Set when L3 `GameSession.complete()` succeeds. The container view navigates
    /// to the result screen when this becomes non-nil.
    private(set) var completedResult: GameResult?

    /// Set to `true` when `GameSessionCoordinator` detects VoiceOver going off mid-game.
    /// The container view pushes the VO interstitial route when this becomes `true`.
    private(set) var voiceOverDisabledMidGame: Bool = false

    // MARK: - Private

    private let storage: any StorageComponent
    private let screenshotScene: iOSScreenshotScene?

    /// L3 session — created fresh each time L3 starts (including retries).
    private var session: GameSession?

    /// VO monitor for L3. Nil during L0–L2.
    private var coordinator: GameSessionCoordinator?

    /// Countdown task running during L2 or L3. Cancelled on phase change via `stopTimer()`.
    ///
    /// Declared as a plain stored property (no isolation modifier). The timer closure
    /// uses `[weak self]` on every iteration so the running task does not retain the
    /// ViewModel — when the ViewModel is released the next `guard let self` exits
    /// cleanly. `stopTimer()` provides eager cancellation before any phase transition.
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    /// Creates the Enchanter view model.
    ///
    /// - Parameters:
    ///   - storage: Persistence used for normal gameplay session storage.
    ///   - screenshotScene: Optional deterministic screenshot scene override.
    init(storage: any StorageComponent, screenshotScene: iOSScreenshotScene? = nil) {
        self.storage = storage
        self.screenshotScene = screenshotScene
        if let screenshotScene {
            applyScreenshotScene(screenshotScene)
        }
    }

    // MARK: - Phase Transitions

    /// Transitions L0 → L1: sets up the 3-relic first-attempt level.
    func beginTrial() {
        stopTimer()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        relics = EnchanterRelic.setForL1()
        targetRelic = EnchanterRelic.pickTarget(from: relics)
        phase = .attempt
    }

    /// Transitions L1 → L2: sets up the 6-relic rising challenge with 45 s timer.
    func advanceToRising() {
        stopTimer()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        l2TimedOut = false
        relics = EnchanterRelic.setForL2()
        targetRelic = EnchanterRelic.pickTarget(from: relics)
        timeRemaining = 45
        phase = .rising
        startTimer(total: 45) { [weak self] in await self?.handleL2Timeout() }
    }

    /// Retries L2 on timeout without returning to L1.
    func retryRising() {
        advanceToRising()
    }

    /// Transitions L2 → L3: sets up all 8 relics with a 20 s hard timer and creates a fresh `GameSession`.
    ///
    /// ## Concurrency
    /// `GameSession.start()` must complete before the timer or any relic activation can call
    /// `recordMistake()` / `complete()`, otherwise those actor methods throw `invalidTransition`.
    /// Both are `await`-ed inside a single `Task` so the timer only starts once the session
    /// is in the `.running` state. `GameSession` and `GameSessionCoordinator` are created fresh
    /// on each call (including retries) so previous state is never reused.
    func advanceToTimed() {
        stopTimer()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        l3TimedOut = false
        completedResult = nil
        voiceOverDisabledMidGame = false
        relics = EnchanterRelic.setForL3()
        targetRelic = EnchanterRelic.pickTarget(from: relics)
        timeRemaining = 20
        phase = .timed

        let newSession = GameSession(
            gameID: "find-and-focus",
            thresholds: .findAndFocus,
            storage: storage
        )
        let newCoordinator = GameSessionCoordinator(
            session: newSession,
            gameKind: .findAndFocus,
            voiceOverProvider: iOSLiveVoiceOverStateProvider()
        )
        session = newSession
        coordinator = newCoordinator

        // Start session and timer in sequence: session MUST be in .running before
        // the timer fires and any relic activation calls recordMistake/complete.
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await newSession.start()
            } catch {
                RA11yLogger.gameSession.error("L3 session start failed: \(error.localizedDescription)")
                return
            }
            newCoordinator.startMonitoring()

            // Grace period for VoiceOver users: the navigation transition announcement
            // and target prompt together take ~4–6 s to read aloud. Without a delay the
            // 20 s window is already draining while VoiceOver is still speaking, making
            // the trial nearly impossible. The grace period lets the user hear the prompt
            // and orient before the countdown begins.
            if UIAccessibility.isVoiceOverRunning {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
            }

            self.startTimer(total: 20) { [weak self] in await self?.handleL3Timeout() }
            self.observeCoordinatorVOState(coordinator: newCoordinator)
        }
    }

    /// Polls the given coordinator for a VoiceOver-off event and mirrors it onto the ViewModel.
    ///
    /// Runs in a `Task` so it does not block the calling context. Exits as soon as the flag
    /// is set or the task is cancelled (e.g., when the phase transitions or ViewModel is released).
    private func observeCoordinatorVOState(coordinator: GameSessionCoordinator) {
        Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { return }
                if coordinator.voiceOverDisabledMidGame {
                    self.voiceOverDisabledMidGame = true
                    self.stopTimer()
                    return
                }
            }
        }
    }

    /// Retries L3 — creates a fresh session and restarts the 20 s timer.
    func retryTimed() {
        advanceToTimed()
    }

    // MARK: - Relic Activation

    /// Handles a relic button tap for the current level.
    ///
    /// - Correct: marks level complete, starts L3 session completion if in `.timed` phase.
    /// - Wrong: records mistake, announces feedback via VoiceOver.
    func activateRelic(_ relic: EnchanterRelic) async {
        guard !levelComplete, !l2TimedOut, !l3TimedOut else { return }

        if relic == targetRelic {
            await handleCorrectActivation(relic)
        } else {
            await handleWrongActivation(relic)
        }
    }

    /// Announces the hint string to VoiceOver and as a visible status message.
    func requestHint() {
        let message = String(format: String(localized: "enchanter.hint.format"), targetRelic.displayName)
        statusMessage = message
        guard screenshotScene == nil else { return }
        announce(message)
    }

    /// Announces the Enchanter's prompt (target name + navigation instruction) to VoiceOver.
    ///
    /// Called from each level view's `.onAppear` so VoiceOver reads the prompt card when
    /// the level first appears — satisfying the spec requirement "prompt card reads the
    /// target name aloud on screen load." Uses the same accessibility label as the visible
    /// prompt card so sighted and VoiceOver users see/hear identical information.
    ///
    /// A brief delay is introduced so VoiceOver's transition focus-move completes before
    /// the announcement fires; without it the announcement can be swallowed by the
    /// navigation transition announcement.
    func announceTargetPrompt() {
        guard screenshotScene == nil else { return }
        let message: String
        switch phase {
        case .attempt:
            message = String(format: String(localized: "simon.a11y.l1.target"), targetRelic.displayName)
        case .rising:
            message = String(format: String(localized: "simon.a11y.l2.target"), targetRelic.displayName)
        case .timed:
            message = String(format: String(localized: "simon.a11y.l3.target"), targetRelic.displayName)
        case .prologue:
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(500))
            self.announce(message)
        }
    }

    // MARK: - Private: Activation Handling

    private func handleCorrectActivation(_ relic: EnchanterRelic) async {
        switch phase {
        case .prologue:
            break

        case .attempt:
            stopTimer()
            levelComplete = true
            let message = String(format: String(localized: "simon.feedback.correct"), relic.displayName)
            statusMessage = message
            // Use the thematic L1-specific announcement ("Trial passed. The Enchanter nods.")
            // rather than the generic "Level complete." used by other contexts.
            announce(String(localized: "simon.l1.complete"))

        case .rising:
            stopTimer()
            levelComplete = true
            let message = String(format: String(localized: "simon.feedback.correct"), relic.displayName)
            statusMessage = message
            announce(String(localized: "simon.l2.complete"))

        case .timed:
            guard let session else { return }
            // Stop the timer first so timeRemaining is stable for bucket calculation.
            stopTimer()

            // Compute elapsed from the 20 s L3 window and record any time-bucket penalty
            // mistakes before completing the session. The first 10 s bucket is free;
            // each additional full 10 s adds +1 (per GameSpec-FindAndFocus.txt).
            let elapsed = 20.0 - timeRemaining
            let buckets = RankThresholds.bucketMistakes(timeSeconds: elapsed, bucketSize: 10)
            for _ in 0..<buckets {
                try? await session.recordMistake()
            }

            do {
                try await session.complete()
                coordinator?.stopMonitoring()
                let successMessage = String(
                    format: String(localized: "simon.l3.success"),
                    relic.displayName
                )
                announce(successMessage)
                if case .completed(let result) = await session.state {
                    completedResult = result
                }
            } catch {
                RA11yLogger.gameSession.error("L3 session complete failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleWrongActivation(_ relic: EnchanterRelic) async {
        if phase == .timed, let session {
            do { try await session.recordMistake() } catch { /* session in non-running state */ }
        }
        mistakes += 1
        let message = String(
            format: String(localized: "simon.feedback.wrong"),
            relic.displayName
        )
        statusMessage = message
        announce(String(localized: "a11y.level.mistake"))
    }

    // MARK: - Private: Timer

    /// Starts a countdown timer for `total` seconds, calling `onTimeout` when it expires.
    ///
    /// ## Concurrency
    /// The timer loop runs in a `Task` confined to `@MainActor` to mutate `timeRemaining`
    /// without data races. Threshold announcements are posted via `UIAccessibility` from
    /// the main actor, which is required by UIKit.
    /// Starts a countdown timer for `total` seconds, calling `onTimeout` when it expires.
    ///
    /// The closure captures `[weak self]` on every iteration so the running `Task` does
    /// not retain the `EnchanterTrialViewModel`. When the ViewModel is released between
    /// iterations the `guard let self` exits the loop cleanly without a deinit hook.
    ///
    /// ## Concurrency
    /// The timer `Task` is `@MainActor`-isolated to allow mutation of `timeRemaining` and
    /// other `@Observable` state without crossing actor boundaries. `UIAccessibility.post`
    /// also requires the main thread.
    private func startTimer(total: Double, onTimeout: @escaping @Sendable () async -> Void) {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            let startDate = Date()
            var announced75 = false
            var announced50 = false
            var announced25 = false
            var announced10 = false
            var announcedCountdown = Set<Int>()

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                // Re-check self and cancellation after each sleep — exits cleanly if
                // the ViewModel was released or stopTimer() cancelled the task.
                guard let self, !Task.isCancelled else { return }

                let elapsed = Date().timeIntervalSince(startDate)
                let remaining = max(0, total - elapsed)
                self.timeRemaining = remaining

                // Threshold VoiceOver announcements
                let pctElapsed = elapsed / total
                if pctElapsed >= 0.75 && !announced75 {
                    announced75 = true
                    self.announceTimerThreshold(for: self.phase, pct: 0.75)
                } else if pctElapsed >= 0.50 && !announced50 {
                    announced50 = true
                    self.announceTimerThreshold(for: self.phase, pct: 0.50)
                } else if pctElapsed >= 0.25 && !announced25 {
                    announced25 = true
                    self.announceTimerThreshold(for: self.phase, pct: 0.25)
                }

                // 10 s remaining (only for L3; L2 uses percentage thresholds)
                if self.phase == .timed && remaining <= 10 && !announced10 {
                    announced10 = true
                    self.announce(String(localized: "a11y.timer.10s"))
                }

                // Final 5 s countdown
                if remaining <= 5 {
                    let secondsLeft = Int(ceil(remaining))
                    if secondsLeft > 0 && !announcedCountdown.contains(secondsLeft) {
                        announcedCountdown.insert(secondsLeft)
                        self.announceCountdown(secondsLeft)
                    }
                }

                if remaining <= 0 {
                    await onTimeout()
                    break
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Handles the view disappearing from the navigation stack (e.g., user taps back).
    ///
    /// Stops any active timer and abandons the L3 `GameSession` if it is still running,
    /// ensuring no result is written for an incomplete play-through.
    ///
    /// ## Concurrency
    /// Called from `@MainActor` context via `.onDisappear`. The inner `Task` inherits
    /// `@MainActor` isolation and safely `await`s the actor-isolated `abandon()`.
    func handleViewDisappear() {
        stopTimer()
        coordinator?.stopMonitoring()
        guard let session else { return }
        Task { await session.abandon() }
    }

    private func handleL2Timeout() async {
        l2TimedOut = true
        announce(String(localized: "simon.timeout"))
    }

    private func handleL3Timeout() async {
        guard let session else { return }
        l3TimedOut = true
        coordinator?.stopMonitoring()
        await session.abandon()
        announce(String(localized: "simon.timeout"))
        // Synthesize a Defeated result for display (not stored — session was abandoned).
        let elapsed = 20.0 - timeRemaining
        completedResult = GameResult(
            gameID: "find-and-focus",
            rank: .failed,
            timeSeconds: elapsed,
            mistakes: mistakes
        )
    }

    // MARK: - Private: VoiceOver Announcements

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// Applies a deterministic static state for screenshot capture.
    ///
    /// Screenshot scenes intentionally avoid timers, coordinators, and persistence writes.
    /// They only shape the visible UI state needed for fastlane capture.
    private func applyScreenshotScene(_ scene: iOSScreenshotScene) {
        stopTimer()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        l2TimedOut = false
        l3TimedOut = false
        completedResult = nil
        voiceOverDisabledMidGame = false
        timeRemaining = 0

        switch scene {
        case .enchanterPrologue:
            phase = .prologue
            relics = []
            targetRelic = .placeholder
        case .enchanterAttempt:
            phase = .attempt
            relics = EnchanterRelic.setForL1()
            targetRelic = EnchanterRelic.pickTarget(from: relics)
        case .enchanterRising:
            phase = .rising
            relics = EnchanterRelic.setForL2()
            targetRelic = EnchanterRelic.pickTarget(from: relics)
            timeRemaining = 32
        case .enchanterTimed:
            phase = .timed
            relics = EnchanterRelic.setForL3()
            targetRelic = EnchanterRelic.pickTarget(from: relics)
            mistakes = 1
            timeRemaining = 12
        default:
            break
        }
    }

    private func announceTimerThreshold(for phase: Phase, pct: Double) {
        switch (phase, pct) {
        case (.timed, 0.75):
            announce(String(localized: "simon.a11y.timer.75pct"))
        case (.timed, 0.50):
            announce(String(localized: "simon.a11y.timer.50pct"))
        case (.timed, 0.25):
            announce(String(localized: "simon.a11y.timer.25pct"))
        case (.rising, 0.50):
            announce(String(localized: "a11y.timer.50pct"))
        case (.rising, 0.25):
            announce(String(localized: "a11y.timer.25pct"))
        default:
            break
        }
    }

    private func announceCountdown(_ seconds: Int) {
        switch seconds {
        case 5: announce(String(localized: "a11y.timer.5s"))
        case 4: announce(String(localized: "a11y.timer.4s"))
        case 3: announce(String(localized: "a11y.timer.3s"))
        case 2: announce(String(localized: "a11y.timer.2s"))
        case 1: announce(String(localized: "a11y.timer.1s"))
        default: break
        }
    }
}

// MARK: - EnchanterRelic

/// A single relic in The Enchanter's Trial.
///
/// All 8 relics share the same pool. Level-specific subsets are composed by
/// `setForL1()`, `setForL2()`, and `setForL3()`.
struct EnchanterRelic: Identifiable, Hashable, Equatable {
    let id: String
    let displayName: String
    let assetName: String

    // MARK: - Relic Pool

    /// Full 8-relic pool used in L3.
    static let all: [EnchanterRelic] = [
        EnchanterRelic(id: "dragon_scale", displayName: "Dragon Scale", assetName: "enchanter_relic_dragon_scale"),
        EnchanterRelic(id: "dragon_claw",  displayName: "Dragon Claw",  assetName: "enchanter_relic_dragon_claw"),
        EnchanterRelic(id: "shadow_stone", displayName: "Shadow Stone", assetName: "enchanter_relic_shadow_stone"),
        EnchanterRelic(id: "sunstone",     displayName: "Sunstone",     assetName: "enchanter_relic_sunstone"),
        EnchanterRelic(id: "ember_glass",  displayName: "Ember Glass",  assetName: "enchanter_relic_ember_glass"),
        EnchanterRelic(id: "frost_glass",  displayName: "Frost Glass",  assetName: "enchanter_relic_frost_glass"),
        EnchanterRelic(id: "iron_shard",   displayName: "Iron Shard",   assetName: "enchanter_relic_iron_shard"),
        EnchanterRelic(id: "moonstone",    displayName: "Moonstone",    assetName: "enchanter_relic_moonstone"),
    ]

    /// Simple-name subset for L1 (no similar-sounding pairs).
    private static let l1Pool: [EnchanterRelic] = all.filter {
        ["dragon_scale", "iron_shard", "moonstone", "ember_glass"].contains($0.id)
    }

    /// Placeholder used as ViewModel initial state before a level is configured.
    static let placeholder = EnchanterRelic(id: "", displayName: "", assetName: "")

    // MARK: - Set Builders

    /// Returns a deterministic 3-relic set for L1 (UI-testing friendly).
    /// L1 relic selection: shuffled each attempt so index memory alone cannot win.
    static func setForL1() -> [EnchanterRelic] {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return Array(l1Pool.prefix(3))
        }
        return Array(l1Pool.shuffled().prefix(3))
    }

    /// Returns 6 relics for L2, guaranteed to include at least one similar-sounding pair.
    ///
    /// Similar-sounding pairs per spec: (Dragon Scale / Dragon Claw),
    /// (Shadow Stone / Sunstone), (Ember Glass / Frost Glass).
    static func setForL2() -> [EnchanterRelic] {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return Array(all.prefix(6))
        }
        // Pick one forced pair, then fill remaining 4 randomly from the rest.
        let pairs: [[String]] = [
            ["dragon_scale", "dragon_claw"],
            ["shadow_stone", "sunstone"],
            ["ember_glass",  "frost_glass"],
        ]
        let forcedPairIDs = pairs.randomElement() ?? pairs[0]
        let forcedPair = all.filter { forcedPairIDs.contains($0.id) }
        let remaining = all.filter { !forcedPairIDs.contains($0.id) }.shuffled()
        return (forcedPair + Array(remaining.prefix(4))).shuffled()
    }

    /// Returns all 8 relics in randomized order for L3.
    static func setForL3() -> [EnchanterRelic] {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return all
        }
        return all.shuffled()
    }

    /// Picks the target from a relic set. Returns the first element during UI testing for determinism.
    static func pickTarget(from relics: [EnchanterRelic]) -> EnchanterRelic {
        guard !relics.isEmpty else { return .placeholder }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return relics[0]
        }
        return relics.randomElement() ?? relics[0]
    }
}

// MARK: - L0: EnchanterPrologueView

/// L0 Prologue — DM narration, VoiceOver lesson card, gesture guide, and "Begin Trial" button.
///
/// No game session. Player reads or listens to the lesson, then taps "Begin Trial" to start L1.
///
/// ## Responsive Layout (SwiftUI Best Practices)
/// - `contentMargins` (iOS 17+) constrains scroll content to safe area without GeometryReader.
/// - `HStack` + `Spacer` centers content on iPad when max width is 600pt.
/// - `frame(minWidth: 0)` prevents content from expanding beyond the container.
private struct EnchanterPrologueView: View {

    let onBeginTrial: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var horizontalPadding: CGFloat {
        sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base
    }

    private var contentMaxWidth: CGFloat? {
        sizeClass == .regular ? 600 : nil
    }

    var body: some View {
        ScrollView(.vertical) {
            enchanterContent {
                dmNarrationCard
                lessonCard
                gestureGuide
                beginButton
            }
        }
        .contentMargins(.horizontal, horizontalPadding, for: .scrollContent)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func enchanterContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let inner = VStack(spacing: RA11ySpacing.lg) {
            content()
        }
        .padding(.vertical, RA11ySpacing.lg)
        .frame(minWidth: 0, maxWidth: contentMaxWidth ?? CGFloat.infinity)
        .frame(maxWidth: .infinity)

        if sizeClass == .regular {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                inner
                Spacer(minLength: 0)
            }
        } else {
            inner
        }
    }

    private var dmNarrationCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Label(String(localized: "dm.label"), systemImage: "scroll.fill")
                .font(.ra11yCaption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(String(localized: "simon.explain.narration"))
                .font(.ra11yBody)
                .italic()
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.72), in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(Color.ra11yDMBorder.opacity(0.5), lineWidth: 1)
        )
    }

    private var lessonCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "simon.explain.lesson.heading"))
                .font(.ra11yHeadline)
                .bold()
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "simon.explain.lesson.body"))
                .font(.ra11yBody)
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.66), in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "simon.a11y.explain.lesson"))
    }

    private var gestureGuide: some View {
        VStack(spacing: RA11ySpacing.sm) {
            GestureRow(symbol: "hand.point.right.fill",  label: String(localized: "simon.explain.gesture.swipe"))
            GestureRow(symbol: "hand.point.left.fill",   label: String(localized: "simon.explain.gesture.back"))
            GestureRow(symbol: "hand.tap.fill",          label: String(localized: "simon.explain.gesture.tap"))
        }
        .accessibilityHidden(true)  // Gesture guide is decorative; content in lesson card label
    }

    private var beginButton: some View {
        Button(action: onBeginTrial) {
            Text(String(localized: "level.button.start"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .accessibilityHint(String(localized: "simon.explain.start.hint"))
        .accessibilityIdentifier("enchanter.beginTrial")
    }
}

// MARK: - L1: EnchanterAttemptView

/// L1 First Attempt — 3 relics, no timer, mistake feedback.
///
/// Displays a prompt card with the target name, then a vertical list of relic buttons.
/// Relics are stacked vertically so VoiceOver's linear swipe navigation mirrors the
/// linear metaphor taught in L0 (swipe right = next item).
private struct EnchanterAttemptView: View {

    let relics: [EnchanterRelic]
    let targetRelic: EnchanterRelic
    let mistakes: Int
    let statusMessage: String?
    let levelComplete: Bool
    /// When `true`, relic artwork is covered by an accessibility-inert blackout layer.
    let lightsOffMode: Bool
    let onActivate: (EnchanterRelic) async -> Void
    let onHint: () -> Void
    let onContinue: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var horizontalPadding: CGFloat {
        sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base
    }

    private var contentMaxWidth: CGFloat? {
        sizeClass == .regular ? 600 : nil
    }

    var body: some View {
        ScrollView(.vertical) {
            enchanterLevelContent {
                promptCard(
                    title: String(format: String(localized: "simon.l1.target.format"), targetRelic.displayName),
                    a11yLabel: String(format: String(localized: "simon.a11y.l1.target"), targetRelic.displayName),
                    a11yHint: String(localized: "simon.a11y.l1.target.hint")
                )

                mistakeHUD

                relicStack

                if let statusMessage {
                    statusRow(statusMessage)
                }

                if levelComplete {
                    continueButton
                } else {
                    hintButton
                }
            }
        }
        .contentMargins(.horizontal, horizontalPadding, for: .scrollContent)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func enchanterLevelContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let inner = VStack(spacing: RA11ySpacing.lg) {
            content()
        }
        .padding(.vertical, RA11ySpacing.lg)
        .frame(minWidth: 0, maxWidth: contentMaxWidth ?? CGFloat.infinity)
        .frame(maxWidth: .infinity)

        if sizeClass == .regular {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                inner
                Spacer(minLength: 0)
            }
        } else {
            inner
        }
    }

    private var mistakeHUD: some View {
        Text(String(format: String(localized: "simon.hud.mistakes.format"), mistakes))
            .font(.ra11ySubheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel(String(format: String(localized: "simon.a11y.hud.l1"), mistakes))
    }

    private var relicStack: some View {
        VStack(spacing: RA11ySpacing.md) {
            ForEach(relics) { relic in
                RelicButton(relic: relic, onActivate: onActivate)
            }
        }
        .ra11yLightsOffGameplayBlackout(isEnabled: lightsOffMode)
    }

    private var hintButton: some View {
        Button(action: onHint) {
            Label(String(localized: "enchanter.hint.button"), systemImage: "ear.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "enchanter.hint.a11yLabel"))
        .accessibilityHint(String(localized: "enchanter.hint.a11yHint"))
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text(String(localized: "level.button.next"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .accessibilityIdentifier("enchanter.l1.continue")
    }
}

// MARK: - L2: EnchanterRisingView

/// L2 Rising Challenge — 6 relics with similar-sounding names, 45 s soft timer.
private struct EnchanterRisingView: View {

    let relics: [EnchanterRelic]
    let targetRelic: EnchanterRelic
    let mistakes: Int
    let timeRemaining: Double
    let statusMessage: String?
    let levelComplete: Bool
    let timedOut: Bool
    let lightsOffMode: Bool
    let onActivate: (EnchanterRelic) async -> Void
    let onHint: () -> Void
    let onContinue: () -> Void
    let onRetry: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var horizontalPadding: CGFloat {
        sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base
    }

    private var contentMaxWidth: CGFloat? {
        sizeClass == .regular ? 600 : nil
    }

    var body: some View {
        ScrollView(.vertical) {
            enchanterLevelContent {
                promptCard(
                    title: String(format: String(localized: "simon.l2.target.format"), targetRelic.displayName),
                    a11yLabel: String(format: String(localized: "simon.a11y.l2.target"), targetRelic.displayName),
                    a11yHint: String(localized: "simon.a11y.l1.target.hint")
                )

                TimerHUD(timeRemaining: timeRemaining, total: 45)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        String(format: String(localized: "simon.a11y.l2.timer"), Int(ceil(timeRemaining)))
                    )
                    .accessibilityHint(String(localized: "a11y.timer.group.hint"))

                if timedOut {
                    timeoutBanner
                } else {
                    relicStack
                    if let statusMessage { statusRow(statusMessage) }
                    if levelComplete { continueButton } else { hintButton }
                }
            }
        }
        .contentMargins(.horizontal, horizontalPadding, for: .scrollContent)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func enchanterLevelContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let inner = VStack(spacing: RA11ySpacing.lg) {
            content()
        }
        .padding(.vertical, RA11ySpacing.lg)
        .frame(minWidth: 0, maxWidth: contentMaxWidth ?? CGFloat.infinity)
        .frame(maxWidth: .infinity)

        if sizeClass == .regular {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                inner
                Spacer(minLength: 0)
            }
        } else {
            inner
        }
    }

    private var relicStack: some View {
        VStack(spacing: RA11ySpacing.md) {
            ForEach(relics) { relic in
                RelicButton(relic: relic, onActivate: onActivate)
            }
        }
        .ra11yLightsOffGameplayBlackout(isEnabled: lightsOffMode)
    }

    private var timeoutBanner: some View {
        VStack(spacing: RA11ySpacing.md) {
            Text(String(localized: "simon.timeout"))
                .font(.ra11yHeadline)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text(String(localized: "level.button.retry"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.ra11yAccent)
        }
        .padding(RA11ySpacing.base)
    }

    private var hintButton: some View {
        Button(action: onHint) {
            Label(String(localized: "enchanter.hint.button"), systemImage: "ear.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "enchanter.hint.a11yLabel"))
        .accessibilityHint(String(localized: "enchanter.hint.a11yHint"))
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text(String(localized: "level.button.next"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .accessibilityIdentifier("enchanter.l2.continue")
    }
}

// MARK: - L3: EnchanterTimedView

/// L3 Timed Trial — all 8 relics, 20 s hard timer, `GameSession` for scoring.
///
/// On timeout, shows the timeout banner with a "Try Again" button. The ViewModel
/// handles session abandonment; the container view navigates to the result screen
/// when `completedResult` is set.
private struct EnchanterTimedView: View {

    let relics: [EnchanterRelic]
    let targetRelic: EnchanterRelic
    let mistakes: Int
    let timeRemaining: Double
    let statusMessage: String?
    let timedOut: Bool
    let lightsOffMode: Bool
    let onActivate: (EnchanterRelic) async -> Void
    let onHint: () -> Void
    let onRetry: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var horizontalPadding: CGFloat {
        sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base
    }

    private var contentMaxWidth: CGFloat? {
        sizeClass == .regular ? 600 : nil
    }

    var body: some View {
        ScrollView(.vertical) {
            enchanterLevelContent {
                enchanterLightsOffFlavorBanner

                promptCard(
                    title: String(format: String(localized: "simon.l3.target.format"), targetRelic.displayName),
                    a11yLabel: String(format: String(localized: "simon.a11y.l3.target"), targetRelic.displayName),
                    a11yHint: nil
                )

                TimerHUD(timeRemaining: timeRemaining, total: 20)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        String(format: String(localized: "simon.a11y.l3.timer"), Int(ceil(timeRemaining)))
                    )
                    .accessibilityHint(String(localized: "a11y.timer.group.hint"))

                if timedOut {
                    timeoutBanner
                } else {
                    relicStack
                    if let statusMessage { statusRow(statusMessage) }
                    hintButton
                }
            }
        }
        .contentMargins(.horizontal, horizontalPadding, for: .scrollContent)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func enchanterLevelContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let inner = VStack(spacing: RA11ySpacing.lg) {
            content()
        }
        .padding(.vertical, RA11ySpacing.lg)
        .frame(minWidth: 0, maxWidth: contentMaxWidth ?? CGFloat.infinity)
        .frame(maxWidth: .infinity)

        if sizeClass == .regular {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                inner
                Spacer(minLength: 0)
            }
        } else {
            inner
        }
    }

    /// Atmospheric copy for the final timed level (torch / darkness).
    private var enchanterLightsOffFlavorBanner: some View {
        Text(String(localized: "enchanter.lightsOff.flavor"))
            .font(.ra11ySubheadline)
            .foregroundStyle(Color.ra11yCardSecondaryText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RA11ySpacing.base)
            .background(Color.black.opacity(0.5), in: .rect(cornerRadius: RA11yRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RA11yRadius.card)
                    .strokeBorder(Color.ra11yDMBorder.opacity(0.35), lineWidth: 1)
            )
            .accessibilityAddTraits(.isStaticText)
    }

    private var relicStack: some View {
        VStack(spacing: RA11ySpacing.md) {
            ForEach(relics) { relic in
                RelicButton(relic: relic, onActivate: onActivate)
            }
        }
        .ra11yLightsOffGameplayBlackout(isEnabled: lightsOffMode)
    }

    private var timeoutBanner: some View {
        VStack(spacing: RA11ySpacing.md) {
            Text(String(localized: "simon.timeout"))
                .font(.ra11yHeadline)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text(String(localized: "level.button.retry"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.ra11yAccent)
            .accessibilityIdentifier("enchanter.l3.retry")
        }
        .padding(RA11ySpacing.base)
    }

    private var hintButton: some View {
        Button(action: onHint) {
            Label(String(localized: "enchanter.hint.button"), systemImage: "ear.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "enchanter.hint.a11yLabel"))
        .accessibilityHint(String(localized: "enchanter.hint.a11yHint"))
    }
}

// MARK: - Shared Subviews

/// Shared prompt card shown at the top of L1–L3.
private func promptCard(title: String, a11yLabel: String, a11yHint: String?) -> some View {
    VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
        Text(title)
            .font(.ra11yHeadline)
            .bold()
    }
    .padding(RA11ySpacing.base)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.black.opacity(0.66), in: .rect(cornerRadius: RA11yRadius.card))
    .overlay(
        RoundedRectangle(cornerRadius: RA11yRadius.card)
            .strokeBorder(Color.ra11yDMBorder.opacity(0.5), lineWidth: 1)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(a11yLabel)
    .modify { view in
        if let hint = a11yHint {
            view.accessibilityHint(hint)
        } else {
            view
        }
    }
}

/// Status feedback row shown after an activation event.
private func statusRow(_ message: String) -> some View {
    Text(message)
        .font(.ra11ySubheadline)
        .foregroundStyle(Color.ra11yCardSecondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RA11ySpacing.xs)
}

/// Single relic button used across L1–L3.
///
/// Displays the relic image (with SF Symbol fallback) and its display name.
/// Configured as a linear-list item so VoiceOver swipe navigation is predictable.
///
/// ## Adaptive Layout
/// - Standard (`dynamicTypeSize < .accessibility2`): `HStack` — icon | label
/// - Large accessibility sizes: `VStack` — icon on top, label below (centered)
///
/// ## Dynamic Type
/// Icon frame uses `@ScaledMetric` so it grows proportionally with text size,
/// capped at 96 pt to prevent outsized icons on large display phones.
private struct RelicButton: View {

    let relic: EnchanterRelic
    let onActivate: (EnchanterRelic) async -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Scales with the `.headline` text style (base 48 pt, max ~96 pt).
    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 48

    private var isLargeAccessibilitySize: Bool { dynamicTypeSize >= .accessibility2 }

    var body: some View {
        Button {
            Task { await onActivate(relic) }
        } label: {
            if isLargeAccessibilitySize {
                VStack(spacing: RA11ySpacing.sm) {
                    relicIcon
                    relicLabel
                }
                .padding(RA11ySpacing.md)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.4), in: .rect(cornerRadius: RA11yRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: RA11yRadius.card)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
            } else {
                HStack(spacing: RA11ySpacing.md) {
                    relicIcon
                    relicLabel
                }
                .padding(RA11ySpacing.md)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.4), in: .rect(cornerRadius: RA11yRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: RA11yRadius.card)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .accessibilityLabel(relic.displayName)
        .accessibilityHint(String(localized: "simon.token.hint"))
        .accessibilityIdentifier("enchanter.relic.\(relic.id)")
    }

    private var relicIcon: some View {
        RelicImage(assetName: relic.assetName)
            .frame(width: min(iconSize, 96), height: min(iconSize, 96))
            .accessibilityHidden(true)
    }

    private var relicLabel: some View {
        Text(relic.displayName)
            .font(.ra11yHeadline)
            .frame(maxWidth: .infinity, alignment: isLargeAccessibilitySize ? .center : .leading)
    }
}

/// Timer progress bar shown in L2 and L3.
///
/// Depletes left-to-right as time passes. Height decreases in the final 50% and 25%
/// to provide a non-color urgency cue, per `GameRules-MVP.txt` timer spec.
/// The timer element is `accessibilityHidden` — the containing L3 view sets a
/// formatted `accessibilityLabel` on the whole HUD.
///
/// ## Dynamic Type
/// Bar height scales with `.caption` text style via `@ScaledMetric` so it remains
/// visually proportional to the adjacent time label at all DT sizes.
private struct TimerHUD: View {

    let timeRemaining: Double
    let total: Double

    private var fraction: Double { max(0, min(1, timeRemaining / total)) }

    private var barHeightMultiplier: Double {
        if fraction > 0.50 { return 1.0 }
        if fraction > 0.25 { return 0.75 }
        return 0.50
    }

    private var barColor: Color {
        if fraction > 0.50 { return .green }
        if fraction > 0.25 { return .yellow }
        return .red
    }

    /// Scales with `.caption` style (base 12 pt), so the bar remains visible alongside
    /// larger text at high DT sizes.
    @ScaledMetric(relativeTo: .caption) private var baseBarHeight: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.1))
                        .frame(height: baseBarHeight)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(
                            width: geo.size.width * fraction,
                            height: baseBarHeight * barHeightMultiplier
                        )
                        .animation(.linear(duration: 0.2), value: fraction)
                }
            }
            .frame(height: baseBarHeight)

            Text(String(format: String(localized: "hud.timer.format"), Int(ceil(timeRemaining))))
                .font(.ra11yCaption)
                .foregroundStyle(Color.ra11yCardTertiaryText)
        }
        .accessibilityHidden(true)  // L3 view sets accessibilityLabel on this entire HUD via .accessibilityElement(children: .ignore) at the call site
    }
}

/// Small gesture guide row used in the L0 prologue.
private struct GestureRow: View {
    let symbol: String
    let label: String

    var body: some View {
        HStack(spacing: RA11ySpacing.md) {
            Image(systemName: symbol)
                .font(.ra11yHeadline)
                .frame(minWidth: 32, alignment: .leading)
                .foregroundStyle(Color.ra11yCardTertiaryText)
            Text(label)
                .font(.ra11yBody)
                .foregroundStyle(Color.ra11yCardSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Relic asset image with SF Symbol fallback.
private struct RelicImage: View {
    let assetName: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)

            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: "sparkles")
                    .font(.ra11yTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

/// Background for The Enchanter's Trial — dark gradient over the tower shelf art.
private struct EnchanterBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)

            if let image = UIImage(named: "enchanter_tower_shelf_bg") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.55))
            }
        }
    }
}

// MARK: - View+Modify Helper

private extension View {
    /// Applies a transform closure, allowing conditional modifier application.
    @ViewBuilder
    func modify<T: View>(@ViewBuilder transform: (Self) -> T) -> some View {
        transform(self)
    }
}

// MARK: - Previews

#Preview("L0 Prologue") {
    NavigationStack {
        iOSEnchantersTrialView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
