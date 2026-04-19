import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSLaunchLoadingView

/// Cold-start overlay with dungeon / guild-hall theming aligned to Crystal Resonance art direction.
///
/// Renders while `iOSRootView` resolves the initial route asynchronously. Background and orb
/// assets match the resonance shaft catalog when present; fallbacks keep the same torchlit mood.
///
/// ## Accessibility
/// Decorative imagery is hidden from VoiceOver; a single label conveys loading state so
/// announcements stay clear and are not duplicated by the visible taglines.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSLaunchLoadingView: View {

    @State private var orbBreathScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            launchAtmosphere
            RadialGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.78)],
                center: .center,
                startRadius: 60,
                endRadius: 520
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            VStack(spacing: RA11ySpacing.lg) {
                orbGlyph
                    .scaleEffect(orbBreathScale)
                    .accessibilityHidden(true)

                VStack(spacing: RA11ySpacing.sm) {
                    Text(String(localized: "app.loading.tagline"))
                        .font(.ra11yTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white.opacity(0.97))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                        .accessibilityHidden(true)

                    Text(String(localized: "app.loading.flavor"))
                        .font(.ra11ySubheadline)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, RA11ySpacing.lg)
                        .accessibilityHidden(true)
                }

                ProgressView(String(localized: "app.loading"))
                    .tint(Color.ra11yAccent)
                    .controlSize(.regular)
                    .padding(.top, RA11ySpacing.sm)
            }
            .padding(RA11ySpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ra11yGameFallbackBackground)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "app.loading.a11yLabel"))
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                orbBreathScale = 1.06
            }
        }
    }

    // MARK: - Layers

    private var launchAtmosphere: some View {
        Group {
            if let ui = UIImage(named: "dungeon_resonance_bg") {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, minHeight: 0)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.04, blue: 0.09),
                        Color(red: 0.11, green: 0.06, blue: 0.05),
                        Color(red: 0.05, green: 0.05, blue: 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var orbGlyph: some View {
        Group {
            if let ui = UIImage(named: "dungeon_resonance_orb_idle") {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .shadow(color: Color.ra11yAccent.opacity(0.45), radius: 16, y: 2)
            } else {
                Image(systemName: "diamond.circle.fill")
                    .font(.system(size: 72))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        Color.ra11yAccent.opacity(0.95),
                        Color.white.opacity(0.4)
                    )
                    .shadow(color: Color.ra11yAccent.opacity(0.35), radius: 12)
            }
        }
    }
}
