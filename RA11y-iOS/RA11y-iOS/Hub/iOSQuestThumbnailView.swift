import SwiftUI

// MARK: - iOSQuestThumbnailView

/// Square game thumbnail displayed on the left side of a quest card.
///
/// Loads a named image from the asset catalog. When the asset is missing
/// (e.g., before Design track delivers final art), displays a placeholder
/// using an SF Symbol that fits the D&D theme.
///
/// Size is driven by `@ScaledMetric` relative to `.body` so it participates
/// in Dynamic Type scaling, but is capped to prevent it from dominating the
/// card layout at large accessibility sizes.
///
/// ## Blend Mode
/// `.blendMode(.multiply)` removes white backgrounds from PNG assets by multiplying
/// pixel values — white (1,1,1) × dark background = dark background, so white becomes
/// transparent. Artwork with actual white content should ship as PNGs with a proper
/// alpha channel to avoid needing this workaround.
///
/// Marked `.accessibilityHidden(true)` because the thumbnail is purely
/// decorative within the quest card — the card's Button provides the full
/// accessibility label including the game's name and goal.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSQuestThumbnailView: View {

    // MARK: - Properties

    /// Asset catalog name for the thumbnail image.
    let assetName: String

    // MARK: - Adaptive Size

    /// Base size scales with Dynamic Type but is capped per device class.
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 72
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var thumbnailSize: CGFloat {
        let cap: CGFloat = sizeClass == .regular ? 108 : 96
        return min(scaledSize, cap)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    // Removes white backgrounds from PNG assets that lack an alpha channel.
                    // White pixels multiply to match the dark card surface beneath.
                    .blendMode(.multiply)
            } else {
                placeholder
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    // MARK: - Placeholder

    /// Shown when the final design asset is not yet available.
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.25))

            Image(systemName: "scroll")
                .font(.system(size: thumbnailSize * 0.4))
                .foregroundStyle(Color.ra11yAccent.opacity(0.6))
        }
    }
}

// MARK: - Previews

#Preview("With asset") {
    iOSQuestThumbnailView(assetName: "simon_room_bg")
        .padding()
        .background(Color(white: 0.15))
}

#Preview("Placeholder (missing asset)") {
    iOSQuestThumbnailView(assetName: "nonexistent_asset")
        .padding()
        .background(Color(white: 0.15))
}
