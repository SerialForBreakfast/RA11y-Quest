import SwiftUI

/// Semantic font style mapping for RA11y.
///
/// All styles map to Dynamic Type text styles so they scale automatically
/// with the user's preferred text size. Add new semantic names here
/// rather than using `.font(...)` with raw text styles in views.
///
/// Usage:
/// ```swift
/// Text("Training Academy")
///     .font(.ra11yLargeTitle)
/// ```
public extension Font {
    /// Primary game or screen title.
    static let ra11yLargeTitle: Font = .largeTitle

    /// Major heading; section or page title.
    static let ra11yTitle: Font = .title2

    /// Sub-heading; card title or list header.
    static let ra11yHeadline: Font = .headline

    /// Primary reading text.
    static let ra11yBody: Font = .body

    /// Supporting detail or secondary text.
    static let ra11ySubheadline: Font = .subheadline

    /// Fine-print labels; rank badges and timestamps.
    static let ra11yCaption: Font = .caption
}
