import SwiftUI
import HopPottyDesignTokens

/// One number and what it counts. The unit of the parent dashboard's summary
/// grid, in the shape Apple Health uses for a daily figure.
///
/// The card is a single accessibility element: "Tried, 6 times today" is one
/// fact, and splitting it into three swipes makes it harder to read, not easier.
public struct HopMetricCard: View {
    @Environment(\.hopTheme) private var theme

    private let value: String
    private let label: String
    private let glyph: HopGlyph
    private let tint: Color

    public init(value: String, label: String, glyph: HopGlyph, tint: Color) {
        self.value = value
        self.label = label
        self.glyph = glyph
        self.tint = tint
    }

    public var body: some View {
        HopCard {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                HStack(spacing: theme.spacing.s) {
                    HopGlyphBadge(glyph, tint: tint, diameter: 32)
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .hopTextStyle(.metric)
                        .foregroundStyle(theme.color.textPrimary)
                        .lineLimit(1)
                        // Numbers shrink rather than truncate: "1,204" losing its
                        // thousands is a wrong number, not a shortened one.
                        .minimumScaleFactor(0.55)

                    Text(label)
                        .hopTextStyle(.parentCallout)
                        .foregroundStyle(theme.color.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

/// A ring showing a fraction of something.
///
/// The track is always visible so the ring reads as "part of a whole" even at
/// zero, and the cap is rounded so a 2% arc is still a visible mark rather than
/// a sliver.
public struct HopProgressRing<Center: View>: View {
    @Environment(\.hopTheme) private var theme

    private let progress: Double
    private let lineWidth: CGFloat
    private let tint: Color
    private let center: Center

    public init(
        progress: Double,
        lineWidth: CGFloat = 12,
        tint: Color,
        @ViewBuilder center: () -> Center
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.tint = tint
        self.center = center()
    }

    private var clamped: Double { min(1, max(0, progress)) }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(
                    HopColors.wash(tint, isDark: theme.isDark),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .hopAnimation(.parentTransition, value: clamped)

            center
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(HopStrings.progressPercent(clamped))
    }
}

public extension HopProgressRing where Center == EmptyView {
    /// The signature from the API contract: a bare ring with nothing inside.
    init(progress: Double, lineWidth: CGFloat = 12, tint: Color) {
        self.init(progress: progress, lineWidth: lineWidth, tint: tint) { EmptyView() }
    }
}

#Preview("Metric cards") {
    ScrollView {
        VStack(spacing: 20) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                HopMetricCard(value: "6", label: "Tried today", glyph: .tried, tint: .purple)
                HopMetricCard(value: "4", label: "Pee", glyph: .pee, tint: .teal)
                HopMetricCard(value: "1", label: "Poop", glyph: .poop, tint: .orange)
                HopMetricCard(value: "1", label: "Accident", glyph: .accident, tint: .gray)
            }

            HopProgressRing(progress: 0.62, tint: .green)
                .frame(width: 140, height: 140)
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Metric cards · AX3 long labels") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        HopMetricCard(value: "1,204", label: "Times Sam gave the potty a try this month", glyph: .tried, tint: .purple)
        HopMetricCard(value: "12", label: "Accidents recorded by a grown-up", glyph: .accident, tint: .gray)
    }
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Metric cards · dark") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        HopMetricCard(value: "6", label: "Tried today", glyph: .tried, tint: .purple)
        HopMetricCard(value: "4", label: "Pee", glyph: .pee, tint: .teal)
    }
    .padding()
    .frame(maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}

#Preview("Progress ring · high contrast") {
    HopProgressRing(progress: 0.35, lineWidth: 16, tint: .green) {
        Text("35%").hopTextStyle(.metric)
    }
    .frame(width: 160, height: 160)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot(appearance: .lightHighContrast)
}
