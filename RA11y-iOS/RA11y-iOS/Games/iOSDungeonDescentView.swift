import Observation
import os
import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSDungeonDescentView

/// Container for The Dungeon Descent (Scroll Hunt) — M7.
///
/// Implements the full 4-level game arc defined in `GameSpec-ScrollHunt.txt`
/// and `GameRules-MVP.txt`:
///
/// - **L0 Prologue**: DM narration + "Descending the Dungeon" lesson + gesture guide +
///   required practice scroll area + "Begin Descent"
/// - **L1 First Attempt**: 4 rooms, no timer — teaches 3-finger scroll via Guard Room
/// - **L2 Rising Challenge**: 8 rooms, 60 s soft timer — Relic Vault as target
/// - **L3 Timed Trial**: 12 rooms, 45 s hard timer; `GameSession` started here for scoring
///
/// Only L3 creates a `GameSession`. Scroll observability uses `onScrollGeometryChange`
/// (iOS 18+ native API, validated in S1 spike) to detect whether the target room is visible.
/// Target activation is gated on `targetIsReachable` to enforce the scroll requirement.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSDungeonDescentView: View {

    // MARK: - State

    @State private var viewModel: DungeonDescentViewModel

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router

    // MARK: - Init

    /// Creates the Dungeon game container.
    ///
    /// - Parameters:
    ///   - storage: Persistence used for L3 session results during normal gameplay.
    ///   - screenshotScene: Optional deterministic screenshot scene override.
    init(storage: any StorageComponent, screenshotScene: iOSScreenshotScene? = nil) {
        _viewModel = State(
            initialValue: DungeonDescentViewModel(storage: storage, screenshotScene: screenshotScene)
        )
    }

    // MARK: - Body

    /// See `iOSEnchantersTrialView` for the rationale for using `.background {}` over ZStack.
    var body: some View {
        levelContent
            .background {
                DungeonBackgroundView()
                    .ignoresSafeArea()
            }
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
            DungeonPlayView(
                rooms: viewModel.rooms,
                targetIsReachable: viewModel.targetIsReachable,
                statusMessage: viewModel.statusMessage,
                levelComplete: viewModel.levelComplete,
                timeRemaining: nil,
                timedOut: false,
                mistakes: viewModel.mistakes,
                onUpdateReachability: { visible, frame in
                    viewModel.updateTargetReachability(visibleRect: visible, targetFrame: frame)
                },
                onActivateTarget: { room in await viewModel.activateTarget(room) },
                onActivateNonTarget: { room in await viewModel.activateNonTarget(room) },
                onHint: nil,
                onContinue: { viewModel.advanceToRising() },
                onRetry: nil
            )
            .navigationTitle(String(localized: "dungeon.l1.title"))
            .onAppear { viewModel.announceObjectivePrompt() }
            .accessibilityIdentifier("dungeon.firstAttempt")
            .transition(.identity)

        case .rising:
            DungeonPlayView(
                rooms: viewModel.rooms,
                targetIsReachable: viewModel.targetIsReachable,
                statusMessage: viewModel.statusMessage,
                levelComplete: viewModel.levelComplete,
                timeRemaining: viewModel.timeRemaining,
                timedOut: viewModel.l2TimedOut,
                mistakes: viewModel.mistakes,
                onUpdateReachability: { visible, frame in
                    viewModel.updateTargetReachability(visibleRect: visible, targetFrame: frame)
                },
                onActivateTarget: { room in await viewModel.activateTarget(room) },
                onActivateNonTarget: { room in await viewModel.activateNonTarget(room) },
                onHint: { viewModel.requestHint() },
                onContinue: { viewModel.advanceToTimed() },
                onRetry: { viewModel.retryRising() }
            )
            .navigationTitle(String(localized: "dungeon.l2.title"))
            .onAppear { viewModel.announceObjectivePrompt() }
            .accessibilityIdentifier("dungeon.rising")
            .transition(.identity)

        case .timed:
            DungeonPlayView(
                rooms: viewModel.rooms,
                targetIsReachable: viewModel.targetIsReachable,
                statusMessage: viewModel.statusMessage,
                levelComplete: false,  // L3 routes via completedResult, not levelComplete
                timeRemaining: viewModel.timeRemaining,
                timedOut: viewModel.l3TimedOut,
                mistakes: viewModel.mistakes,
                onUpdateReachability: { visible, frame in
                    viewModel.updateTargetReachability(visibleRect: visible, targetFrame: frame)
                },
                onActivateTarget: { room in await viewModel.activateTarget(room) },
                onActivateNonTarget: { room in await viewModel.activateNonTarget(room) },
                onHint: { viewModel.requestHint() },
                onContinue: nil,
                onRetry: { viewModel.retryTimed() }
            )
            .navigationTitle(String(localized: "dungeon.l3.title"))
            .onAppear { viewModel.announceObjectivePrompt() }
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

/// Observable view model managing the Dungeon Descent 4-level state machine.
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

    // MARK: - Init

    /// Creates the Dungeon view model.
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

    /// Records that the player has scrolled in the L0 practice zone.
    func recordPracticeScroll() {
        practiceScrollObserved = true
    }

    /// Transitions L0 → L1: 4-room dungeon, no timer.
    func beginTrial() {
        stopTimer()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        targetIsReachable = false
        rooms = DungeonRoom.l1Rooms
        phase = .firstAttempt
    }

    /// Transitions L1 → L2: 8-room dungeon with 60 s soft timer.
    func advanceToRising() {
        stopTimer()
        mistakes = 0
        statusMessage = nil
        levelComplete = false
        l2TimedOut = false
        targetIsReachable = false
        rooms = DungeonRoom.l2Rooms
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
        mistakes = 0
        statusMessage = nil
        l3TimedOut = false
        completedResult = nil
        voiceOverDisabledMidGame = false
        targetIsReachable = false
        rooms = DungeonRoom.l3Rooms
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

    // MARK: - Scroll Observability

    /// Updates the `targetIsReachable` flag from the latest scroll geometry.
    ///
    /// Called from the level view whenever either the visible rect or the target frame changes.
    /// A null `targetFrame` (pre-layout) is treated as not-yet-reachable.
    func updateTargetReachability(visibleRect: CGRect, targetFrame: CGRect) {
        guard !targetFrame.isNull else {
            targetIsReachable = false
            return
        }
        targetIsReachable = visibleRect.intersects(targetFrame)
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
            levelComplete = true
            announce(String(localized: "dungeon.l1.complete"))

        case .rising:
            stopTimer()
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
    /// Increments the mistake counter, announces feedback, and records the mistake
    /// against the L3 `GameSession` if one is running.
    func activateNonTarget(_ room: DungeonRoom) async {
        guard !room.isTarget else { return }
        guard !levelComplete, !l2TimedOut, !l3TimedOut else { return }

        mistakes += 1
        statusMessage = String(localized: "dungeon.feedback.non_target")
        announce(String(localized: "dungeon.feedback.non_target"))

        if phase == .timed, let session {
            do { try await session.recordMistake() } catch { /* session in non-running state */ }
        }
    }

    /// Announces the scroll hint to VoiceOver and as a visible status message.
    func requestHint() {
        let targetName = rooms.first(where: \.isTarget)?.displayName ?? "the target"
        let message = String(format: String(localized: "dungeon.hint.format"), targetName)
        statusMessage = message
        guard screenshotScene == nil else { return }
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
        case .dungeonFirstAttempt:
            phase = .firstAttempt
            rooms = DungeonRoom.l1Rooms
            targetIsReachable = true
        default:
            break
        }
    }

    /// Posts the game-specific timer threshold announcement for the given phase and percent elapsed.
    ///
    /// L2 announces only at 50% and 25%; L3 announces at 75%, 50%, and 25%.
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

/// A single room in the Dungeon Descent dungeon.
///
/// Passage rooms (isTarget) are correct targets; all others are non-interactive decoys.
/// Level-specific room sets are defined in `l1Rooms`, `l2Rooms`, `l3Rooms`.
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
}

// MARK: - L0: DungeonPrologueView

/// L0 Prologue — DM narration, lesson card, gesture guide, practice scroll zone, Begin Descent.
///
/// The "Begin Descent" button is disabled until the player has performed at least one
/// non-zero scroll event in the practice zone, enforcing the paradigm-teaching gate.
private struct DungeonPrologueView: View {

    let practiceScrollObserved: Bool
    let onPracticeScroll: () -> Void
    let onBeginTrial: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: RA11ySpacing.lg) {
                dmNarrationCard
                lessonCard
                gestureGuide
                practiceZone
                beginButton
            }
            .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
            .frame(maxWidth: sizeClass == .regular ? 720 : .infinity)
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

            Text(String(localized: "dungeon.explain.narration"))
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
            Text(String(localized: "dungeon.explain.lesson.heading"))
                .font(.ra11yHeadline)
                .bold()
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "dungeon.explain.lesson.body"))
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
        .accessibilityLabel(String(localized: "dungeon.a11y.explain.lesson"))
    }

    private var gestureGuide: some View {
        VStack(spacing: RA11ySpacing.sm) {
            DungeonGestureRow(symbol: "hand.point.right.fill", label: String(localized: "dungeon.explain.gesture.swipe1"))
            DungeonGestureRow(symbol: "hand.draw.fill",        label: String(localized: "dungeon.explain.gesture.swipe3"))
            DungeonGestureRow(symbol: "hand.draw.fill",        label: String(localized: "dungeon.explain.gesture.swipe3u"))
        }
        .accessibilityHidden(true)
    }

    private var practiceZone: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "dungeon.explain.practice_tip"))
                .font(.ra11ySubheadline)
                .foregroundStyle(.secondary)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
                    ForEach(0..<14, id: \.self) { index in
                        Text(String(format: String(localized: "dungeon.explain.practice.step"), index + 1))
                            .font(.ra11yBody)
                            .foregroundStyle(Color.ra11yCardSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }
                .padding(RA11ySpacing.sm)
            }
            .frame(minHeight: 200, maxHeight: 280)
            .background(Color.black.opacity(0.35), in: .rect(cornerRadius: RA11yRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RA11yRadius.card)
                    .strokeBorder(Color.ra11yAccent.opacity(0.55), lineWidth: 1)
            )
            .accessibilityLabel(String(localized: "dungeon.a11y.scroll.container"))
            .accessibilityHint(String(localized: "dungeon.a11y.explain.practice.hint"))
            .accessibilityIdentifier("dungeon.practiceZone")
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, offsetY in
                if abs(offsetY) > 2 { onPracticeScroll() }
            }

            if practiceScrollObserved {
                Text(String(localized: "dungeon.prologue.practice.ready"))
                    .font(.ra11yCaption)
                    .foregroundStyle(Color.ra11yCardTertiaryText)
            }
        }
        .padding(RA11ySpacing.base)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
        .accessibilityIdentifier("dungeon.prologue.practiceSection")
    }

    private var beginButton: some View {
        Button(action: onBeginTrial) {
            Text(String(localized: "level.button.start"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .disabled(!practiceScrollObserved)
        .accessibilityHint(String(localized: "dungeon.explain.start.hint"))
        .accessibilityIdentifier("dungeon.beginDescent")
    }
}

// MARK: - DungeonPlayView (L1 / L2 / L3)

/// Unified play view for L1, L2, and L3 of the Dungeon Descent.
///
/// The scroll container is wrapped in a named coordinate space so that preference key
/// updates from `DungeonRoomRow` cells are comparable to the scroll geometry's `visibleRect`.
///
/// Timer and hint affordances are conditionally shown based on whether a `timeRemaining`
/// value is provided (L1 has none; L2/L3 have a timer). `onHint` and `onContinue` are
/// optional — L3 uses neither (it routes via `completedResult`).
///
/// ## Scroll Observability
/// `TargetRoomFramePreferenceKey` bubbles the target room's frame (in the named coordinate
/// space) up to this view. `onScrollGeometryChange` provides the `visibleRect` in the same
/// space. Both are forwarded to `onUpdateReachability` so the ViewModel can compute
/// `targetIsReachable`.
private struct DungeonPlayView: View {

    let rooms: [DungeonRoom]
    let targetIsReachable: Bool
    let statusMessage: String?
    let levelComplete: Bool
    let timeRemaining: Double?      // nil = no timer (L1)
    let timedOut: Bool
    let mistakes: Int
    let onUpdateReachability: (CGRect, CGRect) -> Void
    let onActivateTarget: (DungeonRoom) async -> Void
    let onActivateNonTarget: (DungeonRoom) async -> Void
    let onHint: (() -> Void)?       // nil = no hint button (L1)
    let onContinue: (() -> Void)?   // nil = no continue button (L3)
    let onRetry: (() -> Void)?      // non-nil when level has a timer

    @State private var targetFrame: CGRect = .null
    @State private var visibleRect: CGRect = .zero

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: RA11ySpacing.base) {
                objectiveCard

                if let total = timeTotal, let remaining = timeRemaining {
                    DungeonTimerHUD(timeRemaining: remaining, total: total, mistakes: mistakes)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(timerA11yLabel)
                        .accessibilityHint(String(localized: "a11y.timer.group.hint"))
                }

                if timedOut {
                    timeoutBanner
                } else {
                    roomList

                    if let statusMessage { dungeonStatusRow(statusMessage) }

                    if levelComplete, let onContinue {
                        continueButton(onContinue)
                    } else if !levelComplete, let onHint {
                        hintButton(onHint)
                    }
                }
            }
            .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
            .frame(maxWidth: sizeClass == .regular ? 720 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .coordinateSpace(name: DungeonCoordinateSpace.name)
        .accessibilityLabel(String(localized: "dungeon.a11y.scroll.container"))
        .accessibilityHint(String(localized: "dungeon.a11y.scroll.container.hint"))
        .onPreferenceChange(TargetRoomFrameKey.self) { frame in
            targetFrame = frame
            onUpdateReachability(visibleRect, frame)
        }
        .onScrollGeometryChange(for: CGRect.self, of: { $0.visibleRect }) { _, newVisible in
            visibleRect = newVisible
            onUpdateReachability(newVisible, targetFrame)
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Subviews

    private var objectiveCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
            Label(String(localized: "dm.label"), systemImage: "scroll.fill")
                .font(.ra11yCaption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(objectiveText)
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
        .accessibilityLabel(objectiveA11yLabel)
        .accessibilityHint(String(localized: "dungeon.a11y.l1.objective.hint"))
    }

    private var roomList: some View {
        VStack(spacing: RA11ySpacing.sm) {
            ForEach(rooms) { room in
                DungeonRoomRow(
                    room: room,
                    isTargetReachable: targetIsReachable,
                    onActivateTarget:    { Task { await onActivateTarget(room) } },
                    onActivateNonTarget: { Task { await onActivateNonTarget(room) } }
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TargetRoomFrameKey.self,
                            value: room.isTarget
                                ? proxy.frame(in: .named(DungeonCoordinateSpace.name))
                                : .null
                        )
                    }
                )
            }
        }
    }

    private var timeoutBanner: some View {
        VStack(spacing: RA11ySpacing.md) {
            Text(String(localized: "dungeon.timeout"))
                .font(.ra11yHeadline)
                .multilineTextAlignment(.center)
            if let onRetry {
                Button(action: onRetry) {
                    Text(String(localized: "level.button.retry"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color.ra11yAccent)
                .accessibilityIdentifier("dungeon.retry")
            }
        }
        .padding(RA11ySpacing.base)
    }

    private func hintButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(String(localized: "dungeon.hint.button"), systemImage: "ear.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "dungeon.hint.a11yLabel"))
        .accessibilityHint(String(localized: "dungeon.hint.a11yHint"))
    }

    private func continueButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(String(localized: "level.button.next"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .accessibilityIdentifier("dungeon.continue")
    }

    // MARK: - Helpers

    private var objectiveText: String {
        switch rooms.count {
        case DungeonRoom.l1Rooms.count: return String(localized: "dungeon.l1.objective")
        case DungeonRoom.l2Rooms.count: return String(localized: "dungeon.l2.objective")
        default:                        return String(localized: "dungeon.l3.objective")
        }
    }

    private var objectiveA11yLabel: String {
        switch rooms.count {
        case DungeonRoom.l1Rooms.count: return String(localized: "dungeon.a11y.l1.objective")
        case DungeonRoom.l2Rooms.count: return String(localized: "dungeon.a11y.l2.objective")
        default:                        return String(localized: "dungeon.a11y.l3.objective")
        }
    }

    private var timerA11yLabel: String {
        guard let remaining = timeRemaining else { return "" }
        return String(format: String(localized: "dungeon.a11y.l3.timer"), Int(ceil(remaining)))
    }

    private var timeTotal: Double? {
        switch rooms.count {
        case DungeonRoom.l2Rooms.count: return 60
        case DungeonRoom.l3Rooms.count: return 45
        default: return nil
        }
    }
}

// MARK: - DungeonRoomRow

/// Row card representing one dungeon room.
///
/// Target rooms are rendered as a `Button` (with `.isButton` trait) so VoiceOver
/// announces the "double-tap to activate" affordance. Non-target rooms are static
/// accessibility elements with no button trait, suppressing activation affordance.
///
/// ## Adaptive Layout
/// - Standard (`dynamicTypeSize < .accessibility2`): `HStack` — icon | title/subtitle | status
/// - Large accessibility sizes: icon + status in a leading `HStack`, title/subtitle below
///
/// The room-name text has no hard `lineLimit` so it can expand to as many lines as
/// needed; both `DungeonRoomIcon` and the status symbol use `@ScaledMetric`-driven
/// sizes so they remain proportional to the surrounding text.
private struct DungeonRoomRow: View {

    let room: DungeonRoom
    let isTargetReachable: Bool
    let onActivateTarget: () -> Void
    let onActivateNonTarget: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isLargeAccessibilitySize: Bool { dynamicTypeSize >= .accessibility2 }

    var body: some View {
        if room.isTarget {
            baseRow
                .accessibilityIdentifier("dungeon.room.\(room.id)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(room.displayName). The objective.")
                .accessibilityHint(String(localized: "dungeon.room.target.hint"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onActivateTarget() }
                .onTapGesture { onActivateTarget() }
        } else {
            baseRow
                .accessibilityIdentifier("dungeon.room.\(room.id)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(room.displayName). \(room.subtitle)")
                .accessibilityHint(String(localized: "dungeon.room.nonTarget.hint"))
                .onTapGesture { onActivateNonTarget() }
        }
    }

    private var baseRow: some View {
        Group {
            if isLargeAccessibilitySize {
                largeTypeLayout
            } else {
                standardLayout
            }
        }
        .padding(RA11ySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3), in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(Color.ra11yAccent.opacity(room.isTarget ? 0.8 : 0.25), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    /// Standard HStack layout for default through `.accessibility1` Dynamic Type.
    private var standardLayout: some View {
        HStack(spacing: RA11ySpacing.base) {
            DungeonRoomIcon(assetName: room.assetName)

            VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
                Text(room.displayName)
                    .font(.ra11yHeadline)
                    .foregroundStyle(Color.ra11yCardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(room.subtitle)
                    .font(.ra11ySubheadline)
                    .foregroundStyle(Color.ra11yCardTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            statusIcon
        }
    }

    /// VStack layout for `.accessibility2` and above — prevents horizontal crowding.
    private var largeTypeLayout: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            HStack(spacing: RA11ySpacing.base) {
                DungeonRoomIcon(assetName: room.assetName)
                Spacer()
                statusIcon
            }

            Text(room.displayName)
                .font(.ra11yHeadline)
                .foregroundStyle(Color.ra11yCardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(room.subtitle)
                .font(.ra11ySubheadline)
                .foregroundStyle(Color.ra11yCardTertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if room.isTarget {
            Image(systemName: isTargetReachable ? "checkmark.seal" : "lock.fill")
                .foregroundStyle(isTargetReachable ? Color.ra11yTargetReachable : Color.ra11yAccent)
        }
    }
}

// MARK: - DungeonRoomIcon

/// Asset-backed room icon with SF Symbol fallback.
///
/// ## Dynamic Type
/// Icon dimensions scale with the `.title` text style (base 72 pt, max 120 pt) using
/// `@ScaledMetric` so the icon remains proportional to the adjacent room-name text.
private struct DungeonRoomIcon: View {
    let assetName: String

    /// Scales with `.title` style; capped at 120 pt to prevent outsized icons.
    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 72

    private var clampedSize: CGFloat { min(iconSize, 120) }

    var body: some View {
        if let image = UIImage(named: assetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: clampedSize, height: clampedSize)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "shield.lefthalf.filled")
                .font(.ra11yTitle)
                .fontWeight(.semibold)
                .foregroundStyle(Color.ra11yAccent)
                .frame(width: clampedSize, height: clampedSize)
                .accessibilityHidden(true)
        }
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
private struct DungeonTimerHUD: View {

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
    }

    private var mistakesLabel: some View {
        Text(String(format: String(localized: "dungeon.hud.mistakes.format"), mistakes))
            .font(.ra11ySubheadline)
            .foregroundStyle(.secondary)
    }
}

// MARK: - DungeonBackgroundView

/// Full-bleed dungeon background with dark overlay for legibility.
private struct DungeonBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black
            if let image = UIImage(named: "dungeon_descent_bg") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.4))
            }
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.15), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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
                .font(.ra11yBody)
                .foregroundStyle(Color.ra11yCardSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Status feedback row shown after a room activation event.
private func dungeonStatusRow(_ message: String) -> some View {
    Text(message)
        .font(.ra11ySubheadline)
        .foregroundStyle(Color.ra11yCardSecondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RA11ySpacing.xs)
}

// MARK: - Scroll Geometry Support

/// Preference key carrying the target room frame in the named scroll coordinate space.
private struct TargetRoomFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isNull { value = next }
    }
}

/// Names the coordinate space used to align `ScrollGeometry.visibleRect` and target frames.
private enum DungeonCoordinateSpace {
    static let name = "dungeonScroll"
}

// MARK: - Preview

#Preview("L0 Prologue") {
    NavigationStack {
        iOSDungeonDescentView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
