import Foundation

/// A caregiver-readable description of a schedule, in named parts.
///
/// The parts are the point. A summary is assembled as structure first and
/// rendered second, so the English below can be lifted into `HopCopy` without
/// touching this logic, and a translator can reorder every slot in a sentence
/// rather than receiving "except", "between" and "12:30" as three separate
/// strings to glue together in an order English happens to like.
public struct ScheduleSummary: Hashable, Sendable {

    /// Which days the schedule runs, collapsed to the phrase a caregiver uses.
    public enum DayCoverage: Hashable, Sendable {
        case everyDay
        case weekdays
        case weekends
        /// Always sorted, so two equal schedules produce equal summaries.
        case specific([Weekday])

        public init(_ days: Set<Weekday>) {
            // Empty means every day everywhere in HopPotty; a decoded schedule can
            // still arrive that way.
            let resolved = days.isEmpty ? Weekday.everyDay : days
            if resolved == Weekday.everyDay { self = .everyDay }
            else if resolved == Weekday.weekdays { self = .weekdays }
            else if resolved == Weekday.weekend { self = .weekends }
            else { self = .specific(resolved.sorted()) }
        }

        public var weekdays: Set<Weekday> {
            switch self {
            case .everyDay: Weekday.everyDay
            case .weekdays: Weekday.weekdays
            case .weekends: Weekday.weekend
            case .specific(let days): Set(days)
            }
        }
    }

    /// A wall-clock span, kept as structure so a UI can render a picker from it.
    public struct TimeSpan: Hashable, Sendable {
        public let start: LocalTimeOfDay
        public let end: LocalTimeOfDay
        public init(start: LocalTimeOfDay, end: LocalTimeOfDay) {
            self.start = start
            self.end = end
        }
        /// Equal bounds mean the whole day, matching `QuietWindow`.
        public var coversWholeDay: Bool { start == end }
    }

    /// What actually happens when the trigger fires. Derived from `PottyPauseMode`
    /// — gentle mode carries no duration because nothing is ever held.
    public enum Action: Hashable, Sendable {
        case reminder
        case pause(minutes: Int)
        case guidedRoutine(minutes: Int)
    }

    /// What makes it fire.
    public enum Cadence: Hashable, Sendable {
        case afterQualifyingUse(minutes: Int)
        case everyClockInterval(minutes: Int)
    }

    /// A stretch of the day HopPotty stays out of.
    ///
    /// The shape is chosen from the geometry of the blocked run, not from where it
    /// came from: an overnight run renders as "after 7:30 PM" because in a
    /// sentence about a daily routine the morning tail is understood. The full
    /// bounds are kept in the value regardless, so nothing is actually lost.
    public enum Exception: Hashable, Sendable {
        case before(LocalTimeOfDay, label: QuietWindowLabel, days: DayCoverage)
        case between(start: LocalTimeOfDay, end: LocalTimeOfDay, label: QuietWindowLabel, days: DayCoverage)
        case after(from: LocalTimeOfDay, until: LocalTimeOfDay, label: QuietWindowLabel, days: DayCoverage)
        /// A quiet window that covers the entire day — the caregiver set equal
        /// start and end times. Pathological, but a settings screen can spot this
        /// case in the structured value and offer to fix it, which it could not do
        /// if the summary quietly said nothing.
        case allDay(label: QuietWindowLabel, days: DayCoverage)

        public var label: QuietWindowLabel {
            switch self {
            case .before(_, let label, _), .allDay(let label, _): label
            case .between(_, _, let label, _): label
            case .after(_, _, let label, _): label
            }
        }

        public var days: DayCoverage {
            switch self {
            case .before(_, _, let days), .allDay(_, let days): days
            case .between(_, _, _, let days): days
            case .after(_, _, _, let days): days
            }
        }
    }

    /// Whether the schedule is actually running right now.
    public enum Status: Hashable, Sendable {
        case active
        case disabled
        case suspendedIndefinitely
        case suspendedUntil(Date)
        case suspendedUntilTomorrow(resumesAt: Date)
        case skippingNextPause
    }

    public let days: DayCoverage
    public let action: Action
    public let cadence: Cadence
    public let activeWindow: TimeSpan
    /// In reading order: morning cut-off, daytime windows, evening cut-off.
    public let exceptions: [Exception]
    public let status: Status
    /// English rendering of the schedule itself.
    public let sentence: String
    /// `sentence` plus the status sentence, when the status has something to add.
    public let english: String

    public init(
        days: DayCoverage,
        action: Action,
        cadence: Cadence,
        activeWindow: TimeSpan,
        exceptions: [Exception],
        status: Status,
        sentence: String,
        english: String
    ) {
        self.days = days
        self.action = action
        self.cadence = cadence
        self.activeWindow = activeWindow
        self.exceptions = exceptions
        self.status = status
        self.sentence = sentence
        self.english = english
    }
}

