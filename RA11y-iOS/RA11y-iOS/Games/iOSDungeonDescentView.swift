import Observation
import os
import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSDungeonDescentView

/// Container for Crystal Resonance (Glyph stream) — M7.
///
/// Implements the full 4-level game arc defined in `GameSpec-ScrollHunt.txt`
/// and `GameRules-MVP.txt`:
///
/// - **L0 Prologue**: Retained for deterministic `dungeonPrologue` screenshots (`-screenshotScene`);
///   optional narration, lesson, practice scroll, and begin trial — **not** shown on normal launch.
/// - **L1 First Attempt (cold start)**: Normal entry begins at the resonance shaft — fixed orb,
///   scrolling moonstone lane (ADR-0003), no timer; gesture tip + VoiceOver objective in the HUD.
/// - **L2 Rising Challenge**: 8 rooms, 60 s soft timer — Relic Vault as target
/// - **L3 Timed Trial**: 12 rooms, 45 s hard timer; `GameSession` started here for scoring
///
/// Only L3 creates a `GameSession`. Gameplay uses ADR-0003 resonance alignment: vertical
/// distance from the moonstone to the screen aim line drives `targetIsReachable`, orb/reticle
/// presentation, and `QuestFeedbackBand` multimodal feedback (`updateResonanceDelta`).
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSDungeonDescentView: View {

    // MARK: - State

    @State private var viewModel: DungeonDescentViewModel

    /// Final timed level only: blackout of room icons and variable layout (`LightsOffMode-Recommendations.txt`).
    private var isLightsOffFinalLevel: Bool { viewModel.phase == .timed }

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router

    // MARK: - Private

    private let storage: any StorageComponent

    // MARK: - Init

    /// Creates the Crystal Resonance game container.
    ///
    /// - Parameters:
    ///   - storage: Persistence used for L3 session results during normal gameplay.
    ///   - screenshotScene: Optional deterministic screenshot scene override.
    init(storage: any StorageComponent, screenshotScene: iOSScreenshotScene? = nil) {
        self.storage = storage
        _viewModel = State(
            initialValue: DungeonDescentViewModel(storage: storage, screenshotScene: screenshotScene)
        )
    }

    // MARK: - Body

    /// See `iOSEnchantersTrialView` for the rationale for using `.background {}` over ZStack.
    ///
    /// The prologue's full-bleed backdrop is owned by `QuestPaintScreen` inside `DungeonPrologueView`;
    /// no phase-gated background is needed here.
    var body: some View {
        levelContent
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel.completedResult) { _, result in
                guard let result else { return }
                router.push(.gameResult(result, gameKind: .scrollHunt, gameSpecificAnnouncement: gameSpecificAnnouncement(for: result)))
            }
            .onChange(of: viewModel.voiceOverDisabledMidGame) { _, disabled in
                if disabled {
                    router.push(.voiceOverInterstitial(kind: .scrollHunt))
                }
            }
            .onDisappear { viewModel.handleViewDisappear() }
    }

    // MARK: - Level Routing

    /// See `iOSEnchantersTrialView` for the rationale for `.transition(.identity)` on each case.
    @ViewBuilder
    private var levelContent: some View {
        switch viewModel.phase {
        case .prologue:
            DungeonPrologueView(
                practiceScrollObserved: viewModel.practiceScrollObserved,
                onPracticeScroll: { viewModel.recordPracticeScroll() },
                onBeginTrial: { viewModel.beginTrial() }
            )
            .navigationTitle(String(localized: "dungeon.explain.title"))
            .accessibilityIdentifier("dungeon.prologue")
            .transition(.identity)

        case .firstAttempt:
            iOSDungeonResonancePlayView(
                rooms: viewModel.rooms,
                targetIsReachable: viewModel.targetIsReachable,
                statusMessage: viewModel.statusMessage,
                levelComplete: viewModel.levelComplete,
                timeRemaining: nil,
                timedOut: false,
                mistakes: viewModel.mistakes,
                lightsOffMode: isLightsOffFinalLevel,
                lightsOffFlavorText: nil,
                showsFirstLevelGestureTip: true,
                continueButtonTitle: String(localized: "dungeon.resonance.continue.toRising"),
                initialLaneIndexOverride: viewModel.resonanceInitialLaneIndexOverride,
                onResonanceDeltaChanged: { viewModel.updateResonanceDelta($0) },
                onActivateTarget: { room in await viewModel.activateTarget(room) },
                onLaneSlotChanged: { viewModel.notifyResonanceLaneSlotChanged() },
                onHint: nil,
                onContinue: { viewModel.advanceToRising() },
                onRetry: nil
            )
            .navigationTitle(String(localized: "dungeon.l1.title"))
            .accessibilityIdentifier("dungeon.firstAttempt")
            .transition(.identity)

        case .rising:
            iOSDungeonResonancePlayView(
                rooms: viewModel.rooms,
                targetIsReachable: viewModel.targetIsReachable,
                statusMessage: viewModel.statusMessage,
                levelComplete: viewModel.levelComplete,
                timeRemaining: viewModel.timeRemaining,
                timedOut: viewModel.l2TimedOut,
                mistakes: viewModel.mistakes,
                lightsOffMode: isLightsOffFinalLevel,
                lightsOffFlavorText: nil,
                showsFirstLevelGestureTip: false,
                continueButtonTitle: String(localized: "dungeon.resonance.continue.toFinalTrial"),
                initialLaneIndexOverride: viewModel.resonanceInitialLaneIndexOverride,
                onResonanceDeltaChanged: { viewModel.updateResonanceDelta($0) },
                onActivateTarget: { room in await viewModel.activateTarget(room) },
                onLaneSlotChanged: { viewModel.notifyResonanceLaneSlotChanged() },
                onHint: { viewModel.requestHint() },
                onContinue: { viewModel.advanceToTimed() },
                onRetry: { viewModel.retryRising() }
            )
            .navigationTitle(String(localized: "dungeon.l2.title"))
            .accessibilityIdentifier("dungeon.rising")
            .transition(.identity)

        case .timed:
            iOSDungeonResonancePlayView(
                rooms: viewModel.rooms,
                targetIsReachable: viewModel.targetIsReachable,
                statusMessage: viewModel.statusMessage,
                levelComplete: false,  // L3 routes via completedResult, not levelComplete
                timeRemaining: viewModel.timeRemaining,
                timedOut: viewModel.l3TimedOut,
                mistakes: viewModel.mistakes,
                lightsOffMode: isLightsOffFinalLevel,
                lightsOffFlavorText: String(localized: "dungeon.lightsOff.flavor"),
                showsFirstLevelGestureTip: false,
                continueButtonTitle: nil,
                initialLaneIndexOverride: viewModel.resonanceInitialLaneIndexOverride,
                onResonanceDeltaChanged: { viewModel.updateResonanceDelta($0) },
                onActivateTarget: { room in await viewModel.activateTarget(room) },
                onLaneSlotChanged: { viewModel.notifyResonanceLaneSlotChanged() },
                onHint: { viewModel.requestHint() },
                onContinue: nil,
                onRetry: { viewModel.retryTimed() }
            )
            .navigationTitle(String(localized: "dungeon.l3.title"))
            .accessibilityIdentifier("dungeon.timed")
            .transition(.identity)
        }
    }

    // MARK: - Game-Specific Result Announcements

    private func gameSpecificAnnouncement(for result: GameResult) -> String {
        switch result.rank {
        case .perfect: return String(localized: "dungeon.results.legendary")
        case .good:    return String(localized: "dungeon.results.skilled")
        case .ok:      return String(localized: "dungeon.results.novice")
        case .failed:  return String(localized: "dungeon.results.defeated")
        }
    }
}

