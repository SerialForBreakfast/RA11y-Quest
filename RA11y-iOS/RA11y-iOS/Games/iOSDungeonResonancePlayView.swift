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
/// The lane must come first so Crystal Resonance is immediately scrollable on entry.
private enum iOSResonancePlayAccessibilitySortTier {
    static let moonstoneLaneScrollProxy: Double = 30
    static let topChrome: Double = 20
    static let bottomChrome: Double = 10
}

// MARK: - iOSDungeonResonancePlayView

/// Crystal Resonance gameplay surface (ADR-0003): fixed center orb, scrolling target lane,
/// activation only when the moonstone aligns with the aim line.
///
/// **VoiceOver:** The scroll lane is a UIKit ``iOSResonanceVoiceOverScrollProxyRepresentable`` (`UIScrollView`)
/// — a **single** focusable “Glyph stream” with **value** and scroll status naming the current glyph
/// (``dungeon.resonance.item.moonstone`` vs decoy styles) and band so linear navigation still hears
/// *Moonstone*; three-finger shaft scrolling works as before. The UIKit
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

    /// When set, replaces the generic “Next” label after a level completes (Crystal Resonance ascent copy).
    let continueButtonTitle: String?

    /// Screenshot / deterministic builds: pin the first scroll offset to this lane index. `nil` = prefer a decoy under the hub.
    let initialLaneIndexOverride: Int?

    /// Invoked when the moonstone's vertical alignment changes (playfield-space delta from the aim line).
    let onResonanceDeltaChanged: (CGFloat) -> Void

    let onActivateTarget: (DungeonRoom) async -> Void
    /// Invoked when the VoiceOver scroll proxy snaps to a different lane slot (after ``handleProxyScrollOffsetChange``).
    let onLaneSlotChanged: (() -> Void)?
    let onHint: (() -> Void)?
    let onContinue: (() -> Void)?
    let onRetry: (() -> Void)?

    @State private var displayDeltaPoints: CGFloat = 500

    /// Limits alignment telemetry spam while still capturing motion during scroll debugging.
    @State private var lastAlignmentLogTime: Date = .distantPast

    /// Snapped vertical offset for the selected room slot. The UIKit proxy still receives the three-finger
    /// swipe, but gameplay uses discrete room positions rather than raw inertial scrolling.
    @State private var voiceOverProxyScrollOffsetY: CGFloat = 0
    @State private var selectedLaneIndex: Int = 0

    /// Last moonstone vertical center in ``ResonancePlayfieldCoordinateSpace`` (paired with aim = `playfieldViewportHeight * 0.5`).
    @State private var lastTargetMidYInPlayfield: CGFloat = -10_000

    /// Playfield height between safe-area insets; drives minimum UIKit scroll content height so VoiceOver can scroll.
    @State private var playfieldViewportHeight: CGFloat = 600
    @State private var topChromeHeight: CGFloat = 0
    @State private var bottomChromeHeight: CGFloat = 0

    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Stable identity for the current lane room set (L1/L2/L3 transitions and L3 reshuffles).
    private var roomLaneIdentity: String {
        rooms.map(\.id).joined(separator: "\u{1e}")
    }

    private var aimBand: iOSResonanceAimBand {
        iOSResonanceAimBand.displayBand(deltaPoints: displayDeltaPoints, levelComplete: levelComplete)
    }

    /// Reserve enough height for the status row even when no transient message is visible.
    private var topChromeStatusSizingMessage: String {
        String(localized: "dungeon.resonance.hint")
    }

    /// Distance between successive lane row centers (matches ``resonanceLaneColumn`` `VStack` spacing + row height).
    private var laneColumnInterItemSpacing: CGFloat {
        iOSDungeonResonanceLaneLayout.rowSpacingPoints + iOSDungeonResonanceLaneLayout.voiceOverLaneStrideSlackPoints
    }

    private var laneStepPoints: CGFloat {
        iOSDungeonResonanceLaneLayout.rowContentHeightPoints + laneColumnInterItemSpacing
    }

    /// Symmetric spacer that makes every room a centerable snap target.
    private var laneCenterSpacerHeight: CGFloat {
        max(0, playfieldViewportHeight * 0.5 - iOSDungeonResonanceLaneLayout.rowContentHeightPoints * 0.5)
    }

    /// Extra scrollable runway below the lane so VoiceOver three-finger paging can exceed the last snap
    /// without `contentOffset` sitting on the `maxY` clamp (see repo `memlog/research/CrystalResonance-Asset-And-Scroll-QC.md`).
    private var voiceOverLaneTrailingSlack: CGFloat {
        max(160, playfieldViewportHeight * 0.28)
    }

    /// Full height of ``resonanceLaneColumn`` (top/bottom center spacers, lane rows, inter-row gaps, trailing slack).
    private var voiceOverLaneIntrinsicBlockHeight: CGFloat {
        let n = rooms.count
        guard n > 0 else { return RA11ySpacing.xl * 2 }
        /// One more gap than ``n + 1``: the stack is top spacer, ``n`` rows, bottom spacer, **trailing** clear.
        let gapCount = CGFloat(n + 2)
        let rowsBlock = CGFloat(n) * iOSDungeonResonanceLaneLayout.rowContentHeightPoints
            + gapCount * laneColumnInterItemSpacing
            + 2 * laneCenterSpacerHeight
            + voiceOverLaneTrailingSlack
        /// Reserve enough runway for ``snappedLaneOffset`` (includes the first `VStack` gap after the top spacer).
        let minForLastSlot =
            CGFloat(max(0, n - 1)) * laneStepPoints
            + playfieldViewportHeight
            + 48
            + laneColumnInterItemSpacing
        return max(rowsBlock, minForLastSlot)
    }

    /// Scroll content block height passed to the UIKit proxy and mirrored by the visual lane.
    ///
    /// Center spacers turn the lane into a discrete selector: offset `index * laneStepPoints` centers room `index`.
    private var voiceOverLaneTotalScrollBlockHeight: CGFloat {
        voiceOverLaneIntrinsicBlockHeight
    }

    private var currentVoiceOverScrollStatusText: String {
        let selectedName = currentLaneSelectionName
        let bandText = currentAlignmentAnnouncementText
        return "\(selectedName). \(bandText)"
    }

    /// Scroll proxy hint: Lights Off reiterates that the **value** names the current glyph (including Moonstone).
    private var scrollContainerAccessibilityHint: String {
        if lightsOffMode {
            return String(localized: "dungeon.a11y.scroll.container.hint.lightsOff")
        }
        return String(localized: "dungeon.a11y.scroll.container.hint")
    }

    /// Row whose **layout** center is nearest the aim line for the current scroll offset (authoritative for scroll status).
    private var laneIndexAtAimLine: Int {
        laneIndexClosestToAimLine(scrollOffsetY: voiceOverProxyScrollOffsetY)
    }

    private var currentLaneSelectionName: String {
        localizedResonanceItemName(atLaneIndex: laneIndexAtAimLine)
    }

    /// Maps the lane index to Moonstone / decoy glyph names for VoiceOver scroll status (not ``DungeonRoom/displayName``).
    private func localizedResonanceItemName(atLaneIndex index: Int) -> String {
        guard !rooms.isEmpty else { return String(localized: "dungeon.a11y.scroll.container") }
        let i = clampedLaneIndex(index)
        if rooms[i].isTarget {
            return String(localized: "dungeon.resonance.item.moonstone")
        }
        return iOSResonanceDecoyStyle.forRoomIndex(i).localizedAccessibilityItemName
    }

    private var currentAlignmentAnnouncementText: String {
        switch iOSResonanceAlignment.questBand(deltaPoints: displayDeltaPoints) {
        case .far:
            return String(localized: "dungeon.resonance.a11y.orb.far")
        case .warm:
            return String(localized: "dungeon.resonance.a11y.orb.warm")
        case .near:
            return String(localized: "dungeon.resonance.a11y.orb.near")
        case .locked:
            return String(localized: "dungeon.resonance.a11y.orb.locked")
        }
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

    private func clampedLaneIndex(_ index: Int) -> Int {
        guard !rooms.isEmpty else { return 0 }
        return min(max(index, 0), rooms.count - 1)
    }

    /// Vertical center of the playfield aim line (orb / reticle hub), in ``ResonancePlayfieldCoordinateSpace``.
    private var resonanceAimLineMidY: CGFloat {
        playfieldViewportHeight * 0.5
    }

    /// Y coordinate of lane row `laneIndex`’s vertical center in **lane content space** (before ``View/offset(y:)``).
    ///
    /// ``resonanceLaneColumn`` is a `VStack` with ``View/spacing`` between **every** adjacent child, including the gap
    /// between the top centering spacer and the first row. Scroll math must add that leading gap or row centers sit
    /// one spacing interval too low on screen (Moonstone below the hub while VoiceOver names Moonstone).
    private func laneRowCenterContentY(laneIndex: Int) -> CGFloat {
        let s = laneCenterSpacerHeight
        let g = laneColumnInterItemSpacing
        let h = iOSDungeonResonanceLaneLayout.rowContentHeightPoints
        let i = clampedLaneIndex(laneIndex)
        return s + g + CGFloat(i) * laneStepPoints + h * 0.5
    }

    /// `UIScrollView.contentOffset.y` that places ``laneRowCenterContentY`` on ``resonanceAimLineMidY`` for `index`.
    private func snappedLaneOffset(for index: Int) -> CGFloat {
        laneRowCenterContentY(laneIndex: index) - resonanceAimLineMidY
    }

    /// Which lane row is physically centered on the aim line for a given scroll offset (matches ``resonanceLaneColumn`` geometry).
    ///
    /// Using nearest-row geometry avoids VoiceOver scroll status naming the **next** slot when float rounding or
    /// transient `contentOffset` drifts from ``snappedLaneOffset(for:)``.
    private func laneIndexClosestToAimLine(scrollOffsetY: CGFloat) -> Int {
        guard !rooms.isEmpty, playfieldViewportHeight > 50 else { return 0 }
        let aimMidY = resonanceAimLineMidY
        var best = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for i in 0..<rooms.count {
            let rowCenterY = laneRowCenterContentY(laneIndex: i) - scrollOffsetY
            let d = abs(rowCenterY - aimMidY)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return clampedLaneIndex(best)
    }

    private func handleProxyScrollOffsetChange(_ newY: CGFloat) {
        let snappedIndex = laneIndexClosestToAimLine(scrollOffsetY: newY)
        let oldY = voiceOverProxyScrollOffsetY
        let snappedOffset = snappedLaneOffset(for: snappedIndex)
        let previousIndex = selectedLaneIndex
        selectedLaneIndex = snappedIndex
        voiceOverProxyScrollOffsetY = snappedOffset
        if snappedIndex != previousIndex {
            onLaneSlotChanged?()
        }
        if abs(snappedOffset - oldY) > 0.5 {
            logResonanceScroll(
                "VO proxy scroll contentOffset.y \(String(format: "%.1f", oldY)) → \(String(format: "%.1f", snappedOffset))"
            )
        }
    }

    /// Snaps VoiceOver scroll state whenever the room list changes.
    ///
    /// Normal play starts on a **decoy** under the hub so the Moonstone is never pre-aligned and repeat players
    /// cannot rely on muscle memory. Optional ``initialLaneIndexOverride`` keeps marketing screenshots stable.
    private func applyLaneSelectionForCurrentRooms() {
        guard !rooms.isEmpty else { return }
        let idx: Int
        if let initialLaneIndexOverride {
            idx = clampedLaneIndex(initialLaneIndexOverride)
        } else {
            idx = initialLaneIndexPreferringDecoy()
        }
        selectedLaneIndex = idx
        voiceOverProxyScrollOffsetY = snappedLaneOffset(for: idx)
    }

    /// Picks a lane index whose row is **not** the Moonstone when possible (deterministic under UI tests).
    private func initialLaneIndexPreferringDecoy() -> Int {
        let decoyIndices = rooms.indices.filter { !rooms[$0].isTarget }
        guard !decoyIndices.isEmpty else {
            return clampedLaneIndex(rooms.firstIndex(where: \.isTarget) ?? 0)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return clampedLaneIndex(decoyIndices.min() ?? 0)
        }
        return clampedLaneIndex(decoyIndices.randomElement() ?? decoyIndices[0])
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
                applyLaneSelectionForCurrentRooms()
                logResonanceScroll("playSurface.onAppear vo=\(UIAccessibility.isVoiceOverRunning) reducedMotion=\(UIAccessibility.isReduceMotionEnabled)")
            }
            .onChange(of: roomLaneIdentity) { _, _ in
                DispatchQueue.main.async {
                    applyLaneSelectionForCurrentRooms()
                }
            }
            .onChange(of: clampedPlayfieldHeight) { _, newHeight in
                guard abs(newHeight - playfieldViewportHeight) > 0.5 else { return }
                DispatchQueue.main.async {
                    playfieldViewportHeight = newHeight
                    applyResonanceAlignmentFromLastFrames()
                }
            }
        }
    }

    private func playfieldContent(height: CGFloat) -> some View {
        ZStack {
            /// L3 Lights Off: near-black with a hint of shaft art so the beat reads as intentional (checklist §4.4).
            if lightsOffMode {
                ZStack {
                    iOSShaftResonanceBackground()
                    Color.black.opacity(0.92)
                }
            } else {
                iOSShaftResonanceBackground()
            }

            /// Decorative lane: offset tracks the proxy scroller; hidden from VoiceOver.
            resonanceLaneColumn
                .offset(y: -voiceOverProxyScrollOffsetY)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
                .clipped()
                /// L3: opaque blackout over glyphs only (``ra11yLightsOffGameplayBlackout``), matching ``iOSEnchantersTrialView`` relic treatment.
                .ra11yLightsOffGameplayBlackout(isEnabled: lightsOffMode)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            /// UIKit `UIScrollView` proxy (see ``iOSResonanceVoiceOverScrollProxyRepresentable``); visually clear, one AX element (the lane).
            iOSResonanceVoiceOverScrollProxyRepresentable(
                contentBlockHeight: voiceOverLaneTotalScrollBlockHeight,
                verticalPadding: 0,
                accessibilityLabelText: String(localized: "dungeon.a11y.scroll.container"),
                accessibilityHintText: scrollContainerAccessibilityHint,
                accessibilityValueText: currentVoiceOverScrollStatusText,
                accessibilityScrollStatusText: currentVoiceOverScrollStatusText,
                desiredContentOffsetY: snappedLaneOffset(for: selectedLaneIndex),
                onContentOffsetYChanged: handleProxyScrollOffsetChange
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .accessibilitySortPriority(iOSResonancePlayAccessibilitySortTier.moonstoneLaneScrollProxy)

            centerOrbStack
                .opacity(lightsOffMode ? 0 : 1)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .allowsHitTesting(false)
                /// Hides the decorative orb/reticle from the VoiceOver rotor.
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .coordinateSpace(name: ResonancePlayfieldCoordinateSpace.name)
        .background(Color.ra11yGameFallbackBackground)
        .onPreferenceChange(iOSResonanceTargetMidYPreferenceKey.self) { targetY in
            DispatchQueue.main.async {
                guard targetY > -500, abs(targetY - lastTargetMidYInPlayfield) > 0.25 else { return }
                lastTargetMidYInPlayfield = targetY
                applyResonanceAlignmentFromLastFrames()
            }
        }
    }

    // MARK: - Lane

    private var resonanceLaneColumn: some View {
        VStack(alignment: .center, spacing: laneColumnInterItemSpacing) {
            Color.clear
                .frame(height: laneCenterSpacerHeight)
                .accessibilityHidden(true)
            ForEach(Array(rooms.enumerated()), id: \.element.id) { index, room in
                Group {
                    if room.isTarget {
                        moonstoneRow(room: room, index: index)
                    } else {
                        iOSLaneDecoyChip(style: .forRoomIndex(index))
                            .modifier(
                                iOSResonanceLaneSelectionModifier(
                                    distanceFromSelection: abs(index - laneIndexAtAimLine),
                                    isMoonstone: false
                                )
                            )
                    }
                }
                .frame(height: iOSDungeonResonanceLaneLayout.rowContentHeightPoints)
                .frame(maxWidth: .infinity)
            }
            Color.clear
                .frame(height: laneCenterSpacerHeight)
                .accessibilityHidden(true)
            Color.clear
                .frame(height: voiceOverLaneTrailingSlack)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RA11ySpacing.lg)
        /// Lane glyphs stay visual-only; VoiceOver uses the single UIKit scroll surface. This prevents duplicate
        /// focusable elements inside the decorative stack.
        .accessibilityElement(children: .ignore)
    }

    private func moonstoneRow(room: DungeonRoom, index: Int) -> some View {
        iOSMoonstoneTargetOrb()
            .modifier(
                iOSResonanceLaneSelectionModifier(
                    distanceFromSelection: abs(index - laneIndexAtAimLine),
                    isMoonstone: true
                )
            )
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
            /// Orb first so the reticle’s punched center looks through to the lane (orb uses a transparent core mask).
            iOSResonanceCenterOrb(band: aimBand)
            iOSResonanceReticleRing(band: aimBand)
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
        .background(Color.black.opacity(0.5))
        .background {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: ResonanceTopChromeHeightPreferenceKey.self,
                        value: geo.size.height
                    )
            }
        }
        .accessibilitySortPriority(iOSResonancePlayAccessibilitySortTier.topChrome)
        .onPreferenceChange(ResonanceTopChromeHeightPreferenceKey.self) { height in
            guard height > 0, abs(height - topChromeHeight) > 0.5 else { return }
            DispatchQueue.main.async {
                topChromeHeight = height
            }
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
            DispatchQueue.main.async {
                bottomChromeHeight = height
            }
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
                    .background(Color.black.opacity(0.55))
            } else if levelComplete, let continueAction = onContinue {
                continueButton(continueAction)
                    .background(Color.black.opacity(0.55))
            } else if let targetRoom = rooms.first(where: \.isTarget) {
                playfieldControlsContent(targetRoom: targetRoom, isEnabled: targetIsReachable)
                    .background(Color.black.opacity(0.55))
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
                playfieldControlsContent(targetRoom: targetRoom, isEnabled: true)
            } else {
                EmptyView()
            }
        }
    }

    /// Timeout uses `timeoutBanner`; L2/L3 retries are triggered from that banner.
    private var timeoutBanner: some View {
        VStack(spacing: RA11ySpacing.md) {
            Text(String(localized: "dungeon.timeout"))
                .questPaintReadableText(.sectionTitle)
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
            .questPaintReadableText(.bodySupporting)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RA11ySpacing.base)
            .background(Color.black.opacity(0.5), in: .rect(cornerRadius: RA11yRadius.card))
            .accessibilityAddTraits(.isStaticText)
    }

    private func playfieldControlsContent(targetRoom: DungeonRoom, isEnabled: Bool) -> some View {
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
            .accessibilityHint(
                isEnabled
                    ? String(localized: "dungeon.resonance.seal.hint")
                    : String(localized: "dungeon.target.notReachable")
            )
            Text(
                isEnabled
                    ? String(localized: "dungeon.resonance.a11y.orb.locked")
                    : String(localized: "dungeon.target.notReachable")
            )
            .questPaintReadableText(.materialCardMeta)
            .frame(maxWidth: .infinity)
        }
    }

    private func continueButton(_ action: @escaping () -> Void) -> some View {
        let title = continueButtonTitle ?? String(localized: "level.button.next")
        return Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .accessibilityIdentifier("dungeon.continue")
        .accessibilityLabel(title)
        .accessibilityHint(String(localized: "dungeon.a11y.continue.nextAscent.hint"))
    }

    private var objectiveCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
            Label(String(localized: "dm.label"), systemImage: "scroll.fill")
                .font(.ra11yCaption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(objectiveText)
                .questPaintReadableText(.materialCardTitle)
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.66), in: .rect(cornerRadius: RA11yRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(objectiveA11yLabel)
        .accessibilityHint(objectiveA11yHint)
    }

    private var firstLevelGestureTipCard: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
                Text(String(localized: "dungeon.explain.gesture.swipe3"))
                    .questPaintReadableText(.materialCardBody)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(localized: "dungeon.explain.gesture.swipe3u"))
                    .questPaintReadableText(.materialCardBody)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(localized: "dungeon.resonance.tip.voFocusOnGlyphStream"))
                    .questPaintReadableText(.materialCardBody)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 220)
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.45), in: .rect(cornerRadius: RA11yRadius.card))
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

