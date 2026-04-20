import os
import SwiftUI
import UIKit
import RA11yCore

// MARK: - Resonance scroll diagnostics

/// Logs Crystal Resonance scroll and alignment diagnostics to OSLog (`scrollInteraction`) and,
/// in DEBUG builds, mirrors a single line to stdout for Xcode console filtering (`[RA11yScroll]`).
private func logResonanceScroll(_ message: String) {
    RA11yLogger.scrollInteraction.debug("\(message)")
    #if DEBUG
    print("[RA11yScroll] \(message)")
    #endif
}

// MARK: - Playfield coordinate space

/// Named space for alignment math: origin at top-left of the gameplay `ZStack` (between safe-area insets).
/// Moonstone `midY` and aim (`playfieldHeight * 0.5`) are both measured here—**not** `.global`, which is unstable during layout and produced bogus deltas (e.g. `targetMidY=10` vs `aimMidY=139`).
private enum ResonancePlayfieldCoordinateSpace {
    static let name = "resonancePlayfield"
}

/// Height of the playfield `ZStack` (between top/bottom chrome regions) for scroll content sizing.
///
/// The top and bottom chrome reserve a stable footprint, so this value should not jump when
/// controls appear or disappear during a phase.
private struct ResonancePlayfieldViewportHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

/// Measured top chrome height so the playfield can use only the visible remaining space.
private struct ResonanceTopChromeHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

/// Measured bottom chrome height so the playfield can use only the visible remaining space.
private struct ResonanceBottomChromeHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

// MARK: - VoiceOver sort tiers (playfield)

/// `accessibilitySortPriority` — **higher** values are read **earlier** in VoiceOver swipe order among peers.
/// Top HUD (objective, tips) must sort **before** the full-screen UIKit lane so titles and instructions are
/// not skipped; the lane sorts before bottom controls (seal, hint).
private enum iOSResonancePlayAccessibilitySortTier {
    static let topChrome: Double = 30
    static let moonstoneLaneScrollProxy: Double = 20
    static let bottomChrome: Double = 10
}

// MARK: - iOSDungeonResonancePlayView

