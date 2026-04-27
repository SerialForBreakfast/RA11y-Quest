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

    // MARK: - Environment

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
        GeometryReader { geo in
            let horizontalPad = QuestPaintContentMetrics.scrollHorizontalPadding(
                containerWidth: geo.size.width,
                horizontalSizeClass: horizontalSizeClass,
                gameKind: nil
            )
            let readingMax = QuestPaintContentMetrics.readingColumnMaxWidth(
                containerWidth: geo.size.width,
                horizontalSizeClass: horizontalSizeClass,
                horizontalPadding: horizontalPad
            )
            ScrollView {
                VStack(spacing: RA11ySpacing.lg) {
                    magicTapSpellbookPlaceholder

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
                        .accessibilityIdentifier("firstSpell.continueBasics")
                    }

                    Button(String(localized: "firstSpell.help")) {
                        showHelpSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("firstSpell.help")
                }
                .padding(.horizontal, horizontalPad)
                .padding(.vertical, RA11ySpacing.base)
                .frame(maxWidth: readingMax)
                .frame(maxWidth: .infinity)
            }
        }
        .background {
            ZStack {
                Color(red: 0.08, green: 0.06, blue: 0.05)
                QuestPaintAmbientBackdrop(imageName: "simon_room_bg")
                QuestPaintReadableScrim()
            }
        }
        .navigationTitle(String(localized: "firstSpell.navigationTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHelpSheet) {
            iOSVoiceOverHelpSheet()
        }
        .accessibilityAction(.magicTap, castMagicTapSpell)
        .accessibilityElement(children: .contain)
        .onAppear {
            applyScreenshotStateIfNeeded()
        }
    }

    // MARK: - Subviews

    /// SF Symbol placeholder hero until final spellbook art is imported.
    private var magicTapSpellbookPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .fill(.black.opacity(0.32))
            VStack(spacing: RA11ySpacing.base) {
                ZStack {
                    Circle()
                        .stroke(Color.ra11yAccent.opacity(0.85), lineWidth: 2)
                        .frame(width: 180, height: 180)
                    Circle()
                        .stroke(Color.ra11yAccent.opacity(0.4), lineWidth: 1)
                        .frame(width: 220, height: 220)
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(Color.ra11yAccent.opacity(0.95))
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 126, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.16))
                        .offset(y: 24)
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
            .padding(RA11ySpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .stroke(Color.ra11yAccent.opacity(0.45), lineWidth: 1)
        )
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

    private func castMagicTapSpell() {
        guard !isSpellLearned else { return }
        isSpellLearned = true
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
