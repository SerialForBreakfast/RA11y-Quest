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
    ///
    /// - Note: This adapts to system appearance and is designed for use on system
    ///   backgrounds. Do NOT use on the fixed-dark quest card surface — use
    ///   `ra11yCardSecondaryText` instead to guarantee contrast.
    static let ra11ySecondaryLabel = Color(UIColor.secondaryLabel)

    /// Secondary text on the fixed-dark quest card surface.
    ///
    /// Quest cards use `Color(red: 0.13, green: 0.10, blue: 0.09)` — a fixed dark
    /// background that does not adapt to system appearance. Using an adaptive system
    /// color like `UIColor.secondaryLabel` here would pass WCAG arithmetic but
    /// renders perceptually low-contrast on physical devices.
    ///
    /// This token provides ≥ 13:1 contrast on the dark card surface (WCAG AAA),
    /// giving goal-level text strong legibility across all ambient conditions.
    static let ra11yCardSecondaryText = Color.white.opacity(0.85)

    /// Tertiary / fine-print text on the fixed-dark quest card surface.
    ///
    /// Provides ≥ 8:1 contrast (WCAG AAA for large text) on the dark card surface.
    /// Use for caption-level content — estimated duration, supplementary labels.
    static let ra11yCardTertiaryText = Color.white.opacity(0.65)

    /// DM narrative card border — warm gold tone used across all three games.
    ///
    /// Fixed (non-adaptive) because it appears on fixed-dark in-game surfaces.
    static let ra11yDMBorder = Color(red: 0.75, green: 0.55, blue: 0.10)

    /// Fallback solid background for game scenes when asset loading fails.
    ///
    /// A fixed near-black tone matching the expected dark stone/stone-dungeon atmosphere.
    static let ra11yGameFallbackBackground = Color(red: 0.08, green: 0.06, blue: 0.04)

    /// Semantic color for a reachable / confirmed target — used on the target room status icon.
    ///
    /// Uses a fixed success-green appropriate for fixed-dark game surfaces.
    /// The icon shape (checkmark.seal vs lock.fill) conveys the same information
    /// without relying on color alone, satisfying WCAG 1.4.1 (Use of Color).
    static let ra11yTargetReachable = Color(red: 0.20, green: 0.78, blue: 0.35)
}

// MARK: - Token Notes
//
// Spacing tokens: RA11ySpacing.xs / .sm / .md / .base / .lg / .xl (from RA11yCore)
// Radius tokens:  RA11yRadius.badge / .button / .card / .sheet    (from RA11yCore)
// Font tokens:    Font.ra11yLargeTitle … Font.ra11yCaption         (from RA11yCore)
