import Foundation

/// A half-open span of time, `[start, end)`.
///
/// Foundation's `DateInterval` is closed at both ends, which puts midnight in
/// two days at once and makes "which week does this belong to" ambiguous at
/// exactly the boundary a family notices. Half-open is stated in the type so
/// nobody has to remember.
public struct DateWindow: Hashable, Sendable {
    public let start: Date
    /// Exclusive.
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = max(start, end)
    }

    public func contains(_ date: Date) -> Bool { date >= start && date < end }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    /// Whole local days the window spans, used to place the preceding period.
    public func dayCount(calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, days)
    }

    /// The window of the same length immediately before this one.
    ///
    /// Shifted in calendar days rather than seconds so a period containing a
    /// daylight-saving transition still lines up with the previous period's
    /// midnight instead of drifting an hour.
    public func previous(calendar: Calendar) -> DateWindow {
        let days = dayCount(calendar: calendar)
        let newStart = calendar.date(byAdding: .day, value: -days, to: start) ?? start.addingTimeInterval(-duration)
        return DateWindow(start: newStart, end: start)
    }
}

/// Which stretch of the calendar an insights report covers.
///
/// The window is always resolved against an explicit `now` and an explicit
/// `Calendar`. Nothing in this module reads the system clock or the current
/// locale, which is what makes every number here reproducible in a test.
public enum InsightWindow: Hashable, Sendable {
    /// The local day containing `now`.
    case day
    /// The calendar week containing `now`, honouring `calendar.firstWeekday`.
    case week
    /// The `count` local days ending with the day containing `now`.
    case trailingDays(Int)

    /// Resolves the window to concrete instants.
    public func interval(containing now: Date, calendar: Calendar) -> DateWindow {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday

        switch self {
        case .day:
            return DateWindow(start: startOfToday, end: startOfTomorrow)

        case .week:
            // Computed from firstWeekday rather than via dateInterval(of:) so the
            // result is identical on every platform the package builds for.
            let weekday = calendar.component(.weekday, from: startOfToday)
            let offset = ((weekday - calendar.firstWeekday) % 7 + 7) % 7
            let start = calendar.date(byAdding: .day, value: -offset, to: startOfToday) ?? startOfToday
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? startOfTomorrow
            return DateWindow(start: start, end: end)

        case .trailingDays(let count):
            let days = max(1, count)
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday) ?? startOfToday
            return DateWindow(start: start, end: startOfTomorrow)
        }
    }

    /// The comparable window immediately before this one.
    public func previousInterval(containing now: Date, calendar: Calendar) -> DateWindow {
        interval(containing: now, calendar: calendar).previous(calendar: calendar)
    }
}

/// Named parts of the day, used for the time-of-day comparison.
///
/// The boundaries are ordinary household ones — before lunch, after lunch,
/// after the working day, overnight. They carry no claim about when anyone
/// ought to use a bathroom; they are buckets for grouping entries a family
/// already made.
public enum DaySegment: String, CaseIterable, Hashable, Sendable, Identifiable {
    case morning, afternoon, evening, night

    public var id: String { rawValue }

    /// Half-open `[start, end)` on the wall clock. `night` wraps midnight.
    public var range: (start: LocalTimeOfDay, end: LocalTimeOfDay) {
        switch self {
        case .morning: (LocalTimeOfDay(hour: 5, minute: 0), LocalTimeOfDay(hour: 12, minute: 0))
        case .afternoon: (LocalTimeOfDay(hour: 12, minute: 0), LocalTimeOfDay(hour: 17, minute: 0))
        case .evening: (LocalTimeOfDay(hour: 17, minute: 0), LocalTimeOfDay(hour: 21, minute: 0))
        case .night: (LocalTimeOfDay(hour: 21, minute: 0), LocalTimeOfDay(hour: 5, minute: 0))
        }
    }

    /// Stable ordering for deterministic output when two segments tie.
    public var sortOrder: Int {
        switch self {
        case .morning: 0
        case .afternoon: 1
        case .evening: 2
        case .night: 3
        }
    }

    /// Plural noun used in generated sentences ("Mornings had an entry on...").
    public var pluralLabel: String {
        switch self {
        case .morning: "Mornings"
        case .afternoon: "Afternoons"
        case .evening: "Evenings"
        case .night: "Nights"
        }
    }

    /// Lower-case plural, for the second clause of a sentence.
    public var pluralLabelLowercased: String {
        switch self {
        case .morning: "mornings"
        case .afternoon: "afternoons"
        case .evening: "evenings"
        case .night: "nights"
        }
    }

    /// Which segment a wall-clock time falls in.
    public static func containing(_ time: LocalTimeOfDay) -> DaySegment {
        let minutes = time.minutesSinceMidnight
        for segment in [DaySegment.morning, .afternoon, .evening] {
            let bounds = segment.range
            if minutes >= bounds.start.minutesSinceMidnight && minutes < bounds.end.minutesSinceMidnight {
                return segment
            }
        }
        // Everything outside the three daytime bands — 21:00 to 05:00 across
        // midnight — is night.
        return .night
    }

    /// Which segment an instant falls in, in the caller's calendar.
    public static func containing(_ date: Date, calendar: Calendar) -> DaySegment {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return containing(LocalTimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0))
    }
}
