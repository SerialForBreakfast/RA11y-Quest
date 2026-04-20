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

/// Height of the playfield `ZStack` (between top/bottom safe-area insets) for scroll content sizing.
private struct ResonancePlayfieldViewportHeightPreferenceKey: PreferenceKey {
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
/// — a **single** element named “Moonstone alignment lane” for three-finger shaft scrolling. Sort priority places
/// the top HUD (objective, tips) **before** the lane, and the lane **before** bottom controls—programmatic
/// `layoutChanged` to the lane is **not** posted (it skipped the nav title and instructions). Aim/orb alignment and
/// viewport height use scoped `GeometryReader` backgrounds + preference keys (not a root wrapping `GeometryReader`).
///
/// **VoiceOver lane proxy:** The **visual** lane is a clipped, **non-scrolling** stack whose vertical
/// offset mirrors the UIKit scroller’s content offset (same lane label on the scroll view). Chamber
/// names on decoys are decorative; they are not separate VoiceOver items. The glyph column stays
/// `accessibilityHidden`. On iOS,
/// three-finger scrolling affects the scroll view associated with the **current VoiceOver focus**—if
/// focus is on objective/timer chrome, three-finger swipes will not move the lane; the player must
/// navigate until VoiceOver announces the scroll proxy (localized `dungeon.a11y.scroll.container`; see
/// hints and L1 tip copy). Quests
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

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var aimBand: iOSResonanceAimBand {
        iOSResonanceAimBand.displayBand(deltaPoints: displayDeltaPoints, levelComplete: levelComplete)
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
    /// A `UIScrollView` only scrolls when `contentSize.height > bounds.height`. Short shafts (few rooms) produced
    /// intrinsic content shorter than the viewport, so three-finger scroll did nothing. We pad with a clear spacer
    /// in the SwiftUI lane so offsets stay aligned with the UIKit content height.
    private var voiceOverLaneTotalScrollBlockHeight: CGFloat {
        let intrinsic = voiceOverLaneIntrinsicBlockHeight
        guard playfieldViewportHeight > 50 else { return intrinsic }
        let verticalPadding = RA11ySpacing.xl
        let minBlockForScroll = max(0, playfieldViewportHeight - 2 * verticalPadding) + 32
        return max(intrinsic, minBlockForScroll)
    }

    /// Transparent tail under the lane so its laid-out height matches ``voiceOverLaneTotalScrollBlockHeight``.
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

    var body: some View {
        ZStack {
            iOSShaftResonanceBackground()

            /// Decorative lane: offset tracks the proxy scroller; hidden from VoiceOver.
            resonanceLaneColumn
                .padding(.vertical, RA11ySpacing.xl)
                .offset(y: -voiceOverProxyScrollOffsetY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilitySortPriority(iOSResonancePlayAccessibilitySortTier.moonstoneLaneScrollProxy)

            centerOrbStack
                .allowsHitTesting(false)
                /// Hides the decorative orb/reticle from the VoiceOver rotor.
                .accessibilityHidden(true)

            if lightsOffMode {
                iOSResonanceLightsOffVignette()
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: ResonancePlayfieldCoordinateSpace.name)
        .background {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: ResonancePlayfieldViewportHeightPreferenceKey.self,
                        value: geo.size.height
                    )
            }
        }
        .background(Color.ra11yGameFallbackBackground)
        .onPreferenceChange(ResonancePlayfieldViewportHeightPreferenceKey.self) { height in
            Task { @MainActor in
                await Task.yield()
                guard height > 10, abs(height - playfieldViewportHeight) > 0.5 else { return }
                playfieldViewportHeight = height
                applyResonanceAlignmentFromLastFrames()
            }
        }
        .onPreferenceChange(iOSResonanceTargetMidYPreferenceKey.self) { targetY in
            Task { @MainActor in
                await Task.yield()
                guard targetY > -500, abs(targetY - lastTargetMidYInPlayfield) > 0.25 else { return }
                lastTargetMidYInPlayfield = targetY
                applyResonanceAlignmentFromLastFrames()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topChrome }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomChrome }
        .environment(\.colorScheme, .dark)
        .onAppear {
            logResonanceScroll("playSurface.onAppear vo=\(UIAccessibility.isVoiceOverRunning) reducedMotion=\(UIAccessibility.isReduceMotionEnabled)")
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
        VStack(spacing: RA11ySpacing.base) {
            if let lightsOffFlavorText {
                Text(lightsOffFlavorText)
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
            }
        }
        .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
        .padding(.bottom, RA11ySpacing.sm)
        .background(.ultraThinMaterial.opacity(0.92))
        /// Higher than the Moonstone lane proxy so Objective / gesture tips are read before the scroll surface.
        .accessibilitySortPriority(iOSResonancePlayAccessibilitySortTier.topChrome)
    }

    /// `false` during most of L1 when the seal is unavailable and there is no hint — avoids an empty
    /// `VStack` inset that VoiceOver can focus as an unnamed rectangle.
    private var hasPlayfieldBottomControls: Bool {
        if levelComplete, onContinue != nil { return true }
        if targetIsReachable, rooms.contains(where: \.isTarget) { return true }
        if onHint != nil { return true }
        return false
    }

    @ViewBuilder
    private var bottomChrome: some View {
        if timedOut {
            timeoutBanner
                .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
                .padding(.vertical, RA11ySpacing.md)
                .background(.ultraThinMaterial.opacity(0.95))
                .accessibilitySortPriority(iOSResonancePlayAccessibilitySortTier.bottomChrome)
        } else if hasPlayfieldBottomControls {
            sealOrProgressControls
                .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
                .padding(.vertical, RA11ySpacing.md)
                .background(.ultraThinMaterial.opacity(0.95))
                .accessibilitySortPriority(iOSResonancePlayAccessibilitySortTier.bottomChrome)
        }
    }

    @ViewBuilder
    private var sealOrProgressControls: some View {
        if levelComplete, let onContinue {
            continueButton(onContinue)
        } else if !timedOut {
            // At least one subview when `hasPlayfieldBottomControls` is true (see `bottomChrome`).
            VStack(spacing: RA11ySpacing.sm) {
                if targetIsReachable, let targetRoom = rooms.first(where: \.isTarget) {
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
                }
                if let onHint {
                    hintButton(onHint)
                }
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
