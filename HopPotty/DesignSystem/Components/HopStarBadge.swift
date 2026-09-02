import SwiftUI
import HopPottyDesignTokens

/// A five-pointed star with soft points, drawn rather than taken from SF
/// Symbols so it matches the illustrated marks around it.
struct HopStarShape: Shape {
    var points: Int = 5
    var innerRatio: CGFloat = 0.47
    var rounding: CGFloat = 0.16

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let step = Double.pi / Double(points)

        var vertices: [CGPoint] = []
        for index in 0..<(points * 2) {
            // Start at -90° so a point sits straight up.
            let angle = Double(index) * step - .pi / 2
            let radius = index.isMultiple(of: 2) ? outer : inner
            vertices.append(
                CGPoint(x: centre.x + CGFloat(cos(angle)) * radius, y: centre.y + CGFloat(sin(angle)) * radius)
            )
        }

        var path = Path()
        for (index, vertex) in vertices.enumerated() {
            let previous = vertices[(index + vertices.count - 1) % vertices.count]
            let next = vertices[(index + 1) % vertices.count]
            let entry = CGPoint(
                x: vertex.x + (previous.x - vertex.x) * rounding,
                y: vertex.y + (previous.y - vertex.y) * rounding
            )
            let exit = CGPoint(
                x: vertex.x + (next.x - vertex.x) * rounding,
                y: vertex.y + (next.y - vertex.y) * rounding
            )
            if index == 0 { path.move(to: entry) } else { path.addLine(to: entry) }
            path.addQuadCurve(to: exit, control: vertex)
        }
        path.closeSubpath()
        return path
    }
}

/// A count of stars.
///
/// Stars are never removed — the ledger is append-only and there is no decay
/// (`Docs/CONTRACTS.md` §4.2) — so this only ever counts up, and the arrival
/// animation is a settle, not a slot machine.
public struct HopStarBadge: View {
    @Environment(\.hopTheme) private var theme
    @State private var hasArrived = false

    private let count: Int
    private let animatesArrival: Bool
    private let size: CGFloat

    public init(count: Int, animatesArrival: Bool = false) {
        self.count = count
        self.animatesArrival = animatesArrival
        self.size = 28
    }

    /// Larger variant for the celebration, where the badge is the subject.
    public init(count: Int, animatesArrival: Bool = false, size: CGFloat) {
        self.count = count
        self.animatesArrival = animatesArrival
        self.size = size
    }

    public var body: some View {
        HStack(spacing: theme.spacing.xs) {
            star
            Text(count.formatted())
                .hopTextStyle(.metric)
                .foregroundStyle(theme.color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // The number changes without the layout jumping as digits swap.
                // Routed through the motion tokens so Reduce Motion cross-fades
                // the digits rather than rolling them.
                .hopNumericTransition()
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
        .background {
            Capsule().fill(HopColors.wash(theme.color.celebration, isDark: theme.isDark))
        }
        .overlay {
            Capsule().strokeBorder(
                theme.color.celebration.opacity(theme.isHighContrast ? 0.85 : 0.25),
                lineWidth: 1.5
            )
        }
        // The badge grows into place — except under Reduce Motion, where it
        // only fades in. The scale was travelling in both cases before; a
        // shortened grow is still a grow.
        .scaleEffect(hasArrived || theme.reduceMotion ? 1 : 0.86)
        .opacity(hasArrived ? 1 : 0)
        .hopAnimation(.childArrive, value: hasArrived)
        // A star landing animates the number, not the badge: the arrival above
        // has already run and does not run again.
        .hopAnimation(.childArrive, value: count)
        .onAppear { hasArrived = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HopStrings.starCount(count))
    }

    private var star: some View {
        HopStarShape()
            .fill(theme.color.celebration)
            .overlay {
                // A stroke as well as a fill, so the star survives being printed,
                // screenshotted in greyscale, or read by someone who cannot pick
                // the yellow out of the wash behind it.
                HopStarShape().stroke(theme.color.celebration, lineWidth: 1)
            }
            .frame(width: size, height: size)
            .hopFloating(animatesArrival)
            .accessibilityHidden(true)
    }
}

#Preview("Star badge") {
    VStack(spacing: 20) {
        HopStarBadge(count: 0)
        HopStarBadge(count: 7, animatesArrival: true)
        HopStarBadge(count: 1_284)
        HopStarBadge(count: 12, size: 64)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Star badge · AX3 dark") {
    VStack(spacing: 20) {
        HopStarBadge(count: 7)
        HopStarBadge(count: 1_284)
    }
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}

#Preview("Star badge · Reduce Motion") {
    VStack(spacing: 20) {
        HopStarBadge(count: 0)
        HopStarBadge(count: 7, animatesArrival: true)
        HopStarBadge(count: 1_284)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Star badge · high contrast") {
    HopStarBadge(count: 7, size: 48)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hopBackground()
        .hopThemedRoot(appearance: .lightHighContrast)
}
