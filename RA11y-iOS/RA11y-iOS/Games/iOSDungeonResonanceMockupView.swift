import SwiftUI
import UIKit
import Observation
import RA11yCore

// MARK: - iOSDungeonResonanceMockupView

/// Prototype-local bridge that routes resonance interactions through the shared quest feedback system.
@MainActor
@Observable
private final class DungeonResonanceFeedbackPreviewModel {

    /// User-facing feedback preferences exposed in the mockup inspector.
    let settings: iOSFeedbackSettings

    private let coordinator: iOSQuestFeedbackCoordinator

    init() {
        let settings = iOSFeedbackSettings()
        self.settings = settings
        self.coordinator = iOSQuestFeedbackCoordinator(profile: .dungeonResonance, settings: settings)
    }

    /// Applies the currently selected preview profile.
    ///
    /// - Parameter resetState: Whether reducer and cooldown state should be reset.
    func applyCurrentProfile(resetState: Bool = false) {
        coordinator.updateProfile(
            settings.calmMode ? .calmGuidance : .dungeonResonance,
            resetState: resetState
        )
    }

    /// Processes a semantic alignment band transition.
    ///
    /// - Parameter band: Current semantic proximity band.
    func processAlignmentBand(_ band: QuestFeedbackBand) {
        coordinator.process(.alignmentBandChanged(band))
    }

    /// Emits a hint cue.
    func processHintRequest() {
        coordinator.process(.hintRequested)
    }

    /// Emits a wrong-activation cue.
    func processWrongActivation() {
        coordinator.process(.wrongActivation)
    }

    /// Emits a success cue.
    func processSuccess() {
        coordinator.process(.success)
    }

    /// Resets reducer and cooldown state.
    func reset() {
        coordinator.reset()
    }
}

