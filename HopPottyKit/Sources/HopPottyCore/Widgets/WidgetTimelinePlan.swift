import Foundation

/// When a widget timeline should have an entry, and when it should ask to be
/// rebuilt.
///
/// ## The budget this exists to spend well
///
/// WidgetKit does not redraw a widget when the app asks; it redraws it when the
/// system decides, out of a daily allowance the system does not publish. A
/// timeline that asks for an entry every minute all day is a timeline whose
/// allowance is gone by lunchtime, and a widget with no allowance left is a
/// widget showing this morning's answer at bedtime.
///
/// So the plan is shaped like the thing it describes:
///
/// | Distance to the next appointment | Entry every |
/// | --- | --- |
/// | more than ``fineWindow`` | ``coarseStep`` — 15 minutes |
/// | inside ``fineWindow`` | ``fineStep`` — 1 minute |
///
/// and the whole timeline stops at ``horizon`` whatever is or is not coming.
///
/// ## What the entries are *not* for
///
/// The countdown itself needs none of them. `Text(_:style: .timer)` and
/// `Text(_:style: .relative)` are rendered by the system from a date, and they
/// keep ticking with no entry, no reload and no budget spent. The entries exist
/// for everything a date cannot animate on its own: which face Hop is wearing,
/// whether the copy reads "in a while" or "very soon", and the moment the
/// appointment arrives and the widget has to say something different. That is
/// why the fine cadence is a *ten-minute* window rather than an hour — the
/// picture only starts changing once a minute in the last ten
/// (`WidgetSnapshotBuilder.approachWindow`), and paying for a minute-by-minute
/// redraw before that buys an identical frame.
public enum WidgetTimelinePlan {

    // MARK: - The numbers

    /// How close an appointment has to be for minute-by-minute entries.
    ///
    /// Ten minutes, equal to `WidgetSnapshotBuilder.approachWindow`. The two
    /// must stay equal: this one decides when the widget is redrawn, that one
    /// decides when the drawing changes, and a gap between them is either
    /// refreshes that redraw nothing or a change nobody scheduled a refresh for.
    public static let fineWindow: TimeInterval = 10 * 60

    /// The cadence inside ``fineWindow``.
    public static let fineStep: TimeInterval = 60

    /// The cadence outside it.
    ///
    /// Fifteen minutes is also `ScreenTimeIdentifiers.minimumScheduleInterval`
    /// — the floor Apple puts on a `DeviceActivitySchedule` — which is a
    /// coincidence worth keeping: nothing in HopPotty's own scheduling can move
    /// faster than this while the app is not running, so a coarser widget entry
    /// could not have been wrong for long and a finer one could not have been
    /// right any sooner.
    public static let coarseStep: TimeInterval = 15 * 60

    /// How far ahead a single timeline reaches.
    ///
    /// Four hours. Long enough that a phone left alone through a nap still has
    /// entries when someone picks it up; short enough that the app gets asked
    /// for a fresh snapshot several times a day, which is the only way a widget
    /// learns that a schedule changed while it was not being looked at.
    public static let horizon: TimeInterval = 4 * 60 * 60

    /// The hard ceiling on entries in one timeline.
    ///
    /// Forty. The shape above tops out at roughly thirty (fifteen coarse plus
    /// ten fine plus the appointment and its settle entry), so this is a
    /// backstop against a future edit to the constants rather than a limit
    /// anything reaches today — the same reason the pause has a backstop it is
    /// not supposed to need.
    public static let maximumEntries = 40

    /// One entry just past the appointment, so the widget flips to "now" even if
    /// the system is slow to ask for a new timeline.
    ///
    /// Without it the last frame of the day would be a countdown reading zero,
    /// which is the one thing a countdown must never show for long.
    public static let settleStep: TimeInterval = 60

    // MARK: - Entries

    /// Entry dates for a snapshot, from `now`.
    ///
    /// The event refreshed around is the soonest of the next pause and the
    /// pending Quick Reminder — or, while a pause is running, the instant it is
    /// expected to end, because that is the next moment the widget has to say
    /// something different.
    public static func entryDates(for snapshot: WidgetSnapshot, from now: Date) -> [Date] {
        entryDates(from: now, nextEvent: pivot(for: snapshot, at: now))
    }

