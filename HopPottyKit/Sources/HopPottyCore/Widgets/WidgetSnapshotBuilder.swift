import Foundation

/// Turns the models the app already has into the one small record a widget can
/// draw.
///
/// Pure: no clock, no calendar of its own, no store, no file system. Every
/// answer is a function of the values handed in, which is what lets the whole of
/// the widget's judgement be tested on Linux while the drawing itself cannot be
/// compiled here at all.
///
/// ## Why the builder decides the mood
///
/// A widget process is given a fraction of a second, no network, no database and
/// no second chance. Anything it has to work out, it works out badly. So the
/// question "how should Hop look?" — which depends on the schedule, on how close
/// the next appointment is, and on whether a pause is already running — is
/// answered here, once, by the process that has all three, and stored as a
/// string.
///
/// ## Why the name is opt-in
///
/// ``snapshot(schedule:projection:quickReminder:childNickname:includeChildName:pauseEndsAt:now:)``
/// takes the nickname *and* a separate flag, and drops the nickname unless the
/// flag is `true`. Passing the name is not the same act as publishing it: the
/// caller usually has a nickname to hand, and the point of the flag is that
/// putting a child's name on a lock screen has to be typed out deliberately at
/// the call site. `Docs/PrivacyArchitecture.md` §5 and `Docs/Widgets.md` §2.
public enum WidgetSnapshotBuilder {

    /// Inside this much of the next appointment, Hop is jumping.
    ///
    /// Two minutes. The same order as "it is happening now" for a caregiver
    /// crossing a room, and short enough that the excited face is not the face
    /// the widget wears all afternoon.
    public static let imminentWindow: TimeInterval = 2 * 60

    /// Inside this much, Hop is waving.
    ///
    /// Ten minutes, matched to ``WidgetTimelinePlan/fineWindow`` on purpose: the
    /// widget starts being redrawn every minute at exactly the moment its
    /// picture starts changing every minute. Two different numbers here would
    /// mean either a face that changes between refreshes nobody scheduled, or a
    /// minute-by-minute refresh spent redrawing an identical frog.
    public static let approachWindow: TimeInterval = 10 * 60

    // MARK: - The general form

    /// Build from values the caller has already resolved.
    ///
    /// - Parameters:
    ///   - schedule: the child's schedule, or `nil` when there is none.
    ///   - projection: what `PottyScheduleService.nextPause(after:)` returned.
    ///     A projection the caregiver has chosen to skip contributes no date:
    ///     nothing is going to interrupt them, and a countdown to an
    ///     interruption that will not happen is worse than no countdown.
    ///   - quickReminder: the caregiver's pending one-off, if any. Reminders
    ///     that have fired or been cancelled contribute nothing.
    ///   - childNickname: already sanitised by `ChildProfile.sanitize`.
    ///   - includeChildName: whether the caregiver has asked for the name to
    ///     appear on the widget. Defaults to `false`; see the type note.
    ///   - pauseEndsAt: when a pause or routine already in progress is expected
    ///     to end. `nil` when nothing is running.
    ///   - now: the instant the snapshot describes.
    public static func snapshot(
        schedule: PottySchedule?,
        projection: PauseProjection?,
        quickReminder: QuickReminder? = nil,
        childNickname: String? = nil,
        includeChildName: Bool = false,
        pauseEndsAt: Date? = nil,
        now: Date
    ) -> WidgetSnapshot {
        let isEnabled = schedule?.isEnabled ?? false
        let nextPauseAt = resolvedPause(projection, isScheduleEnabled: isEnabled, now: now)
        let reminderAt = resolvedReminder(quickReminder, now: now)
        let runningUntil = resolvedPauseEnd(pauseEndsAt, now: now)

        let mood = self.mood(
            isScheduleEnabled: isEnabled,
            nextPauseAt: nextPauseAt,
            quickReminderAt: reminderAt,
            pauseEndsAt: runningUntil,
            now: now
        )

        return WidgetSnapshot(
            nextPauseAt: nextPauseAt,
            childDisplayName: includeChildName ? ChildProfile.sanitize(childNickname) : nil,
            hopPoseName: mood.rawValue,
            quickReminderAt: reminderAt,
            isScheduleEnabled: isEnabled,
            pauseEndsAt: runningUntil,
            generatedAt: now
        )
    }

