import OSLog
import SwiftUI
import RA11yCore

// MARK: - iOSHubView

/// The game hub — the player's home base and quest board.
///
/// Implemented per `TICKET-M3-Hub-UI-Progress`. Renders three training games as
/// D&D-themed quest cards, provides VoiceOver gating and help affordance, and
/// reflects best results from storage without requiring an app relaunch.
///
/// ## Layout (ZStack)
/// - Layer 0: `iOSHubBackgroundView` — full-bleed image + gradient; `ignoresSafeArea`
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
/// 4–6. Quest cards (combined label per card)
/// 7. "VoiceOver Basics"
/// 8. "Enable VoiceOver to play" (only if VO OFF)
///
/// ## Scrolling
/// Standard VoiceOver scroll: three-finger swipe up/down scrolls the quest list.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSHubView: View {

    // MARK: - State

    @State private var viewModel = HubViewModel(storage: UserDefaultsStorageComponent())
    @State private var showHelpSheet = false

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
                .font(.ra11yCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.ra11yCardSecondaryText)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "hub.orientation.scrollBody"))
                .font(.ra11yCaption)
                .foregroundStyle(Color.ra11yCardTertiaryText)

            if voiceOverEnabled {
                Text(String(localized: "hub.orientation.voActivation"))
                    .font(.ra11yCaption)
                    .foregroundStyle(Color.ra11yCardTertiaryText)
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

    private var contentMaxWidth: CGFloat {
        sizeClass == .regular ? 600 : .infinity
    }

    private var cardHorizontalPadding: CGFloat {
        sizeClass == .regular ? RA11ySpacing.lg : RA11ySpacing.md
    }

    private var cardSpacing: CGFloat {
        sizeClass == .regular ? RA11ySpacing.lg : RA11ySpacing.md
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
            .task {
                await viewModel.refreshBestResults()
            }
    }

    // MARK: - Content Layer

    private var contentLayer: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                hubOrientationBanner
                    .padding(.horizontal, cardHorizontalPadding)
                    .padding(.top, RA11ySpacing.sm)

                iOSHubDMGreetingView()
                    .padding(.top, RA11ySpacing.sm)

                questCardList
            }
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            iOSHubFooterView(
                showHelpAffordance: !voiceOverEnabled,
                onVoiceOverBasics: navigateToBasics,
                onEnableVoiceOver: { showHelpSheet = true }
            )
        }
        // The hub always renders on a fixed dark background (dungeon scene image +
        // dark gradient overlay). Force dark color scheme here so ALL semantic
        // adaptive colors in the hub's content tree — `.primary`, `.secondary`,
        // nav bar title, footer material, DM greeting — resolve to white-based values
        // in both light mode and dark mode.
        .environment(\.colorScheme, .dark)
        // MARK: VoiceOver Accessibility
        // Custom "Quests" rotor — lets VoiceOver users jump directly between quest
        // cards by rotating through the rotor to "Quests" and swiping up/down.
        // Each entry's `prepare` closure sets `focusedCard`, which is bound to
        // the card via `.accessibilityFocused` in `questCardList`.
        .accessibilityRotor(String(localized: "hub.a11y.rotor.quests")) {
            ForEach(GameCatalog.all) { game in
                AccessibilityRotorEntry(
                    LocalizedStringKey(game.titleKey),
                    id: game.id,
                    prepare: { focusedCard = game.kind }
                )
            }
        }
        // When VoiceOver is enabled while the hub is visible, move focus to the
        // first quest card after a brief settle delay. This prevents users from
        // being stranded at the top of the UI after toggling VO on.
        .onChange(of: voiceOverEnabled) { _, isEnabled in
            guard isEnabled else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                focusedCard = GameCatalog.all.first?.kind
            }
        }
        // Post a screenChanged notification when the hub first appears with VO on.
        // Passing `nil` lets VoiceOver focus the first element naturally (nav title).
        .onAppear {
            guard voiceOverEnabled else { return }
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    // MARK: - Quest Cards

    private var questCardList: some View {
        LazyVStack(spacing: cardSpacing) {
            ForEach(GameCatalog.all) { game in
                iOSQuestCardView(
                    game: game,
                    rank: viewModel.bestRank(for: game.id),
                    prerequisiteTitle: prerequisiteTitle(for: game),
                    onTap: { startGame(game) }
                )
                .padding(.horizontal, cardHorizontalPadding)
                // Binds this card to the shared AccessibilityFocusState.
                // Setting `focusedCard = game.kind` from the rotor or the
                // VO-enable handler moves VoiceOver focus here.
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

    /// Initiates the VoiceOver gating check before starting a game.
    ///
    /// Guards against locked games (the card button is already disabled, but this
    /// provides a safe second layer). Then checks VoiceOver state: if VoiceOver is
    /// off, routes to the interstitial; if on, routes to the game entry route.
    private func startGame(_ game: GameDefinition) {
        guard viewModel.isUnlocked(game) else { return }
        if !voiceOverEnabled {
            router.push(.voiceOverInterstitial(kind: game.kind))
        } else {
            RA11yLogger.navigation.debug("Game start gating passed for \(game.id)")
            switch game.kind {
            case .findAndFocus:
                router.push(.enchantersTrial)
            case .activateDoubleTap:
                router.push(.roguesGauntlet)
            case .scrollHunt:
                router.push(.dungeonDescent)
            }
        }
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
