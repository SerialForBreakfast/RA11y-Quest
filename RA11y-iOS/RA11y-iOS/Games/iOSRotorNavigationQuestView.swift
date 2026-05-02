import Observation
import OSLog
import SwiftUI
import UIKit
import RA11yCore

// MARK: - RotorNavigationPhase

/// High-level beats for The Threefold Seal (Practice v1 — three beats, no Trial timer in ship).
private enum RotorNavigationPhase: Equatable {
    case prologue
    case beatHeadings
    case beatContainers
    case beatLinks
}

// MARK: - RotorNavigationQuestViewModel

/// Drives the Threefold Seal Practice flow: prologue plus three shallow rotor-navigation beats.
///
/// **Pedagogy:** Each beat uses real SwiftUI accessibility semantics (headings, combined
/// container regions, link traits) so VoiceOver’s Headings, Containers, and Links rotor
/// settings have honest targets. Wrong selections are detected by **which** control fired,
/// never by inspecting rotor UI state (ADR-0004 / ADR-0008).
///
/// **Scoring:** Practice is scored once at the end using elapsed wall time and
/// mistake count against ``RankThresholds/arcanistsTower`` so the shared result screen and
/// hub storage behave like other quests. A future Trial stage can reuse the same thresholds.
///
/// ## Concurrency
/// `@MainActor` — matches SwiftUI observation and storage writes.
@Observable
@MainActor
private final class RotorNavigationQuestViewModel {

    private(set) var phase: RotorNavigationPhase = .prologue
    private(set) var mistakes: Int = 0
    private(set) var completedResult: GameResult?
    private let storage: any StorageComponent
    private let sessionStartedAt: Date
    private var lastMistakeCountedAt: Date?

    /// Heading IDs for beat A (target: `dawn_oath`).
    static let headingTargetID = "dawn_oath"

    /// Container niche IDs for beat B (target: `niche_quiet`).
    static let containerTargetID = "niche_quiet"

    /// Link IDs for beat C (target: `mark_binding`).
    static let linkTargetID = "mark_binding"

    private static let mistakeCooldownSeconds: TimeInterval = 1.0

    init(storage: any StorageComponent) {
        self.storage = storage
        self.sessionStartedAt = Date()
    }

    /// Moves from prologue into the first rotor-navigation beat (Headings).
    func beginPracticeBeats() {
        phase = .beatHeadings
        postLayoutChangeAnnouncement(String(localized: "rotorThreeSeal.announce.beatHeadings"))
    }

    func recordWrongHeading() { recordMistake(String(localized: "rotorThreeSeal.wrong.heading")) }

    func recordWrongContainer() { recordMistake(String(localized: "rotorThreeSeal.wrong.container")) }

    func recordWrongLink() { recordMistake(String(localized: "rotorThreeSeal.wrong.link")) }

    private func recordMistake(_ announcement: String) {
        let now = Date()
        if let last = lastMistakeCountedAt, now.timeIntervalSince(last) < Self.mistakeCooldownSeconds {
            UIAccessibility.post(notification: .announcement, argument: announcement)
            return
        }
        lastMistakeCountedAt = now
        mistakes += 1
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    func completeHeadingBeat() {
        phase = .beatContainers
        postLayoutChangeAnnouncement(String(localized: "rotorThreeSeal.announce.beatContainers"))
    }

    func completeContainerBeat() {
        phase = .beatLinks
        postLayoutChangeAnnouncement(String(localized: "rotorThreeSeal.announce.beatLinks"))
    }

    func completeLinkBeat() {
        finishRun()
    }

    private func finishRun() {
        let elapsed = Date().timeIntervalSince(sessionStartedAt)
        let rank = RankThresholds.arcanistsTower.evaluate(timeSeconds: elapsed, mistakes: mistakes)
        let result = GameResult(
            gameID: "arcanists-tower",
            rank: rank,
            timeSeconds: elapsed,
            mistakes: mistakes
        )
        Task { await storage.saveResultIfBetter(result) }
        completedResult = result
    }

    private func postLayoutChangeAnnouncement(_ line: String) {
        UIAccessibility.post(notification: .announcement, argument: line)
    }
}

// MARK: - iOSRotorNavigationQuestView

/// The Threefold Seal — rotor navigation Practice (Headings → Containers → Links).
///
/// Implements the slim v1 scope in ADR-0008 and `GameSpec-ArcanistsTower.txt`. Reuses
/// ``QuestPaintScreen`` / hub-adjacent chrome patterns from other quests.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSRotorNavigationQuestView: View {

    @State private var viewModel: RotorNavigationQuestViewModel
    @Environment(iOSAppRouter.self) private var router
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    init(storage: any StorageComponent) {
        _viewModel = State(initialValue: RotorNavigationQuestViewModel(storage: storage))
    }