// MARK: - DungeonDescentViewModel

/// Observable view model managing the Crystal Resonance four-level state machine.
///
/// Owns level phase transitions, room set composition, mistake tracking, timer logic,
/// VoiceOver threshold announcements, and the L3 `GameSession`/`GameSessionCoordinator`.
///
/// Scroll observability is a collaboration between the view (which provides raw CGRect
/// updates from `onScrollGeometryChange` and preference keys) and the ViewModel (which
/// owns `targetIsReachable` and `updateTargetReachability(visibleRect:targetFrame:)`).
///
/// ## Concurrency
/// `@MainActor` isolated for safe SwiftUI observation. The countdown timer runs in a
/// `Task` confined to `@MainActor` to avoid data races on view-observable state.
@Observable
@MainActor
final class DungeonDescentViewModel {

    // MARK: - Phase

    enum Phase { case prologue, firstAttempt, rising, timed }

    private(set) var phase: Phase = .prologue

    // MARK: - Shared Level State

    private(set) var practiceScrollObserved: Bool = false
    private(set) var rooms: [DungeonRoom] = []
    private(set) var targetIsReachable: Bool = false
    private(set) var statusMessage: String?
    private(set) var mistakes: Int = 0
    private(set) var levelComplete: Bool = false

    /// When set, ``iOSDungeonResonancePlayView`` seeds the scroll proxy to this lane index (screenshot determinism).
    /// Normal play leaves this `nil` so the play surface picks a **decoy** under the hub first.
    private(set) var resonanceInitialLaneIndexOverride: Int?

