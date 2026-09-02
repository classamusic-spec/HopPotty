import SwiftUI
import HopPottyCore
#if DEBUG
// Sample children live in their own module so they can never reach a real
// family's data. Previews are the only callers.
import HopPottyFixtures
#endif

/// The plain-language rendering of a schedule.
///
/// `ScheduleSummary` is built as structure first and rendered second, and this
/// view uses both halves: `english` is the sentence a caregiver reads, and the
/// named parts underneath are the same facts as chips, so someone scanning
/// rather than reading still gets the shape of their day.
///
/// A caregiver must never have to mentally decode "every 45 minutes, weekdays,
/// 7:00–19:30, except 12:30–14:30". This card is where that sentence is
/// produced for them, and it is recomputed from the pending edit on every
/// change so it is always describing what they just did.
struct SchedulePreviewCard: View {
    @Environment(\.hopTheme) private var theme

    let summary: ScheduleSummary
    var calendar: Calendar = .current

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            Text(verbatim: HopFeatureStrings.schedulePreviewTitle)
                .font(theme.font(.parentHeadline))
                .foregroundStyle(theme.color.textPrimary)

            // The whole sentence, including the status clause when the schedule
            // is held or switched off — `english` already suppresses the cadence
            // for a disabled schedule, because describing the rhythm of a thing
            // that is off is a lie a caregiver could act on.
            Text(verbatim: summary.english)
                .font(theme.font(.parentBody))
                .foregroundStyle(theme.color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isStaticText)

            chips

            Text(verbatim: HopFeatureStrings.schedulePreviewHint)
                .font(theme.font(.parentFootnote))
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                .fill(theme.color.surface)
        )
    }

    private var chips: some View {
        // `WrappingHStack` does not exist in SwiftUI; a flexible grid with a
        // small minimum gives the same reflow without a custom layout.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            HopPill(daysText, tint: theme.color.neutral, glyph: .timer)
            HopPill(cadenceText, tint: theme.color.brandPrimary, glyph: .play)
            HopPill(actionText, tint: theme.color.brandSecondary, glyph: actionGlyph)
            if !summary.activeWindow.coversWholeDay {
                HopPill(activeWindowText, tint: theme.color.neutral, glyph: .quietHours)
            }
            ForEach(Array(summary.exceptions.enumerated()), id: \.offset) { _, exception in
                HopPill(exceptionText(exception), tint: theme.color.neutral, glyph: .quietHours)
            }
        }
    }

    // MARK: Parts

    private var daysText: String {
        switch summary.days {
        case .everyDay:
            return HopCopy.timerSettings.activeDaysEveryDay.localized
        case .weekdays, .weekends, .specific:
            let names = summary.days.weekdays
                .sorted()
                .map { ParentFormat.weekdayName($0, calendar: calendar) }
            return names.joined(separator: ", ")
        }
    }

    private var cadenceText: String {
        switch summary.cadence {
        case .afterQualifyingUse(let minutes), .everyClockInterval(let minutes):
            return ParentFormat.minutes(minutes)
        }
    }

    private var actionText: String {
        switch summary.action {
        case .reminder:
            return HopCopy.timerSettings.modeGentle.localized
        case .pause(let minutes):
            return ParentFormat.minutes(minutes)
        case .guidedRoutine(let minutes):
            return ParentFormat.minutes(minutes)
        }
    }

    private var actionGlyph: HopGlyph {
        switch summary.action {
        case .reminder: .play
        case .pause: .pause
        case .guidedRoutine: .check
        }
    }

    private var activeWindowText: String {
        ParentFormat.timeSpan(
            summary.activeWindow.start,
            summary.activeWindow.end,
            calendar: calendar
        )
    }

    /// The exception's own label plus its bounds. The label carries why the
    /// window exists — nap, bedtime, school — which is what makes the chip
    /// scannable at a glance.
    private func exceptionText(_ exception: ScheduleSummary.Exception) -> String {
        let bounds: String
        switch exception {
        case .before(let time, _, _):
            bounds = ParentFormat.clock(time, calendar: calendar)
        case .between(let start, let end, _, _):
            bounds = ParentFormat.timeSpan(start, end, calendar: calendar)
        case .after(let from, _, _, _):
            bounds = ParentFormat.clock(from, calendar: calendar)
        case .allDay:
            bounds = HopCopy.timerSettings.activeDaysEveryDay.localized
        }
        return exception.label == .custom ? bounds : "\(exception.label.parentTitle) · \(bounds)"
    }
}

#if DEBUG
// `@MainActor` because `ParentEnvironment` is, and so is everything hanging off
// it including `previewCalendar`. A file-scope function is nonisolated by
// default, which made this the one caller of `previewCalendar` that was not
// already on the main actor:
//
//     error: main actor-isolated static property 'previewCalendar' can not be
//            referenced from a nonisolated context
//
// Every call site is a `#Preview` body, which is main-actor anyway, so the
// annotation costs nothing and states what was already true.
@MainActor
private func previewSummary(_ schedule: PottySchedule) -> ScheduleSummary {
    PottyScheduleService(calendar: ParentEnvironment.previewCalendar)
        .summarize(schedule, at: HopFixtures.referenceDate)
}

#Preview("Pause, weekdays, two quiet windows") {
    SchedulePreviewCard(
        summary: previewSummary(
            PottySchedule(
                childID: HopFixtures.mayaChildID,
                mode: .pause,
                quietWindows: QuietWindow.onboardingSuggestions,
                activeDays: Weekday.weekdays
            )
        ),
        calendar: ParentEnvironment.previewCalendar
    )
    .padding()
    .hopThemedRoot()
}

#Preview("Disabled, AX3 dark") {
    SchedulePreviewCard(
        summary: previewSummary(
            PottySchedule(childID: HopFixtures.mayaChildID, mode: .gentle, isEnabled: false)
        ),
        calendar: ParentEnvironment.previewCalendar
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
    .hopThemedRoot()
}
#endif
