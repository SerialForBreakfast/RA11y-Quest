import SwiftUI
import RA11yCore

// MARK: - iOSHubFooterView

/// Pinned footer containing the "VoiceOver Basics" button and the conditional
/// "Enable VoiceOver to play" help affordance.
///
/// Used as a `.safeAreaInset(edge: .bottom)` on the hub's `ScrollView` — SwiftUI
/// automatically adds equivalent bottom content inset to the scroll view so the
/// last quest card is never hidden behind the footer. No manual padding required.
///
/// ## Help Affordance
/// `showHelpAffordance` is driven by `HubViewModel.showHelpAffordance`. When `true`
/// (VoiceOver OFF), the button is inserted into the hierarchy. When `false`, it is
/// absent entirely — not just hidden — so VoiceOver cannot focus it.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSHubFooterView: View {

    // MARK: - Properties

    /// Whether to show the VoiceOver enable affordance (VO is currently OFF).
    let showHelpAffordance: Bool

    /// Called when the user taps "VoiceOver Basics".
    let onVoiceOverBasics: () -> Void

    /// Called when the user taps "Enable VoiceOver to play".
    let onEnableVoiceOver: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: RA11ySpacing.sm) {
            if showHelpAffordance {
                enableVoiceOverButton
            }
            voiceOverBasicsButton
        }
        .padding(.horizontal, RA11ySpacing.lg)
        .padding(.vertical, RA11ySpacing.md)
        .background(.ultraThinMaterial)
    }

    // MARK: - Subviews

    /// "VoiceOver Basics" — always visible.
    private var voiceOverBasicsButton: some View {
        Button(action: onVoiceOverBasics) {
            Label(
                String(localized: "hub.voiceOverBasics"),
                systemImage: "scroll"
            )
            .font(.ra11ySubheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(Color.ra11yAccent)
    }

    /// "Enable VoiceOver to play" — present only when VoiceOver is OFF.
    private var enableVoiceOverButton: some View {
        Button(action: onEnableVoiceOver) {
            Label(
                String(localized: "hub.enableVoiceOver"),
                systemImage: "speaker.wave.2"
            )
            .font(.ra11ySubheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .tint(Color(red: 0.75, green: 0.55, blue: 0.10))
    }
}

// MARK: - Previews

#Preview("VO OFF — both buttons") {
    iOSHubFooterView(
        showHelpAffordance: true,
        onVoiceOverBasics: {},
        onEnableVoiceOver: {}
    )
    .background(Color(white: 0.12))
}

#Preview("VO ON — basics only") {
    iOSHubFooterView(
        showHelpAffordance: false,
        onVoiceOverBasics: {},
        onEnableVoiceOver: {}
    )
    .background(Color(white: 0.12))
}
