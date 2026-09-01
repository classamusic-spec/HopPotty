import SwiftUI
import Charts
import HopPottyCore

/// Entries per day, split by kind.
///
/// A stacked bar of counts, and nothing else. There is no target line, no
/// rolling average, no "goal" and no percentage — every one of those turns a
/// record of what a family did into a score they can fall short of. Accidents
/// are one of the four stacked kinds, drawn in the same weight as the rest.
struct ProgressChartSection: View {
    @Environment(\.hopTheme) private var theme

    let aggregate: PeriodAggregate
    let calendar: Calendar

    private struct Bar: Identifiable {
        let id: String
        let day: Date
        let kind: PottyEventKind
        let count: Int
    }

    private var bars: [Bar] {
        aggregate.dayTotals.flatMap { total in
            PottyEventKind.parentDisplayOrder.map { kind in
                Bar(
                    id: "\(total.dayStart.timeIntervalSince1970)-\(kind.rawValue)",
                    day: total.dayStart,
                    kind: kind,
                    count: total.count(of: kind)
                )
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HopSectionHeader(HopFeatureStrings.progressTotalsTitle)

            Chart(bars) { bar in
                BarMark(
                    x: .value(HopFeatureStrings.progressRangeDay, bar.day, unit: .day),
                    y: .value(HopFeatureStrings.progressTotalsTitle, bar.count)
                )
                .foregroundStyle(by: .value(HopFeatureStrings.progressTotalsTitle, bar.kind.parentLabel))
                .accessibilityLabel(Text(verbatim: ParentFormat.relativeDay(bar.day, calendar: calendar)))
                .accessibilityValue(
                    Text(verbatim: "\(bar.kind.parentLabel): \(ParentFormat.count(bar.count))")
                )
            }
            .chartForegroundStyleScale(colorScale)
            .chartLegend(position: .bottom, alignment: .leading)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)

            legendFootnote
        }
    }

    /// Colour is assigned explicitly rather than left to the default palette, so
    /// the chart's colours match the timeline's glyph tints and a caregiver does
    /// not have to learn two schemes. Meaning still never rides on colour alone:
    /// the legend labels every series in words.
    private var colorScale: KeyValuePairs<String, Color> {
        [
            PottyEventKind.tried.parentLabel: theme.color.eventTried,
            PottyEventKind.pee.parentLabel: theme.color.eventPee,
            PottyEventKind.poop.parentLabel: theme.color.eventPoop,
            PottyEventKind.accident.parentLabel: theme.color.eventAccident,
        ]
    }

    private var legendFootnote: some View {
        Text(hop: HopCopy.parentHome.eventAccidentFooter)
            .font(theme.font(.parentFootnote))
            .foregroundStyle(theme.color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The period's totals as tiles.
struct ProgressTotalsRow: View {
    @Environment(\.hopTheme) private var theme

    let aggregate: PeriodAggregate

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140), spacing: 12)],
            spacing: 12
        ) {
            ForEach(PottyEventKind.parentDisplayOrder) { kind in
                HopMetricCard(
                    value: ParentFormat.count(aggregate.count(of: kind)),
                    label: kind.parentLabel,
                    glyph: kind.glyph,
                    tint: kind.tint(theme)
                )
            }
        }
    }
}

/// The sectioned timeline for the selected period.
struct ProgressTimelineSection: View {
    @Environment(\.hopTheme) private var theme

    let days: [TimelineDay]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            HopSectionHeader(HopCopy.parentHome.timelineTitle.localized)

            ForEach(days) { day in
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(verbatim: day.title)
                        .font(theme.font(.parentHeadline))
                        .foregroundStyle(theme.color.textSecondary)
                    VStack(spacing: 0) {
                        ForEach(Array(day.events.enumerated()), id: \.element.id) { index, event in
                            HopTimelineRow(event: event, isLast: index == day.events.count - 1)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                            .fill(theme.color.surface)
                    )
                }
            }
        }
    }
}
