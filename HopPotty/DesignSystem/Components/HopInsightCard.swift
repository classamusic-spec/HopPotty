import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

public extension InsightWindow {
    /// How the window is named on a card.
    var displayName: String {
        switch self {
        case .day: "Today"
        case .week: "This week"
        case .trailingDays(let count): "Last \(max(1, count)) days"
        }
    }
}

public extension InsightConfidence.Level {
    /// How much data stands behind the insight, in words rather than a number:
    /// this engine counts one family's entries and has no population to compare
    /// against, so a percentage would be a fiction.
    var displayName: String {
        switch self {
        case .insufficient: "Not enough entries yet"
        case .provisional: "Early pattern"
        case .supported: "Consistent pattern"
        }
    }
}

/// One observed pattern.
///
/// The disclaimer is rendered by the card itself, from ``Insight/disclaimer``,
/// and is not a parameter — there is no way to construct this view without it.
/// See `Docs/CONTRACTS.md` §4.5.
public struct HopInsightCard: View {
    @Environment(\.hopTheme) private var theme

    private let insight: Insight
    private let onAction: ((InsightAction) -> Void)?

    public init(insight: Insight, onAction: ((InsightAction) -> Void)?) {
        self.insight = insight
        self.onAction = onAction
    }

    private var tint: Color {
        insight.confidence == .supported ? theme.color.brandAction : theme.color.brandSecondary
    }

    public var body: some View {
        HopCard {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                HStack(alignment: .top, spacing: theme.spacing.m) {
                    HopGlyphBadge(insight.glyph, tint: tint, diameter: 36)

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text(insight.title)
                            .hopTextStyle(.parentHeadline)
                            .foregroundStyle(theme.color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(insight.detail)
                            .hopTextStyle(.parentBody)
                            .foregroundStyle(theme.color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                provenance

                if let onAction, !insight.actions.isEmpty {
                    actions(onAction)
                }
            }
        }
        // Read as one paragraph: the title, the detail, where the numbers came
        // from, and the disclaimer — in that order, every time.
        .accessibilityElement(children: .contain)
    }

    private var provenance: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack(spacing: theme.spacing.s) {
                HopPill(insight.window.displayName, tint: theme.color.neutral, glyph: .timer)
                Text(HopStrings.insightSample(insight.sampleSize, days: insight.observedDays))
                    .hopTextStyle(.parentCaption)
                    .foregroundStyle(theme.color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(insight.disclaimer)
                .hopTextStyle(.parentFootnote)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(insight.window.displayName). \(insight.confidence.displayName). "
            + "\(HopStrings.insightSample(insight.sampleSize, days: insight.observedDays)). \(insight.disclaimer)"
        )
    }

    private func actions(_ handler: @escaping (InsightAction) -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: theme.spacing.s) {
                ForEach(insight.actions) { action in
                    button(action, handler: handler)
                }
            }
            VStack(spacing: theme.spacing.s) {
                ForEach(insight.actions) { action in
                    button(action, handler: handler)
                }
            }
        }
    }

    private func button(_ action: InsightAction, handler: @escaping (InsightAction) -> Void) -> some View {
        HopSecondaryButton(action.title) { handler(action) }
    }
}

#if DEBUG
enum HopInsightPreviewData {
    static let afterLunch = Insight(
        id: "time-of-day.afternoon",
        title: "Most tries happen after lunch",
        detail: "Between 12:00 and 17:00 Sam went 14 times; the rest of the day, 6.",
        glyph: .timer,
        window: .trailingDays(14),
        sampleSize: 20,
        observedDays: 12,
        confidence: .supported,
        actions: [
            InsightAction(kind: .adjustSchedule, title: "Adjust the interval"),
            InsightAction(kind: .viewTimeline, title: "See the entries"),
        ]
    )

    static let gaps = Insight(
        id: "gaps.median",
        title: "The usual gap is about 90 minutes",
        detail: "Half the gaps between visits fell between 70 and 115 minutes.",
        glyph: .tried,
        window: .week,
        sampleSize: 9,
        observedDays: 5,
        confidence: .provisional
    )
}

#Preview("Insight cards") {
    ScrollView {
        VStack(spacing: 16) {
            HopInsightCard(insight: HopInsightPreviewData.afterLunch) { _ in }
            HopInsightCard(insight: HopInsightPreviewData.gaps, onAction: nil)
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Insight cards · AX3") {
    ScrollView {
        HopInsightCard(insight: HopInsightPreviewData.afterLunch) { _ in }
            .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Insight cards · dark") {
    HopInsightCard(insight: HopInsightPreviewData.afterLunch) { _ in }
        .padding()
        .frame(maxHeight: .infinity)
        .hopBackground()
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}

#Preview("Insight cards · iPad high contrast") {
    HopInsightCard(insight: HopInsightPreviewData.afterLunch) { _ in }
        .hopPageMargins()
        .hopReadableWidth()
        .frame(width: 834, height: 360)
        .hopBackground()
        .hopThemedRoot(appearance: .lightHighContrast)
}
#endif
