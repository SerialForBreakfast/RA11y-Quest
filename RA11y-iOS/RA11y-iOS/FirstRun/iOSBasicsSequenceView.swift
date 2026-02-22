import SwiftUI
import RA11yCore

// MARK: - iOSBasicsSequenceView

/// Guided VoiceOver Basics sequence that runs the three MVP games in order.
///
/// This view is a lightweight placeholder until the game screens land (M5–M7).
/// It advances through the sequence and marks completion in storage.
struct iOSBasicsSequenceView: View {

    // MARK: - Private Properties

    private let storage: any StorageComponent
    private let steps: [GameKind] = [.findAndFocus, .activateDoubleTap, .scrollHunt]

    // MARK: - State

    @State private var currentIndex = 0

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

    /// The primary view content for the Basics sequence.
    var body: some View {
        VStack(alignment: .center, spacing: RA11ySpacing.xl) {
            headerSection
            currentStepCard
            continueButton
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: RA11ySpacing.sm) {
            Text(String(localized: "basicsSequence.title"))
                .font(.ra11yTitle)
                .bold()
                .multilineTextAlignment(.center)

            Text(stepProgressText)
                .font(.ra11ySubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var currentStepCard: some View {
        let definition = currentDefinition
        return VStack(spacing: RA11ySpacing.sm) {
            Text(LocalizedStringKey(definition.titleKey))
                .font(.ra11yHeadline)
                .multilineTextAlignment(.center)

            Text(LocalizedStringKey(definition.goalKey))
                .font(.ra11yBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(RA11ySpacing.lg)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: RA11yRadius.card))
    }

    private var continueButton: some View {
        Button(continueButtonTitle) {
            advance()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(continueAccessibilityLabel)
        .accessibilityHint(continueAccessibilityHint)
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

    private var continueButtonTitle: String {
        if isLastStep {
            return String(localized: "basicsSequence.finish")
        }
        return String(localized: "basicsSequence.continue")
    }

    private var continueAccessibilityLabel: String {
        if isLastStep {
            return String(localized: "basicsSequence.finish.a11yLabel")
        }
        return String(localized: "basicsSequence.continue.a11yLabel")
    }

    private var continueAccessibilityHint: String {
        if isLastStep {
            return String(localized: "basicsSequence.finish.a11yHint")
        }
        return String(localized: "basicsSequence.continue.a11yHint")
    }

    private var isLastStep: Bool {
        currentIndex == steps.count - 1
    }

    // MARK: - Actions

    private func advance() {
        if !isLastStep {
            currentIndex += 1
        } else {
            Task {
                guard !Task.isCancelled else { return }
                await storage.markBasicsCompleted()
                router.popToRoot()
            }
        }
    }
}

#Preview("Basics Sequence") {
    NavigationStack {
        iOSBasicsSequenceView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
