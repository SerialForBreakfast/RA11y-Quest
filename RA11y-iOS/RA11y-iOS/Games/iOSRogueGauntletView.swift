import Observation
import os
import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSRogueGauntletView

/// Container for The Rogue's Gauntlet (Activate / Double-Tap) — M6.
///
/// Implements the full 4-level game arc defined in `GameSpec-ActivateDoubleTap.txt`
/// and `GameRules-MVP.txt`:
///
/// - **L0 Prologue**: DM narration + "The Rogue's Creed" lesson + gesture guide + "Begin Trial"
/// - **L1 First Attempt**: 1 seal (Seal of Passage), no timer — confidence builder for double-tap
/// - **L2 Rising Challenge**: 4 seals in a 2×2 grid, 40 s soft timer
/// - **L3 Timed Trial**: 6 seals in a 2×3 grid, 20 s hard timer; `GameSession` started here for scoring
///
/// Only L3 creates a `GameSession`. Completion writes the result to storage and navigates to
/// the shared `iOSGameResultView`. Timeout abandons the session and synthesises a Defeated result
/// (not stored).
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSRogueGauntletView: View {

    // MARK: - State

    @State private var viewModel: RogueGauntletViewModel

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router

    // MARK: - Init

    init(storage: any StorageComponent) {
        _viewModel = State(initialValue: RogueGauntletViewModel(storage: storage))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            RogueBackgroundView()
                .ignoresSafeArea()

            levelContent
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.completedResult) { _, result in
            guard let result else { return }
            let announcement = gameSpecificAnnouncement(for: result)
            router.push(.gameResult(result, gameKind: .activateDoubleTap, gameSpecificAnnouncement: announcement))
        }
        .onChange(of: viewModel.voiceOverDisabledMidGame) { _, disabled in
            if disabled {
                router.push(.voiceOverInterstitial(kind: .activateDoubleTap))
            }
        }
        .onDisappear { viewModel.handleViewDisappear() }
    }

    // MARK: - Level Routing

    @ViewBuilder
    private var levelContent: some View {
        switch viewModel.phase {
        case .prologue:
            RoguePrologueView(onBeginTrial: { viewModel.beginTrial() })
                .navigationTitle(String(localized: "rogue.explain.title"))
                .accessibilityIdentifier("rogue.prologue")

        case .firstAttempt:
            RogueFirstAttemptView(
                seal: viewModel.targetSeal ?? .placeholder,
                statusMessage: viewModel.statusMessage,
                levelComplete: viewModel.levelComplete,
                onActivate: { seal in await viewModel.activateSeal(seal) },
                onContinue: { viewModel.advanceToRising() }
            )
            .navigationTitle(String(localized: "rogue.l1.title"))
            .onAppear { viewModel.announceObjectivePrompt() }
            .accessibilityIdentifier("rogue.firstAttempt")

        case .rising:
            RogueRisingView(
                seals: viewModel.seals,
                targetSeal: viewModel.targetSeal ?? .placeholder,
                mistakes: viewModel.mistakes,
                timeRemaining: viewModel.timeRemaining,
                statusMessage: viewModel.statusMessage,
                levelComplete: viewModel.levelComplete,
                timedOut: viewModel.l2TimedOut,
                onActivate: { seal in await viewModel.activateSeal(seal) },
                onHint: { viewModel.requestHint() },
                onContinue: { viewModel.advanceToTimed() },
                onRetry: { viewModel.retryRising() }
            )
            .navigationTitle(String(localized: "rogue.l2.title"))
            .onAppear { viewModel.announceObjectivePrompt() }
            .accessibilityIdentifier("rogue.rising")

        case .timed:
            RogueTimedView(
                seals: viewModel.seals,
                targetSeal: viewModel.targetSeal ?? .placeholder,
                mistakes: viewModel.mistakes,
                timeRemaining: viewModel.timeRemaining,
                statusMessage: viewModel.statusMessage,
                timedOut: viewModel.l3TimedOut,
                onActivate: { seal in await viewModel.activateSeal(seal) },
                onHint: { viewModel.requestHint() },
                onRetry: { viewModel.retryTimed() }
            )
            .navigationTitle(String(localized: "rogue.l3.title"))
            .onAppear { viewModel.announceObjectivePrompt() }
            .accessibilityIdentifier("rogue.timed")
        }
    }

    // MARK: - Game-Specific Result Announcements

    /// Returns the per-rank thematic result string for The Rogue's Gauntlet.
    ///
    /// Displayed on the shared result screen below the rank summary.
    private func gameSpecificAnnouncement(for result: GameResult) -> String {
        switch result.rank {
        case .perfect: return String(localized: "rogue.results.legendary")
        case .good:    return String(localized: "rogue.results.skilled")
        case .ok:      return String(localized: "rogue.results.novice")
        case .failed:  return String(localized: "rogue.results.defeated")
        }
    }
}