// MARK: - Building

extension PottyScheduleService {
    /// Describe a schedule for a caregiver.
    ///
    /// `now` is needed only for the status clause — an `until` hold that has
    /// already expired must not be reported as still holding.
    public func summarize(_ schedule: PottySchedule, at now: Date) -> ScheduleSummary {
        let dayCoverage = ScheduleSummary.DayCoverage(schedule.activeDays)

        let pauseMinutes = max(1, Int((schedule.pauseDuration / 60).rounded()))
        let action: ScheduleSummary.Action = switch schedule.mode {
        case .gentle: .reminder
        case .pause: .pause(minutes: pauseMinutes)
        case .routine: .guidedRoutine(minutes: pauseMinutes)
        }

        let cadence: ScheduleSummary.Cadence = switch schedule.triggerBasis {
        case .screenActivity: .afterQualifyingUse(minutes: schedule.interval.minutes)
        case .clockTime: .everyClockInterval(minutes: schedule.interval.minutes)
        }

        let activeWindow = ScheduleSummary.TimeSpan(
            start: schedule.activeWindowStart,
            end: schedule.activeWindowEnd
        )

        let exceptions = ScheduleSummary.exceptions(for: schedule, days: dayCoverage)
        let status = summaryStatus(for: schedule, at: now)

        let sentence = ScheduleSummary.renderSentence(
            days: dayCoverage,
            action: action,
            cadence: cadence,
            exceptions: exceptions
        )
        let statusSentence = renderStatus(status, at: now)

        let english: String = switch status {
        // A schedule that is off is not a schedule that is running; describing its
        // cadence as if it were would be a lie a parent could act on.
        case .disabled: statusSentence ?? sentence
        default:
            if let statusSentence { sentence + " " + statusSentence } else { sentence }
        }

        return ScheduleSummary(
            days: dayCoverage,
            action: action,
            cadence: cadence,
            activeWindow: activeWindow,
            exceptions: exceptions,
            status: status,
            sentence: sentence,
            english: english
        )
    }

    func summaryStatus(for schedule: PottySchedule, at now: Date) -> ScheduleSummary.Status {
        guard schedule.isEnabled else { return .disabled }
        let resolved = resolveSuspension(schedule.suspension, at: now)
        guard resolved.isBlocking else { return .active }
        switch resolved.suspension {
        case .indefinite: return .suspendedIndefinitely
        case .until(let date): return .suspendedUntil(date)
        case .untilTomorrow:
            return .suspendedUntilTomorrow(resumesAt: resolved.resumesAt ?? now)
        case .skipNext: return .skippingNextPause
        case .none: return .active
        }
    }
}

// MARK: - Blocked-run geometry

extension ScheduleSummary {
    /// A stretch of the 24-hour clock, in minutes. `end <= start` wraps midnight;
    /// equal bounds mean the whole day, exactly as `QuietWindow` reads them.
    struct MinuteRun: Hashable {
        let start: Int
        let end: Int

        init(start: Int, end: Int) {
            self.start = ((start % 1440) + 1440) % 1440
            self.end = ((end % 1440) + 1440) % 1440
        }

        var wraps: Bool { end <= start }
        var length: Int { wraps ? 1440 - start + end : end - start }

        func contains(_ minute: Int) -> Bool {
            if wraps { return minute >= start || minute < end }
            return minute >= start && minute < end
        }

        func covers(_ other: MinuteRun) -> Bool {
            for offset in 0..<other.length where !contains((other.start + offset) % 1440) {
                return false
            }
            return true
        }
    }

    struct Candidate {
        let run: MinuteRun
        let label: QuietWindowLabel
        let days: Set<Weekday>
    }

