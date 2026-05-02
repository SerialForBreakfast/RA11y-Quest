import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSBasicsSequenceView

/// Guided VoiceOver Basics sequence that walks the player through MVP games
/// in hub unlock order (Enchanter → Crystal Resonance → The Banishment).
///
/// This view acts as the **conductor** for the M4 basics flow. It stays on the navigation
/// stack throughout the sequence and orchestrates the push-and-return loop:
///
/// 1. Show the current skill card plus completed and locked sequence cards.
/// 2. Magic Tap launches the selected playable card, defaulting to the current step.
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

    private enum StepStatus: Equatable {
        case completed
        case current
        case locked
    }

    private let storage: any StorageComponent
    private let steps: [GameKind] = [.findAndFocus, .scrollHunt, .banishment]

    // MARK: - State

    @State private var currentIndex = 0
    @State private var selectedStepIndex: Int?
    @State private var launchedStepIndex: Int?
    @AccessibilityFocusState private var focusedStep: GameKind?

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router

    // MARK: - Init

    /// Creates a Basics sequence view with the provided storage.
    ///
    /// - Parameter storage: Persistence layer for the completion flag.
    init(storage: any StorageComponent) {
        self.storage = storage
    }

    // MARK: - Body

    var body: some View {
        QuestPaintScreen(
            ambientImageName: "simon_room_bg",
            layoutRole: .reading,
            accessibilityIdentifier: "basicsSequence.screen"
        ) {
            VStack(alignment: .center, spacing: RA11ySpacing.xl) {
                headerSection
                stepList
            }
            .padding(.vertical, RA11ySpacing.base)
        }
        .accessibilityAction(.magicTap, launchSelectedPlayableStep)
        .onAppear {
            handleReappear()
            focusSelectedStep()
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

    private var stepList: some View {
        VStack(spacing: RA11ySpacing.sm) {
            ForEach(Array(steps.enumerated()), id: \.element) { index, kind in
                stepCard(index: index, kind: kind)
            }
        }
    }

    @ViewBuilder
    private func stepCard(index: Int, kind: GameKind) -> some View {
        let status = stepStatus(for: index)
        let isSelected = selectedPlayableIndex == index

        if status == .locked {
            stepCardContent(index: index, kind: kind, status: status, isSelected: false)
                .opacity(0.62)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(stepAccessibilityLabel(index: index, kind: kind, status: status))
                .accessibilityIdentifier("basicsSequence.step.locked.\(kind.rawValue)")
        } else {
            Button {
                selectedStepIndex = index
                focusSelectedStep()
            } label: {
                stepCardContent(index: index, kind: kind, status: status, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(stepAccessibilityLabel(index: index, kind: kind, status: status))
            .accessibilityHint(String(localized: "basicsSequence.step.playable.a11yHint"))
            .accessibilityFocused($focusedStep, equals: kind)
            .accessibilityIdentifier("basicsSequence.step.playable.\(kind.rawValue)")
        }
    }

    private func stepCardContent(index: Int, kind: GameKind, status: StepStatus, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: RA11ySpacing.sm) {
                Text(skillBadgeText(for: index))
                    .questPaintReadableText(.captionGold)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer(minLength: RA11ySpacing.sm)

                statusLabel(status, isSelected: isSelected)
            }

            Text(skillTitle(for: kind))
                .questPaintReadableText(.materialCardTitle)
                .multilineTextAlignment(.leading)

            Text(skillIntro(for: kind))
                .questPaintReadableText(.materialCardBody)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, RA11ySpacing.xs)

            Label {
                Text(localizedGameTitle(for: kind))
                    .questPaintReadableText(.materialCardMeta)
            } icon: {
                Image(systemName: status == .locked ? "lock.fill" : "gamecontroller.fill")
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
        .padding(RA11ySpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: RA11yRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .stroke(isSelected ? Color.ra11yAccent.opacity(0.85) : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
        }
    }

    private func statusLabel(_ status: StepStatus, isSelected: Bool) -> some View {
        Text(statusText(status, isSelected: isSelected))
            .questPaintReadableText(.materialCardMeta)
            .padding(.horizontal, RA11ySpacing.sm)
            .padding(.vertical, RA11ySpacing.xs)
            .background(Color.white.opacity(0.08), in: Capsule())
    }

    // MARK: - Computed

    private var selectedPlayableIndex: Int {
        let candidate = selectedStepIndex ?? currentIndex
        return candidate <= currentIndex ? candidate : currentIndex
    }

    private var stepProgressText: String {
        let format = String(localized: "basicsSequence.stepFormat")
        return String(format: format, currentIndex + 1, steps.count)
    }

    private func stepStatus(for index: Int) -> StepStatus {
        if index < currentIndex { return .completed }
        if index == currentIndex { return .current }
        return .locked
    }

    private func skillBadgeText(for index: Int) -> String {
        let format = String(localized: "basicsSequence.skillBadgeFormat")
        return String(format: format, index + 1, steps.count)
    }

    private func skillTitle(for kind: GameKind) -> String {
        switch kind {
        case .findAndFocus:
            return String(localized: "basicsSequence.skill.findAndFocus.title")
        case .scrollHunt:
            return String(localized: "basicsSequence.skill.scrollHunt.title")
        case .banishment:
            return String(localized: "basicsSequence.skill.banishment.title")
        case .arcanistsTower:
            return String(localized: "basicsSequence.skill.arcanistsTower.title")
        }
    }

    private func skillIntro(for kind: GameKind) -> String {
        switch kind {
        case .findAndFocus:
            return String(localized: "basicsSequence.skill.findAndFocus.intro")
        case .scrollHunt:
            return String(localized: "basicsSequence.skill.scrollHunt.intro")
        case .banishment:
            return String(localized: "basicsSequence.skill.banishment.intro")
        case .arcanistsTower:
            return String(localized: "basicsSequence.skill.arcanistsTower.intro")
        }
    }

    private func localizedGameTitle(for kind: GameKind) -> String {
        guard let definition = GameCatalog.all.first(where: { $0.kind == kind }) else {
            return NSLocalizedString(GameCatalog.all[0].titleKey, comment: "")
        }
        return NSLocalizedString(definition.titleKey, comment: "")
    }

    private func statusText(_ status: StepStatus, isSelected: Bool) -> String {
        if isSelected, status == .completed {
            return String(localized: "basicsSequence.status.selected")
        }
        switch status {
        case .completed:
            return String(localized: "basicsSequence.status.completed")
        case .current:
            return String(localized: "basicsSequence.status.current")
        case .locked:
            return String(localized: "basicsSequence.status.locked")
        }
    }

    private func stepAccessibilityLabel(index: Int, kind: GameKind, status: StepStatus) -> String {
        "\(skillBadgeText(for: index)). \(statusText(status, isSelected: selectedPlayableIndex == index)). \(skillTitle(for: kind)). \(skillIntro(for: kind)). \(localizedGameTitle(for: kind))."
    }

    // MARK: - Actions

    private func launchSelectedPlayableStep() {
        let launchIndex = selectedPlayableIndex
        selectedStepIndex = launchIndex
        launchedStepIndex = launchIndex
        router.isInBasicsSequence = true
        router.pushGame(kind: steps[launchIndex])
    }

    /// Called on every `.onAppear`. Advances the sequence when returning from a completed
    /// game step; no-ops on initial appearance or after back-navigation mid-game.
    private func handleReappear() {
        guard let launchedIndex = launchedStepIndex else { return }
        launchedStepIndex = nil

        // Only advance if "Continue Basics" was explicitly tapped (not a back swipe).
        guard router.basicsStepCompleted else { return }
        router.basicsStepCompleted = false

        guard launchedIndex == currentIndex else {
            selectedStepIndex = nil
            return
        }

        let nextIndex = currentIndex + 1
        if nextIndex < steps.count {
            currentIndex = nextIndex
            selectedStepIndex = nil
        } else {
            // All Basics steps completed — mark done and return to hub.
            router.isInBasicsSequence = false
            Task {
                await storage.markBasicsCompleted()
                router.popToRoot()
            }
        }
    }

    private func focusSelectedStep() {
        let index = selectedPlayableIndex
        let kind = steps[index]
        let status = stepStatus(for: index)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            focusedStep = kind
            UIAccessibility.post(
                notification: .announcement,
                argument: stepAccessibilityLabel(index: index, kind: kind, status: status)
            )
        }
    }
}

#Preview("Basics Sequence — Step 1") {
    NavigationStack {
        iOSBasicsSequenceView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
