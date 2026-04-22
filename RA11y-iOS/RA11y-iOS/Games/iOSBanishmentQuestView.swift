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
/// **VoiceOver:** Wrong decoys are separate buttons; the scrub target is the combined
/// instruction block (and the full-screen trap root) with ``AccessibilityAction/escape``.
/// Each trap posts ``announceThreatArrival()`` — a single announcement naming the encounter
/// and the two-finger Z scrub (escape) so Lights Off play does not depend on on-screen copy.
///
/// ## Concurrency
/// `@MainActor` — matches SwiftUI observation and `GameSessionCoordinator`.
/// Delayed announcement tasks are cancelled in ``handleViewDisappear()`` so pops/timeouts
/// do not speak stale encounter lines.
@Observable
@MainActor
final class BanishmentQuestViewModel {

    private(set) var phase: BanishmentPhase = .prologue
    private(set) var mistakes: Int = 0
    /// Countdown during scored phases (`RankThresholds.banishment.timeoutSeconds`).
    private(set) var timeRemaining: Double = 0
    private(set) var statusMessage: String?
    private(set) var timedOut: Bool = false
    private(set) var completedResult: GameResult?
    private(set) var voiceOverDisabledMidGame: Bool = false

    private var session: GameSession?
    private var coordinator: GameSessionCoordinator?
    private var timerTask: Task<Void, Never>?
    /// Chains a follow-up ``UIAccessibility.post(notification: .announcement, …)`` after VO finishes a prior line.
    private var pendingAnnouncementTask: Task<Void, Never>?

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

    /// Must match ``RankThresholds/banishment`` `timeoutSeconds`.
    private static let scoredDuration: Double = 55

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
        timeRemaining = Self.scoredDuration
        voiceOverDisabledMidGame = false

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
                try await newSession.start()
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
            self.startScoredTimer()
        }
        announceThreatArrival()
    }

    /// VoiceOver two-finger scrub / escape — dismisses the active trap when allowed.
    func performBanishEscape() {
        switch phase {
        case .wardTrap:
            announce(String(localized: "banishment.feedback.banished"))
            continueAfterWard()
        case .tower(let index):
            if index + 1 < Self.towerThreats.count {
                phase = .tower(index + 1)
                announceBanishedThenEncounterArrival()
            } else {
                phase = .darkTower
                announceEnterDarkThenEncounterArrival()
            }
        case .darkTower:
            Task { await self.completeScoredRun() }
        default:
            break
        }
    }

    func wrongDecoyTapped() {
        switch phase {
        case .wardTrap:
            statusMessage = String(localized: "banishment.feedback.wrong.ward")
            announce(String(localized: "banishment.feedback.wrong.ward"))
        case .tower, .darkTower:
            mistakes += 1
            statusMessage = String(localized: "banishment.feedback.wrong.decoy")
            announce(String(localized: "a11y.level.mistake"))
            if let session {
                Task { try? await session.recordMistake() }
            }
        default:
            break
        }
    }

    func handleViewDisappear() {
        cancelPendingAnnouncementTask()
        stopTimer()
        coordinator?.stopMonitoring()
        guard let session else { return }
        Task { await session.abandon() }
    }

    // MARK: - Private

    /// Speaks who appeared and how to banish (Z scrub / escape) in one announcement.
    private func announceThreatArrival() {
        guard let threat = currentThreat else { return }
        let format = String(localized: "banishment.a11y.encounterAnnouncement")
        announce(String(format: format, threat.spokenName))
    }

    private func announceBanishedThenEncounterArrival() {
        announce(String(localized: "banishment.feedback.banished"))
        scheduleAnnouncement(afterSeconds: 0.85) { [weak self] in
            self?.announceThreatArrival()
        }
    }

    private func announceEnterDarkThenEncounterArrival() {
        announce(String(localized: "banishment.feedback.enterDark"))
        scheduleAnnouncement(afterSeconds: 1.2) { [weak self] in
            self?.announceThreatArrival()
        }
    }

    private func cancelPendingAnnouncementTask() {
        pendingAnnouncementTask?.cancel()
        pendingAnnouncementTask = nil
    }

    /// Schedules a MainActor announcement after a delay so VoiceOver does not truncate the prior line.
    private func scheduleAnnouncement(afterSeconds delay: TimeInterval, _ body: @escaping @MainActor () -> Void) {
        cancelPendingAnnouncementTask()
        pendingAnnouncementTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            body()
            pendingAnnouncementTask = nil
        }
    }

    private func completeScoredRun() async {
        stopTimer()
        guard let session else { return }
        coordinator?.stopMonitoring()
        do {
            try await session.complete()
            if case .completed(let result) = await session.state {
                completedResult = result
            }
        } catch {
            RA11yLogger.gameSession.error("Banishment complete failed: \(error.localizedDescription)")
        }
    }

    private func handleTimeout() async {
        cancelPendingAnnouncementTask()
        guard let session else { return }
        timedOut = true
        stopTimer()
        coordinator?.stopMonitoring()
        await session.abandon()
        announce(String(localized: "banishment.timeout"))
        let elapsed = Self.scoredDuration
        completedResult = GameResult(
            gameID: "the-banishment",
            rank: .failed,
            timeSeconds: elapsed,
            mistakes: mistakes
        )
    }

    private func startScoredTimer() {
        timerTask?.cancel()
        let total = Self.scoredDuration
        timerTask = Task { @MainActor [weak self] in
            let startDate = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                let elapsed = Date().timeIntervalSince(startDate)
                self.timeRemaining = max(0, total - elapsed)
                if self.timeRemaining <= 0 {
                    await self.handleTimeout()
                    break
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func observeCoordinatorVOState(coordinator: GameSessionCoordinator) {
        Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { return }
                if coordinator.voiceOverDisabledMidGame {
                    self.cancelPendingAnnouncementTask()
                    self.voiceOverDisabledMidGame = true
                    self.stopTimer()
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
            onEscape: { viewModel.performBanishEscape() },
            onWrongDecoy: { viewModel.wrongDecoyTapped() }
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
/// The **“false seal”** button is a deliberate wrong path: it records a lesson beat (ward
/// feedback or scored **mistake**) if the player double-taps a plausible but incorrect control
/// instead of using **escape** / the two-finger scrub. Keep it for transfer to real
/// “tap everything” habits under stress.
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
    let onWrongDecoy: () -> Void

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
                    decoyButton
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
            let headline = String(
                format: String(localized: "banishment.trap.creatureAppears"),
                threat.spokenName
            )
            Text(headline)
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

    private var decoyButton: some View {
        Button(String(localized: "banishment.trap.decoyButton")) {
            onWrongDecoy()
        }
        .buttonStyle(.bordered)
        .offset(y: encounterPresents ? 0 : 12)
        .opacity(encounterPresents ? 1 : 0)
        .accessibilityIdentifier("banishment.decoy")
        .accessibilityHint(String(localized: "banishment.trap.decoy.hint"))
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
