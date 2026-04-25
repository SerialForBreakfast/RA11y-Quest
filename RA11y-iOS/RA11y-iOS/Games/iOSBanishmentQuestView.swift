import Observation
import OSLog
import SwiftUI
import UIKit
import RA11yCore

// MARK: - Banishment phase

/// High-level progression for The Banishment (creature art: asset catalog or SF Symbol fallback; escape-first).
enum BanishmentPhase: Equatable {
    case prologue
    /// Practice trap — two-finger scrub only; hints visible.
    case wardTrap
    /// Post-ward beat before the timed run.
    case wardIntermission
    /// Timed gauntlet: index 0..<towerThreats.count
    case tower(Int)
    /// **Lights Off** finale: same escape contract; visuals blacked out—player must rely on VoiceOver and the scrub.
    case darkTower
}

// MARK: - Threat model (placeholder art)

/// Single creature beat — raster from ``iOSBanishmentArt`` when the imageset exists, else SF Symbol greybox.
struct BanishmentThreat: Identifiable, Equatable {
    let id: String
    /// SF Symbol name used when ``catalogImageName`` is missing from the asset catalog.
    let symbolName: String
    /// Asset catalog imageset name (see ``iOSBanishmentArt``); must match `DesignTicket-BanishmentPromptSheet`.
    let catalogImageName: String
    /// Spoken name for VoiceOver (plain language).
    let spokenName: String
}

// MARK: - BanishmentQuestViewModel

