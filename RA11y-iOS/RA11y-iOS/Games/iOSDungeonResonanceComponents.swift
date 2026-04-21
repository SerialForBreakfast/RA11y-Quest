import SwiftUI
import UIKit
import RA11yCore

// MARK: - Alignment (ADR-0003)

/// Vertical distance bands between the moonstone target and the fixed aim line (playfield center).
///
/// Values match the tuned mockup in `iOSDungeonResonanceMockupView` and drive orb/reticle
/// presentation plus `QuestFeedbackBand` for multimodal feedback.
enum iOSResonanceAlignment {
    /// Wider than the original 26 pt lock window so coarse VoiceOver scroll increments can still
    /// settle into the seal state instead of bouncing off the lower edge immediately.
    static let lockedMaxPoints: CGFloat = 52
    static let nearMaxPoints: CGFloat = 54
    static let warmMaxPoints: CGFloat = 118

    /// Distance magnitude in points; callers supply vertical centers in the **same** coordinate space.
    ///
    /// Crystal Resonance gameplay uses the named `resonancePlayfield` coordinate space.
    static func deltaPoints(targetMidY: CGFloat, aimMidY: CGFloat) -> CGFloat {
        abs(targetMidY - aimMidY)
    }

    /// Semantic feedback band derived from current alignment (no success state).
    static func questBand(deltaPoints: CGFloat) -> QuestFeedbackBand {
        if deltaPoints < lockedMaxPoints { return .locked }
        if deltaPoints < nearMaxPoints { return .near }
        if deltaPoints < warmMaxPoints { return .warm }
        return .far
    }

    /// Whether the scroll target is close enough to invoke / seal (game rules).
    static func isReachable(deltaPoints: CGFloat) -> Bool {
        deltaPoints < lockedMaxPoints
    }
}

// MARK: - Lane layout (visual + VoiceOver scroll proxy)

/// Shared metrics so the UIKit VoiceOver scroll proxy’s content height matches the on-screen glyph stack.
///
/// Row height uses the same default as ``iOSLaneDecoyChip``’s ``SwiftUI/ScaledMetric`` base (`.title`, 76 pt).
/// At very large Dynamic Type sizes the visual chips may grow slightly; the proxy still uses these
/// nominal values so scroll distance stays close to the shaft layout.
enum iOSDungeonResonanceLaneLayout {
    /// Vertical space between stacked decoys and Moonstone rows in the playfield.
    static let rowSpacingPoints: CGFloat = 56
    /// Nominal content height per lane row for scroll content math and the UIKit accessibility rows.
    static let rowContentHeightPoints: CGFloat = 76
    /// Extra vertical slack between lane rows so three-finger VoiceOver scrolling crosses a larger range per slot.
    static let voiceOverLaneStrideSlackPoints: CGFloat = 64
    /// Matches ``iOSMoonstoneTargetOrb`` default width ÷ height so the reticle’s **elliptical** hole fits the oblong Moonstone.
    static let moonstoneWidthOverHeight: CGFloat = 96.0 / 72.0
}

// MARK: - Presentation band (orb + reticle)

/// Visual ladder for the center orb and ring, including a brief success state after a level completes.
enum iOSResonanceAimBand: Equatable {
    case far
    case warm
    case near
    case locked
    case success

    /// Orb and feedback presentation from geometry; `levelComplete` forces `.success` for the flourish.
    static func displayBand(deltaPoints: CGFloat, levelComplete: Bool) -> iOSResonanceAimBand {
        if levelComplete { return .success }
        if deltaPoints < iOSResonanceAlignment.lockedMaxPoints { return .locked }
        if deltaPoints < iOSResonanceAlignment.nearMaxPoints { return .near }
        if deltaPoints < iOSResonanceAlignment.warmMaxPoints { return .warm }
        return .far
    }
}

// MARK: - Preference

/// Vertical center of the moonstone in the same coordinate space as the playfield aim line (named `resonancePlayfield`).
struct iOSResonanceTargetMidYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = -10_000

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > -1_000 { value = next }
    }
}

// MARK: - Background

