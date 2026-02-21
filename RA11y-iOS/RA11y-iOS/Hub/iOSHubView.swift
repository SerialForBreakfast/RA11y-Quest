import SwiftUI
import RA11yCore

/// The game hub — central sandbox listing all available VoiceOver training games.
///
/// At M0 this is a navigable placeholder that validates routing, Dynamic Type,
/// and VoiceOver accessibility. Full catalog-driven implementation in M3.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSHubView: View {

    // MARK: - Body

    var body: some View {
        VStack(spacing: RA11ySpacing.lg) {
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
        }
        .padding(RA11ySpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ra11yBackground)
        .navigationTitle(String(localized: "hub.navigationTitle"))
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        iOSHubView()
    }
}
