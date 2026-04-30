import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSFirstSpellScreenshotState

/// Deterministic render state for first-spell screenshot captures.
///
/// Use `nil` for normal interactive behavior.
enum iOSFirstSpellScreenshotState: Hashable {
    /// First spell ready for Magic Tap.
    case ready
    /// Spell cast succeeded; continue action visible.
    case success
}

// MARK: - iOSMagicTapFirstSpellView

/// First-run Magic Tap practice surface shown before the Basics sequence.
///
/// Teaches one behavior: **Magic Tap** (two-finger double-tap) triggers the current
/// primary action. The full scene handles ``AccessibilityAction/magicTap`` so players
/// do not need focus on a specific button-like control.
///
/// ## Accessibility
/// - The screen root provides ``AccessibilityAction/magicTap``.
/// - Decorative symbols are hidden from accessibility.
/// - Help is a standard button and does not complete the step.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSMagicTapFirstSpellView: View {

    // MARK: - Properties

    let screenshotState: iOSFirstSpellScreenshotState?
    let onContinueBasics: () -> Void

    // MARK: - State

    @State private var isSpellLearned = false
    @State private var showHelpSheet = false
    @AccessibilityFocusState private var isContinueFocused: Bool

    // MARK: - Environment


    // MARK: - Init

    /// Creates the First Spell practice surface.
    ///
    /// - Parameters:
    ///   - screenshotState: Optional deterministic render state for screenshot capture.
    ///   - onContinueBasics: Invoked when the spell is learned and the user continues.
    init(
        screenshotState: iOSFirstSpellScreenshotState? = nil,
        onContinueBasics: @escaping () -> Void
    ) {
        self.screenshotState = screenshotState
        self.onContinueBasics = onContinueBasics
    }

    // MARK: - Body

    var body: some View {
        QuestPaintScreen(
            ambientImageName: "magictap_bg",
            layoutRole: .reading,
            accessibilityIdentifier: "firstSpell.screen"
        ) {
            VStack(spacing: RA11ySpacing.lg) {
                spellbookHero

                if isSpellLearned {
                    learnedCard
                } else {
                    readyCard
                }

                if isSpellLearned {
                    Button(String(localized: "firstSpell.continueBasics")) {
                        onContinueBasics()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityHint(String(localized: "firstSpell.continueBasics.a11yHint"))
                    .accessibilityFocused($isContinueFocused)
                    .accessibilityIdentifier("firstSpell.continueBasics")
                }

                Button(String(localized: "firstSpell.help")) {
                    showHelpSheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("firstSpell.help")
            }
            .padding(.vertical, RA11ySpacing.base)
        }
        .navigationTitle(String(localized: "firstSpell.navigationTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHelpSheet) {
            iOSVoiceOverHelpSheet()
        }
        .accessibilityAction(.magicTap, performMagicTapPrimaryAction)
        .onAppear {
            applyScreenshotStateIfNeeded()
        }
    }

    // MARK: - Subviews

    private var spellbookHero: some View {
        Image("magictap_spellbook_sigil")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 320)
            .accessibilityHidden(true)
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.md) {
            Text(String(localized: "firstSpell.ready.body.line1"))
            Text(String(localized: "firstSpell.ready.body.line2"))
            Text(String(localized: "firstSpell.ready.body.line3"))
        }
        .font(Font.ra11yBody.weight(.semibold))
        .foregroundStyle(Color.white.opacity(0.94))
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RA11ySpacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .stroke(Color.ra11yAccent.opacity(0.55), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(String(localized: "firstSpell.ready.body.line1")) \(String(localized: "firstSpell.ready.body.line2")) \(String(localized: "firstSpell.ready.body.line3"))"
        )
        .accessibilityHint(String(localized: "firstSpell.ready.a11yHint"))
        .accessibilityIdentifier("firstSpell.ready.card")
    }

    private var learnedCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "firstSpell.success.title"))
                .questPaintReadableText(.sectionTitle)
            Text(String(localized: "firstSpell.success.body"))
                .questPaintReadableText(.bodySupporting)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RA11ySpacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .stroke(Color.ra11yAccent.opacity(0.55), lineWidth: 1)
        )
        .accessibilityIdentifier("firstSpell.success.card")
    }

    // MARK: - Actions

    private func performMagicTapPrimaryAction() {
        if isSpellLearned {
            onContinueBasics()
        } else {
            castMagicTapSpell()
        }
    }

    private func castMagicTapSpell() {
        isSpellLearned = true
        isContinueFocused = true
        UIAccessibility.post(notification: .announcement, argument: String(localized: "firstSpell.success.announcement"))
    }

    private func applyScreenshotStateIfNeeded() {
        switch screenshotState {
        case .ready:
            isSpellLearned = false
        case .success:
            isSpellLearned = true
        case nil:
            break
        }
    }
}

#Preview("First Spell — Ready") {
    NavigationStack {
        iOSMagicTapFirstSpellView(screenshotState: .ready, onContinueBasics: {})
            .environment(\.colorScheme, .dark)
    }
}

#Preview("First Spell — Success") {
    NavigationStack {
        iOSMagicTapFirstSpellView(screenshotState: .success, onContinueBasics: {})
            .environment(\.colorScheme, .dark)
    }
}
