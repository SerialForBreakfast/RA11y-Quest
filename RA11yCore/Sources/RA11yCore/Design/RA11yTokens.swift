import CoreGraphics

/// Spacing step scale used throughout the RA11y UI.
///
/// Use these constants instead of raw numeric literals to keep
/// layout consistent and easy to audit.
///
/// - Note: All values are in points.
public enum RA11ySpacing {
    /// 4pt — tight inline spacing between adjacent elements.
    public static let xs: CGFloat = 4
    /// 8pt — small gaps and icon-level padding.
    public static let sm: CGFloat = 8
    /// 12pt — compact inset padding.
    public static let md: CGFloat = 12
    /// 16pt — standard padding; default screen inset.
    public static let base: CGFloat = 16
    /// 24pt — section-level spacing.
    public static let lg: CGFloat = 24
    /// 32pt — generous outer padding and large layout gaps.
    public static let xl: CGFloat = 32
}

/// Standardized corner radius values.
///
/// Use these instead of raw literals so radius decisions
/// are made once and applied consistently.
public enum RA11yRadius {
    /// 6pt — rank badge or small chip.
    public static let badge: CGFloat = 6
    /// 12pt — button or pill control.
    public static let button: CGFloat = 12
    /// 16pt — game card or container surface.
    public static let card: CGFloat = 16
    /// 20pt — bottom sheet or modal surface.
    public static let sheet: CGFloat = 20
}
