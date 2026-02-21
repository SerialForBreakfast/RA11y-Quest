import SwiftUI
import RA11yCore

// MARK: - iOSHubView

/// The game hub — central screen listing all available VoiceOver training games.
///
/// At M2 this is a navigable placeholder that validates VoiceOver help affordance
/// visibility. Full catalog-driven implementation in M3.
///
/// ## Help Affordance
/// Uses `if viewModel.showHelpAffordance { ... }` — NOT `.hidden()` — so the
/// affordance is fully absent from the view hierarchy when VoiceOver is active.
/// This prevents VoiceOver from landing on or announcing a hidden help button.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSHubView: View {

    // MARK: - State

    /// View model sourced from the live VoiceOver provider.
    /// Reactive: `showHelpAffordance` updates whenever VoiceOver is toggled.
    @State private var viewModel = HubViewModel(
        voiceOverProvider: iOSLiveVoiceOverStateProvider()
    )

    @State private var showHelpSheet = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: RA11ySpacing.lg) {
            Spacer()

            Image(systemName: "figure.walk.motion")
                .font(.system(size: 64))
                .foregroundStyle(Color.ra11yAccent)
                .accessibilityHidden(true)

            Text(String(localized: "hub.title"))
                .font(.ra11yLargeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "hub.subtitle"))
                .font(.ra11yBody)
                .foregroundStyle(Color.ra11ySecondaryLabel)
                .multilineTextAlignment(.center)

            Spacer()

            // Help affordance — present only when VoiceOver is OFF.
            // Removed from the hierarchy entirely when VO is ON so it is
            // not focusable by VoiceOver (per M2-HelpAffordance-Visibility).
            if viewModel.showHelpAffordance {
                helpAffordance
            }
        }
        .padding(RA11ySpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ra11yBackground)
        .navigationTitle(String(localized: "hub.navigationTitle"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showHelpSheet) {
            iOSVoiceOverHelpSheet()
        }
    }

    // MARK: - Subviews

    /// "How to enable VoiceOver" entry point. Only inserted when VO is OFF.
    private var helpAffordance: some View {
        Button {
            showHelpSheet = true
        } label: {
            Label(
                String(localized: "hub.helpAffordance"),
                systemImage: "questionmark.circle"
            )
            .font(.ra11ySubheadline)
        }
        .buttonStyle(.bordered)
        .padding(.bottom, RA11ySpacing.sm)
    }
}

// MARK: - Previews

#Preview("VO Off — help affordance visible") {
    NavigationStack {
        iOSHubView()
    }
}
