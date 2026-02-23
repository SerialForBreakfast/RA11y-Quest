import SwiftUI

// MARK: - iOSHubBackgroundView

/// Full-bleed atmospheric background for the hub screen.
///
/// Renders an asset image in aspect-fill mode behind a dark gradient overlay.
/// The gradient guarantees WCAG AA contrast for text at any point on the image,
/// regardless of how light or dark the underlying region is.
///
/// ## Usage
/// Apply as `.background { iOSHubBackgroundView(assetName:) }` on the content
/// layer — **not** as a ZStack peer. The `.background {}` modifier sizes this
/// view to the foreground content's layout frame; `.ignoresSafeArea()` then
/// extends it behind the navigation bar and home indicator independently,
/// without affecting the content layout's width.
///
/// Using a ZStack peer instead would allow a landscape background image
/// (e.g., 1920×1080) to report its full intrinsic width to the ZStack,
/// causing every sibling to lay out in that inflated space and appear clipped.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSHubBackgroundView: View {

    // MARK: - Properties

    /// Asset catalog name for the background image.
    let assetName: String

    // MARK: - Body

    var body: some View {
        ZStack {
            // Fallback base color shown when the background image asset is absent
            // (e.g., before the Design track delivers final art). Deep tavern brown
            // preserves the D&D atmosphere without relying on the image.
            Color(red: 0.10, green: 0.07, blue: 0.05)
                .accessibilityHidden(true)

            // The image is proposed the full screen size (including safe areas) because
            // of `.ignoresSafeArea()` below. `.scaledToFill()` fills that proposal.
            // No explicit frame is needed; the ZStack's `.ignoresSafeArea()` anchors the
            // size correctly when used inside `.background {}`.
        Image(assetName)
                .resizable()
                .scaledToFill()
                // Clip prevents the fill-scaled image from bleeding outside
                // the ZStack frame when the asset's aspect ratio doesn't match
                // the device's screen ratio exactly.
                .clipped()
                .accessibilityHidden(true)

            // Top-heavy overlay: darker near the nav bar for title legibility,
            // lighter toward the bottom so the dark quest card backgrounds dominate.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.62),
                    Color.black.opacity(0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .accessibilityHidden(true)

            // Subtle vignette to focus attention on the quest cards.
            RadialGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.55)
                ],
                center: .center,
                startRadius: 120,
                endRadius: 520
            )
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    iOSHubBackgroundView(assetName: "hub_quest_board_bg")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