// MARK: - RogueGauntletViewModel

/// Observable view model managing The Rogue's Gauntlet 4-level state machine.
///
/// Owns level phase transitions, seal set composition, mistake tracking, timer logic,
/// VoiceOver threshold announcements, and the L3 `GameSession`/`GameSessionCoordinator`.
///
/// ## Concurrency
/// `@MainActor` isolated for safe SwiftUI observation. The countdown timer runs in a
/// `Task` confined to `@MainActor` to avoid data races on view-observable state.
///
/// Timer task is a plain `private var`. The timer closure uses `[weak self]` on every
/// iteration so the running `Task` does not retain the ViewModel — when the ViewModel
/// is released the next `guard let self` exits cleanly. `stopTimer()` provides eager
/// cancellation before any phase transition.
@Observable
@MainActor
final class RogueGauntletViewModel {

    // MARK: - Phase

    enum Phase { case prologue, firstAttempt, rising, timed }

    private(set) var phase: Phase = .prologue

    // MARK: - Shared Level State

    private(set) var seals: [RogueSeal] = []
    private(set) var targetSeal: RogueSeal?
    private(set) var mistakes: Int = 0
    private(set) var statusMessage: String?
    private(set) var levelComplete: Bool = false

    // MARK: - Timer State (L2 + L3)

    /// Remaining seconds for the active level timer. Updated approximately every 0.2 s.
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

    /// L3 session — created fresh each time L3 starts (including retries).
    private var session: GameSession?

    /// VO monitor for L3. Nil during L0–L2.
    private var coordinator: GameSessionCoordinator?

    /// Countdown task running during L2 or L3. Cancelled on phase change via `stopTimer()`.
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    init(storage: any StorageComponent) {
        self.storage = storage
    }

    // MARK: - Phase Transitions

    /// Transitions L0 → L1: sets the single Seal of Passage for the confidence-builder level.
    func beginTrial() {
        stopTimer()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        let (set, target) = RogueSeal.setForL1()
        seals = set
        targetSeal = target
        phase = .firstAttempt
    }

    /// Transitions L1 → L2: 4-seal grid with 40 s soft timer.
    func advanceToRising() {
        stopTimer()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        l2TimedOut = false
        let (set, target) = RogueSeal.setForL2()
        seals = set
        targetSeal = target
        timeRemaining = 40
        phase = .rising
        startTimer(total: 40) { [weak self] in await self?.handleL2Timeout() }
    }

    /// Retries L2 on timeout without returning to L1.
    func retryRising() {
        advanceToRising()
    }

