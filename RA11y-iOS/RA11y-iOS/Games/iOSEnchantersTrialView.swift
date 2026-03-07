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

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router

    // MARK: - Init

    init(storage: any StorageComponent) {
        _viewModel = State(initialValue: EnchanterTrialViewModel(storage: storage))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            EnchanterBackgroundView()
                .ignoresSafeArea()

            levelContent
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.completedResult) { _, result in
            guard let result else { return }
            let announcement = gameSpecificAnnouncement(for: result)
            router.push(.gameResult(result, gameSpecificAnnouncement: announcement))
        }
        .onChange(of: viewModel.voiceOverDisabledMidGame) { _, disabled in
            if disabled {
                router.push(.voiceOverInterstitial(kind: .findAndFocus))
            }
        }
    }

    // MARK: - Level Routing

    @ViewBuilder
    private var levelContent: some View {
        switch viewModel.phase {
        case .prologue:
            EnchanterPrologueView(onBeginTrial: { viewModel.beginTrial() })
                .navigationTitle(String(localized: "simon.explain.title"))
        case .attempt:
            EnchanterAttemptView(
                relics: viewModel.relics,
                targetRelic: viewModel.targetRelic,
                mistakes: viewModel.mistakes,
                statusMessage: viewModel.statusMessage,
                levelComplete: viewModel.levelComplete,
                onActivate: { relic in await viewModel.activateRelic(relic) },
                onHint: { viewModel.requestHint() },
                onContinue: { viewModel.advanceToRising() }
            )
            .navigationTitle(String(localized: "simon.l1.title"))
        case .rising:
            EnchanterRisingView(
                relics: viewModel.relics,
                targetRelic: viewModel.targetRelic,
                mistakes: viewModel.mistakes,
                timeRemaining: viewModel.timeRemaining,
                statusMessage: viewModel.statusMessage,
                levelComplete: viewModel.levelComplete,
                timedOut: viewModel.l2TimedOut,
                onActivate: { relic in await viewModel.activateRelic(relic) },
                onHint: { viewModel.requestHint() },
                onContinue: { viewModel.advanceToTimed() },
                onRetry: { viewModel.retryRising() }
            )
            .navigationTitle(String(localized: "simon.l2.title"))
        case .timed:
            EnchanterTimedView(
                relics: viewModel.relics,
                targetRelic: viewModel.targetRelic,
                mistakes: viewModel.mistakes,
                timeRemaining: viewModel.timeRemaining,
                statusMessage: viewModel.statusMessage,
                timedOut: viewModel.l3TimedOut,
                onActivate: { relic in await viewModel.activateRelic(relic) },
                onHint: { viewModel.requestHint() },
                onRetry: { viewModel.retryTimed() }
            )
            .navigationTitle(String(localized: "simon.l3.title"))
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

    /// L3 session — created fresh each time L3 starts (including retries).
    private var session: GameSession?

    /// VO monitor for L3. Nil during L0–L2.
    private var coordinator: GameSessionCoordinator?

    /// Countdown task running during L2 or L3. Cancelled on phase change.
    ///
    /// `nonisolated(unsafe)`: allows `deinit` (nonisolated in Swift 6) to cancel
    /// without accessing `@MainActor`-isolated state. `Task.cancel()` is thread-safe.
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?

    // MARK: - Init

    init(storage: any StorageComponent) {
        self.storage = storage
    }

    deinit {
        timerTask?.cancel()
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
    /// `GameSession` and `GameSessionCoordinator` are created fresh so retries start
    /// with a clean session. The previous session (if any) is abandoned via the timer.
    func advanceToTimed() {
        stopTimer()
        mistakes = 0
        statusMessage = nil
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
        session = newSession
        coordinator = GameSessionCoordinator(
            session: newSession,
            gameKind: .findAndFocus,
            voiceOverProvider: iOSLiveVoiceOverStateProvider()
        )
        coordinator?.startMonitoring()

        Task { @MainActor [weak self] in
            guard let self else { return }
            do { try await newSession.start() } catch {
                RA11yLogger.gameSession.error("L3 session start failed: \(error.localizedDescription)")
            }
        }

        startTimer(total: 20) { [weak self] in await self?.handleL3Timeout() }

        // Observe coordinator for VO-off mid-L3
        Task { @MainActor [weak self] in
            guard let self, let coordinator = self.coordinator else { return }
            // Poll coordinator's published flag via a short-sleep loop.
            // The coordinator sets voiceOverDisabledMidGame on VO-off; we mirror it.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                if coordinator.voiceOverDisabledMidGame {
                    self.voiceOverDisabledMidGame = true
                    self.stopTimer()
                    break
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
        announce(message)
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
            announce(String(localized: "a11y.level.completed"))

        case .rising:
            stopTimer()
            levelComplete = true
            let message = String(format: String(localized: "simon.feedback.correct"), relic.displayName)
            statusMessage = message
            announce(String(localized: "simon.l2.complete"))

        case .timed:
            guard let session else { return }
            stopTimer()
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
    private func startTimer(total: Double, onTimeout: @escaping @Sendable () async -> Void) {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startDate = Date()
            var announced75 = false
            var announced50 = false
            var announced25 = false
            var announced10 = false
            var announcedCountdown = Set<Int>()

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { break }

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

                // 10 s remaining (only for L3; L2 uses 50%/25%)
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
        let elapsed = 45.0
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
private struct EnchanterPrologueView: View {

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

            Text(String(localized: "simon.explain.narration"))
                .font(.ra11yBody)
                .italic()
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(Color(red: 0.75, green: 0.55, blue: 0.10).opacity(0.5), lineWidth: 1)
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
        .background(.regularMaterial, in: .rect(cornerRadius: RA11yRadius.card))
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
    let onActivate: (EnchanterRelic) async -> Void
    let onHint: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: RA11ySpacing.lg) {
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
            .padding(.horizontal, RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
        }
        .environment(\.colorScheme, .dark)
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
    let onActivate: (EnchanterRelic) async -> Void
    let onHint: () -> Void
    let onContinue: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: RA11ySpacing.lg) {
                promptCard(
                    title: String(format: String(localized: "simon.l2.target.format"), targetRelic.displayName),
                    a11yLabel: String(format: String(localized: "simon.a11y.l2.target"), targetRelic.displayName),
                    a11yHint: String(localized: "simon.a11y.l1.target.hint")
                )

                TimerHUD(timeRemaining: timeRemaining, total: 45)

                if timedOut {
                    timeoutBanner
                } else {
                    relicStack
                    if let statusMessage { statusRow(statusMessage) }
                    if levelComplete { continueButton } else { hintButton }
                }
            }
            .padding(.horizontal, RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
        }
        .environment(\.colorScheme, .dark)
    }

    private var relicStack: some View {
        VStack(spacing: RA11ySpacing.md) {
            ForEach(relics) { relic in
                RelicButton(relic: relic, onActivate: onActivate)
            }
        }
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
    let onActivate: (EnchanterRelic) async -> Void
    let onHint: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: RA11ySpacing.lg) {
                promptCard(
                    title: String(format: String(localized: "simon.l3.target.format"), targetRelic.displayName),
                    a11yLabel: String(format: String(localized: "simon.a11y.l3.target"), targetRelic.displayName),
                    a11yHint: nil
                )

                TimerHUD(timeRemaining: timeRemaining, total: 20)
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
            .padding(.horizontal, RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
        }
        .environment(\.colorScheme, .dark)
    }

    private var relicStack: some View {
        VStack(spacing: RA11ySpacing.md) {
            ForEach(relics) { relic in
                RelicButton(relic: relic, onActivate: onActivate)
            }
        }
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
    .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
    .overlay(
        RoundedRectangle(cornerRadius: RA11yRadius.card)
            .strokeBorder(Color(red: 0.75, green: 0.55, blue: 0.10).opacity(0.5), lineWidth: 1)
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
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RA11ySpacing.xs)
}

/// Single relic button used across L1–L3.
///
/// Displays the relic image (with SF Symbol fallback) and its display name.
/// Configured as a linear-list item so VoiceOver swipe navigation is predictable.
private struct RelicButton: View {

    let relic: EnchanterRelic
    let onActivate: (EnchanterRelic) async -> Void

    var body: some View {
        Button {
            Task { await onActivate(relic) }
        } label: {
            HStack(spacing: RA11ySpacing.md) {
                RelicImage(assetName: relic.assetName)
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)

                Text(relic.displayName)
                    .font(.ra11yHeadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(RA11ySpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.25), in: .rect(cornerRadius: RA11yRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RA11yRadius.card)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .accessibilityLabel(relic.displayName)
        .accessibilityHint(String(localized: "simon.token.hint"))
    }
}

/// Timer progress bar shown in L2 and L3.
///
/// Depletes left-to-right as time passes. Height decreases in the final 50% and 25%
/// to provide a non-color urgency cue, per `GameRules-MVP.txt` timer spec.
/// The timer element is `accessibilityHidden` — the containing L3 view sets a
/// formatted `accessibilityLabel` on the whole HUD.
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

    var body: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.1))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(
                            width: geo.size.width * fraction,
                            height: 12 * barHeightMultiplier
                        )
                        .animation(.linear(duration: 0.2), value: fraction)
                }
            }
            .frame(height: 12)

            Text(String(format: String(localized: "hud.timer.format"), Int(ceil(timeRemaining))))
                .font(.ra11yCaption)
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)  // L3 view sets accessibilityLabel on this entire HUD
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
                .frame(width: 32)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.ra11yBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Relic asset image with SF Symbol fallback.
private struct RelicImage: View {
    let assetName: String

    var body: some View {
        if let image = UIImage(named: assetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
        }
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