    /// Everything that stops a pause happening, as phrases.
    ///
    /// The list is the complement of the active window plus every enabled quiet
    /// window, with anything wholly contained in something else removed. That
    /// single rule is why a bedtime window of 19:30–07:00 sitting behind an active
    /// window of 07:00–19:30 produces one phrase and not three.
    static func exceptions(for schedule: PottySchedule, days: DayCoverage) -> [Exception] {
        let scheduleDays = days.weekdays
        var candidates: [Candidate] = []

        let windowStart = schedule.activeWindowStart.minutesSinceMidnight
        let windowEnd = schedule.activeWindowEnd.minutesSinceMidnight
        if windowStart != windowEnd {
            // The complement of [start, end) is the run [end, start).
            candidates.append(
                Candidate(
                    run: MinuteRun(start: windowEnd, end: windowStart),
                    label: .custom,
                    days: scheduleDays
                )
            )
        }

        for window in schedule.quietWindows where window.isEnabled {
            let windowDays = window.days.isEmpty ? scheduleDays : window.days.intersection(scheduleDays)
            // A quiet window that only covers days the schedule never runs on has
            // nothing to say to a caregiver.
            guard !windowDays.isEmpty else { continue }
            candidates.append(
                Candidate(
                    run: MinuteRun(
                        start: window.start.minutesSinceMidnight,
                        end: window.end.minutesSinceMidnight
                    ),
                    label: window.label,
                    days: windowDays
                )
            )
        }

        // Keep the widest first so narrower duplicates fall out; among equals the
        // more protective label survives, then start time, then label rank — a
        // total order, so the summary of a given schedule never varies.
        let ordered = candidates.sorted { lhs, rhs in
            if lhs.run.length != rhs.run.length { return lhs.run.length > rhs.run.length }
            if lhs.days.count != rhs.days.count { return lhs.days.count > rhs.days.count }
            if lhs.label.protectionRank != rhs.label.protectionRank {
                return lhs.label.protectionRank < rhs.label.protectionRank
            }
            return lhs.run.start < rhs.run.start
        }

        var kept: [Candidate] = []
        for candidate in ordered {
            let isRedundant = kept.contains { existing in
                existing.run.covers(candidate.run) && existing.days.isSuperset(of: candidate.days)
            }
            if !isRedundant { kept.append(candidate) }
        }

        return kept
            .map { phrase(for: $0, scheduleDays: scheduleDays) }
            .sorted { sortKey($0) < sortKey($1) }
    }

    private static func phrase(for candidate: Candidate, scheduleDays: Set<Weekday>) -> Exception {
        let days = DayCoverage(candidate.days == scheduleDays ? scheduleDays : candidate.days)
        let start = LocalTimeOfDay(minutesSinceMidnight: candidate.run.start)
        let end = LocalTimeOfDay(minutesSinceMidnight: candidate.run.end)

        if candidate.run.length >= 1440 {
            return .allDay(label: candidate.label, days: days)
        }
        if candidate.run.wraps {
            return .after(from: start, until: end, label: candidate.label, days: days)
        }
        if candidate.run.start == 0 {
            return .before(end, label: candidate.label, days: days)
        }
        return .between(start: start, end: end, label: candidate.label, days: days)
    }

    /// Morning cut-off, then the day in order, then the evening cut-off — which is
    /// the order a caregiver reads their own day in.
    private static func sortKey(_ exception: Exception) -> Int {
        switch exception {
        case .allDay: -1
        case .before(let time, _, _): time.minutesSinceMidnight
        case .between(let start, _, _, _): 1_440 + start.minutesSinceMidnight
        case .after(let from, _, _, _): 2_880 + from.minutesSinceMidnight
        }
    }
}

// MARK: - English rendering
//
// Everything below is temporary: it moves to `HopCopy` at integration. It is
// written as templates with named slots rather than string addition so that move
// is a copy-paste and a translator can reorder any part of any sentence.

extension ScheduleSummary {
    enum Template {
        static let sentence = "{days}, Hop will {activity}{except}."
        static let activityScreenActivity =
            "watch selected screen activity and {action} after {interval} of qualifying use"
        static let activityClockTime = "{action} every {interval}"
        static let actionReminder = "send a gentle reminder"
        static let actionPause = "trigger a {duration} Potty Pause"
        static let actionRoutine = "start a {duration} Potty Pause with the full routine"
        static let exceptClause = ", except {exceptions}"
        static let exceptionWithDays = "{exception} on {days}"
        static let exceptionBefore = "before {time}"
        static let exceptionBetween = "between {range}"
        static let exceptionAfter = "after {time}"
        static let exceptionAllDay = "at any time"
        static let pairJoin = "{first} and {second}"
        static let listJoin = "{list}, and {last}"
    }

    static func fill(_ template: String, _ values: [String: String]) -> String {
        // Longest key first so no slot name can be a prefix of another.
        values.sorted { $0.key.count > $1.key.count }
            .reduce(template) { partial, pair in
                partial.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
            }
    }

    static func renderSentence(
        days: DayCoverage,
        action: Action,
        cadence: Cadence,
        exceptions: [Exception]
    ) -> String {
        let actionText = switch action {
        case .reminder:
            Template.actionReminder
        case .pause(let minutes):
            fill(Template.actionPause, ["duration": durationAdjective(minutes)])
        case .guidedRoutine(let minutes):
            fill(Template.actionRoutine, ["duration": durationAdjective(minutes)])
        }

        let activity = switch cadence {
        case .afterQualifyingUse(let minutes):
            fill(
                Template.activityScreenActivity,
                ["action": actionText, "interval": intervalNoun(minutes)]
            )
        case .everyClockInterval(let minutes):
            fill(Template.activityClockTime, ["action": actionText, "interval": recurrenceNoun(minutes)])
        }

        let exceptClause = exceptions.isEmpty
            ? ""
            : fill(
                Template.exceptClause,
                ["exceptions": joined(exceptions.map { render($0, within: days) })]
            )

        return fill(
            Template.sentence,
            [
                "days": dayPhrase(days, capitalised: true),
                "activity": activity,
                "except": exceptClause,
            ]
        )
    }

