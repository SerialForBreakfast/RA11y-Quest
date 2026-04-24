import OSLog
import SwiftUI
import RA11yCore

// MARK: - iOSHubView

/// The game hub — the player's home base and quest board.
///
/// Implemented per `TICKET-M3-Hub-UI-Progress`. Renders catalog training games as
/// D&D-themed quest cards. Quest starts call ``iOSAppRouter/pushGame(kind:provider:)`` so
/// games are never entered without VoiceOver. Also provides help affordance and
/// reflects best results from storage without requiring an app relaunch.
///
/// ## Layout (ZStack)
/// - Layer 0: `iOSHubBackgroundView` — full-bleed ``QuestPaintAmbientBackdrop`` + ``QuestPaintReadableScrim``; `ignoresSafeArea`
/// - Layer 1: Content — DM greeting + scrollable quest cards + pinned footer
///
/// ## Adaptive Design
/// - iPhone (.compact): full-width content minus 16pt horizontal padding
/// - iPad (.regular): content max width 600pt, centered
///
/// ## VoiceOver State
/// VoiceOver state is read from `@Environment(\.accessibilityVoiceOverEnabled)`.
/// SwiftUI propagates changes automatically — no custom observer or stream needed.
/// The affordance footer and game-start gating both read this environment value.
///
/// ## Accessibility
/// - **Focus management**: When VoiceOver is enabled while the hub is visible, focus
///   is programmatically moved to the first quest card after a short settle delay.
/// - **Quest rotor**: A custom "Quests" rotor entry lets VoiceOver users jump directly
///   between quest cards without swiping through the heading and footer.
/// - **Arrival announcement**: A `.screenChanged` notification is posted on first
///   appearance when VoiceOver is on, orienting the user to the screen.
///
/// ## VoiceOver Reading Order
/// 1. Navigation title — visible text "RA11y Quest"; VoiceOver label "Rally Quest"
/// 2. Orientation strip — scroll gesture; with VoiceOver on, also tap / double-tap to open
/// 3. "Choose Your Trial, Adventurer" (.isHeader)
/// 4+. Quest cards (combined label per card)
/// 7. "VoiceOver Basics"
/// 8. "Enable VoiceOver to play" (only if VO OFF)
///
/// ## Scrolling
/// Standard VoiceOver scroll: three-finger swipe up/down scrolls the quest list.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSHubView: View {

    // MARK: - DEBUG audit

    /// Unlocks every quest card for local QA without prerequisite clears.
    ///
    /// Enable: Xcode → Product → Scheme → Edit Scheme → Run → Arguments → add
    /// `-unlockAllQuestsForAudit`. **DEBUG builds only** — release always behaves as `false`.
    private static var unlockAllQuestsForAudit: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-unlockAllQuestsForAudit")
        #else
        false
        #endif
    }

    // MARK: - State

    @State private var viewModel: HubViewModel
    @State private var showHelpSheet = false
    private let shouldRefreshOnAppear: Bool

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// VoiceOver state sourced directly from the SwiftUI environment.
    /// SwiftUI propagates updates on every toggle — no custom observation needed.
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    // MARK: - Accessibility Focus

    /// Drives programmatic VoiceOver focus on quest cards.
    ///
    /// Set to a `GameKind` value to move VoiceOver focus to the corresponding card.
    /// Used when VoiceOver is enabled while the hub is on screen, and by the
    /// custom "Quests" rotor to let users jump directly between cards.
    @AccessibilityFocusState private var focusedCard: GameKind?

    // MARK: - Computed

    /// Short orientation copy at the top of the scroll view: how to scroll the quest list,
    /// and (with VoiceOver on) the minimum tap / double-tap pattern to open a trial.
    private var hubOrientationBanner: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
            Text(String(localized: "hub.orientation.scrollTitle"))
                .questPaintReadableText(.captionGold)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "hub.orientation.scrollBody"))
                .questPaintReadableText(.bodySupporting)

            if voiceOverEnabled {
                Text(String(localized: "hub.orientation.voActivation"))
                    .questPaintReadableText(.bodySupporting)
            }
        }
        .padding(RA11ySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.42), in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(Color.ra11yDMBorder.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hubOrientationA11yLabel)
    }

    /// Single combined string so VoiceOver reads orientation as one structured block.
    private var hubOrientationA11yLabel: String {
        let scroll = String(localized: "hub.orientation.scrollBody")
        if voiceOverEnabled {
            let vo = String(localized: "hub.orientation.voActivation")
            return "\(scroll) \(vo)"
        }
        return scroll
    }

    private var cardSpacing: CGFloat {
        sizeClass == .regular ? RA11ySpacing.lg : RA11ySpacing.md
    }

    // MARK: - Init

    /// Creates the hub view with an injected storage component and refresh policy.
    ///
    /// - Parameters:
    ///   - storage: Persistence layer used to load and refresh best-result summaries.
    ///   - shouldRefreshOnAppear: Whether the hub should immediately read stored results
    ///     when it appears. `iOSRootView` disables this while initial route resolution is
    ///     still pending so startup work does not compete with first-run gating.
    init(
        storage: any StorageComponent = UserDefaultsStorageComponent(),
        shouldRefreshOnAppear: Bool = true
    ) {
        self.shouldRefreshOnAppear = shouldRefreshOnAppear
        _viewModel = State(
            initialValue: HubViewModel(
                storage: storage,
                unlockAllQuestsForAudit: Self.unlockAllQuestsForAudit
            )
        )
    }

    // MARK: - Body

    var body: some View {
        contentLayer
            .background {
                iOSHubBackgroundView(assetName: "simon_room_bg")
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(String(localized: "hub.navigationTitle"))
                        .font(.headline)
                        .accessibilityLabel(String(localized: "hub.navigationTitle.voiceOver"))
                        .accessibilityIdentifier("hub.navigationTitle")
                }
            }
            .sheet(isPresented: $showHelpSheet) {
                iOSVoiceOverHelpSheet()
            }
            .task(id: shouldRefreshOnAppear) {
                guard shouldRefreshOnAppear else { return }
                await viewModel.refreshBestResults()
            }
    }

    // MARK: - Content Layer

    private var contentLayer: some View {
        GeometryReader { geo in
            let horizontalPad = QuestPaintContentMetrics.scrollHorizontalPadding(
                containerWidth: geo.size.width,
                horizontalSizeClass: sizeClass,
                gameKind: nil
            )
            let readingMax = QuestPaintContentMetrics.readingColumnMaxWidth(
                containerWidth: geo.size.width,
                horizontalSizeClass: sizeClass,
                horizontalPadding: horizontalPad
            )
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    hubOrientationBanner
                        .padding(.horizontal, horizontalPad)
                        .padding(.top, RA11ySpacing.sm)

                    iOSHubDMGreetingView()
                        .padding(.top, RA11ySpacing.sm)

                    questCardList(horizontalPadding: horizontalPad)
                }
                .frame(maxWidth: readingMax)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                iOSHubFooterView(
                    showHelpAffordance: !voiceOverEnabled,
                    onVoiceOverBasics: navigateToBasics,
                    onEnableVoiceOver: { showHelpSheet = true }
                )
            }
            // The hub always renders on painted art + scrim. Force dark semantics so
            // `.primary` / `.secondary` on footer materials and controls resolve predictably.
            .environment(\.colorScheme, .dark)
            // MARK: VoiceOver Accessibility
            .accessibilityRotor(String(localized: "hub.a11y.rotor.quests")) {
                ForEach(GameCatalog.all) { game in
                    AccessibilityRotorEntry(
                        LocalizedStringKey(game.titleKey),
                        id: game.id,
                        prepare: { focusedCard = game.kind }
                    )
                }
            }
            .onChange(of: voiceOverEnabled) { _, isEnabled in
                guard isEnabled else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    focusedCard = GameCatalog.all.first?.kind
                }
            }
            .onAppear {
                guard voiceOverEnabled else { return }
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
        }
    }

    // MARK: - Quest Cards

    private func questCardList(horizontalPadding: CGFloat) -> some View {
        LazyVStack(spacing: cardSpacing) {
            ForEach(GameCatalog.all) { game in
                iOSQuestCardView(
                    game: game,
                    rank: viewModel.bestRank(for: game.id),
                    prerequisiteTitle: prerequisiteTitle(for: game),
                    onTap: { startGame(game) }
                )
                .padding(.horizontal, horizontalPadding)
                .accessibilityFocused($focusedCard, equals: game.kind)
            }
        }
        .padding(.top, RA11ySpacing.md)
        .padding(.bottom, RA11ySpacing.xl)
    }

    /// The display title of the prerequisite game for a locked card, or `nil` when unlocked.
    private func prerequisiteTitle(for game: GameDefinition) -> String? {
        guard let prereq = viewModel.prerequisite(for: game) else { return nil }
        return String(localized: String.LocalizationValue(prereq.titleKey))
    }

    // MARK: - Actions

    /// Starts a game when the card is unlocked. VoiceOver is required — see ``iOSAppRouter/pushGame(kind:provider:)``.
    private func startGame(_ game: GameDefinition) {
        guard viewModel.isUnlocked(game) else { return }
        router.pushGame(kind: game.kind)
    }

    private func navigateToBasics() {
        router.push(.firstRun(mode: .sequence))
    }
}

// MARK: - Previews

#Preview("VO OFF — help affordance visible") {
    NavigationStack {
        iOSHubView()
            .environment(iOSAppRouter())
    }
}
