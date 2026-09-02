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

    /// Three across at every width. The tiles are short, and a caregiver
    /// comparing today's three numbers wants them on one line, not reflowed.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    }

    var body: some View {
        // The three tiles lift into place left to right, once, when the day
        // first draws. The stagger is what makes them read as one row arriving
        // rather than three tiles appearing at once — and the accident tile is
        // in it on exactly the same terms as the other two.
        LazyVGrid(columns: columns, spacing: theme.spacing.s) {
            HopMetricCard(
                value: ParentFormat.count(snapshot.participationToday),
                label: HopCopy.parentHome.summaryTriesLabel.localized,
                glyph: .tried,
                tint: theme.color.eventTried,
                arrivalIndex: 0
            )
            HopMetricCard(
                value: ParentFormat.count(snapshot.starsToday),
                label: HopCopy.parentHome.summaryStarsLabel.localized,
                glyph: .star,
                tint: theme.color.celebration,
                arrivalIndex: 1
            )
            HopMetricCard(
                value: ParentFormat.count(snapshot.accidentsToday),
                label: PottyEventKind.accident.parentLabel,
                glyph: .accident,
                tint: theme.color.eventAccident,
                arrivalIndex: 2
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
                        // Each row arrives once, on its own beat down the list.
                        // A row logged later arrives on its own rather than
                        // replaying the whole timeline, because the arrival is
                        // keyed to the row's identity.
                        HopTimelineRow(
                            event: event,
                            isLast: index == events.count - 1,
                            arrivalIndex: index
                        )
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
                HopInsightCard(insight: insight, onAction: onAction, arrivalIndex: 0)
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
/// wrong control. With one child it collapses to its label with no menu behind
/// it, because a picker with one option is a puzzle.
///
/// The caller supplies the label, and the whole label is the target. That is
/// the point: over the pond the child's name sits under a greeting in a 17pt
/// line, and a 17pt line is not a hit target — the 44pt capsule around it is.
struct ChildSwitcher<Label: View>: View {
    private let children: [ChildProfile]
    private let selected: ChildProfile
    private let onSelect: (UUID) -> Void
    private let label: (String) -> Label

    /// `label` is handed the resolved display name, because it almost always
    /// draws it and the fallback for a child with no nickname belongs here,
    /// once.
    init(
        children: [ChildProfile],
        selected: ChildProfile,
        onSelect: @escaping (UUID) -> Void,
        @ViewBuilder label: @escaping (String) -> Label
    ) {
        self.children = children
        self.selected = selected
        self.onSelect = onSelect
        self.label = label
    }

    var body: some View {
        if children.count <= 1 {
            label(displayName(selected))
        } else {
            Menu {
                ForEach(children) { child in
                    Button {
                        onSelect(child.id)
                    } label: {
                        if child.id == selected.id {
                            SwiftUI.Label(displayName(child), systemImage: "checkmark")
                        } else {
                            Text(verbatim: displayName(child))
                        }
                    }
                }
            } label: {
                label(displayName(selected))
            }
            .accessibilityLabel(Text(hop: HopCopy.parentHome.childSwitcher))
            .accessibilityValue(Text(verbatim: displayName(selected)))
        }
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
