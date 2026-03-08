import OSLog
import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSVORequiredView

/// Interstitial screen shown when a user attempts to start a game with VoiceOver disabled.
///
/// ## Flow
/// 1. Explains that VoiceOver is required.
/// 2. **Primary CTA: "Ask Siri"** — shows Siri instructions for enabling VoiceOver.
///    This is the lowest-friction path for a user who has never used VoiceOver, since
///    Siri can toggle it without requiring any accessibility gestures.
/// 3. Secondary CTA: "Open Accessibility Settings" — deep-links to iOS Accessibility settings.
///    Falls back to the general Settings app if the deep link is unavailable.
///    If both fail, inline fallback instructions are revealed.
/// 4. Tertiary CTA: "How to Enable VoiceOver" — presents `iOSVoiceOverHelpSheet` with
///    step-by-step instructions and gesture guides.
/// 5. Back navigation returns the user to the hub.
///
/// ## Bootstrapping Problem
/// A user who has never used VoiceOver cannot navigate a VoiceOver-first interface to
/// enable it. Siri is the lowest-friction solution: they can speak the command without
/// any prior knowledge of gestures. The Siri CTA is therefore placed first.
///
/// ## No Preview Mode
/// There is no way to bypass this screen and enter a game without VoiceOver active.
/// The interstitial is a dead end until the user enables VoiceOver and navigates back.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSVORequiredView: View {

    // MARK: - Properties

    /// The game the user was attempting to start. Preserved so the hub can
    /// resume to the correct game after VoiceOver is enabled (M5+).
    let kind: GameKind

    // MARK: - Private State

    @Environment(iOSAppRouter.self) private var router
    @State private var showHelpSheet = false
    /// Set to true when both the deep link and the Settings fallback fail.
    @State private var showManualFallback = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: RA11ySpacing.xl) {
                headerSection
                ctaSection
                if showManualFallback {
                    manualFallbackSection
                }
            }
            .padding(RA11ySpacing.base)
        }
        .navigationTitle(String(localized: "voiceOverRequired.navigationTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(String(localized: "voiceOverRequired.returnToHub")) {
                    router.popToRoot()
                }
            }
        }
        .sheet(isPresented: $showHelpSheet) {
            iOSVoiceOverHelpSheet()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: RA11ySpacing.md) {
            Image(systemName: "accessibility")
                .font(.system(size: 64))
                .foregroundStyle(.primary)
                .accessibilityHidden(true)

            Text(String(localized: "voiceOverRequired.title"))
                .font(.ra11yTitle)
                .bold()
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("voRequired.title")

            Text(String(localized: "voiceOverRequired.body"))
                .font(.ra11yBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var ctaSection: some View {
        VStack(spacing: RA11ySpacing.sm) {
            // Siri is the primary path: no gestures required, works before any AT knowledge.
            siriCallout

            Button(String(localized: "voiceOverRequired.openSettings")) {
                openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Button(String(localized: "voiceOverRequired.howToEnable")) {
                showHelpSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
    }

    /// Siri shortcut callout — the lowest-friction VoiceOver enablement path for new users.
    ///
    /// Displayed as an informational card (not a tappable button) since Siri is invoked by
    /// the user speaking the phrase, not by the app. The card gives prominence to the phrase
    /// so the user knows exactly what to say.
    private var siriCallout: some View {
        VStack(spacing: RA11ySpacing.sm) {
            HStack(spacing: RA11ySpacing.sm) {
                Image(systemName: "waveform")
                    .font(.ra11yHeadline)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(String(localized: "voiceOverRequired.siri.heading"))
                    .font(.ra11ySubheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(String(localized: "voiceOverRequired.siri.phrase"))
                .font(.ra11yBody)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal, RA11ySpacing.sm)
                .padding(.vertical, RA11ySpacing.xs)
                .frame(maxWidth: .infinity)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: RA11yRadius.button))
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: RA11yRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(String(localized: "voiceOverRequired.siri.heading")). \(String(localized: "voiceOverRequired.siri.a11yLabel"))"
        )
    }

    /// Shown only when both the Accessibility deep link and the Settings fallback fail.
    /// Gives the user a manual path forward without leaving the app.
    private var manualFallbackSection: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Divider()
            Text(String(localized: "voiceOverRequired.settingsFallback"))
                .font(.ra11ySubheadline)
                .foregroundStyle(.secondary)
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    /// Attempts to open iOS Accessibility settings via a deep link.
    ///
    /// Strategy (best-effort):
    /// 1. Try `App-Prefs:root=Accessibility` — opens Accessibility settings directly.
    /// 2. If unavailable, fall back to `UIApplication.openSettingsURLString`.
    /// 3. If both fail, reveal inline manual instructions.
    private func openAccessibilitySettings() {
        Task {
            let accessibilityURL = URL(string: "App-Prefs:root=Accessibility")
            if let url = accessibilityURL, await UIApplication.shared.open(url) {
                RA11yLogger.navigation.info("Opened Accessibility settings via deep link.")
                return
            }

            RA11yLogger.navigation.info("Accessibility deep link failed; trying general Settings.")
            if let settingsURL = URL(string: UIApplication.openSettingsURLString),
               await UIApplication.shared.open(settingsURL) {
                return
            }

            RA11yLogger.navigation.error("Both Settings URLs failed; showing manual fallback.")
            withAnimation {
                showManualFallback = true
            }
        }
    }
}

// MARK: - Preview

#Preview("VO Required — Default") {
    NavigationStack {
        iOSVORequiredView(kind: .findAndFocus)
            .environment(iOSAppRouter())
    }
}

#Preview("VO Required — Manual Fallback") {
    NavigationStack {
        iOSVORequiredView(kind: .activateDoubleTap)
            .environment(iOSAppRouter())
    }
}
