import Observation
import OSLog
import SwiftUI
import UIKit
import RA11yCore

// MARK: - Banishment phase

/// High-level progression for The Banishment (greybox: SF Symbols, escape-first).
enum BanishmentPhase: Equatable {
    case prologue
    /// Practice trap — two-finger scrub only; hints visible.
    case wardTrap
    /// Post-ward beat before the timed run.
    case wardIntermission
    /// Timed gauntlet: index 0..<towerThreats.count
    case tower(Int)
    /// Lights Off–style finale; same escape contract, minimal chrome.
    case darkTower
}

// MARK: - Threat model (placeholder art)

/// Single “creature” beat — SF Symbol until catalog art ships.
struct BanishmentThreat: Identifiable, Equatable {
    let id: String
    let symbolName: String
    /// Spoken name for VoiceOver (plain language).
    let spokenName: String
}

// MARK: - BanishmentQuestViewModel

/// Drives The Banishment: practice ward, timed tower sequence, Lights Off capstone.
///
/// **VoiceOver:** The scrub target is the combined instruction block (and the full-screen trap
/// root) with ``AccessibilityAction/escape``—no decoy / fake buttons.
/// Short, themed lines are posted in sequence without fixed delays; ``performBanishEscape()``
/// cancels any optional queued work and advances the run immediately (skippable pace).
///
/// **Timers (Enchanter-style):** The scored act uses a **separate** countdown **per** tower
/// encounter and for the one dark act; segment budgets sum to
/// ``RankThresholds.banishment`` `timeoutSeconds` (one ``GameSession`` for the run).
///
/// ## Concurrency
/// `@MainActor` — matches SwiftUI observation and `GameSessionCoordinator`.
@Observable
@MainActor
final class BanishmentQuestViewModel {

    private(set) var phase: BanishmentPhase = .prologue
    private(set) var mistakes: Int = 0
    /// Countdown for the **current** scored segment (Enchanter-style per-beat).
    private(set) var timeRemaining: Double = 0
    private(set) var statusMessage: String?
    private(set) var timedOut: Bool = false
    private(set) var completedResult: GameResult?
    private(set) var voiceOverDisabledMidGame: Bool = false

    private var session: GameSession?
    private var coordinator: GameSessionCoordinator?
    private var timerTask: Task<Void, Never>?
    /// Wall time when the running ``GameSession`` was started; used for timeout ``GameResult`` and alignment with the actor.
    private var scoredSessionStart: Date?
    /// Start of the current scored **segment** (each tower threat + the dark act).
    private var segmentDeadlineStart: Date?
    /// True from the first line of ``completeScoredRun()`` until it finishes, so ``handleViewDisappear()`` will not
    /// schedule ``abandon()`` concurrently with ``session.complete()`` (that race could invalidate complete).
    private var isCommittingScoredRunCompletion: Bool = false

    private let storage: any StorageComponent

    private static let wardThreat = BanishmentThreat(
        id: "ward_rat",
        symbolName: "hare.fill",
        spokenName: String(localized: "banishment.threat.ward.spoken")
    )

    private static let towerThreats: [BanishmentThreat] = [
        BanishmentThreat(id: "tower_rat", symbolName: "hare.fill", spokenName: String(localized: "banishment.threat.rat.spoken")),
        BanishmentThreat(id: "tower_golem", symbolName: "shield.lefthalf.filled", spokenName: String(localized: "banishment.threat.golem.spoken")),
        BanishmentThreat(id: "tower_wisp", symbolName: "sparkles", spokenName: String(localized: "banishment.threat.wisp.spoken")),
    ]

    private static let darkThreat = BanishmentThreat(
        id: "dark_shade",
        symbolName: "moon.stars.fill",
        spokenName: String(localized: "banishment.threat.dark.spoken")
    )

    /// Per-encounter segment lengths (seconds) for the scored act. Must sum to ``RankThresholds/banishment`` `timeoutSeconds`.
    private static let towerSegmentSeconds: [Double] = [14, 14, 14]
    private static let darkSegmentSeconds: Double = 13
    /// `timeoutSeconds` in ``RankThresholds/banishment`` (sum of segments).
    private static var scoredActTotalCap: Double {
        Self.towerSegmentSeconds.reduce(0, +) + Self.darkSegmentSeconds
    }

    init(storage: any StorageComponent) {
        self.storage = storage
    }