    // MARK: - Timer State (L2 + L3)

    /// Remaining seconds for the active level timer. Updated approximately every 0.2 s.
    private(set) var timeRemaining: Double = 0

    private(set) var l2TimedOut: Bool = false
    private(set) var l3TimedOut: Bool = false

    // MARK: - L3 Session State

    /// Set when L3 `GameSession.complete()` succeeds (or on timeout as a Defeated sentinel).
    /// The container view navigates to the result screen when this becomes non-nil.
    private(set) var completedResult: GameResult?

    /// Set to `true` when `GameSessionCoordinator` detects VoiceOver going off mid-game.
    private(set) var voiceOverDisabledMidGame: Bool = false

    // MARK: - Private

    private let storage: any StorageComponent
    private let screenshotScene: iOSScreenshotScene?

    /// L3 session — created fresh each time L3 starts (including retries).
    private var session: GameSession?

    /// VO monitor for L3. Nil during L0–L2.
    private var coordinator: GameSessionCoordinator?

    /// Countdown task running during L2 or L3. Cancelled on phase change via `stopTimer()`.
    private var timerTask: Task<Void, Never>?

    /// Multimodal resonance feedback (audio/haptics) for alignment ladder transitions.
    private let questFeedbackCoordinator: iOSQuestFeedbackCoordinator

    /// Last band forwarded to `questFeedbackCoordinator` to avoid redundant cues.
    private var lastResonanceFeedbackBand: QuestFeedbackBand?

    // MARK: - Init

    /// Creates the Crystal Resonance view model.
    ///
    /// - Parameters:
    ///   - storage: Persistence used for normal gameplay session storage.
    ///   - screenshotScene: Optional deterministic screenshot scene override. When `nil`, the flow
    ///     skips L0 and begins at L1 (`beginTrial()`) so play teaches scrolling in the real shaft.
    init(storage: any StorageComponent, screenshotScene: iOSScreenshotScene? = nil) {
        self.storage = storage
        self.screenshotScene = screenshotScene
        self.questFeedbackCoordinator = iOSQuestFeedbackCoordinator(
            profile: .dungeonResonance,
            settings: iOSFeedbackSettings()
        )
        if let screenshotScene {
            applyScreenshotScene(screenshotScene)
        } else {
            beginTrial()
        }
    }

    /// Returns whether lane order and Moonstone position should be randomized (L1–L3).
    ///
    /// Screenshot and UI-test launches keep fixed layouts for determinism.
    private func shouldRandomizeResonanceLaneLayout() -> Bool {
        if screenshotScene != nil { return false }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") { return false }
        return true
    }

    /// Builds the room list for the current level, optionally shuffling order and picking a random Moonstone slot.
    private func roomsForLevel(_ base: [DungeonRoom], randomizeTargetPlacement: Bool) -> [DungeonRoom] {
        if randomizeTargetPlacement, shouldRandomizeResonanceLaneLayout() {
            return DungeonRoom.randomizedRoomsPreservingPool(base)
        }
        return base
    }

    // MARK: - Phase Transitions

    /// Records that the player has scrolled in the L0 practice zone.
    func recordPracticeScroll() {
        practiceScrollObserved = true
    }

    /// Transitions L0 → L1: 4-room dungeon, no timer.
    func beginTrial() {
        stopTimer()
        resetResonanceAlignmentState()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        targetIsReachable = false
        resonanceInitialLaneIndexOverride = nil
        rooms = roomsForLevel(DungeonRoom.l1Rooms, randomizeTargetPlacement: true)
        phase = .firstAttempt
    }