/// Crystal Resonance gameplay surface (ADR-0003): fixed center orb, scrolling target lane,
/// activation only when the moonstone aligns with the aim line.
///
/// **VoiceOver:** The scroll lane is a UIKit ``iOSResonanceVoiceOverScrollProxyRepresentable`` (`UIScrollView`)
/// — a **single** element named “Moonstone alignment lane” for three-finger shaft scrolling. The UIKit
/// proxy restores deterministic VoiceOver landing on entry, while sort priority remains a secondary aid.
/// Aim/orb alignment and viewport height use scoped `GeometryReader` backgrounds + preference keys
/// (not a root wrapping `GeometryReader`).
///
/// **VoiceOver lane proxy:** The **visual** lane is a clipped, **non-scrolling** stack whose vertical
/// offset mirrors the UIKit scroller’s content offset (same lane label on the scroll view). Chamber
/// names on decoys are decorative; they are not separate VoiceOver items. The glyph column stays
/// `accessibilityHidden`. On iOS,
/// three-finger scrolling affects the scroll view associated with the **current VoiceOver focus**. The
/// lane proxy is auto-focused on entry, but the decorative glyph column still remains hidden from
/// accessibility so there is only one playfield scroll surface. Quests
/// cannot be entered without VoiceOver (see ``iOSAppRouter/pushGame(kind:provider:)``), so a
/// separate non-VO `ScrollView` path is not maintained here.
///
/// Lane glyphs are decorative; objectives, seal control, and timer affordances live in the fixed
/// chrome. Multimodal alignment feedback is driven from `DungeonDescentViewModel.updateResonanceDelta`.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSDungeonResonancePlayView: View {

    let rooms: [DungeonRoom]
    let targetIsReachable: Bool
    let statusMessage: String?
    let levelComplete: Bool
    let timeRemaining: Double?
    let timedOut: Bool
    let mistakes: Int
    let lightsOffMode: Bool
    let lightsOffFlavorText: String?
    let showsFirstLevelGestureTip: Bool

    /// Invoked when the moonstone's vertical alignment changes (playfield-space delta from the aim line).
    let onResonanceDeltaChanged: (CGFloat) -> Void

    let onActivateTarget: (DungeonRoom) async -> Void
    let onHint: (() -> Void)?
    let onContinue: (() -> Void)?
    let onRetry: (() -> Void)?

    @State private var displayDeltaPoints: CGFloat = 500

    /// Limits alignment telemetry spam while still capturing motion during scroll debugging.
    @State private var lastAlignmentLogTime: Date = .distantPast

    /// Vertical scroll offset driven by the UIKit proxy ``iOSResonanceVoiceOverScrollProxyRepresentable``; applied to the visual lane below.
    @State private var voiceOverProxyScrollOffsetY: CGFloat = 0

    /// Last moonstone vertical center in ``ResonancePlayfieldCoordinateSpace`` (paired with aim = `playfieldViewportHeight * 0.5`).
    @State private var lastTargetMidYInPlayfield: CGFloat = -10_000

    /// Playfield height between safe-area insets; drives minimum UIKit scroll content height so VoiceOver can scroll.
    @State private var playfieldViewportHeight: CGFloat = 600
    @State private var topChromeHeight: CGFloat = 0
    @State private var bottomChromeHeight: CGFloat = 0

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var aimBand: iOSResonanceAimBand {
        iOSResonanceAimBand.displayBand(deltaPoints: displayDeltaPoints, levelComplete: levelComplete)
    }

    /// Reserve enough height for the status row even when no transient message is visible.
    private var topChromeStatusSizingMessage: String {
        String(localized: "dungeon.resonance.hint")
    }

    /// Geometric height of the glyph column only (rows + spacing), before any scroll slack.
    private var voiceOverLaneIntrinsicBlockHeight: CGFloat {
        let n = rooms.count
        guard n > 0 else { return RA11ySpacing.xl * 2 }
        return CGFloat(n) * iOSDungeonResonanceLaneLayout.rowContentHeightPoints
            + CGFloat(n - 1) * iOSDungeonResonanceLaneLayout.rowSpacingPoints
    }

    /// Scroll content block height passed to the UIKit proxy and mirrored by the visual lane (intrinsic + optional spacer).
    ///
    /// A `UIScrollView` only scrolls when `contentSize.height > bounds.height`. The scroll *range*
    /// (contentSize.height − bounds.height) must be at least `intrinsic + 2 * verticalPadding`
    /// so every row can be brought to the aim line. Setting `contentBlockHeight = intrinsic + viewport`
    /// gives exactly that range: (intrinsic + viewport + 2*pad) − viewport = intrinsic + 2*pad.
    private var voiceOverLaneTotalScrollBlockHeight: CGFloat {
        let intrinsic = voiceOverLaneIntrinsicBlockHeight
        guard playfieldViewportHeight > 50 else { return intrinsic }
        return intrinsic + playfieldViewportHeight
    }

    /// Transparent tail under the lane so its laid-out height matches ``voiceOverLaneTotalScrollBlockHeight``.
    ///
    /// The visual lane and UIKit proxy must always stay in sync. If lane metrics change, update both
    /// this spacer math and the proxy scroll sizing together.
    private var voiceOverLaneBottomSpacerHeight: CGFloat {
        max(0, voiceOverLaneTotalScrollBlockHeight - voiceOverLaneIntrinsicBlockHeight)
    }

    /// Recomputes alignment from moonstone position vs. playfield vertical center (fixed orb line).
    private func applyResonanceAlignmentFromLastFrames() {
        let playfieldH = playfieldViewportHeight
        guard playfieldH > 50 else { return }
        let aimMidY = playfieldH * 0.5
        let targetY = lastTargetMidYInPlayfield
        guard targetY > -1_000 else { return }
        let delta = iOSResonanceAlignment.deltaPoints(
            targetMidY: targetY,
            aimMidY: aimMidY
        )
        displayDeltaPoints = delta
        let now = Date()
        if now.timeIntervalSince(lastAlignmentLogTime) >= 0.28 {
            lastAlignmentLogTime = now
            logResonanceScroll(
                "alignment sample playfieldH=\(String(format: "%.1f", playfieldH)) targetMidY=\(String(format: "%.1f", targetY)) aimMidY=\(String(format: "%.1f", aimMidY)) delta=\(String(format: "%.1f", delta)) reachable=\(iOSResonanceAlignment.isReachable(deltaPoints: delta)) vo=\(UIAccessibility.isVoiceOverRunning)"
            )
        }
        onResonanceDeltaChanged(delta)
    }

    /// The playfield `ZStack` must always contain the UIKit proxy unconditionally. New overlays above it
    /// must disable hit testing, and new playfield content must remain hidden from accessibility.
    var body: some View {
        GeometryReader { geometry in
            let clampedPlayfieldHeight = max(
                240,
                geometry.size.height - topChromeHeight - bottomChromeHeight
            )
            VStack(spacing: 0) {
                topChrome

                playfieldContent(height: clampedPlayfieldHeight)

                bottomChrome
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background(Color.ra11yGameFallbackBackground)
            .environment(\.colorScheme, .dark)
            .onAppear {
                playfieldViewportHeight = clampedPlayfieldHeight
            }
            .onChange(of: clampedPlayfieldHeight) { _, newHeight in
                guard abs(newHeight - playfieldViewportHeight) > 0.5 else { return }
                playfieldViewportHeight = newHeight
                applyResonanceAlignmentFromLastFrames()
            }
            .onAppear {
                logResonanceScroll("playSurface.onAppear vo=\(UIAccessibility.isVoiceOverRunning) reducedMotion=\(UIAccessibility.isReduceMotionEnabled)")
            }
        }
    }

    private func playfieldContent(height: CGFloat) -> some View {
        ZStack {
            iOSShaftResonanceBackground()

            /// Decorative lane: offset tracks the proxy scroller; hidden from VoiceOver.
            resonanceLaneColumn
                .padding(.vertical, RA11ySpacing.xl)
                .offset(y: -voiceOverProxyScrollOffsetY)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
                .clipped()
                .ra11yLightsOffGameplayBlackout(isEnabled: lightsOffMode)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            /// UIKit `UIScrollView` proxy (see ``iOSResonanceVoiceOverScrollProxyRepresentable``); visually clear, one AX element (the lane).
            iOSResonanceVoiceOverScrollProxyRepresentable(
                contentBlockHeight: voiceOverLaneTotalScrollBlockHeight,
                verticalPadding: RA11ySpacing.xl,
                accessibilityLabelText: String(localized: "dungeon.a11y.scroll.container"),
                accessibilityHintText: String(localized: "dungeon.a11y.scroll.container.hint"),
                onContentOffsetYChanged: { newY in
                    let oldY = voiceOverProxyScrollOffsetY
                    voiceOverProxyScrollOffsetY = newY
                    if abs(newY - oldY) > 0.5 {
                        logResonanceScroll(
                            "VO proxy scroll contentOffset.y \(String(format: "%.1f", oldY)) → \(String(format: "%.1f", newY))"
                        )
                    }
                }
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .accessibilitySortPriority(iOSResonancePlayAccessibilitySortTier.moonstoneLaneScrollProxy)

            centerOrbStack
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .allowsHitTesting(false)
                /// Hides the decorative orb/reticle from the VoiceOver rotor.
                .accessibilityHidden(true)

            if lightsOffMode {
                iOSResonanceLightsOffVignette()
                    .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .coordinateSpace(name: ResonancePlayfieldCoordinateSpace.name)
        .background(Color.ra11yGameFallbackBackground)
        .onPreferenceChange(iOSResonanceTargetMidYPreferenceKey.self) { targetY in
            Task { @MainActor in
                guard targetY > -500, abs(targetY - lastTargetMidYInPlayfield) > 0.25 else { return }
                lastTargetMidYInPlayfield = targetY
                applyResonanceAlignmentFromLastFrames()
            }
        }
    }

    // MARK: - Lane

    private var resonanceLaneColumn: some View {
        VStack(alignment: .center, spacing: iOSDungeonResonanceLaneLayout.rowSpacingPoints) {
            ForEach(Array(rooms.enumerated()), id: \.element.id) { index, room in
                if room.isTarget {
                    moonstoneRow(room: room)
                } else {
                    iOSLaneDecoyChip(style: .forRoomIndex(index))
                }
            }
            if voiceOverLaneBottomSpacerHeight > 0.5 {
                Color.clear
                    .frame(height: voiceOverLaneBottomSpacerHeight)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RA11ySpacing.lg)
        /// Lane glyphs stay visual-only; VoiceOver uses the single UIKit scroll surface. This prevents duplicate
        /// focusable elements inside the decorative stack.
        .accessibilityElement(children: .ignore)
    }

    private func moonstoneRow(room: DungeonRoom) -> some View {
        iOSMoonstoneTargetOrb()
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: iOSResonanceTargetMidYPreferenceKey.self,
                        value: geo.frame(in: .named(ResonancePlayfieldCoordinateSpace.name)).midY
                    )
                }
            }
            .accessibilityIdentifier("dungeon.room.\(room.id)")
    }

    // MARK: - Center stack

    private var centerOrbStack: some View {
        ZStack {
            iOSResonanceReticleRing(band: aimBand)
            iOSResonanceCenterOrb(band: aimBand)
            if aimBand == .success, UIImage(named: iOSDungeonResonanceArt.successFlare) != nil {
                iOSResonanceSuccessFlareOverlay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chrome

    private var topChrome: some View {
        ZStack(alignment: .top) {
            topChromeSizingTemplate
                .hidden()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            topChromeVisibleContent
        }
        .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
        .padding(.bottom, RA11ySpacing.sm)
        .background(.ultraThinMaterial.opacity(0.92))
        .background {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: ResonanceTopChromeHeightPreferenceKey.self,
                        value: geo.size.height
                    )
            }
        }
        /// Higher than the Moonstone lane proxy so Objective / gesture tips are read before the scroll surface.
        .accessibilitySortPriority(iOSResonancePlayAccessibilitySortTier.topChrome)
        .onPreferenceChange(ResonanceTopChromeHeightPreferenceKey.self) { height in
            guard height > 0, abs(height - topChromeHeight) > 0.5 else { return }
            topChromeHeight = height
        }
    }

    private var bottomChrome: some View {
        ZStack(alignment: .top) {
            bottomChromeSizingTemplate
                .hidden()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            bottomChromeVisibleContent
        }
        .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
        .padding(.vertical, RA11ySpacing.md)
        .background {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: ResonanceBottomChromeHeightPreferenceKey.self,
                        value: geo.size.height
                    )
            }
        }
        .accessibilitySortPriority(iOSResonancePlayAccessibilitySortTier.bottomChrome)
        .onPreferenceChange(ResonanceBottomChromeHeightPreferenceKey.self) { height in
            guard height > 0, abs(height - bottomChromeHeight) > 0.5 else { return }
            bottomChromeHeight = height
        }
    }

    private var topChromeVisibleContent: some View {
        VStack(spacing: RA11ySpacing.base) {
            if let lightsOffFlavorText {
                lightsOffFlavorCard(message: lightsOffFlavorText)
            }

            objectiveCard

            if showsFirstLevelGestureTip {
                firstLevelGestureTipCard
            }

            if let total = timeTotal, let remaining = timeRemaining {
                DungeonTimerHUD(timeRemaining: remaining, total: total, mistakes: mistakes)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(timerA11yLabel)
                    .accessibilityHint(String(localized: "a11y.timer.group.hint"))
            }

            if let statusMessage {
                iOSResonanceStatusRow(message: statusMessage)
            } else {
                iOSResonanceStatusRow(message: topChromeStatusSizingMessage)
                    .hidden()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var topChromeSizingTemplate: some View {
        VStack(spacing: RA11ySpacing.base) {
            if let lightsOffFlavorText {
                lightsOffFlavorCard(message: lightsOffFlavorText)
            }

            objectiveCard

            if showsFirstLevelGestureTip {
                firstLevelGestureTipCard
            }

            if let total = timeTotal, let remaining = timeRemaining {
                DungeonTimerHUD(timeRemaining: remaining, total: total, mistakes: mistakes)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(timerA11yLabel)
                    .accessibilityHint(String(localized: "a11y.timer.group.hint"))
            }

            iOSResonanceStatusRow(message: topChromeStatusSizingMessage)
        }
    }

    private var bottomChromeVisibleContent: some View {
        Group {
            if timedOut {
                timeoutBanner
                    .background(.ultraThinMaterial.opacity(0.95))
            } else if levelComplete, let continueAction = onContinue {
                continueButton(continueAction)
                    .background(.ultraThinMaterial.opacity(0.95))
            } else if targetIsReachable, let targetRoom = rooms.first(where: \.isTarget) {
                playfieldControlsContent(targetRoom: targetRoom)
                    .background(.ultraThinMaterial.opacity(0.95))
            } else if onHint != nil {
                playfieldControlsWithoutSeal
                    .background(.ultraThinMaterial.opacity(0.95))
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 0)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Hidden sizing template that keeps the playfield height stable while lock state changes.
    private var bottomChromeSizingTemplate: some View {
        Group {
            if timedOut {
                timeoutBanner
            } else if levelComplete, let continueAction = onContinue {
                continueButton(continueAction)
            } else if let targetRoom = rooms.first(where: \.isTarget) {
                playfieldControlsContent(targetRoom: targetRoom)
            } else if onHint != nil {
                playfieldControlsWithoutSeal
            } else {
                EmptyView()
            }
        }
    }

    /// Timeout uses `timeoutBanner`; L2/L3 retries are triggered from that banner.
    private var timeoutBanner: some View {
        VStack(spacing: RA11ySpacing.md) {
            Text(String(localized: "dungeon.timeout"))
                .font(.ra11yHeadline)
                .multilineTextAlignment(.center)
            if let onRetry {
                Button(action: onRetry) {
                    Text(String(localized: "level.button.retry"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color.ra11yAccent)
                .accessibilityIdentifier("dungeon.retry")
            }
        }
    }

    private func lightsOffFlavorCard(message: String) -> some View {
        Text(message)
            .font(.ra11ySubheadline)
            .foregroundStyle(Color.ra11yCardSecondaryText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RA11ySpacing.base)
            .background(Color.black.opacity(0.5), in: .rect(cornerRadius: RA11yRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RA11yRadius.card)
                    .strokeBorder(Color.ra11yDMBorder.opacity(0.35), lineWidth: 1)
            )
            .accessibilityAddTraits(.isStaticText)
    }

    private func playfieldControlsContent(targetRoom: DungeonRoom) -> some View {
        VStack(spacing: RA11ySpacing.sm) {
            Button {
                Task { await onActivateTarget(targetRoom) }
            } label: {
                Text(String(localized: "dungeon.resonance.seal"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.ra11yAccent)
            .accessibilityIdentifier("dungeon.resonance.seal")
            .accessibilityHint(String(localized: "dungeon.resonance.seal.hint"))

            if let onHint {
                hintButton(onHint)
            }
        }
    }

    private var playfieldControlsWithoutSeal: some View {
        VStack(spacing: RA11ySpacing.sm) {
            Button(action: {}) {
                Text(String(localized: "dungeon.resonance.seal"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.ra11yAccent)
            .hidden()
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            if let onHint {
                hintButton(onHint)
            }
        }
    }

    private func hintButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(String(localized: "dungeon.hint.button"), systemImage: "ear.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "dungeon.hint.a11yLabel"))
        .accessibilityHint(String(localized: "dungeon.hint.a11yHint"))
    }

    private func continueButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(String(localized: "level.button.next"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .accessibilityIdentifier("dungeon.continue")
        .accessibilityHint(String(localized: "dungeon.a11y.continue.nextAscent.hint"))
    }

    private var objectiveCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
            Label(String(localized: "dm.label"), systemImage: "scroll.fill")
                .font(.ra11yCaption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(objectiveText)
                .font(.ra11yHeadline)
                .bold()
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.66), in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(Color.ra11yDMBorder.opacity(0.5), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(objectiveA11yLabel)
        .accessibilityHint(objectiveA11yHint)
    }

    private var firstLevelGestureTipCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
            Text(String(localized: "dungeon.explain.gesture.swipe3"))
                .font(.ra11ySubheadline)
                .foregroundStyle(Color.ra11yCardSecondaryText)
                .multilineTextAlignment(.leading)
            Text(String(localized: "dungeon.explain.gesture.swipe3u"))
                .font(.ra11ySubheadline)
                .foregroundStyle(Color.ra11yCardSecondaryText)
                .multilineTextAlignment(.leading)
            Text(String(localized: "dungeon.resonance.tip.voFocusOnLane"))
                .font(.ra11ySubheadline)
                .foregroundStyle(Color.ra11yCardSecondaryText)
                .multilineTextAlignment(.leading)
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.45), in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(Color.ra11yDMBorder.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    /// On-screen objective line: alignment task only (decoy art uses room-themed assets without naming them here).
    private var objectiveText: String {
        switch rooms.count {
        case DungeonRoom.l1Rooms.count:
            return String(localized: "dungeon.l1.objective.format")
        case DungeonRoom.l2Rooms.count:
            return String(localized: "dungeon.l2.objective.format")
        default:
            return String(localized: "dungeon.l3.objective.format")
        }
    }

    /// VoiceOver objective: same metaphor as ``objectiveText``—Moonstone vs orb, not dungeon navigation.
    private var objectiveA11yLabel: String {
        switch rooms.count {
        case DungeonRoom.l1Rooms.count:
            return String(localized: "dungeon.a11y.l1.objective.format")
        case DungeonRoom.l2Rooms.count:
            return String(localized: "dungeon.a11y.l2.objective.format")
        default:
            return String(localized: "dungeon.a11y.l3.objective.format")
        }
    }

    private var objectiveA11yHint: String {
        switch rooms.count {
        case DungeonRoom.l1Rooms.count:
            return String(localized: "dungeon.a11y.l1.objective.hint")
        case DungeonRoom.l2Rooms.count, DungeonRoom.l3Rooms.count:
            return String(localized: "dungeon.a11y.scroll.container.hint")
        default:
            return String(localized: "dungeon.a11y.l1.objective.hint")
        }
    }

    private var timerA11yLabel: String {
        guard let remaining = timeRemaining else { return "" }
        return String(format: String(localized: "dungeon.a11y.l3.timer"), Int(ceil(remaining)))
    }

    private var timeTotal: Double? {
        switch rooms.count {
        case DungeonRoom.l2Rooms.count: return 60
        case DungeonRoom.l3Rooms.count: return 45
        default: return nil
        }
    }
}

// MARK: - Status row

/// Visible-only feedback line below the HUD (VoiceOver still receives hint via `requestHint` paths).
private struct iOSResonanceStatusRow: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.ra11ySubheadline)
            .foregroundStyle(Color.ra11yCardSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RA11ySpacing.xs)
    }
}
