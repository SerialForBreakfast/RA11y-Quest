import SwiftUI
import RA11yCore

// MARK: - iOSRankBadgeView

/// Displays the player's best rank for a game as a D&D-themed wax seal shape plus label.
///
/// Ranks map to distinct shapes — not color alone — to satisfy accessibility contrast
/// requirements. Each shape is drawn with SwiftUI `Canvas` so it renders crisply at
/// any point size without managing image assets.
///
/// When `rank` is `nil` the game has not been played. The badge shows an open scroll
/// shape labeled "Quest Awaits".
///
/// The badge is marked `.accessibilityHidden(true)` when used inside `iOSQuestCardView`
/// because rank information is included in the card Button's combined accessibility label.
/// When used standalone (e.g., a result screen) it should be visible to VoiceOver.
///
/// ## Shape → Rank mapping
/// - `.perfect`  → 6-pointed star seal (Legendary)
/// - `.good`     → shield seal (Skilled)
/// - `.ok`       → circle seal (Novice)
/// - `.failed`   → broken shield seal (Defeated)
/// - `nil`       → open scroll seal (Quest Awaits)
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSRankBadgeView: View {

    // MARK: - Properties

    /// Best rank for this game. `nil` means unplayed ("Quest Awaits").
    let rank: GameRank?

    /// Whether to hide this element from VoiceOver.
    /// Set `true` when used inside a card button that provides a combined label.
    var isAccessibilityHidden: Bool = true

    // MARK: - Constants

    private let shapeSize: CGFloat = 48
    private let labelFont: Font = .ra11yCaption

    // MARK: - Body

    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, size in
                drawSeal(in: &context, size: size)
            }
            .frame(width: shapeSize, height: shapeSize)

            Text(rankLabel)
                .font(labelFont)
                .fontWeight(.semibold)
                .foregroundStyle(labelColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 60)
        .accessibilityHidden(isAccessibilityHidden)
    }

    // MARK: - Computed

    private var rankLabel: String {
        rank?.displayText ?? String(localized: "hub.questAwaits")
    }

    private var labelColor: Color {
        rank.map { sealColor(for: $0) } ?? Color.secondary
    }

    // MARK: - Canvas Drawing

    /// Draws the appropriate seal shape for the given rank (or Quest Awaits scroll).
    private func drawSeal(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let color = rank.map { sealColor(for: $0) } ?? Color.secondary

        switch rank {
        case .perfect:
            drawStarSeal(in: &context, center: center, size: size, color: color)
        case .good:
            drawShieldSeal(in: &context, center: center, size: size, color: color)
        case .ok:
            drawCircleSeal(in: &context, center: center, size: size, color: color)
        case .failed:
            drawBrokenShieldSeal(in: &context, center: center, size: size, color: color)
        case nil:
            drawScrollSeal(in: &context, center: center, size: size)
        }
    }

    /// Filled 6-pointed star — Legendary rank.
    private func drawStarSeal(
        in context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        color: Color
    ) {
        let r = min(size.width, size.height) / 2 * 0.85
        let innerR = r * 0.45
        let points = 6
        var path = Path()

        for i in 0 ..< points * 2 {
            let angle = (Double(i) * .pi / Double(points)) - .pi / 2
            let radius = i.isMultiple(of: 2) ? r : innerR
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()

        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(color.opacity(0.6)), lineWidth: 1)
    }

    /// Solid shield — Skilled rank.
    private func drawShieldSeal(
        in context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        color: Color
    ) {
        let w = size.width * 0.7
        let h = size.height * 0.85
        let left  = center.x - w / 2
        let right = center.x + w / 2
        let top   = center.y - h / 2
        let mid   = center.y
        let bot   = center.y + h / 2

        var path = Path()
        path.move(to: CGPoint(x: center.x, y: bot))
        path.addLine(to: CGPoint(x: left, y: mid))
        path.addLine(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: right, y: top))
        path.addLine(to: CGPoint(x: right, y: mid))
        path.closeSubpath()

        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(color.opacity(0.6)), lineWidth: 1)
    }

    /// Filled circle — Novice rank.
    private func drawCircleSeal(
        in context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        color: Color
    ) {
        let r = min(size.width, size.height) / 2 * 0.8
        let rect = CGRect(
            x: center.x - r, y: center.y - r,
            width: r * 2, height: r * 2
        )
        let path = Path(ellipseIn: rect)
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(color.opacity(0.6)), lineWidth: 1)
    }

    /// Shield with a diagonal break — Defeated rank.
    private func drawBrokenShieldSeal(
        in context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        color: Color
    ) {
        let w = size.width * 0.7
        let h = size.height * 0.85
        let left  = center.x - w / 2
        let right = center.x + w / 2
        let top   = center.y - h / 2
        let mid   = center.y
        let bot   = center.y + h / 2

        // Draw an outlined (hollow) shield with a crack line through it.
        var shield = Path()
        shield.move(to: CGPoint(x: center.x, y: bot))
        shield.addLine(to: CGPoint(x: left, y: mid))
        shield.addLine(to: CGPoint(x: left, y: top))
        shield.addLine(to: CGPoint(x: right, y: top))
        shield.addLine(to: CGPoint(x: right, y: mid))
        shield.closeSubpath()

        context.fill(shield, with: .color(color.opacity(0.25)))
        context.stroke(shield, with: .color(color), lineWidth: 1.5)

        // Diagonal crack
        var crack = Path()
        crack.move(to: CGPoint(x: center.x - 4, y: top + 4))
        crack.addLine(to: CGPoint(x: center.x + 2, y: mid - 4))
        crack.addLine(to: CGPoint(x: center.x - 2, y: mid + 4))
        crack.addLine(to: CGPoint(x: center.x + 4, y: bot - 6))
        context.stroke(crack, with: .color(color), lineWidth: 1.5)
    }

    /// Open scroll outline — Quest Awaits (no rank yet).
    private func drawScrollSeal(
        in context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize
    ) {
        let w = size.width * 0.65
        let h = size.height * 0.55
        let scrollRect = CGRect(
            x: center.x - w / 2,
            y: center.y - h / 2,
            width: w,
            height: h
        )
        let scroll = Path(roundedRect: scrollRect, cornerRadius: 4)
        context.stroke(scroll, with: .color(.secondary), lineWidth: 1.5)

        // Curled top and bottom edges
        let curlH: CGFloat = 6
        let topCurlRect = CGRect(
            x: center.x - w / 2 - 2,
            y: center.y - h / 2 - curlH,
            width: w + 4,
            height: curlH * 2
        )
        let botCurlRect = CGRect(
            x: center.x - w / 2 - 2,
            y: center.y + h / 2 - curlH,
            width: w + 4,
            height: curlH * 2
        )
        context.stroke(
            Path(ellipseIn: topCurlRect),
            with: .color(.secondary),
            lineWidth: 1
        )
        context.stroke(
            Path(ellipseIn: botCurlRect),
            with: .color(.secondary),
            lineWidth: 1
        )
    }

    // MARK: - Seal Colors

    /// Thematic color per rank. Shapes must also differ — color alone is insufficient.
    private func sealColor(for rank: GameRank) -> Color {
        switch rank {
        case .perfect: return Color(red: 1.0,  green: 0.84, blue: 0.0)   // gold
        case .good:    return Color(red: 0.53, green: 0.81, blue: 0.98)  // silver-blue
        case .ok:      return Color(red: 0.75, green: 0.65, blue: 0.50)  // bronze
        case .failed:  return Color(red: 0.55, green: 0.55, blue: 0.55)  // dim gray
        }
    }
}

// MARK: - Previews

#Preview("All ranks") {
    HStack(spacing: 16) {
        iOSRankBadgeView(rank: .perfect, isAccessibilityHidden: false)
        iOSRankBadgeView(rank: .good,    isAccessibilityHidden: false)
        iOSRankBadgeView(rank: .ok,      isAccessibilityHidden: false)
        iOSRankBadgeView(rank: .failed,  isAccessibilityHidden: false)
        iOSRankBadgeView(rank: nil,      isAccessibilityHidden: false)
    }
    .padding()
    .background(Color(white: 0.15))
}
