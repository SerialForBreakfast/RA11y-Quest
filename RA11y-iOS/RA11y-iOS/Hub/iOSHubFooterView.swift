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
        .background(footerBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.ra11yGoldDeep.opacity(0.35))
                .frame(height: 1)
        }
    }

    // MARK: - Subviews

    /// "VoiceOver Basics" — always visible.
    private var voiceOverBasicsButton: some View {
        Button(action: onVoiceOverBasics) {
            HStack(spacing: RA11ySpacing.sm) {
                Image(systemName: "scroll")
                Text(String(localized: "hub.voiceOverBasics"))
                    .fontWeight(.semibold)
            }
            .font(.ra11ySubheadline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BasicsScrollButtonStyle())
        .controlSize(.regular)
    }

    /// "Enable VoiceOver to play" — present only when VoiceOver is OFF.
    private var enableVoiceOverButton: some View {
        Button(action: onEnableVoiceOver) {
            HStack(spacing: RA11ySpacing.sm) {
                Image(systemName: "speaker.wave.2")
                Text(String(localized: "hub.enableVoiceOver"))
                    .fontWeight(.semibold)
            }
            .font(.ra11ySubheadline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(EnableVoiceOverButtonStyle())
        .controlSize(.regular)
    }

    private var footerBackground: some View {
        LinearGradient(
            colors: [
                Color.ra11yFooterSurface.opacity(0.95),
                Color.black.opacity(0.65)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Button Styles

private struct BasicsScrollButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: RA11yRadius.button)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.88, green: 0.82, blue: 0.70),
                                Color(red: 0.73, green: 0.64, blue: 0.46)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RA11yRadius.button)
                            .stroke(Color.ra11yGoldDeep.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            )
            .foregroundStyle(Color.black.opacity(0.85))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

private struct EnableVoiceOverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: RA11yRadius.button)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.ra11yGold,
                                Color.ra11yGoldDeep
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RA11yRadius.button)
                            .stroke(Color.ra11yGoldDeep.opacity(0.9), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
            )
            .foregroundStyle(Color.black.opacity(0.9))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
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
