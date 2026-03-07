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
/// ## VoiceOver Reading Order
/// 1. Navigation title "RA11y"
/// 2. "Choose Your Trial, Adventurer" (.isHeader)
/// 3–5. Quest cards (combined label per card)
/// 6. "VoiceOver Basics"
/// 7. "Enable VoiceOver to play" (only if VO OFF)
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

    // MARK: - Computed

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
            // `.background {}` sizes the background to the content frame, then the
            // background extends into safe area regions on its own. This prevents the
            // background image's intrinsic size (1920pt wide for landscape assets)
            // from widening the ZStack and overflowing the content layout.
            .background {
                iOSHubBackgroundView(assetName: "simon_room_bg")
            }
            .navigationTitle(String(localized: "hub.navigationTitle"))
            .navigationBarTitleDisplayMode(.inline)
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
                iOSHubDMGreetingView()
                    .padding(.top, RA11ySpacing.sm)

                questCardList
            }
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
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
        //
        // Scope: This modifier applies only to this view's subtree. It does NOT
        // affect pushed NavigationStack destinations (VORequired, FirstRun) because
        // those are siblings managed by the NavigationStack, not children of this view.
        //
        // "Increase Contrast" is respected automatically — the system overlays higher
        // contrast values on top of the forced dark scheme.
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Quest Cards

    private var questCardList: some View {
        LazyVStack(spacing: cardSpacing) {
            ForEach(GameCatalog.all) { game in
                iOSQuestCardView(
                    game: game,
                    rank: viewModel.bestRank(for: game.id),
                    onTap: { startGame(game) }
                )
                .padding(.horizontal, cardHorizontalPadding)
            }
        }
        .padding(.top, RA11ySpacing.md)
        .padding(.bottom, RA11ySpacing.xl)
    }

    // MARK: - Actions

    /// Initiates the VoiceOver gating check before starting a game.
    ///
    /// Reads `voiceOverEnabled` from the SwiftUI environment — always current at
    /// the moment the user taps. If VoiceOver is off, routes to the interstitial.
    private func startGame(_ game: GameDefinition) {
        if !voiceOverEnabled {
            router.push(.voiceOverInterstitial(kind: game.kind))
        } else {
            // VoiceOver is ON — proceed to game (M5+: push game route)
            RA11yLogger.navigation.debug("Game start gating passed for \(game.id)")
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