/// Full-bleed shaft background for resonance gameplay (`dungeon_resonance_bg`).
struct iOSShaftResonanceBackground: View {
    var body: some View {
        Group {
            if let uiImage = UIImage(named: iOSDungeonResonanceArt.background) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, minHeight: 0)
                    .clipped()
                    .overlay {
                        RadialGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.45)],
                            center: .center,
                            startRadius: 40,
                            endRadius: 420
                        )
                    }
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.04, blue: 0.06),
                        Color(red: 0.12, green: 0.08, blue: 0.06),
                        Color(red: 0.05, green: 0.04, blue: 0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    RadialGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                        center: .center,
                        startRadius: 40,
                        endRadius: 420
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Lights Off vignette: darkens the lane while preserving the center orb anchor (ADR-0003).
struct iOSResonanceLightsOffVignette: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
            RadialGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.95)],
                center: .center,
                startRadius: 56,
                endRadius: 320
            )
            if let spot = UIImage(named: iOSDungeonResonanceArt.spotlightMaskReference) {
                Image(uiImage: spot)
                    .renderingMode(.original)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFill()
                    .blendMode(.plusLighter)
                    .opacity(0.32)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Wide canvas catalog scaling

/// Draw helper for Crystal Resonance PNGs authored on **wide landscape** masters (~1376×768) with the
/// subject centered (see ``iOSDungeonResonanceArt`` and the design pipeline note).
///
/// ``SwiftUI/View/scaledToFit()`` fits the **entire** bitmap into small point frames, so the centered
/// glyph shrinks to a faint smear. ``SwiftUI/View/scaledToFill()`` with a fixed ``SwiftUI/View/frame``
/// and ``SwiftUI/View/clipped()`` center-crops and fills the allotted points so silhouettes read at the
/// intended visual weight on phone and iPad.
struct iOSResonanceWideCanvasImage: View {
    let uiImage: UIImage
    var width: CGFloat?
    var height: CGFloat?

    var body: some View {
        Image(uiImage: uiImage)
            .renderingMode(.original)
            .interpolation(.high)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
    }
}

// MARK: - Lane content

/// Visual decoy families for non-target chambers (catalog-first).
enum iOSResonanceDecoyStyle: CaseIterable {
    case ember
    case shadowGlyph
    case sunSigil

    fileprivate var assetName: String {
        switch self {
        case .ember: return iOSDungeonResonanceArt.decoyEmberShard
        case .shadowGlyph: return iOSDungeonResonanceArt.decoyShadowGlyph
        case .sunSigil: return iOSDungeonResonanceArt.decoySunSigil
        }
    }

    /// Rotates through decoy silhouettes by list index so the lane stays visually distinct.
    static func forRoomIndex(_ index: Int) -> iOSResonanceDecoyStyle {
        let all = iOSResonanceDecoyStyle.allCases
        return all[index % all.count]
    }

    /// VoiceOver name for the visible glyph — Crystal Resonance uses relic motifs, not dungeon room titles.
    var localizedAccessibilityItemName: String {
        switch self {
        case .ember:
            String(localized: "dungeon.resonance.item.emberShard")
        case .shadowGlyph:
            String(localized: "dungeon.resonance.item.shadowGlyph")
        case .sunSigil:
            String(localized: "dungeon.resonance.item.sunSigil")
        }
    }
}

/// Moving resonance target — prefers `dungeon_target_moonstone` from the asset catalog.
///
/// In play, ``iOSDungeonResonancePlayView`` applies a **larger** center-row scale to this view than to decoys so the
/// Moonstone oval reads as seating into the reticle while echo glyphs stay visually “off.”
struct iOSMoonstoneTargetOrb: View {
    @ScaledMetric(relativeTo: .title) private var moonW: CGFloat = 96
    @ScaledMetric(relativeTo: .title) private var moonH: CGFloat = 72

    var body: some View {
        Group {
            if let ui = UIImage(named: iOSDungeonResonanceArt.targetMoonstone) {
                iOSResonanceWideCanvasImage(uiImage: ui, width: moonW, height: moonH)
                    // Avoid shadow / compositingGroup — both can read as grey boxes on dark shaft art.
            } else {
                ZStack {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color(red: 0.72, green: 0.78, blue: 0.92).opacity(0.85),
                                    Color(red: 0.35, green: 0.45, blue: 0.62).opacity(0.5),
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 44
                            )
                        )
                        .frame(width: moonW * 0.92, height: moonH * 0.89)
                    Ellipse()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        .frame(width: moonW * 0.92, height: moonH * 0.89)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Wrong-target glyphs — catalog art with geometric fallbacks if an asset is missing.
struct iOSLaneDecoyChip: View {
    let style: iOSResonanceDecoyStyle
    var hidesFromAccessibility: Bool = true

    @ScaledMetric(relativeTo: .title) private var chip: CGFloat = 76

    var body: some View {
        Group {
            if let ui = UIImage(named: style.assetName) {
                iOSResonanceWideCanvasImage(uiImage: ui, width: chip, height: chip)
            } else {
                legacyDecoyPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(0.9)
        .accessibilityHidden(hidesFromAccessibility)
    }

    @ViewBuilder
    private var legacyDecoyPlaceholder: some View {
        switch style {
        case .ember:
            iOSEmberShardFallbackShape()
                .fill(Color.orange.opacity(0.55))
                .frame(width: chip * 0.92, height: chip)
        case .shadowGlyph:
            Image(systemName: "diamond.fill")
                .font(.system(size: chip * 0.72))
                .foregroundStyle(Color.purple.opacity(0.45))
        case .sunSigil:
            Image(systemName: "sun.max.fill")
                .font(.system(size: chip * 0.72))
                .foregroundStyle(Color.yellow.opacity(0.5))
        }
    }
}

private struct iOSEmberShardFallbackShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Neutral lane tick — prefers `dungeon_lane_marker_neutral`.
struct iOSLaneLaneMarkerNeutral: View {
    var body: some View {
        Group {
            if let ui = UIImage(named: iOSDungeonResonanceArt.laneMarkerNeutral) {
                GeometryReader { geo in
                    iOSResonanceWideCanvasImage(uiImage: ui, width: geo.size.width, height: 22)
                }
                .frame(height: 22)
                .frame(maxWidth: .infinity)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 22)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.ra11yDMBorder.opacity(0.2), lineWidth: 1)
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Center orb & reticle

/// Cuts an **elliptical** window in the middle of the reticle (Moonstone oblong inside a circular ring PNG) so lane glyphs
/// read through the hole and the lock shape matches the Moonstone aspect ratio.
///
/// Uses even-odd fill instead of ``blendMode(.destinationOut)`` so UI updates (e.g. seal press / state changes)
/// do not flash a transient grey compositing slab around the hub.
private struct iOSResonanceReticleDonutMask: View {
    let diameter: CGFloat
    /// Inner hole **width** as a fraction of the square mask’s width (height follows ``iOSDungeonResonanceLaneLayout.moonstoneWidthOverHeight``).
    var innerWidthFraction: CGFloat = 0.58

    var body: some View {
        iOSResonanceReticleDonutMaskShape(diameter: diameter, innerWidthFraction: innerWidthFraction)
            .fill(Color.white, style: FillStyle(eoFill: true))
            .frame(width: diameter, height: diameter)
    }
}

/// Even-odd donut for ``iOSResonanceReticleDonutMask`` — stable masking without destination-out compositing.
private struct iOSResonanceReticleDonutMaskShape: Shape {
    var diameter: CGFloat
    var innerWidthFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        let innerW = diameter * innerWidthFraction
        // Matches `iOSDungeonResonanceLaneLayout.moonstoneWidthOverHeight` (Shape `path(in:)` is nonisolated).
        let moonstoneWidthOverHeight: CGFloat = 96.0 / 72.0
        let innerH = innerW / moonstoneWidthOverHeight
        let outerOrigin = CGPoint(x: rect.midX - diameter * 0.5, y: rect.midY - diameter * 0.5)
        var path = Path()
        path.addEllipse(in: CGRect(origin: outerOrigin, size: CGSize(width: diameter, height: diameter)))
        path.addEllipse(in: CGRect(
            x: rect.midX - innerW * 0.5,
            y: rect.midY - innerH * 0.5,
            width: innerW,
            height: innerH
        ))
        return path
    }
}

/// Fixed center reticle ring; responds to `iOSResonanceAimBand` for glow/pulse.
struct iOSResonanceReticleRing: View {
    let band: iOSResonanceAimBand

    @ScaledMetric(relativeTo: .title) private var ringBase: CGFloat = 172

    var body: some View {
        let pulse: CGFloat = switch band {
        case .far: 0.15
        case .warm: 0.35
        case .near: 0.55
        case .locked: 0.85
        case .success: 1.0
        }

        let diameter = ringBase + pulse * 14

        Group {
            if let ui = UIImage(named: iOSDungeonResonanceArt.reticleRing) {
                iOSResonanceWideCanvasImage(uiImage: ui, width: diameter, height: diameter)
                    .opacity(0.62 + pulse * 0.32)
                    .mask {
                        iOSResonanceReticleDonutMask(diameter: diameter, innerWidthFraction: 0.58)
                    }
            } else {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.ra11yDMBorder.opacity(0.25 + pulse * 0.5),
                                Color(red: 0.55, green: 0.75, blue: 0.95).opacity(0.35 + pulse * 0.45),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2 + pulse * 2
                    )
                    .frame(width: diameter, height: diameter)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Fixed crystal orb — primary VoiceOver anchor for the resonance shaft (spoken label varies by band).
struct iOSResonanceCenterOrb: View {
    let band: iOSResonanceAimBand

    @ScaledMetric(relativeTo: .title) private var orbDiameter: CGFloat = 112

    var body: some View {
        ZStack {
            if let uiImage = UIImage(named: orbImageName) {
                iOSResonanceWideCanvasImage(uiImage: uiImage, width: orbDiameter, height: orbDiameter)
                    .saturation(bandSaturation)
                    /// Fully clear core so the Moonstone lane reads through the hub (avoids grey “film” / checkerboard seams with the reticle hole).
                    .mask {
                        RadialGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Color.white.opacity(0.28), location: 0.32),
                                .init(color: Color.white.opacity(0.78), location: 0.58),
                                .init(color: Color.white, location: 1.0),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: orbDiameter * 0.56
                        )
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(orbGlowColor.opacity(0.4), lineWidth: 1.5)
                            .frame(width: orbDiameter + 6, height: orbDiameter + 6)
                    }
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(orbGradient)
                    .frame(width: orbDiameter, height: orbDiameter)
                    .shadow(color: orbGlowColor, radius: orbGlowRadius)
            }

            if band == .success {
                Circle()
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 3)
                    .frame(width: orbDiameter + 12, height: orbDiameter + 12)
                    .transition(.opacity)
            }

            if UIImage(named: orbImageName) == nil {
                Circle()
                    .strokeBorder(Color.white.opacity(0.22 + ringHighlight * 0.5), lineWidth: 1)
                    .frame(width: orbDiameter + 8, height: orbDiameter + 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: band)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var orbImageName: String {
        switch band {
        case .locked, .success:
            return iOSDungeonResonanceArt.orbLocked
        default:
            return iOSDungeonResonanceArt.orbIdle
        }
    }

    private var bandSaturation: Double {
        switch band {
        case .far: return 0.82
        case .warm: return 0.92
        case .near: return 1.0
        case .locked: return 1.05
        case .success: return 1.12
        }
    }

    private var ringHighlight: CGFloat {
        switch band {
        case .far: return 0.1
        case .warm: return 0.35
        case .near: return 0.55
        case .locked: return 0.85
        case .success: return 1.0
        }
    }

    private var orbGlowRadius: CGFloat {
        switch band {
        case .far: return 6
        case .warm: return 12
        case .near: return 18
        case .locked: return 26
        case .success: return 32
        }
    }

    private var orbGlowColor: Color {
        switch band {
        case .far:
            return Color(red: 0.4, green: 0.35, blue: 0.55).opacity(0.35)
        case .warm:
            return Color.ra11yAccent.opacity(0.35)
        case .near:
            return Color(red: 0.65, green: 0.82, blue: 1.0).opacity(0.55)
        case .locked:
            return Color(red: 0.85, green: 0.95, blue: 1.0).opacity(0.75)
        case .success:
            return Color.ra11yTargetReachable.opacity(0.65)
        }
    }

    private var orbGradient: LinearGradient {
        switch band {
        case .success:
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color.ra11yTargetReachable.opacity(0.85),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [
                    Color(red: 0.75, green: 0.82, blue: 0.95),
                    Color(red: 0.35, green: 0.42, blue: 0.62),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var accessibilityLabelText: String {
        switch band {
        case .far: return String(localized: "dungeon.resonance.a11y.orb.far")
        case .warm: return String(localized: "dungeon.resonance.a11y.orb.warm")
        case .near: return String(localized: "dungeon.resonance.a11y.orb.near")
        case .locked: return String(localized: "dungeon.resonance.a11y.orb.locked")
        case .success: return String(localized: "dungeon.resonance.a11y.orb.success")
        }
    }
}

/// Brief success burst over the orb when the chamber is cleared.
struct iOSResonanceSuccessFlareOverlay: View {
    @ScaledMetric(relativeTo: .title) private var flareSize: CGFloat = 220

    var body: some View {
        if let ui = UIImage(named: iOSDungeonResonanceArt.successFlare) {
            iOSResonanceWideCanvasImage(uiImage: ui, width: flareSize, height: flareSize)
                .blendMode(.screen)
                .opacity(0.88)
                .accessibilityHidden(true)
        }
    }
}
