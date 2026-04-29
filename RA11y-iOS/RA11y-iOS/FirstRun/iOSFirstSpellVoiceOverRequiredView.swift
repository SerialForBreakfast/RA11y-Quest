import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSFirstSpellVoiceOverRequiredView

/// VoiceOver gate shown before entering First Spell when VoiceOver is off.
///
/// Uses first-spell-specific copy rather than a `GameKind` gate, while preserving
/// Siri-first guidance and Settings fallback behavior.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSFirstSpellVoiceOverRequiredView: View {

    private enum FocusTarget: Hashable {
        case continueButton
    }

    let onReturnToEntry: () -> Void
    let onVoiceOverEnabled: () -> Void

    private let voiceOverProvider: any VoiceOverStateProvider

    @State private var showHelpSheet = false
    @State private var showManualFallback = false
    @State private var voiceOverIsReady = false
    @State private var statusMessage: String?

    @AccessibilityFocusState private var focusedTarget: FocusTarget?

    init(
        voiceOverProvider: some VoiceOverStateProvider = iOSLiveVoiceOverStateProvider(),
        onReturnToEntry: @escaping () -> Void,
        onVoiceOverEnabled: @escaping () -> Void
    ) {
        self.voiceOverProvider = voiceOverProvider
        self.onReturnToEntry = onReturnToEntry
        self.onVoiceOverEnabled = onVoiceOverEnabled
    }

    var body: some View {
        QuestPaintScreen(
            ambientImageName: "simon_room_bg",
            layoutRole: .reading
        ) {
            VStack(alignment: .center, spacing: RA11ySpacing.xl) {
                headerSection
                ctaSection
                if showManualFallback {
                    manualFallbackSection
                }
            }
            .padding(.vertical, RA11ySpacing.lg)
        }
        .navigationTitle(String(localized: "firstSpellVORequired.navigationTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(String(localized: "firstSpellVORequired.returnToEntry")) {
                    onReturnToEntry()
                }
            }
        }
        .sheet(isPresented: $showHelpSheet) {
            iOSVoiceOverHelpSheet()
        }
        .onAppear {
            refreshVoiceOverState(announceChange: false, showOffStatus: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshVoiceOverState(announceChange: false)
        }
        .task {
            for await isRunning in voiceOverProvider.stateChanges {
                handleVoiceOverStateChange(isRunning)
            }
        }
        .onDisappear {
            focusedTarget = nil
        }
    }

    private var headerSection: some View {
        VStack(spacing: RA11ySpacing.md) {
            Image(systemName: "accessibility")
                .font(.system(size: 64))
                .foregroundStyle(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                .accessibilityHidden(true)

            Text(String(localized: "firstSpellVORequired.title"))
                .multilineTextAlignment(.center)
                .questPaintReadableText(.heroTitle)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("firstSpellVORequired.title")

            Text(String(localized: "firstSpellVORequired.body"))
                .multilineTextAlignment(.center)
                .questPaintReadableText(.bodySupporting)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

    private var ctaSection: some View {
        VStack(spacing: RA11ySpacing.sm) {
            if voiceOverIsReady {
                readySection
            } else {
                enableVoiceOverSection
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var enableVoiceOverSection: some View {
        VStack(spacing: RA11ySpacing.sm) {
            siriCallout

            Button(String(localized: "firstSpellVORequired.openSettings")) {
                openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Button(String(localized: "firstSpellVORequired.howToEnable")) {
                showHelpSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            if let statusMessage {
                statusText(statusMessage)
            }

            voiceOverCheckButton
        }
    }

    private var readySection: some View {
        VStack(spacing: RA11ySpacing.sm) {
            if let statusMessage {
                statusText(statusMessage)
            }

            Button(String(localized: "firstSpellVORequired.continue")) {
                onVoiceOverEnabled()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(String(localized: "firstSpellVORequired.continue"))
            .accessibilityHint(String(localized: "firstSpellVORequired.continue.accessibilityHint"))
            .accessibilityFocused($focusedTarget, equals: .continueButton)
            .accessibilityIdentifier("firstSpellVORequired.voiceOverEnabled")
        }
    }

    private var voiceOverCheckButton: some View {
        Button(String(localized: "firstSpellVORequired.iTurnedOnVoiceOver")) {
            handleVoiceOverEnabledButton()
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .frame(maxWidth: .infinity)
        .accessibilityHint(String(localized: "firstSpellVORequired.iTurnedOnVoiceOver.accessibilityHint"))
        .accessibilityIdentifier("firstSpellVORequired.voiceOverEnabled")
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .questPaintReadableText(.materialCardMeta)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("firstSpellVORequired.status")
    }

    private var siriCallout: some View {
        VStack(spacing: RA11ySpacing.sm) {
            HStack(spacing: RA11ySpacing.sm) {
                Image(systemName: "waveform")
                    .font(.ra11yHeadline)
                    .foregroundStyle(Color(red: 0.92, green: 0.72, blue: 0.38))
                    .accessibilityHidden(true)
                Text(String(localized: "firstSpellVORequired.siri.heading"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .questPaintReadableText(.materialCardTitle)
            }
            Text(String(localized: "firstSpellVORequired.siri.phrase"))
                .italic()
                .multilineTextAlignment(.center)
                .questPaintReadableText(.materialCardBody)
                .padding(.horizontal, RA11ySpacing.sm)
                .padding(.vertical, RA11ySpacing.xs)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: RA11yRadius.button))
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RA11yRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(String(localized: "firstSpellVORequired.siri.heading")). \(String(localized: "firstSpellVORequired.siri.a11yLabel"))"
        )
    }

    private var manualFallbackSection: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Divider().opacity(0.35)
            Text(String(localized: "firstSpellVORequired.settingsFallback"))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .questPaintReadableText(.materialCardMeta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }

    private func openAccessibilitySettings() {
        Task {
            let accessibilityURL = URL(string: "App-Prefs:root=Accessibility")
            if let url = accessibilityURL, await UIApplication.shared.open(url) {
                return
            }
            if let settingsURL = URL(string: UIApplication.openSettingsURLString),
               await UIApplication.shared.open(settingsURL) {
                return
            }
            withAnimation {
                showManualFallback = true
            }
        }
    }

    private func refreshVoiceOverState(announceChange: Bool, showOffStatus: Bool = true) {
        handleVoiceOverStateChange(
            voiceOverProvider.isVoiceOverRunning,
            announceChange: announceChange,
            showOffStatus: showOffStatus
        )
    }

    private func handleVoiceOverStateChange(
        _ isRunning: Bool,
        announceChange: Bool = true,
        showOffStatus: Bool = true
    ) {
        guard isRunning || showOffStatus else { return }
        guard voiceOverIsReady != isRunning || statusMessage == nil else { return }
        withAnimation {
            voiceOverIsReady = isRunning
            statusMessage = String(
                localized: isRunning
                ? "firstSpellVORequired.voiceOverReady"
                : "firstSpellVORequired.voiceOverStillOff"
            )
        }
        if announceChange {
            UIAccessibility.post(notification: .announcement, argument: statusMessage)
        }
        if isRunning {
            focusContinueButton()
        } else {
            focusedTarget = nil
        }
    }

    private func handleVoiceOverEnabledButton() {
        let isRunning = voiceOverProvider.isVoiceOverRunning
        handleVoiceOverStateChange(isRunning, announceChange: true)
        guard isRunning else { return }
    }

    private func focusContinueButton() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            focusedTarget = .continueButton
        }
    }
}

#Preview("First Spell VO Required") {
    NavigationStack {
        iOSFirstSpellVoiceOverRequiredView(onReturnToEntry: {}, onVoiceOverEnabled: {})
    }
}
