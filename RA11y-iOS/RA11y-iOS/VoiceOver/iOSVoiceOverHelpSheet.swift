import SwiftUI
import RA11yCore

/// A modal sheet explaining how to enable VoiceOver and perform key gestures.
///
/// Present this when the user taps the help affordance. The sheet is fully
/// navigable with VoiceOver and uses semantic headings, labeled steps,
/// and minimum 44pt tap targets throughout.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSVoiceOverHelpSheet: View {

    @Environment(\.dismiss) private var dismiss: DismissAction

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: RA11ySpacing.lg) {
                        headerSection
                        // Scroll gestures first: users often open this sheet to learn how to
                        // move inside RA11y before reading full enable steps.
                        scrollGesturesSection
                        Divider()
                        enableStepsSection
                        Divider()
                        quickToggleSection
                        Divider()
                        inAppUsageSection
                    }
                    .padding(RA11ySpacing.xl)
                    .frame(width: geo.size.width)
                    .frame(maxWidth: .infinity)
                }
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(String(localized: "voiceOverHelp.navigationTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "voiceOverHelp.done")) {
                        dismiss()
                    }
                    .accessibilityLabel(Text(String(localized: "voiceOverHelp.done.accessibilityLabel")))
                    .accessibilityHint(Text(String(localized: "voiceOverHelp.done.accessibilityHint")))
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "voiceOverHelp.header.title"))
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text(String(localized: "voiceOverHelp.header.body"))
                .font(.ra11yBody)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var enableStepsSection: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.base) {
            VOHelpStepRow(
                icon: VOHelpSettingsGearIcon(),
                title: String(localized: "voiceOverHelp.step1.title"),
                detail: String(localized: "voiceOverHelp.step1.detail")
            )
            VOHelpStepRow(
                icon: VOHelpAccessibilityPersonIcon(),
                title: String(localized: "voiceOverHelp.step2.title"),
                detail: String(localized: "voiceOverHelp.step2.detail")
            )
            VOHelpStepRow(
                icon: VOHelpSpeakerWaveIcon(),
                title: String(localized: "voiceOverHelp.step3.title"),
                detail: String(localized: "voiceOverHelp.step3.detail")
            )
        }
    }

    private var quickToggleSection: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "voiceOverHelp.quickToggle.title"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: RA11ySpacing.md) {
                VOHelpTripleClickButtonIcon()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
                    Text(String(localized: "voiceOverHelp.quickToggle.body"))
                        .font(.ra11yBody)
                    Text(String(localized: "voiceOverHelp.quickToggle.tip"))
                        .font(.ra11ySubheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var scrollGesturesSection: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "voiceOverHelp.scroll.title"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: RA11ySpacing.md) {
                HStack(alignment: .top, spacing: RA11ySpacing.md) {
                    VOHelpThreeFingerSwipeIcon(direction: .up)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                    Text(String(localized: "voiceOverHelp.scroll.swipeUp"))
                        .font(.ra11yBody)
                }
                HStack(alignment: .top, spacing: RA11ySpacing.md) {
                    VOHelpThreeFingerSwipeIcon(direction: .down)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                    Text(String(localized: "voiceOverHelp.scroll.swipeDown"))
                        .font(.ra11yBody)
                }
                Text(String(localized: "voiceOverHelp.scroll.tip"))
                    .font(.ra11ySubheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var inAppUsageSection: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "voiceOverHelp.inApp.title"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(String(localized: "voiceOverHelp.inApp.body"))
                .font(.ra11yBody)
        }
    }
}

// MARK: - Step Row

/// A labeled step combining a decorative icon, title, and detail text.
///
/// The entire row is combined into a single accessibility element.
private struct VOHelpStepRow<Icon: View>: View {
    let icon: Icon
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: RA11ySpacing.md) {
            icon
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.ra11yBody)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Decorative Vector Icons

/// Settings gear — represents the Settings app.
private struct VOHelpSettingsGearIcon: View {
    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 2)
            Circle().stroke(lineWidth: 2).frame(width: 14, height: 14)
            ForEach(0..<6) { i in
                Rectangle()
                    .frame(width: 3, height: 10)
                    .offset(y: -16)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
        }
        .padding(6)
    }
}

/// Person in circle — represents Accessibility settings.
private struct VOHelpAccessibilityPersonIcon: View {
    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 2)
            Circle().stroke(lineWidth: 2).frame(width: 10, height: 10).offset(y: -6)
            Path { p in
                p.move(to: CGPoint(x: 14, y: 30))
                p.addQuadCurve(to: CGPoint(x: 30, y: 30), control: CGPoint(x: 22, y: 20))
            }
            .stroke(lineWidth: 2)
        }
        .padding(6)
    }
}

/// Speaker with wave arcs — represents VoiceOver / speech output.
private struct VOHelpSpeakerWaveIcon: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 10, y: 18))
                p.addLine(to: CGPoint(x: 16, y: 18))
                p.addLine(to: CGPoint(x: 22, y: 12))
                p.addLine(to: CGPoint(x: 22, y: 32))
                p.addLine(to: CGPoint(x: 16, y: 26))
                p.addLine(to: CGPoint(x: 10, y: 26))
                p.closeSubpath()
            }.stroke(lineWidth: 2)
            Path { p in
                p.addArc(center: CGPoint(x: 25, y: 22), radius: 8,
                         startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
            }.stroke(lineWidth: 2)
            Path { p in
                p.addArc(center: CGPoint(x: 25, y: 22), radius: 12,
                         startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
            }.stroke(lineWidth: 2)
        }
        .padding(6)
    }
}

/// Side button with triple-click dots — represents the Accessibility Shortcut gesture.
private struct VOHelpTripleClickButtonIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).stroke(lineWidth: 2)
            RoundedRectangle(cornerRadius: 2).frame(width: 4, height: 16).offset(x: 18)
            VStack(spacing: 4) {
                Circle().frame(width: 4, height: 4)
                Circle().frame(width: 4, height: 4)
                Circle().frame(width: 4, height: 4)
            }
            .offset(x: 2)
        }
        .padding(6)
    }
}

private enum VOHelpSwipeDirection { case up, down }

/// Three-finger swipe gesture illustration.
private struct VOHelpThreeFingerSwipeIcon: View {
    let direction: VOHelpSwipeDirection

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).stroke(lineWidth: 2)
            HStack(spacing: 6) {
                Capsule().frame(width: 6, height: 14)
                Capsule().frame(width: 6, height: 14)
                Capsule().frame(width: 6, height: 14)
            }
            Path { p in
                switch direction {
                case .up:
                    p.move(to: CGPoint(x: 22, y: 30)); p.addLine(to: CGPoint(x: 22, y: 16))
                    p.addLine(to: CGPoint(x: 18, y: 20))
                    p.move(to: CGPoint(x: 22, y: 16)); p.addLine(to: CGPoint(x: 26, y: 20))
                case .down:
                    p.move(to: CGPoint(x: 22, y: 14)); p.addLine(to: CGPoint(x: 22, y: 28))
                    p.addLine(to: CGPoint(x: 18, y: 24))
                    p.move(to: CGPoint(x: 22, y: 28)); p.addLine(to: CGPoint(x: 26, y: 24))
                }
            }
            .stroke(lineWidth: 2)
        }
        .padding(6)
    }
}

#Preview {
    iOSVoiceOverHelpSheet()
}
