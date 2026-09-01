import SwiftUI
import HopPottyCore

/// Today's numbers.
///
/// Three tiles, and the accident tile is one of them — drawn identically to the
/// others, with no red, no warning glyph and no percentage. It is a count of
/// something that happened, which is the only thing HopPotty ever claims it is
/// (`Docs/CONTRACTS.md` §4.3). There is deliberately no "success rate" tile,
/// because the denominator that would make one is the thing this product
/// refuses to compute.
struct TodayMetricsRow: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let snapshot: ParentHomeModel.Snapshot

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 3 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: theme.spacing.s) {
            HopMetricCard(
                value: ParentFormat.count(snapshot.participationToday),
                label: HopCopy.parentHome.summaryTriesLabel.localized,
                glyph: .tried,
                tint: theme.color.eventTried
            )
            HopMetricCard(
                value: ParentFormat.count(snapshot.starsToday),
                label: HopCopy.parentHome.summaryStarsLabel.localized,
                glyph: .star,
                tint: theme.color.celebration
            )
            HopMetricCard(
                value: ParentFormat.count(snapshot.accidentsToday),
                label: PottyEventKind.accident.parentLabel,
                glyph: .accident,
                tint: theme.color.eventAccident
            )
        }
        .accessibilityElement(children: .contain)
    }
}

/// Today's entries, newest first.
struct TodayTimelineSection: View {
    @Environment(\.hopTheme) private var theme

    let events: [PottyEvent]
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HopSectionHeader(
                HopCopy.parentHome.timelineTitle.localized,
                action: (title: HopCopy.parentHome.timelineAddButton.localized, handler: onAdd)
            )

            if events.isEmpty {
                HopEmptyState(
                    glyph: .tried,
                    title: HopStrings.timelineEmptyTitle,
                    message: HopCopy.parentHome.timelineEmpty.localized,
                    action: (HopCopy.parentHome.timelineAddButton.localized, onAdd)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        HopTimelineRow(event: event, isLast: index == events.count - 1)
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

/// The insight card, drawn only when the engine returned one.
///
/// There is no "not enough data" card standing in for a finding: below its
/// threshold an insight is `nil`, and the correct screen shows nothing at all.
/// The one line of prose below is the exception — it appears where the section
/// would be, says the log is young, and makes no claim about the child.
struct HomeInsightSection: View {
    @Environment(\.hopTheme) private var theme

    let insight: Insight?
    let onAction: (InsightAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HopSectionHeader(HopCopy.parentHome.insightsTitle.localized)

            if let insight {
                HopInsightCard(insight: insight, onAction: onAction)
                // Attached here as well as inside the card: no surface showing
                // an observation may omit it.
                InsightDisclaimerLabel()
            } else {
                Text(hop: HopCopy.parentHome.insightsNotEnoughData)
                    .font(theme.font(.parentCallout))
                    .foregroundStyle(theme.color.textSecondary)
            }
        }
    }
}

/// The child switcher.
///
/// A `Menu` rather than a segmented control: families can have several children,
/// nicknames can be long, and a control that truncates a child's name is the
/// wrong control. With one child it collapses to a plain title, because a
/// picker with one option is a puzzle.
struct ChildSwitcher: View {
    @Environment(\.hopTheme) private var theme

    let children: [ChildProfile]
    let selected: ChildProfile
    let onSelect: (UUID) -> Void

    var body: some View {
        if children.count <= 1 {
            title
        } else {
            Menu {
                ForEach(children) { child in
                    Button {
                        onSelect(child.id)
                    } label: {
                        if child.id == selected.id {
                            Label(displayName(child), systemImage: "checkmark")
                        } else {
                            Text(verbatim: displayName(child))
                        }
                    }
                }
            } label: {
                HStack(spacing: theme.spacing.xxs) {
                    title
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote)
                        .foregroundStyle(theme.color.textSecondary)
                }
            }
            .hopAccessibilityLabel(HopCopy.parentHome.childSwitcher)
        }
    }

    private var title: some View {
        Text(verbatim: displayName(selected))
            .font(theme.font(.parentTitle))
            .foregroundStyle(theme.color.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    /// Falls back to the neutral phrasing rather than an empty gap — the whole
    /// reason `HopNameVariants` exists.
    private func displayName(_ child: ChildProfile) -> String {
        child.nickname ?? HopCopy.pond.title.unnamed.localized
    }
}

/// "Good morning" / "Good afternoon" / "Good evening", from the wall clock.
enum ParentGreeting {
    static func text(at date: Date, calendar: Calendar) -> String {
        switch DaySegment.containing(date, calendar: calendar) {
        case .morning: HopFeatureStrings.homeGreetingMorning
        case .afternoon: HopFeatureStrings.homeGreetingAfternoon
        case .evening, .night: HopFeatureStrings.homeGreetingEvening
        }
    }
}
