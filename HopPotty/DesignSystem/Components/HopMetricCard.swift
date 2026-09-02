import SwiftUI
import HopPottyDesignTokens

/// One number and what it counts. The unit of the parent dashboard's summary
/// grid, in the shape Apple Health uses for a daily figure.
///
/// The card is a single accessibility element: "Tried, 6 times today" is one
/// fact, and splitting it into three swipes makes it harder to read, not easier.
///
/// ## A live number
///
/// This card updates while a caregiver is looking at it — a child finishes a
/// routine in the next room and "6" becomes "7". Two separate pieces of motion
/// handle that, and keeping them separate is the whole trick:
///
/// - the **arrival** (`arrivalIndex:`) runs once, when the card first appears;
/// - the **value change** rolls the digits in place, on the card's own
///   transaction, and never touches the arrival state.
///
/// So a number going up animates the number. It does not re-play the dashboard.
public struct HopMetricCard: View {
    @Environment(\.hopTheme) private var theme

    private let value: String
    private let label: String
    private let glyph: HopGlyph
    private let tint: Color
    private let arrivalIndex: Int?

    public init(
        value: String,
        label: String,
        glyph: HopGlyph,
        tint: Color,
        arrivalIndex: Int? = nil
    ) {
        self.value = value
        self.label = label
        self.glyph = glyph
        self.tint = tint
        self.arrivalIndex = arrivalIndex
    }

    public var body: some View {
        HopCard(arrivalIndex: arrivalIndex) {
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
                        // Digits roll into their replacement. Under Reduce Motion
                        // they cross-fade instead — see HopAnimationToken.
                        .hopNumericTransition()
                        .hopAnimation(.parentTransition, value: value)

                    Text(label)
                        .hopTextStyle(.parentCallout)
                        .foregroundStyle(theme.color.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .hopValueChange(label)
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
///
/// `animatesArrival` draws the arc on from zero the first time the ring appears.
/// Off by default: a ring inside a card that is already arriving would otherwise
/// be two animations doing the same job, and the second one is the one that
/// looks wrong.
public struct HopProgressRing<Center: View>: View {
    @Environment(\.hopTheme) private var theme
    @State private var hasArrived = false

    private let progress: Double
    private let lineWidth: CGFloat
    private let tint: Color
    private let animatesArrival: Bool
    private let center: Center

    public init(
        progress: Double,
        lineWidth: CGFloat = 12,
        tint: Color,
        animatesArrival: Bool = false,
        @ViewBuilder center: () -> Center
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.tint = tint
        self.animatesArrival = animatesArrival
        self.center = center()
    }

    private var clamped: Double { min(1, max(0, progress)) }

    /// What the arc is drawing right now. Reduce Motion skips the draw-on
    /// entirely rather than shortening it: an arc growing is travel.
    private var drawn: Double {
        guard animatesArrival, !hasArrived, !theme.reduceMotion else { return clamped }
        return 0
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(
                    HopColors.wash(tint, isDark: theme.isDark),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            Circle()
                .trim(from: 0, to: drawn)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .hopAnimation(.parentTransition, value: drawn)

            center
        }
        .onAppear { hasArrived = true }
        .accessibilityElement(children: .combine)
        .accessibilityValue(HopStrings.progressPercent(clamped))
    }
}

public extension HopProgressRing where Center == EmptyView {
    /// The signature from the API contract: a bare ring with nothing inside.
    init(progress: Double, lineWidth: CGFloat = 12, tint: Color, animatesArrival: Bool = false) {
        self.init(
            progress: progress,
            lineWidth: lineWidth,
            tint: tint,
            animatesArrival: animatesArrival
        ) { EmptyView() }
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

#if DEBUG
/// A dashboard that arrives once and then updates in place, which is the case
/// this card actually has to get right.
private struct HopMetricMotionGallery: View {
    @Environment(\.hopTheme) private var theme
    @State private var tried = 6
    @State private var pee = 4

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            Text(theme.reduceMotion
                 ? "Reduce Motion: the grid fades in, and a changed number cross-fades in place."
                 : "The grid lifts in, staggered. Changing a number rolls the digits and leaves the card alone.")
                .hopTextStyle(.parentCaption)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacing.m) {
                HopMetricCard(
                    value: tried.formatted(), label: "Tried today",
                    glyph: .tried, tint: theme.color.eventTried, arrivalIndex: 0
                )
                HopMetricCard(
                    value: pee.formatted(), label: "Pee",
                    glyph: .pee, tint: theme.color.eventPee, arrivalIndex: 1
                )
                HopMetricCard(
                    value: "1", label: "Poop",
                    glyph: .poop, tint: theme.color.eventPoop, arrivalIndex: 2
                )
                HopMetricCard(
                    value: "1", label: "Accident",
                    glyph: .accident, tint: theme.color.eventAccident, arrivalIndex: 3
                )
            }

            HopProgressRing(progress: Double(tried) / 12, tint: theme.color.success, animatesArrival: true)
                .frame(width: 140, height: 140)

            HopPrimaryButton("Log a try", icon: "plus") {
                tried += 1
                pee += 1
            }
        }
        .padding()
    }
}

#Preview("Metric cards · live") {
    ScrollView { HopMetricMotionGallery() }
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Metric cards · live, Reduce Motion") {
    ScrollView { HopMetricMotionGallery() }
        .hopBackground()
        .hopThemedRoot(reduceMotion: true)
}
#endif
