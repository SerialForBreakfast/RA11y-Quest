import SwiftUI

// MARK: - iOSLightsOffGameplayBlackoutModifier

/// Covers the wrapped view with an opaque black layer that does not receive touches or
/// accessibility focus, so VoiceOver continues to navigate interactive content underneath.
///
/// Used for Lights Off training mode: the player must rely on assistive technology rather
/// than sight. The overlay is visually opaque but excluded from the accessibility tree
/// (`accessibilityHidden(true)`) and does not block hit testing (`allowsHitTesting(false)`).
///
/// Apply only to gameplay visuals (e.g. relic rows, seal grids, dungeon room icons), not
/// to instructional prompts, timers, or navigation chrome.
///
/// ## Stability within a run
/// Callers must not reorder or replace the accessibility subtree under this overlay
/// mid-attempt except through normal game rules. Randomize layout only when a level
/// begins, not during active play (`LightsOffMode-Recommendations.txt`).
struct iOSLightsOffGameplayBlackoutModifier: ViewModifier {

    /// When `true`, the blackout layer is drawn over the content.
    let isEnabled: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
            if isEnabled {
                Color.black
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {

    /// Hides gameplay visuals behind an opaque, accessibility-inert blackout layer.
    ///
    /// - Parameter isEnabled: When `true`, covers this subtree with black without
    ///   affecting VoiceOver traversal of the underlying controls.
    func ra11yLightsOffGameplayBlackout(isEnabled: Bool) -> some View {
        modifier(iOSLightsOffGameplayBlackoutModifier(isEnabled: isEnabled))
    }
}