    var body: some View {
        QuestPaintScreen(
            ambientImageName: GameKind.arcanistsTower.questLessonAmbientImageName,
            layoutRole: .lesson,
            gameKind: .arcanistsTower
        ) {
            VStack(alignment: .leading, spacing: RA11ySpacing.md) {
                sealProgress
                phaseContent
            }
            .padding(.horizontal, RA11ySpacing.md)
            .padding(.vertical, RA11ySpacing.sm)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.completedResult) { _, result in
            guard let result else { return }
            router.push(
                .gameResult(
                    result,
                    gameKind: .arcanistsTower,
                    gameSpecificAnnouncement: String(localized: "rotorThreeSeal.result.flavor")
                )
            )
        }
        .onChange(of: voiceOverEnabled) { _, enabled in
            if !enabled {
                router.push(.voiceOverInterstitial(kind: .arcanistsTower))
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.phase {
        case .prologue:
            return String(localized: "rotorThreeSeal.prologue.title")
        case .beatHeadings:
            return String(localized: "rotorThreeSeal.beat.headings.title")
        case .beatContainers:
            return String(localized: "rotorThreeSeal.beat.containers.title")
        case .beatLinks:
            return String(localized: "rotorThreeSeal.beat.links.title")
        }
    }

    private var sealProgress: some View {
        Text(progressVisibleTitle)
        .questPaintReadableText(.captionGold)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(progressAccessibilityLabel)
    }

    private var progressVisibleTitle: String {
        switch viewModel.phase {
        case .prologue:
            return String(localized: "rotorThreeSeal.progress.visible.prologue")
        case .beatHeadings:
            return String(localized: "rotorThreeSeal.progress.visible.one")
        case .beatContainers:
            return String(localized: "rotorThreeSeal.progress.visible.two")
        case .beatLinks:
            return String(localized: "rotorThreeSeal.progress.visible.three")
        }
    }

    private var progressAccessibilityLabel: String {
        switch viewModel.phase {
        case .prologue:
            return String(localized: "rotorThreeSeal.progress.a11y.prologue")
        case .beatHeadings:
            return String(localized: "rotorThreeSeal.progress.a11y.one")
        case .beatContainers:
            return String(localized: "rotorThreeSeal.progress.a11y.two")
        case .beatLinks:
            return String(localized: "rotorThreeSeal.progress.a11y.three")
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch viewModel.phase {
        case .prologue:
            prologueStack
        case .beatHeadings:
            headingsBeat
        case .beatContainers:
            containersBeat
        case .beatLinks:
            linksBeat
        }
    }

    private var prologueStack: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.md) {
            Text(String(localized: "rotorThreeSeal.prologue.body"))
                .questPaintReadableText(.bodySupporting)
            Button(String(localized: "rotorThreeSeal.prologue.continue")) {
                viewModel.beginPracticeBeats()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("rotorThreeSeal.prologue.continue")
        }
    }

    private var headingsBeat: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "rotorThreeSeal.beat.headings.objective"))
                .questPaintReadableText(.bodyEmphasis)
            Text(String(localized: "rotorThreeSeal.practice.hint.headings"))
                .questPaintReadableText(.bodySupporting)
            headingButton(title: String(localized: "rotorThreeSeal.heading.ash"), id: "chapter_ash")
            headingButton(title: String(localized: "rotorThreeSeal.heading.ember"), id: "chapter_ember")
            headingButton(title: String(localized: "rotorThreeSeal.heading.dawn"), id: RotorNavigationQuestViewModel.headingTargetID)
            headingButton(title: String(localized: "rotorThreeSeal.heading.cinders"), id: "chapter_cinders")
        }
        .accessibilityIdentifier("rotorThreeSeal.beat.headings")
    }

    private func headingButton(title: String, id: String) -> some View {
        Button {
            if id == RotorNavigationQuestViewModel.headingTargetID {
                viewModel.completeHeadingBeat()
            } else {
                viewModel.recordWrongHeading()
            }
        } label: {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(RA11ySpacing.sm)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: RA11yRadius.card))
        }
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("rotorThreeSeal.heading.\(id)")
    }

    private var containersBeat: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "rotorThreeSeal.beat.containers.objective"))
                .questPaintReadableText(.bodyEmphasis)
            Text(String(localized: "rotorThreeSeal.practice.hint.containers"))
                .questPaintReadableText(.bodySupporting)
            nicheGroup(id: "niche_iron", label: String(localized: "rotorThreeSeal.niche.iron"))
            nicheGroup(id: RotorNavigationQuestViewModel.containerTargetID, label: String(localized: "rotorThreeSeal.niche.quiet"))
            nicheGroup(id: "niche_bond", label: String(localized: "rotorThreeSeal.niche.bond"))
        }
        .accessibilityIdentifier("rotorThreeSeal.beat.containers")
    }

    private func nicheGroup(id: String, label: String) -> some View {
        Group {
            VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
                Text(label)
                    .questPaintReadableText(.bodyEmphasis)
                Button(String(localized: "rotorThreeSeal.niche.open")) {
                    if id == RotorNavigationQuestViewModel.containerTargetID {
                        viewModel.completeContainerBeat()
                    } else {
                        viewModel.recordWrongContainer()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(RA11ySpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: RA11yRadius.card))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityIdentifier("rotorThreeSeal.niche.\(id)")
    }

    private var linksBeat: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "rotorThreeSeal.beat.links.objective"))
                .questPaintReadableText(.bodyEmphasis)
            Text(String(localized: "rotorThreeSeal.practice.hint.links"))
                .questPaintReadableText(.bodySupporting)
            Text(String(localized: "rotorThreeSeal.links.prose"))
                .questPaintReadableText(.bodySupporting)
            linkRow(title: String(localized: "rotorThreeSeal.link.binding"), id: RotorNavigationQuestViewModel.linkTargetID)
            linkRow(title: String(localized: "rotorThreeSeal.link.bonding"), id: "mark_bonding")
            linkRow(title: String(localized: "rotorThreeSeal.link.ember"), id: "mark_ember")
        }
        .accessibilityIdentifier("rotorThreeSeal.beat.links")
    }

    private func linkRow(title: String, id: String) -> some View {
        Button {
            if id == RotorNavigationQuestViewModel.linkTargetID {
                viewModel.completeLinkBeat()
            } else {
                viewModel.recordWrongLink()
            }
        } label: {
            Text(title)
                .underline()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
        .accessibilityIdentifier("rotorThreeSeal.link.\(id)")
    }
}
