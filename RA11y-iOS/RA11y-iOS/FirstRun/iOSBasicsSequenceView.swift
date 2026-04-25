import SwiftUI
import RA11yCore

// MARK: - iOSBasicsSequenceView

/// Guided VoiceOver Basics sequence that walks the player through MVP games
/// in hub unlock order (Enchanter → Crystal Resonance → The Banishment).
///
/// This view acts as the **conductor** for the M4 basics flow. It stays on the navigation
/// stack throughout the sequence and orchestrates the push-and-return loop:
///
/// 1. Show a skill-intro card for the current game.
/// 2. Player taps "Begin [Game Name]" → game route is pushed onto the stack.
/// 3. Game plays; on L3 completion the game pushes `.gameResult`.
/// 4. Result screen shows "Continue Basics" → `router.popForBasicsContinue()` removes
///    both the result and the game view, returning here.
/// 5. `.onAppear` detects the completed step (via `router.basicsStepCompleted`) and either
///    advances to the next card or marks the sequence complete and pops to root.
///
/// If the player uses back-navigation from within a game (without completing it),
/// `router.basicsStepCompleted` remains `false` so the index does **not** advance.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSBasicsSequenceView: View {

    // MARK: - Private Properties

    private let storage: any StorageComponent
    private let steps: [GameKind] = [.findAndFocus, .scrollHunt, .banishment]

    // MARK: - State

    @State private var currentIndex = 0
    /// `true` after the player taps "Begin" to launch a game. Consumed by `.onAppear`
    /// when the sequence view returns to the top of the nav stack.
    @State private var hasLaunchedGame = false

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Init

    /// Creates a Basics sequence view with the provided storage.
    ///
    /// - Parameter storage: Persistence layer for the completion flag.
    init(storage: any StorageComponent) {
        self.storage = storage
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let horizontalPad = QuestPaintContentMetrics.scrollHorizontalPadding(
                containerWidth: geo.size.width,
                horizontalSizeClass: horizontalSizeClass,
                gameKind: nil
            )
            let readingMax = QuestPaintContentMetrics.readingColumnMaxWidth(
                containerWidth: geo.size.width,
                horizontalSizeClass: horizontalSizeClass,
                horizontalPadding: horizontalPad
            )
            ScrollView {
                VStack(alignment: .center, spacing: RA11ySpacing.xl) {
                    headerSection
                    currentStepCard
                    beginButton
                }
                .padding(.horizontal, horizontalPad)
                .padding(.vertical, RA11ySpacing.base)
                .frame(maxWidth: readingMax)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
        .background {
            ZStack {
                Color(red: 0.10, green: 0.07, blue: 0.05)
                QuestPaintAmbientBackdrop(imageName: "simon_room_bg")
                QuestPaintReadableScrim()
            }
        }
        .onAppear {
            handleReappear()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: RA11ySpacing.sm) {
            Text(String(localized: "basicsSequence.title"))
                .questPaintReadableText(.heroTitle)
                .multilineTextAlignment(.center)

            Text(stepProgressText)
                .questPaintReadableText(.bodySupporting)
                .multilineTextAlignment(.center)
        }
    }

    private var currentStepCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.md) {
            // Skill badge
            Text(skillBadgeText)
                .questPaintReadableText(.captionGold)
                .textCase(.uppercase)
                .tracking(0.5)
                .accessibilityHidden(true)

            // Skill title
            Text(skillTitle)
                .questPaintReadableText(.materialCardTitle)
                .multilineTextAlignment(.leading)

            // Skill intro body
            Text(skillIntro)
                .questPaintReadableText(.materialCardBody)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, RA11ySpacing.xs)

            // Game name
            Label {
                Text(LocalizedStringKey(currentDefinition.titleKey))
                    .questPaintReadableText(.materialCardMeta)
            } icon: {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
        .padding(RA11ySpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: RA11yRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    private var beginButton: some View {
        Button(beginButtonTitle) {
            launchCurrentGame()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(beginAccessibilityLabel)
        .accessibilityHint(beginAccessibilityHint)
    }

    // MARK: - Computed

    private var currentDefinition: GameDefinition {
        let kind = steps[currentIndex]
        return GameCatalog.all.first { $0.kind == kind } ?? GameCatalog.all[0]
    }

    private var stepProgressText: String {
        let format = String(localized: "basicsSequence.stepFormat")
        return String(format: format, currentIndex + 1, steps.count)
    }

    private var skillBadgeText: String {
        let format = String(localized: "basicsSequence.skillBadgeFormat")
        return String(format: format, currentIndex + 1, steps.count)
    }

    private var skillTitle: String {
        switch steps[currentIndex] {
        case .findAndFocus:
            return String(localized: "basicsSequence.skill.findAndFocus.title")
        case .scrollHunt:
            return String(localized: "basicsSequence.skill.scrollHunt.title")
        case .banishment:
            return String(localized: "basicsSequence.skill.banishment.title")
        }
    }

    private var skillIntro: String {
        switch steps[currentIndex] {
        case .findAndFocus:
            return String(localized: "basicsSequence.skill.findAndFocus.intro")
        case .scrollHunt:
            return String(localized: "basicsSequence.skill.scrollHunt.intro")
        case .banishment:
            return String(localized: "basicsSequence.skill.banishment.intro")
        }
    }

    /// Localized game title resolved from the definition key at runtime.
    private var localizedGameTitle: String {
        NSLocalizedString(currentDefinition.titleKey, comment: "")
    }

    private var cardAccessibilityLabel: String {
        "\(skillBadgeText). \(skillTitle). \(skillIntro). \(localizedGameTitle)."
    }

    private var beginButtonTitle: String {
        let format = String(localized: "basicsSequence.beginGame")
        return String(format: format, localizedGameTitle)
    }

    private var beginAccessibilityLabel: String {
        let format = String(localized: "basicsSequence.beginGame.a11yLabel")
        return String(format: format, localizedGameTitle)
    }

    private var beginAccessibilityHint: String {
        String(localized: "basicsSequence.beginGame.a11yHint")
    }

    // MARK: - Actions

    private func launchCurrentGame() {
        hasLaunchedGame = true
        router.isInBasicsSequence = true
        router.pushGame(kind: steps[currentIndex])
    }

    /// Called on every `.onAppear`. Advances the sequence when returning from a completed
    /// game step; no-ops on initial appearance or after back-navigation mid-game.
    private func handleReappear() {
        guard hasLaunchedGame else { return }
        hasLaunchedGame = false

        // Only advance if "Continue Basics" was explicitly tapped (not a back swipe).
        guard router.basicsStepCompleted else { return }
        router.basicsStepCompleted = false

        let nextIndex = currentIndex + 1
        if nextIndex < steps.count {
            currentIndex = nextIndex
        } else {
            // All Basics steps completed — mark done and return to hub.
            router.isInBasicsSequence = false
            Task {
                await storage.markBasicsCompleted()
                router.popToRoot()
            }
        }
    }
}

#Preview("Basics Sequence — Step 1") {
    NavigationStack {
        iOSBasicsSequenceView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
