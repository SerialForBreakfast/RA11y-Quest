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

    /// Warm gold used for headings, borders, and accents in the D&D theme.
    static let ra11yGold = Color(red: 0.88, green: 0.72, blue: 0.38)

    /// Deeper gold used for fills and emphasis.
    static let ra11yGoldDeep = Color(red: 0.72, green: 0.54, blue: 0.20)

    /// Primary quest card surface color.
    static let ra11yCardSurface = Color(red: 0.16, green: 0.12, blue: 0.10)

    /// Highlighted quest card surface tone for subtle gradients.
    static let ra11yCardSurfaceHighlight = Color(red: 0.20, green: 0.15, blue: 0.12)

    /// Quest card border color.
    static let ra11yCardBorder = Color(red: 0.78, green: 0.60, blue: 0.22)

    /// Footer background surface behind the hub buttons.
    static let ra11yFooterSurface = Color(red: 0.12, green: 0.09, blue: 0.07)

    /// Text color tuned for dark, warm surfaces.
    static let ra11yWarmText = Color(red: 0.92, green: 0.88, blue: 0.80)

    /// Secondary text color for warm surfaces.
    static let ra11yWarmTextSecondary = Color(red: 0.82, green: 0.76, blue: 0.68)
}

// MARK: - Token Notes
//
// Spacing tokens: RA11ySpacing.xs / .sm / .md / .base / .lg / .xl (from RA11yCore)
// Radius tokens:  RA11yRadius.badge / .button / .card / .sheet    (from RA11yCore)
// Font tokens:    Font.ra11yLargeTitle … Font.ra11yCaption         (from RA11yCore)
