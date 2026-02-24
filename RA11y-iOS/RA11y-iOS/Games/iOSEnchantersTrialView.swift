import os
import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSEnchantersTrialView

/// The Enchanter's Trial (Find & Focus) — L1 minimal playable screen.
///
/// Presents a prompt card and a grid of relics. The player must select
/// the named relic; mistakes are recorded and the session completes on
/// a correct selection.
struct iOSEnchantersTrialView: View {

    // MARK: - Private State

    @State private var session: GameSession
    @State private var coordinator: GameSessionCoordinator
    @State private var relics: [EnchanterRelic]
    @State private var targetRelic: EnchanterRelic
    @State private var statusMessage: String?
    @State private var hasStartedSession = false
    @State private var isCompleting = false

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    // MARK: - Init

    /// Creates the Enchanter's Trial view with the provided storage backend.
    ///
    /// - Parameter storage: Persistence layer for game results.
    init(storage: any StorageComponent) {
        let session = GameSession(
            gameID: "find-and-focus",
            thresholds: .findAndFocus,
            storage: storage
        )
        let relics = EnchanterRelic.all
        let targetRelic = EnchanterRelic.target(from: relics)
        _session = State(initialValue: session)
        _coordinator = State(
            initialValue: GameSessionCoordinator(
                session: session,
                gameKind: .findAndFocus,
                voiceOverProvider: iOSLiveVoiceOverStateProvider()
            )
        )
        _relics = State(initialValue: relics)
        _targetRelic = State(initialValue: targetRelic)
    }

    // MARK: - Body

    var body: some View {
        content
            .background {
                EnchanterBackgroundView()
            }
            .navigationTitle(String(localized: "game.findAndFocus.title"))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await startSessionIfNeeded()
            }
            .onChange(of: coordinator.voiceOverDisabledMidGame) { _, disabled in
                if disabled {
                    router.push(.voiceOverInterstitial(kind: .findAndFocus))
                }
            }
            .onDisappear {
                coordinator.stopMonitoring()
            }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView(.vertical) {
            VStack(spacing: RA11ySpacing.lg) {
                promptCard
                relicGrid
                statusMessageView
            }
            .padding(.horizontal, RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("enchanter.trial")
        }
    }

    private var contentMaxWidth: CGFloat {
        sizeClass == .regular ? 720 : .infinity
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(format: String(localized: "enchanter.prompt.format"), targetRelic.displayName))
                .font(.ra11yHeadline)
                .bold()
                .accessibilityLabel(
                    String(format: String(localized: "enchanter.prompt.format"), targetRelic.displayName)
                )
                .accessibilityHint(String(localized: "enchanter.prompt.a11yHint"))

            Text(String(localized: "enchanter.prompt.instructions"))
                .font(.ra11yBody)
                .foregroundStyle(.secondary)

            Button(String(localized: "enchanter.hint.button")) {
                statusMessage = String(
                    format: String(localized: "enchanter.hint.format"),
                    targetRelic.displayName
                )
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(String(localized: "enchanter.hint.a11yLabel"))
            .accessibilityHint(String(localized: "enchanter.hint.a11yHint"))
        }
        .padding(RA11ySpacing.base)
        .background(
            .ultraThinMaterial,
            in: .rect(cornerRadius: RA11yRadius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var relicGrid: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "enchanter.relics.header"))
                .font(.ra11yHeadline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: gridColumns, spacing: RA11ySpacing.sm) {
                ForEach(relics) { relic in
                    relicButton(relic)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var gridColumns: [GridItem] {
        let count = sizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: RA11ySpacing.sm), count: count)
    }

