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

// MARK: - Aim line (global Y)

/// Supplies the screen-global Y of the resonance play area vertical midpoint (fixed orb / aim line).
/// Measured from a hit-invisible `GeometryReader` overlay so the play surface does not wrap in a
/// root-level `GeometryReader` (those often register an unnamed VoiceOver frame).
private struct ResonanceAimLineGlobalMidYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = -10_000

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > -1_000 { value = next }
    }
}

// MARK: - iOSDungeonResonancePlayView

/// Crystal Resonance gameplay surface (ADR-0003): fixed center orb, scrolling target lane,
/// activation only when the moonstone aligns with the aim line.
///
/// **VoiceOver:** The scroll lane is a UIKit ``iOSResonanceVoiceOverScrollProxyRepresentable`` (`UIScrollView`)
/// with higher `accessibilitySortPriority` than chrome. Initial focus uses `UIAccessibility.post`
/// (`.screenChanged`, then `.layoutChanged` with the scroll view, then announcement). The play surface
/// avoids a **root** `GeometryReader` (measurement uses a hidden overlay `GeometryReader` + preference key).
///
/// **VoiceOver lane proxy:** The **visual** lane is a clipped, **non-scrolling** stack whose vertical
/// offset mirrors the UIKit scroller’s content offset (same lane accessibility label on the scroll view).
/// VoiceOver scrolls that proxy only; the glyph column stays `accessibilityHidden`. On iOS,
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

    /// Invoked when the moonstone's vertical alignment changes (global-space delta from aim line).
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

    /// Vertical midpoint (global Y) of the resonance play area aim line (from ``ResonanceAimLineGlobalMidYPreferenceKey``).
    @State private var aimLineGlobalMidY: CGFloat = -10_000

    /// Last moonstone `midY` from ``iOSResonanceTargetMidYPreferenceKey`` (paired with `aimLineGlobalMidY`).
    @State private var lastTargetGlobalMidY: CGFloat = -10_000

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var aimBand: iOSResonanceAimBand {
        iOSResonanceAimBand.displayBand(deltaPoints: displayDeltaPoints, levelComplete: levelComplete)
    }

    /// Minimum height for the VoiceOver proxy scroll content so three-finger scroll has room (mirrors L0 practice).
    private var voiceOverProxyScrollableContentHeight: CGFloat {
        let rowCount = max(rooms.count * 2, 18)
        return CGFloat(rowCount) * 44 + 2 * RA11ySpacing.xl
    }

    /// Recomputes alignment when either the aim line or moonstone global position changes (preferences can arrive in either order).
    private func applyResonanceAlignmentFromLastFrames() {
        let targetY = lastTargetGlobalMidY
        let aimMidY = aimLineGlobalMidY
        guard targetY > -1_000, aimMidY > -1_000 else { return }
        let delta = iOSResonanceAlignment.deltaPoints(
            targetMidYGlobal: targetY,
            aimMidYGlobal: aimMidY
        )
        displayDeltaPoints = delta
        let now = Date()
        if now.timeIntervalSince(lastAlignmentLogTime) >= 0.28 {
            lastAlignmentLogTime = now
            logResonanceScroll(
                "alignment sample targetMidY=\(String(format: "%.1f", targetY)) aimMidY=\(String(format: "%.1f", aimMidY)) delta=\(String(format: "%.1f", delta)) reachable=\(iOSResonanceAlignment.isReachable(deltaPoints: delta)) vo=\(UIAccessibility.isVoiceOverRunning)"
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

            /// UIKit `UIScrollView` proxy (see ``iOSResonanceVoiceOverScrollProxyRepresentable``); visually clear, one AX element.
            iOSResonanceVoiceOverScrollProxyRepresentable(
                contentBlockHeight: voiceOverProxyScrollableContentHeight,
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
            .accessibilitySortPriority(10)

            centerOrbStack
                .allowsHitTesting(false)
                /// Hides the decorative orb/reticle from the VoiceOver rotor.
                .accessibilityHidden(true)

            if lightsOffMode {
                iOSResonanceLightsOffVignette()
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: ResonanceAimLineGlobalMidYPreferenceKey.self,
                        value: geo.frame(in: .global).midY
                    )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onPreferenceChange(ResonanceAimLineGlobalMidYPreferenceKey.self) { midY in
            aimLineGlobalMidY = midY
            applyResonanceAlignmentFromLastFrames()
        }
        .onPreferenceChange(iOSResonanceTargetMidYPreferenceKey.self) { targetY in
            lastTargetGlobalMidY = targetY
            applyResonanceAlignmentFromLastFrames()
        }
        .background(Color.ra11yGameFallbackBackground)
        .safeAreaInset(edge: .top, spacing: 0) { topChrome }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomChrome }
        .environment(\.colorScheme, .dark)
        .onAppear {
            logResonanceScroll("playSurface.onAppear vo=\(UIAccessibility.isVoiceOverRunning) reducedMotion=\(UIAccessibility.isReduceMotionEnabled)")
        }
    }

    // MARK: - Lane

    private var resonanceLaneColumn: some View {
        VStack(spacing: 56) {
            ForEach(Array(rooms.enumerated()), id: \.element.id) { index, room in
                if room.isTarget {
                    moonstoneRow(room: room)
                } else {
                    iOSLaneDecoyChip(style: .forRoomIndex(index))
                }
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RA11ySpacing.lg)
        /// Single scroll target for VoiceOver: lane glyphs stay visual-only; without this, nested
        /// identifiers can receive focus and three-finger swipes no longer move the `ScrollView`.
        .accessibilityElement(children: .ignore)
    }

    private func moonstoneRow(room: DungeonRoom) -> some View {
        iOSMoonstoneTargetOrb()
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: iOSResonanceTargetMidYPreferenceKey.self,
                        value: geo.frame(in: .global).midY
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
        /// After the playfield scroll proxy (`accessibilitySortPriority` 10); keeps objectives and HUD
        /// from preempting swipe order when the platform merges inset and content accessibility trees.
        .accessibilitySortPriority(-5)
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
                .accessibilitySortPriority(-5)
        } else if hasPlayfieldBottomControls {
            sealOrProgressControls
                .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
                .padding(.vertical, RA11ySpacing.md)
                .background(.ultraThinMaterial.opacity(0.95))
                .accessibilitySortPriority(-5)
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

    private var objectiveText: String {
        guard let target = rooms.first(where: \.isTarget) else { return "" }
        switch rooms.count {
        case DungeonRoom.l1Rooms.count:
            return String(format: String(localized: "dungeon.l1.objective.format"), target.displayName)
        case DungeonRoom.l2Rooms.count:
            return String(format: String(localized: "dungeon.l2.objective.format"), target.displayName)
        default:
            return String(format: String(localized: "dungeon.l3.objective.format"), target.displayName)
        }
    }

    private var objectiveA11yLabel: String {
        guard let target = rooms.first(where: \.isTarget) else { return "" }
        switch rooms.count {
        case DungeonRoom.l1Rooms.count:
            return String(format: String(localized: "dungeon.a11y.l1.objective.format"), target.displayName)
        case DungeonRoom.l2Rooms.count:
            return String(format: String(localized: "dungeon.a11y.l2.objective.format"), target.displayName)
        default:
            return String(format: String(localized: "dungeon.a11y.l3.objective.format"), target.displayName)
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
