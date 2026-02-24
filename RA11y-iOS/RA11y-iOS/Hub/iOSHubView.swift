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

    @Bindable private var viewModel: HubViewModel
    @State private var showHelpSheet = false

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    // MARK: - Init

    /// Creates the hub view with an injected view model.
    ///
    /// - Parameter viewModel: Observable hub view model owned by the caller.
    init(viewModel: HubViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
    }

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
                iOSHubBackgroundView(assetName: "hub_quest_board_bg")
            }
            .navigationTitle(String(localized: "hub.navigationTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHelpSheet) {
            iOSVoiceOverHelpSheet()
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
                showHelpAffordance: viewModel.showHelpAffordance,
                onVoiceOverBasics: navigateToBasics,
                onEnableVoiceOver: { showHelpSheet = true }
            )
        }
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
    /// If VoiceOver is running: route directly to the game (M5+).
    /// If VoiceOver is off: push the interstitial so the user can enable it.
    private func startGame(_ game: GameDefinition) {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            router.push(.game(kind: game.kind))
            return
        }
        if viewModel.showHelpAffordance {
            // VoiceOver is OFF — route to interstitial
            router.push(.voiceOverInterstitial(kind: game.kind))
        } else {
            // VoiceOver is ON — proceed to game (M5+: push game route)
            switch game.kind {
            case .findAndFocus:
                router.push(.game(kind: game.kind))
            case .activateDoubleTap, .scrollHunt:
                RA11yLogger.navigation.debug("Game start gating passed for \(game.id) (not yet implemented)")
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
        iOSHubView(
            viewModel: HubViewModel(
                voiceOverProvider: StubVoiceOverStateProvider(isVoiceOverRunning: false),
                storage: UserDefaultsStorageComponent()
            )
        )
            .environment(iOSAppRouter())
    }
}