    private func relicButton(_ relic: EnchanterRelic) -> some View {
        Button {
            handleRelicSelection(relic)
        } label: {
            VStack(spacing: RA11ySpacing.sm) {
                RelicImage(assetName: relic.assetName)
                    .frame(height: 72)

                Text(relic.displayName)
                    .font(.ra11ySubheadline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(RA11ySpacing.md)
            .background(
                Color.black.opacity(0.2),
                in: .rect(cornerRadius: RA11yRadius.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RA11yRadius.card)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
        }
        .accessibilityLabel(relic.displayName)
        .accessibilityHint(String(localized: "enchanter.relic.a11yHint"))
    }

    @ViewBuilder
    private var statusMessageView: some View {
        if let statusMessage {
            Text(statusMessage)
                .font(.ra11ySubheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func handleRelicSelection(_ relic: EnchanterRelic) {
        guard !isCompleting else { return }
        if relic == targetRelic {
            isCompleting = true
            Task { await completeSession() }
        } else {
            Task { await recordMistake(for: relic) }
        }
    }

    private func startSessionIfNeeded() async {
        guard !hasStartedSession else { return }
        hasStartedSession = true
        coordinator.startMonitoring()
        do {
            try await session.start()
        } catch {
            statusMessage = String(localized: "enchanter.startError")
            RA11yLogger.gameSession.error("Session start failed: \(error.localizedDescription)")
        }
    }

    private func recordMistake(for relic: EnchanterRelic) async {
        do {
            try await session.recordMistake()
        } catch {
            statusMessage = String(localized: "enchanter.mistakeError")
            RA11yLogger.gameSession.error("Mistake record failed: \(error.localizedDescription)")
            return
        }
        statusMessage = String(
            format: String(localized: "enchanter.mistake.format"),
            relic.displayName
        )
    }

    private func completeSession() async {
        do {
            try await session.complete()
        } catch {
            statusMessage = String(localized: "enchanter.completeError")
            RA11yLogger.gameSession.error("Session complete failed: \(error.localizedDescription)")
            return
        }

        coordinator.stopMonitoring()
        statusMessage = String(
            format: String(localized: "enchanter.success.format"),
            targetRelic.displayName
        )

        let state = await session.state
        if case .completed(let result) = state {
            router.push(.gameResult(result))
        }
    }
}

// MARK: - EnchanterRelic

private struct EnchanterRelic: Identifiable, Hashable {
    let id: String
    let displayName: String
    let assetName: String

    static let all: [EnchanterRelic] = [
        EnchanterRelic(id: "dragon_scale", displayName: "Dragon Scale", assetName: "enchanter_relic_dragon_scale"),
        EnchanterRelic(id: "dragon_claw", displayName: "Dragon Claw", assetName: "enchanter_relic_dragon_claw"),
        EnchanterRelic(id: "shadow_stone", displayName: "Shadow Stone", assetName: "enchanter_relic_shadow_stone"),
        EnchanterRelic(id: "sunstone", displayName: "Sunstone", assetName: "enchanter_relic_sunstone"),
        EnchanterRelic(id: "ember_glass", displayName: "Ember Glass", assetName: "enchanter_relic_ember_glass"),
        EnchanterRelic(id: "frost_glass", displayName: "Frost Glass", assetName: "enchanter_relic_frost_glass"),
        EnchanterRelic(id: "iron_shard", displayName: "Iron Shard", assetName: "enchanter_relic_iron_shard"),
        EnchanterRelic(id: "moonstone", displayName: "Moonstone", assetName: "enchanter_relic_moonstone"),
    ]

    static func target(from relics: [EnchanterRelic]) -> EnchanterRelic {
        guard !relics.isEmpty else { return EnchanterRelic(id: "unknown", displayName: "Relic", assetName: "") }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return relics[0]
        }
        return relics.randomElement() ?? relics[0]
    }
}

// MARK: - RelicImage

private struct RelicImage: View {
    let assetName: String

    var body: some View {
        if let image = UIImage(named: assetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - EnchanterBackgroundView

private struct EnchanterBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.85), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            if let image = UIImage(named: "enchanter_tower_shelf_bg") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.45))
            }
        }
        .ignoresSafeArea()
    }
}

#Preview("Enchanter Trial") {
    NavigationStack {
        iOSEnchantersTrialView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