/// Crystal Resonance v2 resonance prototype surface.
///
/// This view encodes ADR-0003 layout intent and currently serves as both the routed
/// prototype destination and the screenshot/mockup surface while gameplay is iterating:
/// fixed center orb + reticle, vertical lane scrolling underneath, multimodal feedback
/// driven by geometry-derived alignment bands and the shared feedback coordinator.
///
/// ## Iteration controls
/// - **Live alignment**: Scroll the lane; orb reflectance follows distance from the
///   moonstone target to the screen aim line (geometry-driven).
/// - **Manual band**: Override the resonance ladder to snapshot Far → Success for reviews.
/// - **Lights Off**: Dark vignette with orb/reticle preserved per ADR Lights Off rule.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSDungeonResonanceMockupView: View {

    /// ADR ladder (+ success flourish).
    enum ResonanceBand: String, CaseIterable, Identifiable {
        case far = "Far"
        case warm = "Warm"
        case near = "Near"
        case locked = "Locked"
        case success = "Success"
        var id: String { rawValue }
    }

    /// When `true`, ignore geometry and use `manualBand`.
    @State private var useManualBand = false
    @State private var manualBand: ResonanceBand = .far

    @State private var liveDeltaPoints: CGFloat = 500

    /// Edge darkening for Lights Off exploration (orb stays visible).
    @State private var lightsOffPreview = false

    @State private var showInspector = true
    @State private var feedbackPreview = DungeonResonanceFeedbackPreviewModel()

    /// Mock tuning: |Δy| bands in points (see inspector footer for current values).
    private let bandLockedMax: CGFloat = 26
    private let bandNearMax: CGFloat = 54
    private let bandWarmMax: CGFloat = 118

    /// Geometry-driven band: largest delta → Far, then Warm, Near, smallest → Locked.
    private var liveBand: ResonanceBand {
        let d = liveDeltaPoints
        if d < bandLockedMax { return .locked }
        if d < bandNearMax { return .near }
        if d < bandWarmMax { return .warm }
        return .far
    }

    /// Smooth orb presentation: locked reads more energized than raw distance alone.
    private var effectiveBand: ResonanceBand {
        if useManualBand { return manualBand }
        return liveBand
    }

    var body: some View {
        GeometryReader { screenGeo in
            let aimMidY = screenGeo.frame(in: .global).midY
            ZStack {
                shaftBackground

                ScrollView(.vertical) {
                    laneColumn
                        .padding(.vertical, RA11ySpacing.xl)
                }
                .scrollIndicators(.visible)
                /// Hides the system scroll surface so transparent glyph PNGs composite on the shaft
                /// instead of picking up a grey default background (visible in screenshots as boxes).
                .scrollContentBackground(.hidden)
                .coordinateSpace(name: "mockupLane")

                centerOrbOverlay
                    .allowsHitTesting(false)

                if lightsOffPreview {
                    lightsOffVignette
                        .allowsHitTesting(false)
                }
            }
            .onPreferenceChange(TargetMidYPreferenceKey.self) { targetY in
                guard !useManualBand else { return }
                guard targetY > -1_000 else { return }
                liveDeltaPoints = abs(targetY - aimMidY)
            }
        }
        .background(Color.ra11yGameFallbackBackground)
        .navigationTitle("Crystal Resonance (prototype)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInspector.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel(showInspector ? "Hide design inspector" : "Show design inspector")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showInspector {
                VStack(spacing: RA11ySpacing.sm) {
                    inspectorBar
                    feedbackActionBar
                }
            }
        }
        .accessibilityIdentifier("resonance.mockup.root")
        .preferredColorScheme(.dark)
        .onAppear {
            feedbackPreview.applyCurrentProfile(resetState: true)
            feedbackPreview.processAlignmentBand(feedbackBand(for: effectiveBand))
        }
        .onChange(of: effectiveBand) { _, newBand in
            feedbackPreview.processAlignmentBand(feedbackBand(for: newBand))
        }
        .onChange(of: feedbackPreview.settings.calmMode) { _, _ in
            feedbackPreview.applyCurrentProfile(resetState: true)
            feedbackPreview.processAlignmentBand(feedbackBand(for: effectiveBand))
        }
    }

    // MARK: - Background

    private var shaftBackground: some View {
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

    /// Darkens the lane; keeps orb visible. Optional catalog spotlight softens the center.
    private var lightsOffVignette: some View {
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

    // MARK: - Lane (scrollable)

    private var laneColumn: some View {
        VStack(spacing: 56) {
            laneSectionLabel(String(localized: "dungeon.resonance.mockup.laneSectionAbove"))

            LaneDecoyChip(style: .ember, accessibilityHidden: true)
            LaneLaneMarkerNeutral()

            LaneDecoyChip(style: .shadowGlyph, accessibilityHidden: true)

            moonstoneTarget

            LaneLaneMarkerNeutral()
            LaneLaneMarkerNeutral()

            LaneDecoyChip(style: .sunSigil, accessibilityHidden: true)

            laneSectionLabel(String(localized: "dungeon.resonance.mockup.laneSectionBelow"))
            Color.clear.frame(height: 200)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RA11ySpacing.lg)
    }

    /// Preview-only lane captions; aligns mockup labels with the Moonstone / echo-glyph metaphor.
    private func laneSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.ra11yCaption)
            .foregroundStyle(Color.ra11yCardTertiaryText)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var moonstoneTarget: some View {
        MoonstoneTargetOrb()
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: TargetMidYPreferenceKey.self,
                        value: geo.frame(in: .global).midY
                    )
                }
            }
    }

    // MARK: - Fixed center (orb + reticle)

    /// Sits above the scroll lane; hit testing disabled so 3-finger scroll reaches the lane beneath.
    private var centerOrbOverlay: some View {
        ZStack {
            ResonanceReticleRing(band: effectiveBand)
            ResonanceCenterOrb(band: effectiveBand)
            if effectiveBand == .success, UIImage(named: iOSDungeonResonanceArt.successFlare) != nil {
                ResonanceSuccessFlareOverlay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Inspector

    private var inspectorBar: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Toggle("Manual band (override)", isOn: $useManualBand)

            if useManualBand {
                Picker("Band", selection: $manualBand) {
                    ForEach(ResonanceBand.allCases) { band in
                        Text(band.rawValue).tag(band)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                HStack {
                    Text("Δ to aim")
                        .font(.ra11yCaption)
                    Spacer()
                    Text("\(Int(liveDeltaPoints)) pt")
                        .font(.ra11yCaption.monospacedDigit())
                        .foregroundStyle(Color.ra11yCardSecondaryText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Distance to aim line, \(Int(liveDeltaPoints)) points")
            }

            Toggle("Lights Off preview", isOn: $lightsOffPreview)
            Toggle("Sound cues", isOn: soundEnabledBinding)
            Toggle("Haptics", isOn: hapticsEnabledBinding)
            Toggle("Spoken hints", isOn: spokenHintsEnabledBinding)
            Toggle("Calm feedback mode", isOn: calmModeBinding)

            Text(
                "Scroll the lane until the moonstone aligns with the center orb. " +
                    "Live bands: locked < \(Int(bandLockedMax)), " +
                    "near < \(Int(bandNearMax)), warm < \(Int(bandWarmMax)), else Far."
            )
            .font(.ra11yCaption)
            .foregroundStyle(Color.ra11yCardTertiaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RA11ySpacing.md)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
        .padding(.horizontal, RA11ySpacing.md)
        .padding(.bottom, RA11ySpacing.sm)
    }

    /// Preview-only row for semantic actions that are not produced by scrolling alone.
    private var feedbackActionBar: some View {
        HStack(spacing: RA11ySpacing.sm) {
            Button("Hint") {
                feedbackPreview.processHintRequest()
            }
            .buttonStyle(.bordered)

            Button("Invoke") {
                handleInvokeAction()
            }
            .buttonStyle(.borderedProminent)

            Button("Reset Cues") {
                feedbackPreview.reset()
                feedbackPreview.processAlignmentBand(feedbackBand(for: effectiveBand))
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RA11ySpacing.md)
        .padding(.bottom, RA11ySpacing.sm)
    }

    /// Converts mockup presentation bands into reusable semantic feedback bands.
    private func feedbackBand(for band: ResonanceBand) -> QuestFeedbackBand {
        switch band {
        case .far:
            return .far
        case .warm:
            return .warm
        case .near:
            return .near
        case .locked, .success:
            return .locked
        }
    }

    /// Applies the mockup's invoke behavior using shared semantic success/error events.
    private func handleInvokeAction() {
        if effectiveBand == .locked || effectiveBand == .success {
            if useManualBand {
                manualBand = .success
            }
            feedbackPreview.processSuccess()
        } else {
            feedbackPreview.processWrongActivation()
        }
    }

    /// Binding wrapper for preview sound settings.
    private var soundEnabledBinding: Binding<Bool> {
        Binding(
            get: { feedbackPreview.settings.soundEnabled },
            set: { feedbackPreview.settings.soundEnabled = $0 }
        )
    }

    /// Binding wrapper for preview haptic settings.
    private var hapticsEnabledBinding: Binding<Bool> {
        Binding(
            get: { feedbackPreview.settings.hapticsEnabled },
            set: { feedbackPreview.settings.hapticsEnabled = $0 }
        )
    }

    /// Binding wrapper for preview spoken-hint settings.
    private var spokenHintsEnabledBinding: Binding<Bool> {
        Binding(
            get: { feedbackPreview.settings.spokenHintsEnabled },
            set: { feedbackPreview.settings.spokenHintsEnabled = $0 }
        )
    }

    /// Binding wrapper for preview calm-mode selection.
    private var calmModeBinding: Binding<Bool> {
        Binding(
            get: { feedbackPreview.settings.calmMode },
            set: { feedbackPreview.settings.calmMode = $0 }
        )
    }
}

// MARK: - Preference

/// Global-space vertical center of the moonstone target (for aim delta).
private struct TargetMidYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = -10_000

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > -1_000 { value = next }
    }
}

// MARK: - Moonstone (catalog + fallback)

/// Moving resonance target — prefers `dungeon_target_moonstone` from the asset catalog.
private struct MoonstoneTargetOrb: View {
    @ScaledMetric(relativeTo: .title) private var moonW: CGFloat = 96
    @ScaledMetric(relativeTo: .title) private var moonH: CGFloat = 72

    var body: some View {
        Group {
            if let ui = UIImage(named: iOSDungeonResonanceArt.targetMoonstone) {
                iOSResonanceWideCanvasImage(uiImage: ui, width: moonW, height: moonH)
                    .shadow(color: Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.4), radius: 10)
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
        .compositingGroup()
        .accessibilityHidden(true)
    }
}

// MARK: - Decoys & lane markers (catalog + fallback)

private enum DecoyStyle {
    case ember, shadowGlyph, sunSigil

    fileprivate var assetName: String {
        switch self {
        case .ember: return iOSDungeonResonanceArt.decoyEmberShard
        case .shadowGlyph: return iOSDungeonResonanceArt.decoyShadowGlyph
        case .sunSigil: return iOSDungeonResonanceArt.decoySunSigil
        }
    }
}

/// Wrong-target chips — prefers catalog art; geometric fallbacks if a PNG is missing.
private struct LaneDecoyChip: View {
    let style: DecoyStyle
    var accessibilityHidden: Bool = true

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
        .compositingGroup()
        .opacity(0.9)
        .accessibilityHidden(accessibilityHidden)
    }

    @ViewBuilder
    private var legacyDecoyPlaceholder: some View {
        switch style {
        case .ember:
            EmberShardFallbackShape()
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

private struct EmberShardFallbackShape: Shape {
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
private struct LaneLaneMarkerNeutral: View {
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

// MARK: - Center orb & reticle (catalog + fallback)

private struct ResonanceReticleRing: View {
    let band: iOSDungeonResonanceMockupView.ResonanceBand

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
                    .opacity(0.42 + pulse * 0.5)
                    .shadow(color: Color.ra11yAccent.opacity(0.12 + pulse * 0.38), radius: 6 + pulse * 10)
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
                    .shadow(color: Color.ra11yAccent.opacity(0.15 + pulse * 0.35), radius: 8 + pulse * 10)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ResonanceCenterOrb: View {
    let band: iOSDungeonResonanceMockupView.ResonanceBand

    @ScaledMetric(relativeTo: .title) private var orbDiameter: CGFloat = 112

    var body: some View {
        ZStack {
            if let uiImage = UIImage(named: orbImageName) {
                iOSResonanceWideCanvasImage(uiImage: uiImage, width: orbDiameter, height: orbDiameter)
                    .saturation(bandSaturation)
                    .shadow(color: orbGlowColor, radius: orbGlowRadius)
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

/// Brief success burst over the orb when the Success band is selected (manual preview).
private struct ResonanceSuccessFlareOverlay: View {
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

// MARK: - Preview

#Preview("Crystal Resonance — mockup") {
    iOSDungeonResonanceMockupView()
}
