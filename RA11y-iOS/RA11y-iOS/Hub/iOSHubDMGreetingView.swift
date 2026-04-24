import SwiftUI
import RA11yCore

// MARK: - iOSHubDMGreetingView

/// Atmospheric greeting header (copy uses `hub.dmGreeting`; narrator label is `dm.label` / Resonance Guide).
///
/// Non-interactive. Marked with `.isHeader` so VoiceOver announces it as a
/// section heading and users can navigate to it directly via the rotor.
///
/// Typography uses ``View/questPaintReadableText(_:)`` (`.sectionTitle`) so the line
/// reads clearly over the hub’s painted backdrop + scrim.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSHubDMGreetingView: View {

    // MARK: - Body

    var body: some View {
        Text(String(localized: "hub.dmGreeting"))
            .questPaintReadableText(.sectionTitle)
            .multilineTextAlignment(.center)
            // Explicit maxWidth ensures the text view fills the parent's proposed
            // width so centering and wrapping behave consistently across device sizes.
            .frame(maxWidth: .infinity)
            .padding(.horizontal, RA11ySpacing.xl)
            .padding(.vertical, RA11ySpacing.md)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("hub.dmGreeting")
    }
}

// MARK: - Preview

#Preview {
    iOSHubDMGreetingView()
        .background(Color.black)
}