    var isLightsOffPhase: Bool {
        if case .darkTower = phase { return true }
        return false
    }

    var showsTimedHUD: Bool {
        switch phase {
        case .tower, .darkTower: return true
        default: return false
        }
    }

    var currentThreat: BanishmentThreat? {
        switch phase {
        case .wardTrap: return Self.wardThreat
        case .tower(let i):
            guard i >= 0, i < Self.towerThreats.count else { return nil }
            return Self.towerThreats[i]
        case .darkTower: return Self.darkThreat
        default: return nil
        }
    }

    var showsTrapHint: Bool {
        if case .wardTrap = phase { return true }
        return false
    }

    func beginTrial() {
        phase = .wardTrap
        statusMessage = nil
        announce(String(localized: "banishment.a11y.approach"))
        announceThreatArrival()
    }

    func continueAfterWard() {
        phase = .wardIntermission
        statusMessage = String(localized: "banishment.ward.cleared")
    }

    /// Starts the scored session + countdown after the player leaves the ward.
    func beginScoredGauntlet() {
        phase = .tower(0)
        mistakes = 0
        timedOut = false
        completedResult = nil
        statusMessage = nil
        timeRemaining = 0
        voiceOverDisabledMidGame = false
        scoredSessionStart = nil
        segmentDeadlineStart = nil

        let newSession = GameSession(
            gameID: "the-banishment",
            thresholds: .banishment,
            storage: storage
        )
        let newCoordinator = GameSessionCoordinator(
            session: newSession,
            gameKind: .banishment,
            voiceOverProvider: iOSLiveVoiceOverStateProvider()
        )
        session = newSession
        coordinator = newCoordinator

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let startDate = Date()
                try await newSession.start(at: startDate)
                self.scoredSessionStart = startDate
            } catch {
                RA11yLogger.gameSession.error("Banishment session start failed: \(error.localizedDescription)")
                return
            }
            newCoordinator.startMonitoring()
            self.observeCoordinatorVOState(coordinator: newCoordinator)
            if UIAccessibility.isVoiceOverRunning {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
            }
            self.restartScoredSegmentTimer()
            self.startScoredCountdown()
        }
        announceThreatArrival()
    }

    /// VoiceOver two-finger scrub / escape — dismisses the active trap when allowed.
    /// Cancels any soft-queued work and advances **immediately** (skippable pace).
    func performBanishEscape() {
        if isCommittingScoredRunCompletion || completedResult != nil {
            RA11yLogger.banishment.debug("performBanishEscape ignored — isCommitting=\(self.isCommittingScoredRunCompletion) hasResult=\(self.completedResult != nil) — \(RA11yLogger.startupTimestampTag())")
            return
        }
        switch phase {
        case .wardTrap:
            let done = currentThreat
            if let name = done?.spokenName {
                announce(String(format: String(localized: "banishment.feedback.banishedNamed"), name))
            } else {
                announce(String(localized: "banishment.feedback.banished"))
            }
            continueAfterWard()
        case .tower(let index):
            let banished = currentThreat
            if index + 1 < Self.towerThreats.count {
                phase = .tower(index + 1)
                if let n = banished?.spokenName {
                    announce(String(format: String(localized: "banishment.feedback.banishedNamed"), n))
                }
                announceThreatArrival()
                restartScoredSegmentTimer()
            } else {
                phase = .darkTower
                if let n = banished?.spokenName {
                    announce(String(format: String(localized: "banishment.feedback.banishedNamed"), n))
                }
                announce(String(localized: "banishment.feedback.enterDark"))
                announceThreatArrival()
                restartScoredSegmentTimer()
            }
        case .darkTower:
            isCommittingScoredRunCompletion = true
            if let n = currentThreat?.spokenName {
                announce(String(format: String(localized: "banishment.feedback.banishedNamed"), n))
            }
            RA11yLogger.banishment.info("darkTower banish → completeScoredRun (commit flag set sync) — \(RA11yLogger.startupTimestampTag())")
            Task { await self.completeScoredRun() }
        default:
            break
        }
    }

    func handleViewDisappear() {
        stopScoredCountdown()
        coordinator?.stopMonitoring()
        if isCommittingScoredRunCompletion {
            RA11yLogger.banishment.debug("handleViewDisappear: skip abandon (session completing) — \(RA11yLogger.startupTimestampTag())")
            return
        }
        guard let session else { return }
        RA11yLogger.banishment.info("handleViewDisappear: abandon phase=\(String(describing: self.phase)) — \(RA11yLogger.startupTimestampTag())")
        Task { await session.abandon() }
    }

    // MARK: - Private

    /// Speaks who appeared and how to banish (Z scrub / escape) in one announcement.
    private func announceThreatArrival() {
        guard let threat = currentThreat else { return }
        let format = String(localized: "banishment.a11y.encounterAnnouncement")
        announce(String(format: format, threat.spokenName))
    }

    private func completeScoredRun() async {
        /// Commit flag is set synchronously in ``performBanishEscape()`` (dark) before this `Task` is created.
        defer { isCommittingScoredRunCompletion = false }
        RA11yLogger.banishment.info("completeScoredRun begin — \(RA11yLogger.startupTimestampTag())")
        stopScoredCountdown()
        guard let session else {
            RA11yLogger.banishment.error("completeScoredRun: no session — \(RA11yLogger.startupTimestampTag())")
            return
        }
        coordinator?.stopMonitoring()
        do {
            try await session.complete()
            if case .completed(let result) = await session.state {
                completedResult = result
                RA11yLogger.banishment.info("completeScoredRun success rank=\(result.rank.displayText) time=\(result.timeSeconds) — \(RA11yLogger.startupTimestampTag())")
            } else {
                RA11yLogger.banishment.error("completeScoredRun: state not completed after success — \(RA11yLogger.startupTimestampTag())")
            }
        } catch {
            let desc = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            RA11yLogger.banishment.error("completeScoredRun failed: \(desc) — \(RA11yLogger.startupTimestampTag())")
        }
    }

    private func handleTimeout() async {
        guard let session else { return }
        timedOut = true
        stopScoredCountdown()
        coordinator?.stopMonitoring()
        await session.abandon()
        announce(String(localized: "banishment.timeout"))
        let start = scoredSessionStart ?? Date()
        let elapsed = min(Date().timeIntervalSince(start), Self.scoredActTotalCap + 0.01)
        completedResult = GameResult(
            gameID: "the-banishment",
            rank: .failed,
            timeSeconds: elapsed,
            mistakes: mistakes
        )
    }

    /// Resets the visible countdown to the current phase’s **segment** budget and starts a new segment clock.
    private func restartScoredSegmentTimer() {
        switch phase {
        case .tower, .darkTower:
            let dur = segmentDurationForCurrentPhase
            timeRemaining = dur
            segmentDeadlineStart = Date()
        default:
            timeRemaining = 0
            segmentDeadlineStart = nil
        }
    }

    private var segmentDurationForCurrentPhase: Double {
        switch phase {
        case .tower(let i):
            guard i >= 0, i < Self.towerSegmentSeconds.count else { return 0 }
            return Self.towerSegmentSeconds[i]
        case .darkTower:
            return Self.darkSegmentSeconds
        default:
            return 0
        }
    }

    private func startScoredCountdown() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                switch self.phase {
                case .tower, .darkTower:
                    break
                default:
                    continue
                }
                guard self.segmentDurationForCurrentPhase > 0, let start = self.segmentDeadlineStart else { continue }
                let dur = self.segmentDurationForCurrentPhase
                let rem = max(0, dur - Date().timeIntervalSince(start))
                self.timeRemaining = rem
                if rem <= 0 {
                    await self.handleTimeout()
                    break
                }
            }
        }
    }

    private func stopScoredCountdown() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func observeCoordinatorVOState(coordinator: GameSessionCoordinator) {
        Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { return }
                if coordinator.voiceOverDisabledMidGame {
                    self.voiceOverDisabledMidGame = true
                    self.stopScoredCountdown()
                    return
                }
            }
        }
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - iOSBanishmentQuestView

