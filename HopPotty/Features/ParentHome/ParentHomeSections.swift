import SwiftUI
import HopPottyCore

/// Today's numbers.
///
/// Four counts on one line — check-ins, and the three kinds that make them up —
/// in `HopMetricRow`, which is one card with hairlines between the columns.
///
/// ## What changed
///
/// This was a three-column grid of ``HopMetricCard``: Tries, Stars and
/// Accidents, each its own card with a 32pt tinted disc at the top of it. Three
/// problems, in order of how much they mattered.
///
/// 1. **Accidents had a headline of their own.** A third of the day's summary,
///    at the same weight as everything else a caregiver came to read. It is a
///    count of something that happened and it stays counted — it is on the
///    timeline below, and on Progress as a row — but it is not one of the three
///    biggest numbers on the screen. §7.
/// 2. **Stars are not a parent metric.** They are the child's currency and they
///    are already at the top of this screen, on the pond, where they are earned.
/// 3. **Three cards with three coloured discs** is what the brief calls giant
///    colourful tiles, directly under a painted pond.
///
/// There is still deliberately no "success rate" figure, because the
/// denominator that would make one is the thing this product refuses to compute
/// (`Docs/CONTRACTS.md` §4.3).
struct TodayMetricsRow: View {
    @Environment(\.hopTheme) private var theme

    let snapshot: ParentHomeModel.Snapshot

    private func count(_ kind: PottyEventKind) -> Int {
        snapshot.todayEvents.filter { $0.kind == kind }.count
    }

    var body: some View {
        HopMetricRow(
            [
                HopMetricColumn(
                    value: ParentFormat.count(snapshot.participationToday),
                    label: HopCopy.parentHome.summaryChecksLabel.localized,
                    glyph: .check,
                    tint: theme.color.success
                ),
                HopMetricColumn(
                    value: ParentFormat.count(count(.tried)),
                    label: PottyEventKind.tried.parentLabel,
                    glyph: .tried,
                    tint: theme.color.eventTried
                ),
                HopMetricColumn(
                    value: ParentFormat.count(count(.pee)),
                    label: PottyEventKind.pee.parentLabel,
                    glyph: .pee,
                    tint: theme.color.eventPee
                ),
                HopMetricColumn(
                    value: ParentFormat.count(count(.poop)),
                    label: PottyEventKind.poop.parentLabel,
                    glyph: .poop,
                    tint: theme.color.eventPoop
                ),
            ],
            arrivalIndex: 0
        )
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
                .padding(.horizontal, theme.spacing.l)
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
                // The card renders `insight.disclaimer` itself and cannot be
                // constructed without it (`Docs/CONTRACTS.md` §4.5), so the
                // second copy that used to sit under it said the same sentence
                // twice in eight points of each other. Said once (§49).
                HopInsightCard(insight: insight, onAction: onAction, arrivalIndex: 0)
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
