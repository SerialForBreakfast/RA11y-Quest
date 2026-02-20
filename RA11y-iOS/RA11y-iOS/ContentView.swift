//
//  ContentView.swift
//  RA11y-iOS
//
//  Created by Joseph McCraw on 2/19/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isShowingVoiceOverInfo: Bool = false

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .overlay(alignment: .bottomTrailing) {
            Button {
                self.isShowingVoiceOverInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .imageScale(.large)
                    .font(.title3)
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("VoiceOver help"))
            .accessibilityHint(Text("Shows steps to enable VoiceOver and navigate this screen"))
            .accessibilityAddTraits(.isButton)
            .safeAreaPadding([.trailing, .bottom], 16)
        }
        .sheet(isPresented: $isShowingVoiceOverInfo) {
            VoiceOverInfoSheet()
        }
    }
}

/// A modal sheet that explains how to enable VoiceOver and how to navigate scrollable content.
///
/// This view is intended to be readable and navigable under VoiceOver.
/// It uses semantic headings, clear step-by-step language, and large tap targets.
private struct VoiceOverInfoSheet: View {
    @Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    self.header

                    VoiceOverStepRow(
                        icon: SettingsGearIcon(),
                        title: "1. Open Settings",
                        detail: "Open the Settings app on your iPhone or iPad."
                    )

                    VoiceOverStepRow(
                        icon: AccessibilityPersonIcon(),
                        title: "2. Go to Accessibility",
                        detail: "In Settings, tap Accessibility."
                    )

                    VoiceOverStepRow(
                        icon: SpeakerWaveIcon(),
                        title: "3. Turn on VoiceOver",
                        detail: "Tap VoiceOver, then turn it on. VoiceOver changes how gestures work: single-tap selects an item and double-tap activates it."
                    )

                    Divider()

                    Group {
                        Text("Quick toggle")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                TripleClickButtonIcon()
                                    .frame(width: 44, height: 44)
                                    .accessibilityHidden(true)

                                Text("Set up an Accessibility Shortcut in Settings → Accessibility → Accessibility Shortcut. If VoiceOver is the only selected feature, you can toggle it on/off quickly by triple‑clicking the Side button (most iPhones), the Home button (older models), or the Top button (many iPads).")
                                    .font(.body)
                            }

                            Text("Tip: If triple‑clicking feels too fast, you can adjust click speed in Accessibility settings for the Side/Top/Home button.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }

                    Divider()

                    Group {
                        Text("Scrolling with VoiceOver")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                ThreeFingerSwipeIcon(direction: .up)
                                    .frame(width: 44, height: 44)
                                    .accessibilityHidden(true)

                                Text("To scroll down a page: swipe up with three fingers.")
                                    .font(.body)
                            }

                            HStack(alignment: .top, spacing: 12) {
                                ThreeFingerSwipeIcon(direction: .down)
                                    .frame(width: 44, height: 44)
                                    .accessibilityHidden(true)

                                Text("To scroll up a page: swipe down with three fingers.")
                                    .font(.body)
                            }

                            Text("If scrolling doesn’t work, make sure your fingers are slightly separated and swipe quickly.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .contain)
                    }

                    Divider()

                    Group {
                        Text("In this app")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)

                        Text("This help sheet is a ScrollView. With VoiceOver on, use three‑finger swipes to move through the content. Use the Done button to close.")
                            .font(.body)
                    }
                }
                .padding(20)
            }
            .navigationTitle("VoiceOver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        self.dismiss()
                    }
                    .accessibilityLabel(Text("Done"))
                    .accessibilityHint(Text("Closes VoiceOver help"))
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enable VoiceOver")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            Text("VoiceOver is Apple’s screen reader. It reads items on screen and changes how touch gestures behave.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A single step row with a simple vector icon.
private struct VoiceOverStepRow<Icon: View>: View {
    let icon: Icon
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Simple vector icons

/// A minimal gear-like icon used to represent Settings.
private struct SettingsGearIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 2)

            Circle()
                .stroke(lineWidth: 2)
                .frame(width: 14, height: 14)

            ForEach(0..<6) { index in
                Rectangle()
                    .frame(width: 3, height: 10)
                    .offset(y: -16)
                    .rotationEffect(.degrees(Double(index) * 60.0))
            }
        }
        .padding(6)
    }
}

/// A simple person-in-a-circle icon used to represent Accessibility.
private struct AccessibilityPersonIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 2)

            Circle()
                .stroke(lineWidth: 2)
                .frame(width: 10, height: 10)
                .offset(y: -6)

            Path { path in
                path.move(to: CGPoint(x: 14, y: 30))
                path.addQuadCurve(to: CGPoint(x: 30, y: 30), control: CGPoint(x: 22, y: 20))
            }
            .stroke(lineWidth: 2)
        }
        .padding(6)
    }
}

/// A speaker with sound waves.
private struct SpeakerWaveIcon: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 10, y: 18))
                path.addLine(to: CGPoint(x: 16, y: 18))
                path.addLine(to: CGPoint(x: 22, y: 12))
                path.addLine(to: CGPoint(x: 22, y: 32))
                path.addLine(to: CGPoint(x: 16, y: 26))
                path.addLine(to: CGPoint(x: 10, y: 26))
                path.closeSubpath()
            }
            .stroke(lineWidth: 2)

            Path { path in
                path.addArc(center: CGPoint(x: 25, y: 22), radius: 8, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
            }
            .stroke(lineWidth: 2)

            Path { path in
                path.addArc(center: CGPoint(x: 25, y: 22), radius: 12, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
            }
            .stroke(lineWidth: 2)
        }
        .padding(6)
    }
}

/// A minimal side-button triple-click illustration.
private struct TripleClickButtonIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(lineWidth: 2)

            RoundedRectangle(cornerRadius: 2)
                .frame(width: 4, height: 16)
                .offset(x: 18)

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

private enum SwipeDirection {
    case up
    case down
}

/// A three-finger swipe illustration.
private struct ThreeFingerSwipeIcon: View {
    let direction: SwipeDirection

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(lineWidth: 2)

            HStack(spacing: 6) {
                Capsule().frame(width: 6, height: 14)
                Capsule().frame(width: 6, height: 14)
                Capsule().frame(width: 6, height: 14)
            }

            Path { path in
                switch self.direction {
                case .up:
                    path.move(to: CGPoint(x: 22, y: 30))
                    path.addLine(to: CGPoint(x: 22, y: 16))
                    path.addLine(to: CGPoint(x: 18, y: 20))
                    path.move(to: CGPoint(x: 22, y: 16))
                    path.addLine(to: CGPoint(x: 26, y: 20))
                case .down:
                    path.move(to: CGPoint(x: 22, y: 14))
                    path.addLine(to: CGPoint(x: 22, y: 28))
                    path.addLine(to: CGPoint(x: 18, y: 24))
                    path.move(to: CGPoint(x: 22, y: 28))
                    path.addLine(to: CGPoint(x: 26, y: 24))
                }
            }
            .stroke(lineWidth: 2)
        }
        .padding(6)
    }
}

#Preview {
    ContentView()
}