/// The Banishment — teaches VoiceOver’s two-finger scrub escape using SF Symbol greybox UI.
///
/// **VoiceOver:** While a trap is active, the system navigation bar is hidden so the scrub
/// gesture is not delivered to UIKit’s back affordance (which can pop the whole quest).
/// Players leave via ``trapLeaveQuestControl``; the scrub is handled by
/// ``BanishmentTrapOverlay``’s ``accessibilityAction(.escape)``.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSBanishmentQuestView: View {

    @State private var viewModel: BanishmentQuestViewModel
    @Environment(iOSAppRouter.self) private var router

    private let storage: any StorageComponent

    init(storage: any StorageComponent) {
        self.storage = storage
        _viewModel = State(initialValue: BanishmentQuestViewModel(storage: storage))
    }

    var body: some View {
        ZStack {
            background
            mainContent
            if viewModel.currentThreat != nil {
                trapOverlay
                trapLeaveQuestControl
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(viewModel.currentThreat == nil ? .automatic : .hidden, for: .navigationBar)
        .onChange(of: viewModel.completedResult) { _, result in
            guard let result else { return }
            router.push(.gameResult(result, gameKind: .banishment, gameSpecificAnnouncement: announcement(for: result)))
        }
        .onChange(of: viewModel.voiceOverDisabledMidGame) { _, disabled in
            if disabled {
                router.push(.voiceOverInterstitial(kind: .banishment))
            }
        }
        .onDisappear { viewModel.handleViewDisappear() }
    }

    private var navigationTitle: String {
        switch viewModel.phase {
        case .prologue: return String(localized: "banishment.nav.prologue")
        case .wardTrap, .wardIntermission: return String(localized: "banishment.nav.ward")
        case .tower: return String(localized: "banishment.nav.tower")
        case .darkTower: return String(localized: "banishment.nav.dark")
        }
    }

    @ViewBuilder
    private var background: some View {
        if viewModel.isLightsOffPhase {
            Color.black.ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.12),
                    Color(red: 0.05, green: 0.04, blue: 0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.phase {
        case .prologue:
            prologueBody
                .accessibilityIdentifier("banishment.prologue")
        case .wardTrap:
            Color.clear
                .accessibilityHidden(true)
        case .wardIntermission:
            wardIntermissionBody
                .accessibilityIdentifier("banishment.wardIntermission")
        case .tower, .darkTower:
            scoredChrome
                .accessibilityIdentifier("banishment.scored")
        }
    }

    private var prologueBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RA11ySpacing.lg) {
                Label(String(localized: "banishment.prologue.kicker"), systemImage: "hand.draw.fill")
                    .font(.ra11yCaption)
                    .foregroundStyle(.secondary)
                Text(String(localized: "banishment.prologue.title"))
                    .font(.ra11yTitle)
                    .bold()
                Text(String(localized: "banishment.prologue.body"))
                    .font(.ra11yBody)
                    .foregroundStyle(.secondary)
                Button(String(localized: "banishment.prologue.begin")) {
                    viewModel.beginTrial()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("banishment.beginTrial")
            }
            .padding(RA11ySpacing.lg)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private var wardIntermissionBody: some View {
        VStack(spacing: RA11ySpacing.lg) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 56))
                .foregroundStyle(Color.ra11yAccent)
                .accessibilityHidden(true)
            Text(String(localized: "banishment.ward.intermission.title"))
                .font(.ra11yHeadline)
                .multilineTextAlignment(.center)
            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.ra11yBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(String(localized: "banishment.ward.continueGauntlet")) {
                viewModel.beginScoredGauntlet()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("banishment.continueGauntlet")
        }
        .padding(RA11ySpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scoredChrome: some View {
        VStack(spacing: RA11ySpacing.md) {
            if viewModel.showsTimedHUD {
                HStack {
                    Label {
                        Text(String(localized: "banishment.hud.timeRemaining"))
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.ra11yCaption)
                    Spacer()
                    Text(String(format: "%.0f", viewModel.timeRemaining))
                        .font(.ra11yHeadline)
                        .monospacedDigit()
                        .accessibilityLabel(
                            String(format: String(localized: "banishment.a11y.secondsLeft"), Int(ceil(viewModel.timeRemaining)))
                        )
                }
                .padding(RA11ySpacing.md)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
                .padding(.horizontal, RA11ySpacing.lg)
                .accessibilityElement(children: .combine)
            }
            if let msg = viewModel.statusMessage {
                Text(msg)
                    .font(.ra11yCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, RA11ySpacing.md)
    }

    private var trapOverlay: some View {
        BanishmentTrapOverlay(
            threat: viewModel.currentThreat,
            showsHint: viewModel.showsTrapHint,
            isLightsOff: viewModel.isLightsOffPhase,
            onEscape: { viewModel.performBanishEscape() }
        )
        .id(viewModel.currentThreat?.id ?? "banishment.trap.nil")
    }

    /// Explicit exit while the trap hides the system bar (see type-level VoiceOver note).
    private var trapLeaveQuestControl: some View {
        VStack {
            HStack {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.semibold))
                        .padding(RA11ySpacing.sm)
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.isLightsOffPhase ? Color.white.opacity(0.92) : Color.ra11yAccent)
                .accessibilityLabel(String(localized: "result.returnToHub"))
                .accessibilityHint(String(localized: "banishment.leaveQuest.a11yHint"))
                .accessibilityIdentifier("banishment.leaveQuest")
                Spacer()
            }
            .padding(.horizontal, RA11ySpacing.md)
            .padding(.top, RA11ySpacing.xs)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func announcement(for result: GameResult) -> String {
        switch result.rank {
        case .perfect: return String(localized: "banishment.results.legendary")
        case .good: return String(localized: "banishment.results.skilled")
        case .ok: return String(localized: "banishment.results.novice")
        case .failed: return String(localized: "banishment.results.defeated")
        }
    }
}

// MARK: - Trap overlay

/// Full-screen trap presented like a **popup encounter** (card animates in; VO announces arrival).
///
/// Expects the hosting screen to hide the system navigation bar during traps so the
/// VoiceOver scrub is not handled as a navigation “back” pop.
///
/// **Lights Off:** On-screen scrub copy is hidden; the instruction card’s accessibility label
/// carries the Z-scrub banish line, and ``banishment.a11y.encounterAnnouncement`` is announced
/// when the trap appears.
private struct BanishmentTrapOverlay: View {
    let threat: BanishmentThreat?
    let showsHint: Bool
    let isLightsOff: Bool
    let onEscape: () -> Void

    @State private var encounterPresents: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(isLightsOff ? 0.92 : 0.78)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: RA11ySpacing.xl) {
                if let threat {
                    threatPortrait(for: threat)
                    encounterCard(for: threat)
                }
            }
            .padding(RA11ySpacing.xl)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, onEscape)
        .accessibilityIdentifier("banishment.trap.root")
        .onAppear(perform: playEncounterEntrance)
        .onChange(of: threat?.id) { _, _ in
            playEncounterEntrance()
        }
    }

    @ViewBuilder
    private func threatPortrait(for threat: BanishmentThreat) -> some View {
        Image(systemName: threat.symbolName)
            .font(.system(size: 72))
            .foregroundStyle(isLightsOff ? Color.white.opacity(0.85) : Color.ra11yAccent)
            .accessibilityHidden(true)
            .scaleEffect(encounterPresents ? 1 : 0.88)
            .opacity(encounterPresents ? 1 : 0)
    }

    @ViewBuilder
    private func encounterCard(for threat: BanishmentThreat) -> some View {
        VStack(spacing: RA11ySpacing.sm) {
            Text(String(localized: "banishment.trap.encounterKicker"))
                .font(.ra11yCaption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
            Text(
                String(
                    format: String(localized: "banishment.trap.creatureAppears"),
                    threat.spokenName
                )
            )
            .font(.ra11yTitle)
            .bold()
            .multilineTextAlignment(.center)
            if showsHint {
                Text(String(localized: "banishment.trap.hint"))
                    .font(.ra11yBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(RA11ySpacing.lg)
        .background(.thinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
        .compositingGroup()
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        .offset(y: encounterPresents ? 0 : 22)
        .scaleEffect(encounterPresents ? 1 : 0.94, anchor: .center)
        .opacity(encounterPresents ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityInstructionLabel(threat: threat))
        .accessibilityHint(
            isLightsOff
                ? String(localized: "banishment.a11y.lightsOffTrapHint")
                : String(localized: "banishment.trap.escape.hint")
        )
        .accessibilityAction(.escape, onEscape)
    }

    private func playEncounterEntrance() {
        encounterPresents = false
        withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
            encounterPresents = true
        }
    }

    private func accessibilityInstructionLabel(threat: BanishmentThreat) -> String {
        if isLightsOff {
            return String(format: String(localized: "banishment.a11y.trapLightsOffCombined"), threat.spokenName)
        }
        let base = String(format: String(localized: "banishment.a11y.trapCombined"), threat.spokenName)
        if showsHint {
            return "\(base) \(String(localized: "banishment.trap.hint"))"
        }
        return base
    }
}

#Preview {
    NavigationStack {
        iOSBanishmentQuestView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
