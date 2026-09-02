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
///
/// `arrivalIndex:` staggers a list of these into place on first appearance. The
/// wording inside the card cross-fades independently of it, so an insight being
/// re-phrased by a new entry does not re-play the whole list.
public struct HopInsightCard: View {
    @Environment(\.hopTheme) private var theme

    private let insight: Insight
    private let onAction: ((InsightAction) -> Void)?
    private let arrivalIndex: Int?

    public init(insight: Insight, onAction: ((InsightAction) -> Void)?, arrivalIndex: Int? = nil) {
        self.insight = insight
        self.onAction = onAction
        self.arrivalIndex = arrivalIndex
    }

    private var tint: Color {
        insight.confidence == .supported ? theme.color.brandAction : theme.color.brandSecondary
    }

    public var body: some View {
        HopCard(arrivalIndex: arrivalIndex) {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                HStack(alignment: .top, spacing: theme.spacing.m) {
                    // A mark, not a badge. The 36pt tinted disc that used to be
                    // here was a coloured circle on every observation, on a
                    // dashboard that already carries four of them in its
                    // timeline — §35, and §34's colour budget.
                    HopGlyphView(insight.glyph, size: 18)
                        .foregroundStyle(tint)
                        .frame(width: 22)
                        .padding(.top, 2)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        // The insights engine re-runs whenever an entry is
                        // logged, so the same card is very often re-worded in
                        // place. Cross-fading rather than snapping is what keeps
                        // that reading as an update instead of a redraw.
                        Text(insight.title)
                            .hopTextStyle(.parentHeadline)
                            .foregroundStyle(theme.color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .hopValueChange(insight.title)

                        Text(insight.detail)
                            .hopTextStyle(.parentBody)
                            .foregroundStyle(theme.color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .hopValueChange(insight.detail)
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

    /// Where the numbers came from, and the sentence that qualifies them.
    ///
    /// Was a filled ``HopPill`` naming the window, a caption in `textTertiary`
    /// counting the sample, and the disclaimer under both. Two changes:
    ///
    /// - the pill became text. A capsule is a control's shape, and this is not a
    ///   control; on a screen with several observations it was several more
    ///   coloured objects saying "This week" over and over.
    /// - `textTertiary` became `textSecondary`. `#7D766D` on `surface` measures
    ///   **4.49:1** — a hair under the 4.5:1 floor — and the role it was carrying
    ///   here is real prose, not decoration. `textSecondary` is 6.9:1.
    private var provenance: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(verbatim: "\(insight.window.displayName) · "
                + HopStrings.insightSample(insight.sampleSize, days: insight.observedDays))
                .hopTextStyle(.parentCaption)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

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

/// Insights arriving as a list, and then being re-worded underneath the reader.
private struct HopInsightMotionGallery: View {
    @Environment(\.hopTheme) private var theme
    @State private var showsAlternative = false

    private var first: Insight {
        showsAlternative ? HopInsightPreviewData.gaps : HopInsightPreviewData.afterLunch
    }

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            Text(theme.reduceMotion
                 ? "Reduce Motion: the cards fade in, and re-worded copy cross-fades in place."
                 : "The cards lift in, staggered. Re-worded copy cross-fades; the cards do not move again.")
                .hopTextStyle(.parentCaption)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HopInsightCard(insight: first, onAction: nil, arrivalIndex: 0)
            HopInsightCard(insight: HopInsightPreviewData.gaps, onAction: nil, arrivalIndex: 1)

            HopSecondaryButton("Re-word the first card", icon: "text.badge.checkmark") {
                showsAlternative.toggle()
            }
        }
        .padding()
    }
}

#Preview("Insight cards · motion") {
    ScrollView { HopInsightMotionGallery() }
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Insight cards · motion, Reduce Motion") {
    ScrollView { HopInsightMotionGallery() }
        .hopBackground()
        .hopThemedRoot(reduceMotion: true)
}
#endif