/// Drives The Banishment: practice ward, timed tower sequence, then **Lights Off** (``BanishmentPhase/darkTower``)
/// as the final proof-of-knowledge encounter—blackout visuals, same Z-scrub contract.
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
    /// Increments on every successful escape banish so the view can flash ``iOSBanishmentArt.flareEscape`` (creature-agnostic).
    private(set) var banishFlareTick: Int = 0

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

    /// When set, the view model skips live session/timer setup and renders a frozen phase for ``iOSScreenshotScene`` capture.
    private let screenshotScene: iOSScreenshotScene?

    private static let wardThreat = BanishmentThreat(
        id: "ward_goblin",
        symbolName: "figure.run",
        catalogImageName: iOSBanishmentArt.banishmentGoblin,
        spokenName: String(localized: "banishment.threat.goblin.spoken")
    )

    /// Spoken name of the practice-ward creature — used in intermission copy (`%@ banished`).
    var wardPracticeSpokenName: String { Self.wardThreat.spokenName }

    private static let towerThreats: [BanishmentThreat] = [
        BanishmentThreat(
            id: "tower_skeleton",
            symbolName: "skull.fill",
            catalogImageName: iOSBanishmentArt.banishmentSkeleton,
            spokenName: String(localized: "banishment.threat.skeleton.spoken")
        ),
        BanishmentThreat(
            id: "tower_orc",
            symbolName: "shield.lefthalf.filled",
            catalogImageName: iOSBanishmentArt.banishmentOrc,
            spokenName: String(localized: "banishment.threat.orc.spoken")
        ),
        BanishmentThreat(
            id: "tower_troll",
            symbolName: "hammer.fill",
            catalogImageName: iOSBanishmentArt.banishmentTroll,
            spokenName: String(localized: "banishment.threat.troll.spoken")
        ),
    ]

    private static let darkThreat = BanishmentThreat(
        id: "dark_dragon",
        symbolName: "flame.fill",
        catalogImageName: iOSBanishmentArt.banishmentDragon,
        spokenName: String(localized: "banishment.threat.dragon.spoken")
    )

    /// Per-encounter segment lengths (seconds) for the scored act. Must sum to ``RankThresholds/banishment`` `timeoutSeconds`.
    private static let towerSegmentSeconds: [Double] = [14, 14, 14]
    private static let darkSegmentSeconds: Double = 13
    /// `timeoutSeconds` in ``RankThresholds/banishment`` (sum of segments).
    private static var scoredActTotalCap: Double {
        Self.towerSegmentSeconds.reduce(0, +) + Self.darkSegmentSeconds
    }

    /// Creates the Banishment view model.
    ///
    /// - Parameters:
    ///   - storage: Persistence for scored runs.
    ///   - screenshotScene: Optional deterministic phase for fastlane screenshot automation (no ``GameSession``).
    init(storage: any StorageComponent, screenshotScene: iOSScreenshotScene? = nil) {
        self.storage = storage
        self.screenshotScene = screenshotScene
        if let screenshotScene {
            applyScreenshotScene(screenshotScene)
        }
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
        // Intermission title uses `banishment.ward.intermission.title` (`%@ banished. …`); keep status line empty to avoid duplicate copy.
        statusMessage = nil
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
            banishFlareTick += 1
            let done = currentThreat
            if let name = done?.spokenName {
                announce(String(format: String(localized: "banishment.feedback.banishedNamed"), name))
            } else {
                announce(String(localized: "banishment.feedback.banished"))
            }
            continueAfterWard()
        case .tower(let index):
            banishFlareTick += 1
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
            banishFlareTick += 1
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

    /// Forces a stable phase and HUD for `-screenshotScene` launches (no async session work).
    private func applyScreenshotScene(_ scene: iOSScreenshotScene) {
        stopScoredCountdown()
        session = nil
        coordinator = nil
        scoredSessionStart = nil
        segmentDeadlineStart = nil
        mistakes = 0
        timedOut = false
        completedResult = nil
        statusMessage = nil
        voiceOverDisabledMidGame = false
        isCommittingScoredRunCompletion = false
        banishFlareTick = 0

        switch scene {
        case .banishmentPrologue:
            phase = .prologue
            timeRemaining = 0
        case .banishmentWardTrap:
            phase = .wardTrap
            timeRemaining = 0
        case .banishmentTower:
            phase = .tower(0)
            timeRemaining = 12
        default:
            phase = .prologue
            timeRemaining = 0
        }
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
///
/// **Mockup bootstrap:** Landscape PNGs from ``utility/import_banishment_mockups_to_assets`` are detected and skipped
/// for full-bleed backgrounds and trap rasters so UI does not paint a device frame inside the real device.
struct iOSBanishmentQuestView: View {

    @State private var viewModel: BanishmentQuestViewModel
    @Environment(iOSAppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Opacity for creature-agnostic ``iOSBanishmentArt.flareEscape`` (driven by ``BanishmentQuestViewModel/banishFlareTick``).
    @State private var banishFlareOpacity: Double = 0

    private let storage: any StorageComponent

    /// - Parameter screenshotScene: When non-`nil`, renders a deterministic phase for fastlane (see ``iOSScreenshotRootView``).
    init(storage: any StorageComponent, screenshotScene: iOSScreenshotScene? = nil) {
        self.storage = storage
        _viewModel = State(initialValue: BanishmentQuestViewModel(storage: storage, screenshotScene: screenshotScene))
    }

    var body: some View {
        ZStack {
            background
            mainContent
            if viewModel.currentThreat != nil {
                trapOverlay
                trapLeaveQuestControl
            }
            banishFlareOverlay
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
        .onChange(of: viewModel.banishFlareTick) { _, _ in
            playBanishFlareFeedback()
        }
        .onDisappear { viewModel.handleViewDisappear() }
        .preferredColorScheme(.dark)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    private var navigationTitle: String {
        switch viewModel.phase {
        case .prologue: return String(localized: "banishment.nav.prologue")
        case .wardTrap, .wardIntermission: return String(localized: "banishment.nav.ward")
        case .tower: return String(localized: "banishment.nav.tower")
        case .darkTower: return String(localized: "banishment.nav.lightsOff")
        }
    }

    @ViewBuilder
    private var background: some View {
        if viewModel.isLightsOffPhase {
            ZStack {
                Color.black
                if Self.shouldUseRasterBackground(named: iOSBanishmentArt.towerBackground) {
                    Image(iOSBanishmentArt.towerBackground)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                        .accessibilityHidden(true)
                        .opacity(0.14)
                }
            }
            .ignoresSafeArea()
        } else if Self.useWardSceneBackground(for: viewModel.phase) {
            banishmentSceneBackground(assetName: iOSBanishmentArt.wardBackground)
        } else {
            banishmentSceneBackground(assetName: iOSBanishmentArt.towerBackground)
        }
    }

    /// Practice and intermission use the ward master; timed gauntlet uses the tower master (`BanishmentAssetPipeline`).
    private static func useWardSceneBackground(for phase: BanishmentPhase) -> Bool {
        switch phase {
        case .prologue, .wardTrap, .wardIntermission: return true
        case .tower, .darkTower: return false
        }
    }

    @ViewBuilder
    private func banishmentSceneBackground(assetName: String) -> some View {
        if Self.shouldUseRasterBackground(named: assetName) {
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .clipped()
        } else {
            banishmentFallbackGradient
        }
    }

    private var banishmentFallbackGradient: some View {
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

    /// Portrait masters read as *taller-than-wide*; landscape phone mockups with device frames fail this check
    /// and fall back to ``banishmentFallbackGradient`` until replaced with portrait masters (see asset pipeline).
    ///
    /// **Screenshot automation:** Uses the same policy as interactive play so Fastlane captures match App Store art.
    private static func shouldUseRasterBackground(named name: String) -> Bool {
        guard let image = UIImage(named: name) else { return false }
        return isPortraitOrSquareFullBleedCandidate(image)
    }

    /// `true` when catalog PNGs are safe to composite (final art). Mockup-derived sprites are usually landscape.
    ///
    /// **Screenshot automation:** Same as ``shouldUseRasterBackground(named:)`` — trap ring, creatures, and flare
    /// render in UI tests when assets pass aspect-ratio heuristics.
    private static func shouldUseRasterTrapDecorations() -> Bool {
        if !isPortraitOrSquareFullBleedCandidate(UIImage(named: iOSBanishmentArt.wardBackground)) { return false }
        if !isPortraitOrSquareFullBleedCandidate(UIImage(named: iOSBanishmentArt.towerBackground)) { return false }
        let threatKeys = [
            iOSBanishmentArt.banishmentGoblin,
            iOSBanishmentArt.banishmentSkeleton,
            iOSBanishmentArt.banishmentOrc,
            iOSBanishmentArt.banishmentTroll,
            iOSBanishmentArt.banishmentDragon,
        ]
        for key in threatKeys {
            if let im = UIImage(named: key), !isLikelyCreatureSpriteRaster(im) { return false }
        }
        if let flare = UIImage(named: iOSBanishmentArt.flareEscape), !isLikelySquareSpriteRaster(flare) { return false }
        return true
    }

    private static func isPortraitOrSquareFullBleedCandidate(_ image: UIImage?) -> Bool {
        guard let image else { return true }
        let w = image.size.width
        let h = image.size.height
        guard h > 1 else { return true }
        return w <= h * 1.08
    }

    private static func isLikelyCreatureSpriteRaster(_ image: UIImage) -> Bool {
        let w = image.size.width
        let h = image.size.height
        guard h > 1 else { return false }
        return w <= h * 1.25
    }

    private static func isLikelySquareSpriteRaster(_ image: UIImage) -> Bool {
        let w = image.size.width
        let h = image.size.height
        guard h > 1 else { return false }
        let ratio = max(w, h) / min(w, h)
        return ratio <= 1.35
    }

    /// Centered banish burst (``banishFlarePoints``); **straight alpha** only — no `.screen` / `.plusLighter`,
    /// which over the trap stack can read as checkerboard in screenshots.
    @ViewBuilder
    private var banishFlareOverlay: some View {
        if Self.shouldUseRasterTrapDecorations(),
           UIImage(named: iOSBanishmentArt.flareEscape) != nil
        {
            Image(iOSBanishmentArt.flareEscape)
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: Self.banishFlarePoints, height: Self.banishFlarePoints)
                .opacity(banishFlareOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Escape flare diameter in points; align with ``BanishmentAssetPipeline`` when resizing art.
    private static let banishFlarePoints: CGFloat = 220

    private func playBanishFlareFeedback() {
        guard Self.shouldUseRasterTrapDecorations(),
              UIImage(named: iOSBanishmentArt.flareEscape) != nil
        else { return }
        if accessibilityReduceMotion {
            banishFlareOpacity = 0.95
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                banishFlareOpacity = 0
            }
            return
        }
        banishFlareOpacity = 0
        withAnimation(.easeOut(duration: 0.12)) {
            banishFlareOpacity = 1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.easeIn(duration: 0.18)) {
                banishFlareOpacity = 0
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.phase {
        case .prologue:
            prologueBody
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
            VStack(alignment: .center, spacing: RA11ySpacing.lg) {
                Text(String(localized: "banishment.prologue.title"))
                    .multilineTextAlignment(.center)
                    .questPaintReadableText(.heroTitle)
                    .accessibilityIdentifier("banishment.prologue.title")
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "banishment.prologue.body"))
                    .multilineTextAlignment(.center)
                    .questPaintReadableText(.bodySupporting)
                    .accessibilityIdentifier("banishment.prologue.body")
                Text(String(localized: "banishment.prologue.instructions"))
                    .multilineTextAlignment(.center)
                    .questPaintReadableText(.bodyEmphasis)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("banishment.prologue.instructions")
                banishmentZScrubSpellPlate
                Button(String(localized: "banishment.prologue.begin")) {
                    viewModel.beginTrial()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("banishment.beginTrial")
                .accessibilityHint(String(localized: "banishment.prologue.begin.a11yHint"))
            }
            .padding(.horizontal, RA11ySpacing.lg)
            .padding(.vertical, RA11ySpacing.md)
            .frame(maxWidth: prologueColumnMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.vertical, RA11ySpacing.sm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("banishment.prologue")
    }

    /// Z-scrub “spell card” shared with other quests via ``QuestVoiceOverGestureSpellPlate``; raster or vector fallback.
    private var banishmentZScrubSpellPlate: some View {
        let name = iOSBanishmentArt.gestureZReference
        let fallback: AnyView? = UIImage(named: name) == nil ? AnyView(prologueZGestureFallback) : nil
        return QuestVoiceOverGestureSpellPlate.banishmentZScrubLesson(
            catalogArtName: name,
            catalogArtFallback: fallback
        )
    }

    /// Matches mockup stroke weight when raster art is not yet imported.
    private var prologueZGestureFallback: some View {
        ZStack {
            BanishmentZGestureShape()
                .stroke(
                    Color.black.opacity(0.5),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                )
            BanishmentZGestureShape()
                .stroke(
                    Color.ra11yAccent.opacity(0.98),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color.ra11yAccent.opacity(0.55), radius: 10, y: 3)
        }
        .frame(width: 280, height: 150)
    }

    /// iPad / regular width uses a wider lesson column so screenshots and Dynamic Type do not hug the left edge.
    private var prologueColumnMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 600 : 560
    }

    private var wardIntermissionBody: some View {
        VStack(spacing: RA11ySpacing.lg) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 56))
                .foregroundStyle(Color(red: 0.92, green: 0.72, blue: 0.38))
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                .accessibilityHidden(true)
            Text(String(format: String(localized: "banishment.ward.intermission.title"), viewModel.wardPracticeSpokenName))
                .multilineTextAlignment(.center)
                .questPaintReadableText(.sectionTitle)
            Text(String(localized: "banishment.ward.lightsOffPreview"))
                .multilineTextAlignment(.center)
                .questPaintReadableText(.bodySupporting)
            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .multilineTextAlignment(.center)
                    .questPaintReadableText(.bodySupporting)
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
                    Spacer(minLength: 0)
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
                    .frame(maxWidth: scoredHUDMaxWidth)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, RA11ySpacing.lg)
                .accessibilityElement(children: .combine)
            }
            if case .darkTower = viewModel.phase {
                banishmentLightsOffProofBanner
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

    /// Caps timer strip width on tablet so it does not stretch edge-to-edge in screenshots.
    private var scoredHUDMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 560 : .infinity
    }

    /// **Lights Off (``BanishmentPhase/darkTower``):** Mirrors Crystal Resonance’s `dungeon.lightsOff.flavor` banner—
    /// names the final “proof of knowledge” beat so players see the mode even when creature art is blacked out.
    private var banishmentLightsOffProofBanner: some View {
        HStack(alignment: .top, spacing: RA11ySpacing.sm) {
            Image(systemName: "moon.stars.fill")
                .font(.title3)
                .foregroundStyle(Color(red: 0.92, green: 0.72, blue: 0.38))
                .accessibilityHidden(true)
            Text(String(localized: "banishment.lightsOff.proofBanner"))
                .font(Font.ra11ySubheadline)
                .foregroundStyle(Color.white.opacity(0.92))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(RA11ySpacing.md)
        .frame(maxWidth: scoredHUDMaxWidth)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
        .padding(.horizontal, RA11ySpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(String(localized: "banishment.lightsOff.proofBanner.a11y"))
        .accessibilityIdentifier("banishment.lightsOff.proofBanner")
    }

    private var trapOverlay: some View {
        BanishmentTrapOverlay(
            threat: viewModel.currentThreat,
            showsHint: viewModel.showsTrapHint,
            trapKicker: banishmentTrapKicker,
            isLightsOff: viewModel.isLightsOffPhase,
            useRasterDecorations: Self.shouldUseRasterTrapDecorations(),
            onEscape: { viewModel.performBanishEscape() }
        )
        .id(viewModel.currentThreat?.id ?? "banishment.trap.nil")
    }

    /// Short kicker above the trap headline — practice shows binding-ward context; tower beats stay terse.
    private var banishmentTrapKicker: String {
        switch viewModel.phase {
        case .wardTrap:
            return String(localized: "banishment.trap.kicker.practice")
        case .tower:
            return String(localized: "banishment.trap.kicker.tower")
        case .darkTower:
            return String(localized: "banishment.trap.kicker.dark")
        default:
            return String(localized: "banishment.trap.encounterKicker")
        }
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
    /// Uppercase-style kicker (Practice / Tower / Dark) above the encounter headline.
    let trapKicker: String
    let isLightsOff: Bool
    /// When `false`, skip creature catalog PNGs (e.g. landscape mockup crops that fail sprite heuristics).
    let useRasterDecorations: Bool
    let onEscape: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var encounterPresents: Bool = false

    var body: some View {
        GeometryReader { geo in
            let layout = BanishmentTrapPlayfieldLayout(
                containerSize: geo.size,
                isRegularWidthLayout: horizontalSizeClass == .regular
            )
            ZStack {
                Color.black.opacity(isLightsOff ? 0.92 : 0.78)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: RA11ySpacing.xl) {
                    if let threat {
                        encounterStack(for: threat, layout: layout)
                        encounterCard(for: threat)
                    }
                }
                .padding(RA11ySpacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAction(.escape, onEscape)
            .accessibilityIdentifier("banishment.trap.root")
            .onAppear(perform: playEncounterEntrance)
            .onChange(of: threat?.id) { _, _ in
                playEncounterEntrance()
            }
        }
    }

    /// Hero creature only — Z gesture and ward ring are **prologue-only** until art direction revisits compositing.
    @ViewBuilder
    private func encounterStack(for threat: BanishmentThreat, layout: BanishmentTrapPlayfieldLayout) -> some View {
        ZStack {
            threatPortrait(for: threat, layout: layout)
        }
        .frame(width: layout.clusterWidth, height: layout.clusterHeight)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func threatPortrait(for threat: BanishmentThreat, layout: BanishmentTrapPlayfieldLayout) -> some View {
        let diameter = layout.portraitDiameter(for: threat, isLightsOff: isLightsOff)
        Group {
            if useRasterDecorations,
               let raster = threatRasterName(for: threat),
               let uiRaster = UIImage(named: raster)
            {
                Image(uiImage: uiRaster)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: diameter, height: diameter)
                    .opacity(isLightsOff ? 0.88 : 1)
            } else {
                Image(systemName: threat.symbolName)
                    .font(.system(size: layout.symbolPointSize))
                    .foregroundStyle(isLightsOff ? Color.white.opacity(0.85) : Color.ra11yAccent)
            }
        }
        .accessibilityHidden(true)
        .scaleEffect(encounterPresents ? 1 : 0.88)
        .opacity(encounterPresents ? 1 : 0)
    }

    /// Lights Off: prefer creature art; if missing, optional ``iOSBanishmentArt/darkAnchor``; else SF Symbol.
    private func threatRasterName(for threat: BanishmentThreat) -> String? {
        if UIImage(named: threat.catalogImageName) != nil {
            return threat.catalogImageName
        }
        if isLightsOff, UIImage(named: iOSBanishmentArt.darkAnchor) != nil {
            return iOSBanishmentArt.darkAnchor
        }
        return nil
    }

    @ViewBuilder
    private func encounterCard(for threat: BanishmentThreat) -> some View {
        VStack(spacing: RA11ySpacing.sm) {
            Text(trapKicker)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .questPaintReadableText(.captionGold)
                .accessibilityHidden(true)
            Text(
                String(
                    format: String(localized: "banishment.trap.creatureAppears"),
                    threat.spokenName
                )
            )
            .multilineTextAlignment(.center)
            .font(.system(.title2, design: .serif).weight(.bold))
            .foregroundStyle(Color.white.opacity(0.96))
            if showsHint {
                Text(String(localized: "banishment.trap.hint"))
                    .multilineTextAlignment(.center)
                    .questPaintReadableText(.materialCardBody)
            }
        }
        .padding(RA11ySpacing.lg)
        .background(.thinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
        // Avoid compositingGroup + shadow — on dark trap scrims it can read as grey / transparency artifacts (Crystal shaft note).
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

// MARK: - Trap playfield layout

/// Sizes the creature cluster from the live trap container so foes stay **large** on phone and iPad without hard-coded caps.
private struct BanishmentTrapPlayfieldLayout {
    let clusterWidth: CGFloat
    let clusterHeight: CGFloat
    let basePortraitDiameter: CGFloat
    let symbolPointSize: CGFloat

    init(containerSize: CGSize, isRegularWidthLayout: Bool) {
        let horizontalInset = RA11ySpacing.xl * 2
        let verticalReserve: CGFloat = 300
        let maxW = max(0, containerSize.width - horizontalInset)
        let maxClusterH = max(160, containerSize.height - verticalReserve - RA11ySpacing.xl * 2)
        let widthCap: CGFloat = isRegularWidthLayout ? 560 : 480
        clusterWidth = min(maxW * 0.98, widthCap)
        clusterHeight = min(clusterWidth * 0.98, maxClusterH * 0.95)
        basePortraitDiameter = min(clusterWidth, clusterHeight) * 0.9
        symbolPointSize = min(clusterWidth, clusterHeight) * 0.28
    }

    func portraitDiameter(for threat: BanishmentThreat, isLightsOff: Bool) -> CGFloat {
        let scale: CGFloat = {
            if isLightsOff { return 0.92 }
            switch threat.id {
            case "ward_goblin": return 0.94
            case "tower_troll": return 1
            default: return 0.97
            }
        }()
        return basePortraitDiameter * scale
    }
}

// MARK: - Z gesture (code-drawn)

/// Prologue-only vector fallback when ``iOSBanishmentArt/gestureZReference`` is absent.
private struct BanishmentZGestureShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.06, y: h * 0.22))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.22))
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.78))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.78))
        return p
    }
}

#Preview {
    NavigationStack {
        iOSBanishmentQuestView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
