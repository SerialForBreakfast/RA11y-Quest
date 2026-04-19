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

// MARK: - iOSDungeonResonancePlayView

/// Crystal Resonance gameplay surface (ADR-0003): fixed center orb, scrolling target lane,
/// activation only when the moonstone aligns with the aim line.
///
/// **VoiceOver:** The scroll lane uses a higher `accessibilitySortPriority` than chrome so it surfaces
/// earlier in swipe order, then `UIAccessibility.post` with `.screenChanged` plus a short-delay
/// `AccessibilityFocusState` assignment after navigation. SwiftUI’s `ScrollView` may still not
/// deliver three-finger scroll reliably; `accessibilityAdjustableAction` remains a discrete nudge
/// via `ScrollViewReader` when three-finger input does nothing.
/// The lane column uses `accessibilityElement(children: .ignore)` so glyphs do not become separate
/// VoiceOver stops.
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

    /// Moves VoiceOver to the `ScrollView` so chrome does not retain initial focus.
    @AccessibilityFocusState private var accessibilityFocusScrollLane: ScrollLaneFocusID?

    /// Last room index used by the scroll container's VoiceOver adjustable action (chamber-by-chamber nudges).
    /// May drift if the user mixes three-finger scroll with those nudges.
    @State private var voiceOverLaneRoomIndex: Int = 0

    @Environment(\.horizontalSizeClass) private var sizeClass

    private enum ScrollLaneFocusID: Hashable {
        case scrollLane
    }

    private var aimBand: iOSResonanceAimBand {
        iOSResonanceAimBand.displayBand(deltaPoints: displayDeltaPoints, levelComplete: levelComplete)
    }

    var body: some View {
        ScrollViewReader { scrollViewProxy in
            GeometryReader { screenGeo in
                ZStack {
                    iOSShaftResonanceBackground()

                    ScrollView(.vertical) {
                        resonanceLaneColumn
                            .padding(.vertical, RA11ySpacing.xl)
                    }
                    .scrollIndicators(.visible)
                    .ra11yLightsOffGameplayBlackout(isEnabled: lightsOffMode)
                    /// Surfaces the lane earlier in VoiceOver swipe order than `safeAreaInset` chrome (priority 0).
                    .accessibilitySortPriority(10)
                    .accessibilityIdentifier("dungeon.resonance.scrollLane")
                    .accessibilityLabel(String(localized: "dungeon.a11y.scroll.container"))
                    .accessibilityHint(String(localized: "dungeon.a11y.scroll.container.hint"))
                    /// Ensures VoiceOver routes direct interaction to this scroll surface when the OS supports it.
                    .accessibilityRespondsToUserInteraction(true)
                    /// Reliable lane control for VoiceOver: one-finger swipe up/down while this element is focused.
                    .accessibilityAdjustableAction { direction in
                        guard !levelComplete, !timedOut else { return }
                        switch direction {
                        case .increment:
                            nudgeCrystalShaftForVoiceOver(using: scrollViewProxy, towardDeeper: true)
                        case .decrement:
                            nudgeCrystalShaftForVoiceOver(using: scrollViewProxy, towardDeeper: false)
                        @unknown default:
                            break
                        }
                    }
                    .accessibilityFocused($accessibilityFocusScrollLane, equals: .scrollLane)
                    .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { oldY, newY in
                        if abs(newY - oldY) > 0.5 {
                            logResonanceScroll(
                                "lane scroll contentOffset.y \(String(format: "%.1f", oldY)) → \(String(format: "%.1f", newY)) vo=\(UIAccessibility.isVoiceOverRunning)"
                            )
                        }
                    }

                    centerOrbStack
                        .allowsHitTesting(false)
                        /// Hides the decorative orb/reticle from the VoiceOver rotor.
                        .accessibilityHidden(true)

                    if lightsOffMode {
                        iOSResonanceLightsOffVignette()
                            .allowsHitTesting(false)
                    }
                }
                .onPreferenceChange(iOSResonanceTargetMidYPreferenceKey.self) { targetY in
                    guard targetY > -1_000 else { return }
                    let aimMidY = screenGeo.frame(in: .global).midY
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
            }
            .background(Color.ra11yGameFallbackBackground)
            .safeAreaInset(edge: .top, spacing: 0) { topChrome }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomChrome }
            .environment(\.colorScheme, .dark)
            .onChange(of: rooms.map(\.id)) { _, _ in
                voiceOverLaneRoomIndex = rooms.firstIndex(where: \.isTarget) ?? 0
            }
            .onAppear {
                voiceOverLaneRoomIndex = rooms.firstIndex(where: \.isTarget) ?? 0
                logResonanceScroll("playSurface.onAppear vo=\(UIAccessibility.isVoiceOverRunning) reducedMotion=\(UIAccessibility.isReduceMotionEnabled)")
                guard UIAccessibility.isVoiceOverRunning else {
                    logResonanceScroll("skip programmatic VO focus — VoiceOver off")
                    return
                }
                Task { @MainActor in
                    // Aligns with `announceObjectivePrompt` (~500 ms); lets the navigation push settle.
                    try? await Task.sleep(for: .milliseconds(500))
                    UIAccessibility.post(notification: .screenChanged, argument: nil)
                    logResonanceScroll("posted UIAccessibility.Notification.screenChanged to reset VO traversal")
                    try? await Task.sleep(for: .milliseconds(300))
                    accessibilityFocusScrollLane = .scrollLane
                    logResonanceScroll("accessibilityFocus set to scrollLane (dungeon.resonance.scrollLane) backup binding")
                    let focusLine = String(localized: "dungeon.a11y.scroll.vo.focusAnnouncement")
                    UIAccessibility.post(notification: .announcement, argument: focusLine)
                    logResonanceScroll("posted VO focus announcement (length=\(focusLine.count))")
                }
            }
        }
    }

    // MARK: - VoiceOver lane scrolling

    /// Moves the shaft one chamber toward deeper or shallower lists using ``ScrollViewReader``
    /// so gameplay does not depend on three-finger scroll (often flaky with SwiftUI `ScrollView`).
    ///
    /// Must run on the main actor; invoked from `accessibilityAdjustableAction` on the scroll container.
    private func nudgeCrystalShaftForVoiceOver(
        using proxy: ScrollViewProxy,
        towardDeeper: Bool
    ) {
        guard !rooms.isEmpty else { return }
        let nextIndex: Int
        if towardDeeper {
            nextIndex = min(voiceOverLaneRoomIndex + 1, rooms.count - 1)
        } else {
            nextIndex = max(voiceOverLaneRoomIndex - 1, 0)
        }
        guard nextIndex != voiceOverLaneRoomIndex else {
            logResonanceScroll("VO nudge blocked at boundary index=\(voiceOverLaneRoomIndex) deeper=\(towardDeeper)")
            return
        }
        let room = rooms[nextIndex]
        voiceOverLaneRoomIndex = nextIndex
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            proxy.scrollTo(room.id, anchor: .center)
        }
        logResonanceScroll(
            "programmatic VO shaft nudge → index \(nextIndex) id=\(room.id) towardDeeper=\(towardDeeper)"
        )
    }

    // MARK: - Lane

    private var resonanceLaneColumn: some View {
        VStack(spacing: 56) {
            ForEach(Array(rooms.enumerated()), id: \.element.id) { index, room in
                Group {
                    if room.isTarget {
                        moonstoneRow(room: room)
                    } else {
                        iOSLaneDecoyChip(style: .forRoomIndex(index))
                    }
                }
                .id(room.id)
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
    }

    @ViewBuilder
    private var bottomChrome: some View {
        VStack(spacing: RA11ySpacing.sm) {
            if timedOut {
                timeoutBanner
            } else {
                sealOrProgressControls
            }
        }
        .padding(.horizontal, sizeClass == .regular ? RA11ySpacing.xl : RA11ySpacing.base)
        .padding(.vertical, RA11ySpacing.md)
        .background(.ultraThinMaterial.opacity(0.95))
    }

    @ViewBuilder
    private var sealOrProgressControls: some View {
        if levelComplete, let onContinue {
            continueButton(onContinue)
        } else if !timedOut {
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