    /// Transitions L1 → L2: 8-room dungeon with 60 s soft timer.
    func advanceToRising() {
        stopTimer()
        resetResonanceAlignmentState()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        l2TimedOut = false
        targetIsReachable = false
        resonanceInitialLaneIndexOverride = nil
        rooms = roomsForLevel(DungeonRoom.l2Rooms, randomizeTargetPlacement: true)
        timeRemaining = 60
        phase = .rising
        startTimer(total: 60) { [weak self] in await self?.handleL2Timeout() }
    }

    /// Retries L2 on timeout without returning to L1.
    func retryRising() {
        advanceToRising()
    }

    /// Transitions L2 → L3: 12-room dungeon with 45 s hard timer and a fresh `GameSession`.
    ///
    /// ## Concurrency
    /// `GameSession.start()` must complete before the timer or any room activation can call
    /// `recordMistake()` / `complete()`. Both are sequenced inside a single `Task`.
    func advanceToTimed() {
        stopTimer()
        resetResonanceAlignmentState()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        l3TimedOut = false
        completedResult = nil
        voiceOverDisabledMidGame = false
        targetIsReachable = false
        resonanceInitialLaneIndexOverride = nil
        rooms = roomsForLevel(DungeonRoom.l3Rooms, randomizeTargetPlacement: true)
        timeRemaining = 45
        phase = .timed

        let newSession = GameSession(
            gameID: "scroll-hunt",
            thresholds: .scrollHunt,
            storage: storage
        )
        let newCoordinator = GameSessionCoordinator(
            session: newSession,
            gameKind: .scrollHunt,
            voiceOverProvider: iOSLiveVoiceOverStateProvider()
        )
        session = newSession
        coordinator = newCoordinator

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
            // 45 s window is already draining while VoiceOver is still speaking, making
            // the trial nearly impossible. The grace period lets the user hear the prompt
            // and orient before the countdown begins.
            if UIAccessibility.isVoiceOverRunning {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
            }
            self.startTimer(total: 45) { [weak self] in await self?.handleL3Timeout() }
            self.observeCoordinatorVOState(coordinator: newCoordinator)
        }
    }

    /// Polls coordinator for VoiceOver-off event and mirrors it onto the ViewModel.
    ///
    /// ## Concurrency
    /// Runs in a `Task` isolated to `@MainActor`. Exits on cancellation or flag set.
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

    /// Retries L3 — creates a fresh session and restarts the 45 s timer.
    func retryTimed() {
        advanceToTimed()
    }

    // MARK: - Resonance alignment (ADR-0003)

    /// Updates scroll alignment from the vertical delta between the moonstone and the aim line.
    ///
    /// Called from `iOSDungeonResonancePlayView` on each preference-driven geometry change.
    /// `screenshotScene` launches skip updates so deterministic captures keep VM-forced reachability.
    ///
    /// ## Concurrency
    /// Must run on the main actor in lockstep with SwiftUI layout; the view calls this from
    /// `onPreferenceChange` on the main thread.
    func updateResonanceDelta(_ deltaPoints: CGFloat) {
        guard screenshotScene == nil else { return }
        if completedResult != nil { return }
        switch phase {
        case .firstAttempt, .rising:
            if levelComplete { return }
        default:
            break
        }
        targetIsReachable = iOSResonanceAlignment.isReachable(deltaPoints: deltaPoints)
        let band = iOSResonanceAlignment.questBand(deltaPoints: deltaPoints)
        if band != lastResonanceFeedbackBand {
            lastResonanceFeedbackBand = band
            questFeedbackCoordinator.process(.alignmentBandChanged(band))
            RA11yLogger.scrollInteraction.debug(
                "ViewModel alignment band→\(String(describing: band)) reachable=\(self.targetIsReachable) vo=\(UIAccessibility.isVoiceOverRunning)"
            )
            #if DEBUG
            print("[RA11yScroll] ViewModel band→\(band) reachable=\(self.targetIsReachable)")
            #endif
        }
    }

    /// Fires multimodal feedback when the VoiceOver scroll proxy snaps to another lane item.
    ///
    /// ## Concurrency
    /// Must run on the main actor with SwiftUI; the play view invokes this from scroll offset updates.
    func notifyResonanceLaneSlotChanged() {
        guard screenshotScene == nil else { return }
        if completedResult != nil { return }
        switch phase {
        case .firstAttempt, .rising, .timed:
            questFeedbackCoordinator.process(.laneSlotChanged)
        default:
            break
        }
    }

    /// Clears resonance feedback reducer state when room sets or phases change.
    private func resetResonanceAlignmentState() {
        lastResonanceFeedbackBand = nil
        questFeedbackCoordinator.reset()
    }

    // MARK: - Room Activation

    /// Handles activation of the target room for the current level.
    ///
    /// L1/L2: marks level complete and announces completion.
    /// L3: records time-bucket mistakes, completes `GameSession`, navigates to result.
    func activateTarget(_ room: DungeonRoom) async {
        guard room.isTarget, targetIsReachable else {
            if room.isTarget && !targetIsReachable {
                statusMessage = String(localized: "dungeon.target.notReachable")
                announce(String(localized: "dungeon.target.notReachable"))
            }
            return
        }
        guard !levelComplete, !l2TimedOut, !l3TimedOut else { return }

        switch phase {
        case .prologue:
            break

        case .firstAttempt:
            questFeedbackCoordinator.process(.success)
            levelComplete = true
            announce(String(localized: "dungeon.l1.complete"))

        case .rising:
            stopTimer()
            questFeedbackCoordinator.process(.success)
            levelComplete = true
            announce(String(localized: "dungeon.l2.complete"))

        case .timed:
            guard let session else { return }
            stopTimer()

            // Compute elapsed from the 45 s L3 window and record time-bucket penalty mistakes.
            // Bucket size for this game is 15 s per `GameSpec-ScrollHunt.txt`:
            // 0–15 s → +0; 15–30 s → +1; 30–45 s → +2.
            let elapsed = 45.0 - timeRemaining
            let buckets = RankThresholds.bucketMistakes(timeSeconds: elapsed, bucketSize: 15)
            for _ in 0..<buckets {
                try? await session.recordMistake()
            }

            do {
                try await session.complete()
                coordinator?.stopMonitoring()
                questFeedbackCoordinator.process(.success)
                announce(String(localized: "dungeon.l3.success"))
                if case .completed(let result) = await session.state {
                    completedResult = result
                }
            } catch {
                RA11yLogger.gameSession.error("L3 session complete failed: \(error.localizedDescription)")
            }
        }
    }

    /// Handles activation of a non-target room (decoy).
    ///
    /// Increments the mistake counter, announces feedback, emits quest multimodal wrong-activation
    /// feedback (when not in a screenshot scene), and records the mistake
    /// against the L3 `GameSession` if one is running.
    func activateNonTarget(_ room: DungeonRoom) async {
        guard !room.isTarget else { return }
        guard !levelComplete, !l2TimedOut, !l3TimedOut else { return }

        mistakes += 1
        statusMessage = String(localized: "dungeon.feedback.non_target")
        announce(String(localized: "dungeon.feedback.non_target"))
        if screenshotScene == nil {
            questFeedbackCoordinator.process(.wrongActivation)
        }

        if phase == .timed, let session {
            do { try await session.recordMistake() } catch { /* session in non-running state */ }
        }
    }

    /// Announces the resonance alignment hint to VoiceOver and as a visible status message.
    ///
    /// Copy is intentionally Moonstone-and-orb alignment only; room asset names are not part of this hint.
    func requestHint() {
        let message = String(localized: "dungeon.resonance.hint")
        statusMessage = message
        guard screenshotScene == nil else { return }
        questFeedbackCoordinator.process(.hintRequested)
        announce(message)
    }

    /// Announces the level objective to VoiceOver on screen load.
    ///
    /// A 500 ms delay prevents the announcement from being swallowed by the navigation
    /// transition focus announcement.
    func announceObjectivePrompt() {
        guard screenshotScene == nil else { return }
        let message: String
        switch phase {
        case .firstAttempt:
            message = String(localized: "dungeon.a11y.l1.objective")
        case .rising:
            message = String(localized: "dungeon.a11y.l2.objective")
        case .timed:
            message = String(format: String(localized: "dungeon.a11y.l3.timer"), Int(timeRemaining))
        case .prologue:
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(500))
            self.announce(message)
        }
    }

    // MARK: - Private: Timer

    /// Starts a countdown timer for `total` seconds, calling `onTimeout` when it expires.
    ///
    /// ## Concurrency
    /// Runs in a `@MainActor`-isolated `Task`. Uses `[weak self]` on every iteration to
    /// avoid retaining the ViewModel in long-running tasks.
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

                // Final 5 s countdown (shared)
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
        announce(String(localized: "dungeon.timeout"))
    }

    private func handleL3Timeout() async {
        guard let session else { return }
        l3TimedOut = true
        coordinator?.stopMonitoring()
        await session.abandon()
        announce(String(localized: "dungeon.timeout"))
        // Synthesise a Defeated result for display (not stored — session was abandoned).
        completedResult = GameResult(
            gameID: "scroll-hunt",
            rank: .failed,
            timeSeconds: 45.0,
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
        resetResonanceAlignmentState()
        practiceScrollObserved = false
        rooms = []
        targetIsReachable = false
        statusMessage = nil
        mistakes = 0
        levelComplete = false
        timeRemaining = 0
        l2TimedOut = false
        l3TimedOut = false
        completedResult = nil
        voiceOverDisabledMidGame = false

        switch scene {
        case .dungeonPrologue:
            phase = .prologue
            practiceScrollObserved = true
            resonanceInitialLaneIndexOverride = nil
        case .dungeonFirstAttempt:
            phase = .firstAttempt
            rooms = DungeonRoom.l1Rooms
            targetIsReachable = true
            resonanceInitialLaneIndexOverride = rooms.firstIndex(where: \.isTarget)
        default:
            resonanceInitialLaneIndexOverride = nil
            break
        }
    }

    /// Posts the game-specific timer threshold announcement for the given phase and **percent elapsed**.
    ///
    /// `pct` is the fraction of total time that has **elapsed** (not remaining):
    /// - `0.25` elapsed → ~75% remains → soft start cue ("Timer running.")
    /// - `0.50` elapsed → 50% remains → mid-game warning ("Half time left.")
    /// - `0.75` elapsed → ~25% remains → urgent warning ("One quarter left.")
    ///
    /// L2 announces only at 50% and 25% elapsed; L3 announces at all three thresholds.
    private func announceTimerThreshold(for phase: Phase, pct: Double) {
        switch (phase, pct) {
        case (.timed, 0.75):
            announce(String(localized: "dungeon.a11y.timer.75pct"))
        case (.timed, 0.50), (.rising, 0.50):
            announce(String(localized: "dungeon.a11y.timer.50pct"))
        case (.timed, 0.25), (.rising, 0.25):
            announce(String(localized: "dungeon.a11y.timer.25pct"))
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

// MARK: - DungeonRoom

/// One vertical slot in the resonance lane (scene art and icon assets).
///
/// The scroll game is **alignment**: move the Moonstone glyph to the orb. `displayName` exists for
/// catalog / Lights Off copy, not as a navigation metaphor in VO—player-facing objectives use alignment strings.
/// Exactly one room per level has `isTarget`; the rest are visual decoys.
struct DungeonRoom: Identifiable {
    let id: String
    let displayName: String
    let subtitle: String
    let assetName: String
    let isTarget: Bool

    // MARK: - Room Pools

    /// L1: 4 rooms (2 visible, 2 below fold). Guard Room is target at index 2.
    static let l1Rooms: [DungeonRoom] = [
        DungeonRoom(id: "entry_hall",   displayName: "Entry Hall",   subtitle: "Torchlit. Safe.",        assetName: "dungeon_room_entry_hall",  isTarget: false),
        DungeonRoom(id: "armory",       displayName: "Armory",       subtitle: "Empty racks.",            assetName: "dungeon_room_armory",      isTarget: false),
        DungeonRoom(id: "guard_room",   displayName: "Guard Room",   subtitle: "Empty. The objective.",  assetName: "dungeon_room_guard_post",  isTarget: true),
        DungeonRoom(id: "well_chamber", displayName: "Well Chamber", subtitle: "The water is still.",    assetName: "dungeon_room_well_chamber", isTarget: false),
    ]

    /// L2: 8 rooms (3 visible, 5 below fold). Relic Vault is target at index 6.
    static let l2Rooms: [DungeonRoom] = [
        DungeonRoom(id: "entry_hall",   displayName: "Entry Hall",   subtitle: "Torchlit.",              assetName: "dungeon_room_entry_hall",    isTarget: false),
        DungeonRoom(id: "guard_post",   displayName: "Guard Post",   subtitle: "Abandoned.",             assetName: "dungeon_room_guard_post",    isTarget: false),
        DungeonRoom(id: "armory",       displayName: "Armory",       subtitle: "Empty racks.",           assetName: "dungeon_room_armory",        isTarget: false),
        DungeonRoom(id: "well_chamber", displayName: "Well Chamber", subtitle: "The water is still.",   assetName: "dungeon_room_well_chamber",  isTarget: false),
        DungeonRoom(id: "store_room",   displayName: "Store Room",   subtitle: "Dusty barrels.",        assetName: "dungeon_room_store_room",    isTarget: false),
        DungeonRoom(id: "barracks",     displayName: "Barracks",     subtitle: "Cold hearths.",          assetName: "dungeon_room_barracks",      isTarget: false),
        DungeonRoom(id: "relic_vault",  displayName: "Relic Vault",  subtitle: "The objective.",        assetName: "dungeon_room_relic_vault",   isTarget: true),
        DungeonRoom(id: "trophy_room",  displayName: "Trophy Room",  subtitle: "Faded banners.",        assetName: "dungeon_room_trophy_room",   isTarget: false),
    ]

    /// L3: 12 rooms (3 visible, 9 below fold). Ancient Vault is target at index 10.
    static let l3Rooms: [DungeonRoom] = [
        DungeonRoom(id: "entry_hall",      displayName: "Entry Hall",      subtitle: "Torchlit.",                        assetName: "dungeon_room_entry_hall",      isTarget: false),
        DungeonRoom(id: "guard_post",      displayName: "Guard Post",      subtitle: "Abandoned.",                       assetName: "dungeon_room_guard_post",      isTarget: false),
        DungeonRoom(id: "armory",          displayName: "Armory",          subtitle: "Empty racks.",                     assetName: "dungeon_room_armory",          isTarget: false),
        DungeonRoom(id: "well_chamber",    displayName: "Well Chamber",    subtitle: "The water is still.",             assetName: "dungeon_room_well_chamber",    isTarget: false),
        DungeonRoom(id: "store_room",      displayName: "Store Room",      subtitle: "Dusty barrels.",                  assetName: "dungeon_room_store_room",      isTarget: false),
        DungeonRoom(id: "barracks",        displayName: "Barracks",        subtitle: "Cold hearths.",                    assetName: "dungeon_room_barracks",        isTarget: false),
        DungeonRoom(id: "trophy_room",     displayName: "Trophy Room",     subtitle: "Faded banners.",                  assetName: "dungeon_room_trophy_room",     isTarget: false),
        DungeonRoom(id: "ritual_chamber",  displayName: "Ritual Chamber",  subtitle: "Symbols cover the walls.",        assetName: "dungeon_room_ritual_chamber",  isTarget: false),
        DungeonRoom(id: "flooded_hall",    displayName: "Flooded Hall",    subtitle: "Knee-deep water.",                assetName: "dungeon_room_flooded_hall",    isTarget: false),
        DungeonRoom(id: "bone_room",       displayName: "Bone Room",       subtitle: "Don't look too closely.",         assetName: "dungeon_room_bone_room",       isTarget: false),
        DungeonRoom(id: "ancient_vault",   displayName: "Ancient Vault",   subtitle: "The relic glows.",               assetName: "dungeon_room_ancient_vault",   isTarget: true),
        DungeonRoom(id: "collapsed_wall",  displayName: "Collapsed Wall",  subtitle: "A gap you can pass.",            assetName: "dungeon_room_collapsed_wall",  isTarget: false),
    ]

    // MARK: - Lane randomization (Moonstone slot + vertical order)

    /// Returns a copy of `base` with exactly one random Moonstone row and **shuffled** vertical order.
    ///
    /// Used for L1–L3 during normal play so repeat runs cannot rely on memorized shaft positions.
    static func randomizedRoomsPreservingPool(_ base: [DungeonRoom]) -> [DungeonRoom] {
        let targetIndex = Int.random(in: base.indices)
        let objectiveSubtitle = String(localized: "dungeon.room.objective.subtitle")
        let mapped = base.enumerated().map { i, room -> DungeonRoom in
            let isTarget = i == targetIndex
            let subtitle: String
            if isTarget {
                subtitle = objectiveSubtitle
            } else {
                switch room.id {
                case "guard_room":
                    subtitle = String(localized: "dungeon.l1.guardRoom.decoySubtitle")
                case "relic_vault":
                    subtitle = String(localized: "dungeon.room.relicVault.decoySubtitle")
                case "ancient_vault":
                    subtitle = String(localized: "dungeon.room.ancientVault.decoySubtitle")
                default:
                    subtitle = room.subtitle
                }
            }
            return DungeonRoom(
                id: room.id,
                displayName: room.displayName,
                subtitle: subtitle,
                assetName: room.assetName,
                isTarget: isTarget
            )
        }
        return mapped.shuffled()
    }
}

// MARK: - L0: DungeonPrologueView

/// L0 Prologue — Guide narration, lesson card, gesture guide, practice scroll zone, begin trial.
///
/// Used when the view model is launched with `-screenshotScene dungeonPrologue` or if L0 is
/// reintroduced as an optional path. The begin trial button is disabled until the player has
/// performed at least one non-zero scroll event in the practice zone.
private struct DungeonPrologueView: View {

    let practiceScrollObserved: Bool
    let onPracticeScroll: () -> Void
    let onBeginTrial: () -> Void

    var body: some View {
        QuestPaintScreen(
            ambientImageName: "dungeon_descent_bg",
            layoutRole: .lesson,
            gameKind: .scrollHunt
        ) {
            VStack(spacing: RA11ySpacing.lg) {
                QuestNarrationCard(text: String(localized: "dungeon.explain.narration"))
                QuestVoiceOverGestureSpellPlate.moonstoneScrollLesson()
                QuestPracticeCard(
                    tipText: String(localized: "dungeon.explain.practice_tip"),
                    stepTexts: (0..<8).map { String(format: String(localized: "dungeon.explain.practice.step"), $0 + 1) },
                    scrollAccessibilityLabel: String(localized: "dungeon.a11y.scroll.container"),
                    scrollAccessibilityHint: String(localized: "dungeon.a11y.explain.practice.hint"),
                    scrollAccessibilityIdentifier: "dungeon.practiceZone",
                    containerAccessibilityIdentifier: "dungeon.prologue.practiceSection",
                    isReady: practiceScrollObserved,
                    readyText: String(localized: "dungeon.prologue.practice.ready"),
                    onNonZeroScroll: onPracticeScroll
                )
                QuestPrologueActionBar(
                    title: String(localized: "level.button.start"),
                    hint: String(localized: "dungeon.explain.start.hint"),
                    identifier: "dungeon.beginDescent",
                    isEnabled: practiceScrollObserved,
                    action: onBeginTrial
                )
            }
            .padding(.vertical, RA11ySpacing.md)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - DungeonTimerHUD

/// Combined timer progress bar + time + mistake count HUD used in L2 and L3.
///
/// `accessibilityHidden` — the containing play view sets a combined `accessibilityLabel`
/// on the whole HUD group. The bar height decreases at 50% and 25% remaining.
///
/// ## Dynamic Type
/// Bar height scales with `.subheadline` via `@ScaledMetric`.
/// At `.accessibility4`+ the label row switches to `VStack` so the timer and mistake
/// count don't crowd each other in the ~200 pt available width.
struct DungeonTimerHUD: View {

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
        HStack(spacing: RA11ySpacing.xs) {
            Image(systemName: "clock")
                .foregroundStyle(Color.white.opacity(0.72))
            Text(String(format: String(localized: "hud.timer.format"), Int(ceil(timeRemaining))))
                .questPaintReadableText(.materialCardMeta)
        }
    }

    private var mistakesLabel: some View {
        Text(String(format: String(localized: "dungeon.hud.mistakes.format"), mistakes))
            .questPaintReadableText(.materialCardMeta)
    }
}

// MARK: - Shared Primitive Subviews

/// Small gesture guide row used in L0 prologue.
private struct DungeonGestureRow: View {
    let symbol: String
    let label: String

    var body: some View {
        HStack(spacing: RA11ySpacing.md) {
            Image(systemName: symbol)
                .font(.ra11yHeadline)
                .frame(minWidth: 32, alignment: .leading)
                .foregroundStyle(Color.ra11yCardTertiaryText)
            Text(label)
                .questPaintReadableText(.bodySupporting)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview("L1 First Attempt") {
    NavigationStack {
        iOSDungeonDescentView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