    static func render(_ exception: Exception, within scheduleDays: DayCoverage) -> String {
        let base = switch exception {
        case .allDay:
            Template.exceptionAllDay
        case .before(let time, _, _):
            fill(Template.exceptionBefore, ["time": clock(time)])
        case .between(let start, let end, _, _):
            fill(Template.exceptionBetween, ["range": clockRange(start, end)])
        case .after(let from, _, _, _):
            fill(Template.exceptionAfter, ["time": clock(from)])
        }
        guard exception.days != scheduleDays else { return base }
        return fill(
            Template.exceptionWithDays,
            ["exception": base, "days": dayPhrase(exception.days, capitalised: false, bare: true)]
        )
    }

    static func joined(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return fill(Template.pairJoin, ["first": items[0], "second": items[1]])
        default:
            let head = items.dropLast().joined(separator: ", ")
            return fill(Template.listJoin, ["list": head, "last": items[items.count - 1]])
        }
    }

    /// "3-minute", as in "a 3-minute Potty Pause".
    static func durationAdjective(_ minutes: Int) -> String { "\(minutes)-minute" }

    /// The noun after "every", where English drops the "1": "every hour", never
    /// "every 1 hour".
    static func recurrenceNoun(_ minutes: Int) -> String {
        if minutes >= 60, minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "hour" : "\(hours) hours"
        }
        return "\(minutes) minutes"
    }

    /// "45 minutes", "1 hour", "2 hours".
    static func intervalNoun(_ minutes: Int) -> String {
        if minutes >= 60, minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "\(minutes) minutes"
    }

    /// "7 AM", "12:30 PM". The `:00` is dropped because a caregiver reading a
    /// sentence says "seven", not "seven oh oh".
    static func clock(_ time: LocalTimeOfDay) -> String {
        "\(bareClock(time)) \(meridiem(time))"
    }

    static func bareClock(_ time: LocalTimeOfDay) -> String {
        let hour = time.hour % 12 == 0 ? 12 : time.hour % 12
        return time.minute == 0 ? "\(hour)" : String(format: "%d:%02d", hour, time.minute)
    }

    static func meridiem(_ time: LocalTimeOfDay) -> String { time.hour < 12 ? "AM" : "PM" }

    /// "12:30–2:30 PM" when both sides share a meridiem, "11:30 AM–1 PM" when they
    /// do not.
    static func clockRange(_ start: LocalTimeOfDay, _ end: LocalTimeOfDay) -> String {
        if meridiem(start) == meridiem(end) {
            return "\(bareClock(start))–\(bareClock(end)) \(meridiem(end))"
        }
        return "\(clock(start))–\(clock(end))"
    }

    static func dayPhrase(_ days: DayCoverage, capitalised: Bool, bare: Bool = false) -> String {
        switch days {
        case .everyDay:
            return bare ? "any day" : (capitalised ? "Every day" : "every day")
        case .weekdays:
            return bare ? "weekdays" : (capitalised ? "On weekdays" : "on weekdays")
        case .weekends:
            return bare ? "weekends" : (capitalised ? "On weekends" : "on weekends")
        case .specific(let list):
            let names = joined(list.map { $0.pluralName })
            return bare ? names : (capitalised ? "On \(names)" : "on \(names)")
        }
    }
}

extension PottyScheduleService {
    /// The status clause, or `nil` when the schedule is simply running.
    func renderStatus(_ status: ScheduleSummary.Status, at now: Date) -> String? {
        switch status {
        case .active:
            return nil
        case .disabled:
            return "Potty Pause is off."
        case .suspendedIndefinitely:
            return "Potty Pause is paused until you turn it back on."
        case .suspendedUntilTomorrow:
            return "Paused until tomorrow."
        case .skippingNextPause:
            return "The next Potty Pause will be skipped."
        case .suspendedUntil(let date):
            let time = ScheduleSummary.clock(localTime(at: date))
            let sameDay = calendar.isDate(date, inSameDayAs: now)
            return sameDay
                ? "Paused until \(time)."
                : "Paused until \(weekday(at: date).name) at \(time)."
        }
    }
}

extension Weekday {
    /// English day names live here only until the copy catalog exists.
    var name: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }

    var pluralName: String { name + "s" }
}
