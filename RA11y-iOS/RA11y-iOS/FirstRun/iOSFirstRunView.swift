import SwiftUI
import RA11yCore

// MARK: - iOSFirstRunView

/// First-run entry screen and container for the VoiceOver Basics sequence.
///
/// **Roadmap:** The product spec at `memlog/requirements/GameSpec-MagicTapFirstSpell.txt` calls
/// for a **First Spell: Magic Tap** step *before* this Basics sequence (VoiceOver on → practice
/// surface → success → "Continue Basics"). When that ships, this view should route the primary
/// CTA through the first-spell flow instead of jumping straight to ``iOSBasicsSequenceView``.
///
/// Presents the entry choice on initial launch and starts the sequence when
/// launched from the hub or when the user chooses "Start Basics."
///
/// Entry and Basics use the same hub tavern art with ``QuestPaintReadableScrim``,
/// ``QuestPaintReadableText`` roles, and ``QuestPaintContentMetrics`` as the main hub.
struct iOSFirstRunView: View {

    /// First-run subflow state before entering ``iOSBasicsSequenceView``.
    private enum FirstSpellStage: Equatable {
        case entry
        case voiceOverRequired
        case ready
    }

    // MARK: - Private Properties

    private let mode: FirstRunMode
    private let storage: any StorageComponent
    private let voiceOverProvider: any VoiceOverStateProvider

    // MARK: - State

    @State private var isShowingSequence = false
    @State private var firstSpellStage: FirstSpellStage = .entry
    @State private var hasAttemptedAutoStart = false

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Init

    /// Creates the first-run view with the given mode and storage.
    ///
    /// - Parameters:
    ///   - mode: Entry mode controlling whether the entry screen is shown.
    ///   - storage: Persistence layer for first-run flags.
    ///   - voiceOverProvider: Source of VoiceOver state for gating.
    init(
        mode: FirstRunMode,
        storage: any StorageComponent,
        voiceOverProvider: some VoiceOverStateProvider = iOSLiveVoiceOverStateProvider()
    ) {
        self.mode = mode
        self.storage = storage
        self.voiceOverProvider = voiceOverProvider
    }

    // MARK: - Body

    /// The primary view content for the first-run flow.
    var body: some View {
        Group {
            if isShowingSequence {
                iOSBasicsSequenceView(storage: storage)
            } else {
                switch firstSpellStage {
                case .entry:
                    entryContent
                case .voiceOverRequired:
                    iOSFirstSpellVoiceOverRequiredView(
                        voiceOverProvider: voiceOverProvider,
                        onReturnToEntry: { firstSpellStage = .entry },
                        onVoiceOverEnabled: { firstSpellStage = .ready }
                    )
                case .ready:
                    iOSMagicTapFirstSpellView(
                        onContinueBasics: { isShowingSequence = true }
                    )
                    .accessibilityIdentifier("firstSpell.ready")
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.colorScheme, .dark)
        .task {
            await handleAutoStartIfNeeded()
        }
    }

    private var navigationTitle: String {
        if isShowingSequence {
            return String(localized: "firstRun.navigationTitle")
        }
        switch firstSpellStage {
        case .entry, .ready:
            return String(localized: "firstSpell.navigationTitle")
        case .voiceOverRequired:
            return String(localized: "firstSpellVORequired.navigationTitle")
        }
    }

    // MARK: - Entry Content

    private var entryContent: some View {
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
                    VStack(spacing: RA11ySpacing.md) {
                        Text(String(localized: "firstSpell.entry.title"))
                            .questPaintReadableText(.heroTitle)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("firstRun.title")

                        Text(String(localized: "firstSpell.entry.body"))
                            .questPaintReadableText(.bodySupporting)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: RA11ySpacing.sm) {
                        Button(String(localized: "firstSpell.start")) {
                            attemptStartFirstSpell()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityLabel(String(localized: "firstSpell.start.a11yLabel"))
                        .accessibilityHint(String(localized: "firstSpell.start.a11yHint"))
                        .accessibilityIdentifier("firstSpell.start")

                        Button(String(localized: "firstRun.goToHub")) {
                            dismissToHub()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityLabel(String(localized: "firstRun.goToHub.a11yLabel"))
                        .accessibilityHint(String(localized: "firstRun.goToHub.a11yHint"))
                    }
                }
                .padding(.horizontal, horizontalPad)
                .padding(.vertical, RA11ySpacing.base)
                .frame(maxWidth: readingMax)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color(red: 0.10, green: 0.07, blue: 0.05)
                QuestPaintAmbientBackdrop(imageName: "simon_room_bg")
                QuestPaintReadableScrim()
            }
        }
    }

    // MARK: - Actions

    private func handleAutoStartIfNeeded() async {
        guard mode == .sequence, !hasAttemptedAutoStart else { return }
        hasAttemptedAutoStart = true
        attemptStartFirstSpell()
    }

    private func attemptStartFirstSpell() {
        let decision = GameStartDecision.evaluate(kind: .findAndFocus, provider: voiceOverProvider)
        switch decision {
        case .proceed:
            firstSpellStage = .ready
        case .requireVoiceOver:
            firstSpellStage = .voiceOverRequired
        }
    }

    private func dismissToHub() {
        Task {
            guard !Task.isCancelled else { return }
            await storage.markBasicsDismissed()
            router.popToRoot()
        }
    }
}

#Preview("First Run — Entry") {
    NavigationStack {
        iOSFirstRunView(mode: .entry, storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}

#Preview("First Run — Sequence") {
    NavigationStack {
        iOSFirstRunView(mode: .sequence, storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