    /// The instant a snapshot's timeline is built around, or `nil` when there is
    /// nothing to count towards.
    public static func pivot(for snapshot: WidgetSnapshot, at now: Date) -> Date? {
        if let endsAt = snapshot.pauseEndsAt, endsAt > now { return endsAt }
        return snapshot.nextEvent(after: now)
    }

    /// The general form: entries from `now` up to and a little past `nextEvent`.
    ///
    /// Always returns at least one entry — `now` itself — because a timeline
    /// with no entries is a widget WidgetKit will not draw at all.
    ///
    /// Every returned date is `>= now`, strictly increasing, and no more than
    /// ``maximumEntries`` long.
    public static func entryDates(from now: Date, nextEvent: Date?) -> [Date] {
        var dates: [Date] = [now]
        let end = now.addingTimeInterval(horizon)

        // Anything past the horizon is, for this timeline, no event at all: the
        // widget will have been asked for a fresh plan long before it arrives.
        guard let event = nextEvent, event > now, event <= end else {
            appendCadence(&dates, from: now, until: end, step: coarseStep)
            return capped(dates)
        }

        // Coarse up to the edge of the fine window, then a minute at a time.
        // `fineStart` can be at or before `now` when the appointment is already
        // close, in which case the coarse phase contributes nothing and the fine
        // loop simply starts at the first whole minute after now.
        //
        // The boundary itself is appended by name between the two phases. It is
        // the instant Hop changes from waiting to waving
        // (`WidgetSnapshotBuilder.approachWindow`), so it is the one entry in the
        // whole plan that must exist for a reason other than cadence — and
        // neither loop would produce it, since both are exclusive at their start.
        let fineStart = event.addingTimeInterval(-fineWindow)
        appendCadence(&dates, from: now, until: fineStart, step: coarseStep)
        append(&dates, fineStart)
        appendCadence(&dates, from: max(now, fineStart), until: event, step: fineStep)

        append(&dates, event)
        append(&dates, event.addingTimeInterval(settleStep))

        return capped(dates)
    }

    // MARK: - Refresh

    /// The instant to hand WidgetKit's `.after(_:)` reload policy.
    ///
    /// The last entry, so the system comes back for a new snapshot exactly when
    /// this timeline runs out of things to say. When a timeline is a single
    /// entry — no appointment, nothing to count — it is one coarse step out, so
    /// a widget that has nothing to show still checks back rather than freezing
    /// on an empty state that may have stopped being true.
    public static func refreshDate(from now: Date, nextEvent: Date?) -> Date {
        let dates = entryDates(from: now, nextEvent: nextEvent)
        guard let last = dates.last, last > now else {
            return now.addingTimeInterval(coarseStep)
        }
        return last
    }

    /// The same, for a snapshot.
    public static func refreshDate(for snapshot: WidgetSnapshot, from now: Date) -> Date {
        refreshDate(from: now, nextEvent: pivot(for: snapshot, at: now))
    }

    // MARK: - Mechanics

    /// Append `step`-spaced dates strictly after `start` and strictly before
    /// `limit`.
    ///
    /// Exclusive at both ends on purpose: `start` is either `now` (already in
    /// the list) or the previous phase's boundary (about to be added by the next
    /// phase), and `limit` is the appointment itself, which is appended once, by
    /// name, so it cannot be missed by an arithmetic edge.
    private static func appendCadence(
        _ dates: inout [Date],
        from start: Date,
        until limit: Date,
        step: TimeInterval
    ) {
        guard step > 0, limit > start else { return }
        var cursor = start.addingTimeInterval(step)
        // Bounded by the ceiling as well as by `limit`, so a bad constant can
        // produce a short timeline but never a loop that does not end.
        while cursor < limit, dates.count < maximumEntries {
            append(&dates, cursor)
            cursor = cursor.addingTimeInterval(step)
        }
    }

    /// Append while keeping the list strictly increasing.
    private static func append(_ dates: inout [Date], _ date: Date) {
        guard let last = dates.last else {
            dates.append(date)
            return
        }
        guard date > last else { return }
        dates.append(date)
    }

    private static func capped(_ dates: [Date]) -> [Date] {
        dates.count <= maximumEntries ? dates : Array(dates.prefix(maximumEntries))
    }
}