    /// Transitions L2 → L3: 6-seal grid with 20 s hard timer and a fresh `GameSession`.
    ///
    /// ## Concurrency
    /// `GameSession.start()` must complete before the timer or any seal activation can call
    /// `recordMistake()` / `complete()`, otherwise those actor methods throw `invalidTransition`.
    /// Both are `await`-ed inside a single `Task` so the timer only starts once the session
    /// is in the `.running` state. `GameSession` and `GameSessionCoordinator` are created fresh
    /// on each call (including retries) so previous state is never reused.
    func advanceToTimed() {
        stopTimer()
        mistakes = 0
        statusMessage = nil
        l3TimedOut = false
        completedResult = nil
        voiceOverDisabledMidGame = false
        let (set, target) = RogueSeal.setForL3()
        seals = set
        targetSeal = target
        timeRemaining = 20
        phase = .timed

        let newSession = GameSession(
            gameID: "rogue-gauntlet",
            thresholds: .activateDoubleTap,
            storage: storage
        )
        let newCoordinator = GameSessionCoordinator(
            session: newSession,
            gameKind: .activateDoubleTap,
            voiceOverProvider: iOSLiveVoiceOverStateProvider()
        )
        session = newSession
        coordinator = newCoordinator

        // Start session first — session MUST be in .running before any activation
        // calls recordMistake/complete or they throw invalidTransition.
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await newSession.start()
            } catch {
                RA11yLogger.gameSession.error("L3 session start failed: \(error.localizedDescription)")
                return
            }
            newCoordinator.startMonitoring()
            self.startTimer(total: 20) { [weak self] in await self?.handleL3Timeout() }
            self.observeCoordinatorVOState(coordinator: newCoordinator)
        }
    }

    /// Polls the given coordinator for a VoiceOver-off event and mirrors it onto the ViewModel.
    ///
    /// ## Concurrency
    /// Runs in a `Task` so it does not block the calling context. Exits as soon as the flag
    /// is set, the task is cancelled, or the ViewModel is released.
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

    // MARK: - Seal Activation

    /// Handles a seal button tap for the current level.
    ///
    /// - Correct seal: marks level complete; starts L3 session completion if in `.timed` phase.
    /// - Wrong seal: records mistake, announces feedback via VoiceOver.
    func activateSeal(_ seal: RogueSeal) async {
        guard !levelComplete, !l2TimedOut, !l3TimedOut else { return }

        if seal == targetSeal {
            await handleCorrectActivation(seal)
        } else {
            await handleWrongActivation(seal)
        }
    }

    /// Announces the hint string via VoiceOver and sets it as the visible status message.
    func requestHint() {
        guard let target = targetSeal else { return }
        let message = String(format: String(localized: "rogue.hint.format"), target.displayName)
        statusMessage = message
        announce(message)
    }

    /// Announces the objective prompt to VoiceOver when a level view appears.
    ///
    /// Called from each level view's `.onAppear` so VoiceOver reads the target seal name
    /// aloud on screen load — satisfying the spec requirement "announce objective on level load."
    /// A 500 ms delay prevents the announcement from being swallowed by the navigation
    /// transition focus announcement.
    func announceObjectivePrompt() {
        guard let target = targetSeal else { return }
        let message: String
        switch phase {
        case .firstAttempt:
            message = String(format: String(localized: "rogue.a11y.l1.objective"), target.displayName)
        case .rising:
            message = String(format: String(localized: "rogue.a11y.l2.objective"), target.displayName)
        case .timed:
            message = String(format: String(localized: "rogue.a11y.l3.objective"), target.displayName)
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

    private func handleCorrectActivation(_ seal: RogueSeal) async {
        switch phase {
        case .prologue:
            break

        case .firstAttempt:
            stopTimer()
            levelComplete = true
            statusMessage = String(localized: "rogue.feedback.correct")
            announce(String(localized: "rogue.l1.complete"))

        case .rising:
            stopTimer()
            levelComplete = true
            statusMessage = String(localized: "rogue.feedback.correct")
            announce(String(localized: "rogue.l2.complete"))

        case .timed:
            guard let session else { return }
            stopTimer()

            // Compute elapsed from the 20 s L3 window and record any time-bucket penalty
            // mistakes before completing the session. Bucket size for this game is 8 s
            // (per GameSpec-ActivateDoubleTap.txt): first 8 s is free, each subsequent
            // full 8 s adds +1 mistake.
            let elapsed = 20.0 - timeRemaining
            let buckets = RankThresholds.bucketMistakes(timeSeconds: elapsed, bucketSize: 8)
            for _ in 0..<buckets {
                try? await session.recordMistake()
            }

            do {
                try await session.complete()
                coordinator?.stopMonitoring()
                announce(String(localized: "rogue.l3.success"))
                if case .completed(let result) = await session.state {
                    completedResult = result
                }
            } catch {
                RA11yLogger.gameSession.error("L3 session complete failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleWrongActivation(_ seal: RogueSeal) async {
        if phase == .timed, let session {
            do { try await session.recordMistake() } catch { /* session in non-running state */ }
        }
        mistakes += 1
        statusMessage = String(localized: "rogue.feedback.trap")
        announce(String(localized: "rogue.feedback.trap"))
    }

    // MARK: - Private: Timer

    /// Starts a countdown timer for `total` seconds, calling `onTimeout` when it expires.
    ///
    /// ## Concurrency
    /// Runs in a `@MainActor`-isolated `Task` to allow mutation of `timeRemaining` without
    /// data races. `UIAccessibility.post` also requires the main thread.
    /// Uses `[weak self]` on every iteration to avoid retaining the ViewModel in long-running tasks.
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
                guard let self, !Task.isCancelled else { return }

                let elapsed = Date().timeIntervalSince(startDate)
                let remaining = max(0, total - elapsed)
                self.timeRemaining = remaining

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

                // 10 s remaining — L3 only
                if self.phase == .timed && remaining <= 10 && !announced10 {
                    announced10 = true
                    self.announce(String(localized: "a11y.timer.10s"))
                }

                // Final 5 s countdown (shared across games)
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
        announce(String(localized: "rogue.timeout"))
    }

    private func handleL3Timeout() async {
        guard let session else { return }
        l3TimedOut = true
        coordinator?.stopMonitoring()
        await session.abandon()
        announce(String(localized: "rogue.timeout"))
        // Synthesise a Defeated result for display (not stored — session was abandoned).
        completedResult = GameResult(
            gameID: "rogue-gauntlet",
            rank: .failed,
            timeSeconds: 20.0,
            mistakes: mistakes
        )
    }

    // MARK: - Private: VoiceOver Announcements

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// Posts the game-specific timer threshold announcement for the given phase and elapsed percent.
    ///
    /// L2 only announces at 50% and 25% (no 75% for the soft timer).
    /// L3 announces at 75%, 50%, and 25%.
    private func announceTimerThreshold(for phase: Phase, pct: Double) {
        switch (phase, pct) {
        case (.timed, 0.75):
            announce(String(localized: "rogue.a11y.timer.75pct"))
        case (.timed, 0.50), (.rising, 0.50):
            announce(String(localized: "rogue.a11y.timer.50pct"))
        case (.timed, 0.25), (.rising, 0.25):
            announce(String(localized: "rogue.a11y.timer.25pct"))
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

// MARK: - RogueSeal

/// A single seal in The Rogue's Gauntlet.
///
/// Passage seals are the correct target; trap seals spring missteps when activated.
/// Level-specific sets are composed by `setForL1()`, `setForL2()`, and `setForL3()`.
struct RogueSeal: Identifiable, Hashable, Equatable {
    let id: String
    let displayName: String
    let assetName: String
    /// `true` for passage seals (correct target); `false` for trap seals.
    let isPassage: Bool

    // MARK: - Seal Pools

    /// All passage seals. L1 always uses `passage`; L2/L3 pick randomly from this pool.
    static let passageSeals: [RogueSeal] = [
        RogueSeal(id: "passage", displayName: "Seal of Passage", assetName: "rogue_seal_passage", isPassage: true),
        RogueSeal(id: "ward",    displayName: "Warding Seal",    assetName: "rogue_seal_ward",    isPassage: true),
        RogueSeal(id: "binding", displayName: "Binding Seal",    assetName: "rogue_seal_binding", isPassage: true),
    ]

    /// All trap seals. Wrong activations increment mistakes.
    static let trapSeals: [RogueSeal] = [
        RogueSeal(id: "spike",    displayName: "Spike Trap Seal", assetName: "rogue_seal_spike",    isPassage: false),
        RogueSeal(id: "alarm",    displayName: "Alarm Seal",      assetName: "rogue_seal_alarm",    isPassage: false),
        RogueSeal(id: "collapse", displayName: "Collapse Seal",   assetName: "rogue_seal_collapse", isPassage: false),
        RogueSeal(id: "reveal",   displayName: "Reveal Seal",     assetName: "rogue_seal_reveal",   isPassage: false),
        RogueSeal(id: "freeze",   displayName: "Freeze Seal",     assetName: "rogue_seal_freeze",   isPassage: false),
        RogueSeal(id: "silence",  displayName: "Silence Seal",    assetName: "rogue_seal_silence",  isPassage: false),
    ]

    /// Placeholder used as ViewModel initial state before a level is configured.
    static let placeholder = RogueSeal(id: "", displayName: "", assetName: "", isPassage: false)

    // MARK: - Set Builders

    /// Returns the single-seal L1 set. Always Seal of Passage — never randomised.
    static func setForL1() -> (seals: [RogueSeal], target: RogueSeal) {
        let seal = passageSeals[0]   // always "passage"
        return ([seal], seal)
    }

    /// Returns 4 seals for L2: 1 passage (random) + 3 trap seals (random).
    ///
    /// UI-testing mode uses a fixed, deterministic selection for screenshot repeatability.
    static func setForL2() -> (seals: [RogueSeal], target: RogueSeal) {
        let isTesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let passage = isTesting ? passageSeals[0] : (passageSeals.randomElement() ?? passageSeals[0])
        let traps   = isTesting ? Array(trapSeals.prefix(3)) : Array(trapSeals.shuffled().prefix(3))
        let seals   = isTesting ? [passage] + traps : ([passage] + traps).shuffled()
        return (seals, passage)
    }

    /// Returns 6 seals for L3: 1 passage (random) + 5 trap seals (random).
    ///
    /// UI-testing mode uses a fixed, deterministic selection for screenshot repeatability.
    static func setForL3() -> (seals: [RogueSeal], target: RogueSeal) {
        let isTesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let passage = isTesting ? passageSeals[0] : (passageSeals.randomElement() ?? passageSeals[0])
        let traps   = isTesting ? Array(trapSeals.prefix(5)) : Array(trapSeals.shuffled().prefix(5))
        let seals   = isTesting ? [passage] + traps : ([passage] + traps).shuffled()
        return (seals, passage)
    }
}

// MARK: - L0: RoguePrologueView

/// L0 Prologue — DM narration, "The Rogue's Creed" lesson card, gesture guide, and "Begin Trial".
///
/// No game session. Player reads (or VoiceOver reads) the paradigm shift, then taps "Begin Trial"
/// to start L1.
private struct RoguePrologueView: View {

    let onBeginTrial: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: RA11ySpacing.lg) {
                dmNarrationCard
                lessonCard
                gestureGuide
                beginButton
            }
            .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
            .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .dark)
    }

    private var dmNarrationCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Label(String(localized: "dm.label"), systemImage: "scroll.fill")
                .font(.ra11yCaption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(String(localized: "rogue.explain.narration"))
                .font(.ra11yBody)
                .italic()
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(Color.ra11yDMBorder.opacity(0.5), lineWidth: 1)
        )
    }

    private var lessonCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "rogue.explain.lesson.heading"))
                .font(.ra11yHeadline)
                .bold()
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "rogue.explain.lesson.body"))
                .font(.ra11yBody)
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "rogue.a11y.explain.lesson"))
    }

    private var gestureGuide: some View {
        VStack(spacing: RA11ySpacing.sm) {
            RogueGestureRow(symbol: "hand.tap.fill",        label: String(localized: "rogue.explain.gesture.tap1"))
            RogueGestureRow(symbol: "hand.tap.fill",        label: String(localized: "rogue.explain.gesture.tap2"))
            RogueGestureRow(symbol: "exclamationmark.triangle.fill", label: String(localized: "rogue.explain.gesture.wrong"))
        }
        .accessibilityHidden(true)
    }

    private var beginButton: some View {
        Button(action: onBeginTrial) {
            Text(String(localized: "level.button.start"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .accessibilityHint(String(localized: "rogue.explain.start.hint"))
        .accessibilityIdentifier("rogue.beginTrial")
    }
}

// MARK: - L1: RogueFirstAttemptView

/// L1 First Attempt — single Seal of Passage, no timer, no hint button, no mistake HUD.
///
/// Layout: prompt card + instructional text + large centered seal button.
/// Teaches the double-tap mechanic with zero ambiguity — only one interactive element exists.
private struct RogueFirstAttemptView: View {

    let seal: RogueSeal
    let statusMessage: String?
    let levelComplete: Bool
    let onActivate: (RogueSeal) async -> Void
    let onContinue: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: RA11ySpacing.lg) {
                roguePromptCard(
                    title: String(format: String(localized: "rogue.l1.objective.format"), seal.displayName),
                    a11yLabel: String(format: String(localized: "rogue.a11y.l1.objective"), seal.displayName),
                    a11yHint: String(localized: "rogue.a11y.l1.objective.hint")
                )

                Text(String(localized: "rogue.l1.dm_prompt"))
                    .font(.ra11yBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityHidden(true)

                // Large centered seal — the only interactive element on this screen.
                largeSealButton

                if let statusMessage {
                    rogueStatusRow(statusMessage)
                }

                if levelComplete {
                    continueButton
                }
            }
            .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
            .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .dark)
    }

    private var largeSealButton: some View {
        Button {
            Task { await onActivate(seal) }
        } label: {
            VStack(spacing: RA11ySpacing.sm) {
                SealImage(assetName: seal.assetName)
                    .frame(width: 160, height: 160)
                    .accessibilityHidden(true)

                Text(seal.displayName)
                    .font(.ra11yHeadline)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding(RA11ySpacing.base)
            .background(Color.black.opacity(0.25), in: .rect(cornerRadius: RA11yRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RA11yRadius.card)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .accessibilityLabel(seal.displayName)
        .accessibilityHint(String(localized: "rogue.seal.hint"))
        .accessibilityIdentifier("rogue.seal.\(seal.id)")
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text(String(localized: "level.button.next"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .accessibilityIdentifier("rogue.l1.continue")
    }
}

// MARK: - L2: RogueRisingView

/// L2 Rising Challenge — 4 seals in a 2×2 grid, 40 s soft timer, hint button.
///
/// VoiceOver reads the LazyVGrid in row-major order (left→right, top→bottom),
/// which is linear and deterministic — equivalent to a vertical list for accessibility.
private struct RogueRisingView: View {

    let seals: [RogueSeal]
    let targetSeal: RogueSeal
    let mistakes: Int
    let timeRemaining: Double
    let statusMessage: String?
    let levelComplete: Bool
    let timedOut: Bool
    let onActivate: (RogueSeal) async -> Void
    let onHint: () -> Void
    let onContinue: () -> Void
    let onRetry: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: RA11ySpacing.lg) {
                roguePromptCard(
                    title: String(format: String(localized: "rogue.l2.objective.format"), targetSeal.displayName),
                    a11yLabel: String(format: String(localized: "rogue.a11y.l2.objective"), targetSeal.displayName),
                    a11yHint: String(localized: "rogue.a11y.l2.objective.hint")
                )

                RogueTimerHUD(timeRemaining: timeRemaining, total: 40, mistakes: mistakes)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        String(format: String(localized: "rogue.a11y.l2.timer"), Int(ceil(timeRemaining)))
                    )
                    .accessibilityHint(String(localized: "a11y.timer.group.hint"))

                if timedOut {
                    timeoutBanner
                } else {
                    SealGrid(seals: seals, columns: 2, onActivate: onActivate)

                    if let statusMessage { rogueStatusRow(statusMessage) }

                    if levelComplete {
                        continueButton
                    } else {
                        hintButton
                    }
                }
            }
            .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
            .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .dark)
    }

    private var timeoutBanner: some View {
        VStack(spacing: RA11ySpacing.md) {
            Text(String(localized: "rogue.timeout"))
                .font(.ra11yHeadline)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text(String(localized: "level.button.retry"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.ra11yAccent)
            .accessibilityIdentifier("rogue.l2.retry")
        }
        .padding(RA11ySpacing.base)
    }

    private var hintButton: some View {
        Button(action: onHint) {
            Label(String(localized: "rogue.hint.button"), systemImage: "ear.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "rogue.hint.a11yLabel"))
        .accessibilityHint(String(localized: "rogue.hint.a11yHint"))
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text(String(localized: "level.button.next"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .accessibilityIdentifier("rogue.l2.continue")
    }
}

// MARK: - L3: RogueTimedView

/// L3 Timed Trial — 6 seals in a 2×3 grid, 20 s hard timer, `GameSession` for scoring.
///
/// On timeout, shows the timeout banner with "Try Again". The ViewModel handles session
/// abandonment; the container view navigates to the result screen when `completedResult` is set.
private struct RogueTimedView: View {

    let seals: [RogueSeal]
    let targetSeal: RogueSeal
    let mistakes: Int
    let timeRemaining: Double
    let statusMessage: String?
    let timedOut: Bool
    let onActivate: (RogueSeal) async -> Void
    let onHint: () -> Void
    let onRetry: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: RA11ySpacing.lg) {
                roguePromptCard(
                    title: String(format: String(localized: "rogue.l3.objective.format"), targetSeal.displayName),
                    a11yLabel: String(format: String(localized: "rogue.a11y.l3.objective"), targetSeal.displayName),
                    a11yHint: nil
                )

                RogueTimerHUD(timeRemaining: timeRemaining, total: 20, mistakes: mistakes)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        String(format: String(localized: "rogue.a11y.l3.timer"), Int(ceil(timeRemaining)))
                    )
                    .accessibilityHint(String(localized: "a11y.timer.group.hint"))

                if timedOut {
                    timeoutBanner
                } else {
                    SealGrid(seals: seals, columns: 2, onActivate: onActivate)

                    if let statusMessage { rogueStatusRow(statusMessage) }

                    hintButton
                }
            }
            .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
            .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .dark)
    }

    private var timeoutBanner: some View {
        VStack(spacing: RA11ySpacing.md) {
            Text(String(localized: "rogue.timeout"))
                .font(.ra11yHeadline)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text(String(localized: "level.button.retry"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.ra11yAccent)
            .accessibilityIdentifier("rogue.l3.retry")
        }
        .padding(RA11ySpacing.base)
    }

    private var hintButton: some View {
        Button(action: onHint) {
            Label(String(localized: "rogue.hint.button"), systemImage: "ear.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "rogue.hint.a11yLabel"))
        .accessibilityHint(String(localized: "rogue.hint.a11yHint"))
    }
}

// MARK: - Shared: SealGrid

/// Responsive grid of seal buttons: 2-column by default, collapses to 1-column at
/// `.accessibility2`+ Dynamic Type sizes to prevent horizontal crowding.
///
/// VoiceOver reads LazyVGrid in row-major order: left→right within each row,
/// then the next row — deterministic and linear, matching the accessibility teaching goal.
private struct SealGrid: View {

    let seals: [RogueSeal]
    let columns: Int
    let onActivate: (RogueSeal) async -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isLargeAccessibilitySize: Bool { dynamicTypeSize >= .accessibility2 }

    private var activeColumns: Int { isLargeAccessibilitySize ? 1 : columns }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: RA11ySpacing.sm), count: activeColumns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: RA11ySpacing.sm) {
            ForEach(seals) { seal in
                SealButton(seal: seal, onActivate: onActivate)
            }
        }
    }
}

// MARK: - Shared: SealButton

/// Single seal button used across L1–L3 (grid cells in L2/L3; standalone large button in L1
/// uses a bespoke layout — see `RogueFirstAttemptView.largeSealButton`).
///
/// Each button announces its name and hint to VoiceOver, fulfilling the accessibility requirement
/// "all seals: accessibilityLabel (seal name) + accessibilityHint (Double-tap to sever)."
///
/// ## Dynamic Type
/// The seal name label has no `lineLimit` so it can expand to as many lines as needed at
/// large DT sizes. `SealGrid` collapses to 1 column at `.accessibility2`+ which provides
/// sufficient width for any reasonable label.
private struct SealButton: View {

    let seal: RogueSeal
    let onActivate: (RogueSeal) async -> Void

    var body: some View {
        Button {
            Task { await onActivate(seal) }
        } label: {
            VStack(spacing: RA11ySpacing.xs) {
                SealImage(assetName: seal.assetName)
                    .aspectRatio(1, contentMode: .fit)
                    .accessibilityHidden(true)

                Text(seal.displayName)
                    .font(.ra11yCaption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(RA11ySpacing.sm)
            .background(Color.black.opacity(0.35), in: .rect(cornerRadius: RA11yRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RA11yRadius.card)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .accessibilityLabel(seal.displayName)
        .accessibilityHint(String(localized: "rogue.seal.hint"))
        .accessibilityIdentifier("rogue.seal.\(seal.id)")
    }
}

// MARK: - Shared: SealImage

/// Circular medallion image for a seal sprite, with a fallback SF Symbol.
///
/// Uses `.blendMode(.multiply)` so white-background sprite exports blend cleanly
/// against the dark circular base — matching the M5 RelicImage pattern.
private struct SealImage: View {
    let assetName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.12))

            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .blendMode(.multiply)
            } else {
                Image(systemName: "seal.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(16)
                    .foregroundStyle(.gray)
            }
        }
        .clipShape(Circle())
    }
}

// MARK: - Shared: RogueTimerHUD

/// Combined timer progress bar + time + mistake count HUD used in L2 and L3.
///
/// The HUD is `accessibilityHidden` — the containing level view sets a combined
/// `accessibilityLabel` on the whole HUD group so VoiceOver reads time + mistakes together.
/// The bar height decreases at 50% and 25% remaining to provide a non-color urgency cue.
///
/// ## Dynamic Type
/// Bar height scales with `.subheadline` via `@ScaledMetric`.
/// At `.accessibility4`+ the label row switches to `VStack` so the timer and mistake
/// count don't crowd each other in the ~200 pt available width.
private struct RogueTimerHUD: View {

    let timeRemaining: Double
    let total: Double
    let mistakes: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    /// Scales with `.subheadline` style (base 12 pt).
    @ScaledMetric(relativeTo: .subheadline) private var baseBarHeight: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
            hudLabels

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
        }
        .accessibilityHidden(true)
    }

    /// Timer + mistakes labels. Switches to `VStack` at `.accessibility4`+ to prevent
    /// horizontal crowding at large Dynamic Type sizes.
    @ViewBuilder
    private var hudLabels: some View {
        if dynamicTypeSize >= .accessibility4 {
            VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
                timerLabel
                mistakesLabel
            }
        } else {
            HStack {
                timerLabel
                Spacer()
                mistakesLabel
            }
        }
    }

    private var timerLabel: some View {
        Label(
            String(format: String(localized: "hud.timer.format"), Int(ceil(timeRemaining))),
            systemImage: "clock"
        )
        .font(.ra11ySubheadline)
        .foregroundStyle(.primary)
    }

    private var mistakesLabel: some View {
        Text(String(format: String(localized: "rogue.hud.mistakes.format"), mistakes))
            .font(.ra11ySubheadline)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Shared: RogueBackgroundView

/// Full-bleed background for all Rogue's Gauntlet levels.
///
/// Uses `rogue_trap_door_bg` with a dark overlay for legibility. Falls back to a solid
/// dark stone color if the asset is unavailable.
private struct RogueBackgroundView: View {
    var body: some View {
        if let image = UIImage(named: "rogue_trap_door_bg") {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.45))
        } else {
            Color.ra11yGameFallbackBackground
        }
    }
}

// MARK: - Shared: Primitive Subviews

/// Small gesture guide row used in L0 prologue.
private struct RogueGestureRow: View {
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

/// Prompt card shown at the top of L1–L3. Displays the DM objective + accessibility metadata.
private func roguePromptCard(title: String, a11yLabel: String, a11yHint: String?) -> some View {
    VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
        Label(String(localized: "dm.label"), systemImage: "scroll.fill")
            .font(.ra11yCaption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

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

/// Status feedback row shown after a seal activation event.
private func rogueStatusRow(_ message: String) -> some View {
    Text(message)
        .font(.ra11ySubheadline)
        .foregroundStyle(Color.ra11yCardSecondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RA11ySpacing.xs)
}

// MARK: - View+Modify Helper

private extension View {
    /// Applies a transform closure, enabling conditional modifier application without AnyView erasure.
    @ViewBuilder
    func modify<T: View>(@ViewBuilder transform: (Self) -> T) -> some View {
        transform(self)
    }
}

// MARK: - Preview

#Preview("L0 Prologue") {
    NavigationStack {
        iOSRogueGauntletView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
