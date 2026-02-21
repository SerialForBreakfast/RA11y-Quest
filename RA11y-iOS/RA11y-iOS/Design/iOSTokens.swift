import SwiftUI

// MARK: - Semantic Color Tokens

/// Semantic color tokens for the RA11y iOS app.
///
/// Custom brand colors are backed by named entries in `Assets.xcassets/RA11y Colors/`,
/// which define Light, Dark, and High Contrast variants.
/// System-adaptive colors use UIKit's semantic palette, which already responds
/// to Dark Mode and Increase Contrast without additional asset catalog entries.
///
/// Usage:
/// ```swift
/// Text("Score").foregroundStyle(Color.ra11yLabel)
/// Button("Play") { ... }.tint(Color.ra11yAccent)
/// ```
extension Color {

    /// Brand accent color — primary interactive and highlight color.
    ///
    /// Defined in Assets.xcassets with Light, Dark, and High Contrast variants.
    /// Meets WCAG AA contrast requirements in all variants.
    static let ra11yAccent = Color("RA11yAccent")

    /// App background — adapts to Dark Mode and Increase Contrast via UIKit.
    static let ra11yBackground = Color(UIColor.systemBackground)

    /// Secondary surface for cards and grouped containers.
    static let ra11ySurface = Color(UIColor.secondarySystemGroupedBackground)

    /// Primary text color.
    static let ra11yLabel = Color(UIColor.label)

    /// Secondary / supporting text color.
    static let ra11ySecondaryLabel = Color(UIColor.secondaryLabel)
}

// MARK: - Token Notes
//
// Spacing tokens: RA11ySpacing.xs / .sm / .md / .base / .lg / .xl (from RA11yCore)
// Radius tokens:  RA11yRadius.badge / .button / .card / .sheet    (from RA11yCore)
// Font tokens:    Font.ra11yLargeTitle … Font.ra11yCaption         (from RA11yCore)