    /// Build straight from a `ScheduleState`, doing the projection here.
    ///
    /// The convenience the app actually calls. `service` carries the calendar,
    /// so this stays as free of ambient time zone as everything else in Core.
    public static func snapshot(
        state: ScheduleState,
        using service: PottyScheduleService,
        quickReminder: QuickReminder? = nil,
        childNickname: String? = nil,
        includeChildName: Bool = false,
        pauseEndsAt: Date? = nil
    ) -> WidgetSnapshot {
        snapshot(
            schedule: state.schedule,
            projection: service.nextPause(after: state),
            quickReminder: quickReminder,
            childNickname: childNickname,
            includeChildName: includeChildName,
            pauseEndsAt: pauseEndsAt,
            now: state.now
        )
    }

    /// The snapshot for a device with no schedule at all: onboarding not
    /// finished, every child deleted, or Potty Pause never switched on.
    ///
    /// A separate entry point rather than a `nil` schedule falling through the
    /// general form, because "there is nothing to show" is a state the widget
    /// draws deliberately and not an accident of empty inputs.
    public static func emptySnapshot(
        quickReminder: QuickReminder? = nil,
        now: Date
    ) -> WidgetSnapshot {
        snapshot(
            schedule: nil,
            projection: nil,
            quickReminder: quickReminder,
            childNickname: nil,
            includeChildName: false,
            pauseEndsAt: nil,
            now: now
        )
    }

    // MARK: - Mood

    /// The one judgement in this file.
    ///
    /// Ordered by urgency, and every branch fails toward the calmer face. A
    /// widget that looks excited when nothing is happening teaches a family to
    /// ignore it.
    public static func mood(
        isScheduleEnabled: Bool,
        nextPauseAt: Date?,
        quickReminderAt: Date?,
        pauseEndsAt: Date?,
        now: Date
    ) -> HopWidgetMood {
        // A pause running right now outranks everything, including a schedule
        // that has since been switched off: the child is in front of the shield
        // whatever the settings say.
        if let pauseEndsAt, now < pauseEndsAt { return .cheer }

        let upcoming = [nextPauseAt, quickReminderAt]
            .compactMap { $0 }
            .filter { $0 > now }
            .min()

        guard let upcoming else {
            // Nothing coming. Asleep when that is because the schedule is off,
            // waiting when the schedule is on but has nothing to project — a
            // skipped pause, or a day whose active window has closed.
            return isScheduleEnabled ? .idle : .sleep
        }

        let until = upcoming.timeIntervalSince(now)
        if until <= imminentWindow { return .jump }
        if until <= approachWindow { return .wave }
        return .idle
    }

    // MARK: - Resolution

    /// A projection becomes a date only if it is in the future and is actually
    /// going to happen.
    private static func resolvedPause(
        _ projection: PauseProjection?,
        isScheduleEnabled: Bool,
        now: Date
    ) -> Date? {
        guard isScheduleEnabled, let projection, !projection.willBeSkipped else { return nil }
        // A projection at or before `now` is a pause that is due rather than
        // upcoming. Something else — the monitor extension, or the app on
        // foreground — is about to act on it, and a countdown reading "0:00" for
        // the next quarter of an hour is a worse answer than none.
        return projection.start > now ? projection.start : nil
    }

    /// Only a pending reminder that has not yet come due is worth a countdown.
    /// `QuickReminderPlanner` owns the definition of "due"; this defers to it so
    /// the widget and the caregiver's own chip can never disagree.
    private static func resolvedReminder(_ reminder: QuickReminder?, now: Date) -> Date? {
        guard let reminder, reminder.isPending, !QuickReminderPlanner.isDue(reminder, at: now) else {
            return nil
        }
        return reminder.fireAt
    }

    /// A pause whose expected end has already passed is not running. Every
    /// end-path clears the record; this is the reading for the window between
    /// the instant passing and some process noticing.
    private static func resolvedPauseEnd(_ endsAt: Date?, now: Date) -> Date? {
        guard let endsAt, endsAt > now else { return nil }
        return endsAt
    }
}
