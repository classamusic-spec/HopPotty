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

/// The period's totals: one compact row, and the accident count under it.
///
/// ## What changed
///
/// This was a `LazyVGrid` of ``HopMetricCard`` — four cards, each with a 32pt
/// tinted disc, each 140pt wide, reflowing into two rows on a phone. On a screen
/// that also carries a chart, a list of observations and a timeline, that is
/// four more cards for four numbers.
///
/// It is now one card of four columns divided by hairlines, in the shape Fitness
/// and Screen Time use for a period's summary. Accidents left the row and became
/// a labelled line beneath it — still counted, still in the caregiver's own
/// words, and no longer a quarter of the biggest numbers on the screen (§7:
/// recorded, never ranked). "Checks" replaces the row's fourth tile: it is the
/// participation total, the preferred vocabulary for this product.
struct ProgressTotalsRow: View {
    @Environment(\.hopTheme) private var theme

    let aggregate: PeriodAggregate

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HopMetricRow(
                [
                    HopMetricColumn(
                        value: ParentFormat.count(aggregate.participationCount),
                        label: HopCopy.parentHome.summaryChecksLabel.localized,
                        glyph: .check,
                        tint: theme.color.success
                    ),
                    HopMetricColumn(
                        value: ParentFormat.count(aggregate.count(of: .tried)),
                        label: PottyEventKind.tried.parentLabel,
                        glyph: .tried,
                        tint: theme.color.eventTried
                    ),
                    HopMetricColumn(
                        value: ParentFormat.count(aggregate.count(of: .pee)),
                        label: PottyEventKind.pee.parentLabel,
                        glyph: .pee,
                        tint: theme.color.eventPee
                    ),
                    HopMetricColumn(
                        value: ParentFormat.count(aggregate.count(of: .poop)),
                        label: PottyEventKind.poop.parentLabel,
                        glyph: .poop,
                        tint: theme.color.eventPoop
                    ),
                ],
                arrivalIndex: 0
            )

            HStack(spacing: theme.spacing.s) {
                Text(hop: HopCopy.parentHome.summaryAccidentsRecorded)
                    .font(theme.font(.parentCallout))
                    .foregroundStyle(theme.color.textSecondary)
                Spacer(minLength: theme.spacing.s)
                Text(verbatim: ParentFormat.count(aggregate.accidentCount))
                    .font(theme.font(.parentCallout))
                    .foregroundStyle(theme.color.textSecondary)
                    .hopNumericText()
            }
            .padding(.horizontal, theme.spacing.xs)
            .accessibilityElement(children: .combine)
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
                            HopTimelineRow(
                                event: event,
                                isLast: index == day.events.count - 1,
                                arrivalIndex: index
                            )
                        }
                    }
                    .padding(.horizontal, theme.spacing.l)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                            .fill(theme.color.surface)
                    )
                }
            }
        }
    }
}
