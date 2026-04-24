import SwiftUI

// MARK: - iOSHubBackgroundView

/// Full-bleed atmospheric background for the hub screen.
///
/// Stacks ``QuestPaintAmbientBackdrop`` with ``QuestPaintReadableScrim`` so hub copy
/// matches the mockup “quest paint” treatment used on results and VO gates.
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
            // Fallback base color when the catalog image is missing (deep tavern brown).
            Color(red: 0.10, green: 0.07, blue: 0.05)
                .accessibilityHidden(true)

            QuestPaintAmbientBackdrop(imageName: assetName)

            QuestPaintReadableScrim()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    iOSHubBackgroundView(assetName: "simon_room_bg")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