// MARK: - Lane emphasis

/// Keeps the lane visually focused on one slot and sells the **fit** metaphor: the Moonstone nests into the hub when
/// centered; echo glyphs stay slightly undersized and canted so they read as “almost but not quite” the lock shape.
private struct iOSResonanceLaneSelectionModifier: ViewModifier {
    let distanceFromSelection: Int
    let isMoonstone: Bool

    /// Centered Moonstone: modest boost so the oval meets the reticle’s inner opening; centered decoy: smaller than 1 so it never “seats.”
    private var centerScale: CGFloat { isMoonstone ? 1.04 : 0.91 }

    private var offRowScale: CGFloat { 0.88 }

    /// Tiny yaw on centered decoys only — enough to break symmetry against the circular orb without clownish spin.
    private var decoyCenterTilt: Angle {
        guard !isMoonstone, distanceFromSelection == 0 else { return .zero }
        return .degrees(3.5)
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(distanceFromSelection == 0 ? centerScale : offRowScale)
            .rotationEffect(decoyCenterTilt)
            .opacity(distanceFromSelection == 0 ? 1.0 : (distanceFromSelection == 1 ? 0.28 : 0.0))
            // Avoid blur — it composites into dark rectangular bands behind PNG glyphs in the shaft.
            .animation(.easeOut(duration: 0.18), value: distanceFromSelection)
    }
}

// MARK: - Status row

/// Visible-only feedback line below the HUD (VoiceOver still receives hint via `requestHint` paths).
private struct iOSResonanceStatusRow: View {
    let message: String

    var body: some View {
        Text(message)
            .questPaintReadableText(.materialCardMeta)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RA11ySpacing.xs)
    }
}
