import Foundation

/// One local day's counts.
///
/// `accident` is present here because the timeline is honest about what a
/// family recorded. It is a count and nothing else: there is deliberately no
/// ratio, no rate and no "of which" derived from it anywhere in this module,
/// because the moment an accident count acquires a denominator it becomes a
/// score a child can do badly at.
public struct DayTotal: Hashable, Sendable, Comparable {
    /// Midnight local time for the day this row describes.
    public let dayStart: Date
    public let weekday: Weekday
    public let countsByKind: [PottyEventKind: Int]

    init(dayStart: Date, weekday: Weekday, countsByKind: [PottyEventKind: Int]) {
        self.dayStart = dayStart
        self.weekday = weekday
        // Every kind is present, so a chart does not have to distinguish "zero"
        // from "missing" and a diff between two days is always well defined.
        var filled = countsByKind
        for kind in PottyEventKind.allCases where filled[kind] == nil { filled[kind] = 0 }
        self.countsByKind = filled
    }

    public func count(of kind: PottyEventKind) -> Int { countsByKind[kind] ?? 0 }

    /// Entries where the child took part, in any of the three child-loggable
    /// kinds. `tried` counts exactly as much as `pee`; that is the point.
    public var participationCount: Int {
        PottyEventKind.allCases
            .filter(\.countsAsParticipation)
            .reduce(0) { $0 + count(of: $1) }
    }

    public var accidentCount: Int { count(of: .accident) }

    public var recordedCount: Int {
        PottyEventKind.allCases.reduce(0) { $0 + count(of: $1) }
    }

    public var hasAnyEntry: Bool { recordedCount > 0 }

    public static func < (lhs: DayTotal, rhs: DayTotal) -> Bool { lhs.dayStart < rhs.dayStart }
}

/// Counts for one period, plus the per-day and per-weekday rollups a dashboard
/// needs to draw it.
public struct PeriodAggregate: Hashable, Sendable {
    public let window: DateWindow
    /// One row per local day in the window, ascending, including days with no
    /// entries at all.
    public let dayTotals: [DayTotal]
    public let countsByKind: [PottyEventKind: Int]
    /// Participation entries summed per weekday — the "which days of the week
    /// look like each other" rollup.
    public let participationByWeekday: [Weekday: Int]
    /// How many days of each weekday fell in this window, so a caller can turn
    /// the rollup into a per-day figure without assuming a seven-day period.
    public let daysByWeekday: [Weekday: Int]

    init(
        window: DateWindow,
        dayTotals: [DayTotal],
        countsByKind: [PottyEventKind: Int],
        participationByWeekday: [Weekday: Int],
        daysByWeekday: [Weekday: Int]
    ) {
        self.window = window
        self.dayTotals = dayTotals.sorted()
        var filled = countsByKind
        for kind in PottyEventKind.allCases where filled[kind] == nil { filled[kind] = 0 }
        self.countsByKind = filled
        var participation = participationByWeekday
        var days = daysByWeekday
        for weekday in Weekday.allCases {
            if participation[weekday] == nil { participation[weekday] = 0 }
            if days[weekday] == nil { days[weekday] = 0 }
        }
        self.participationByWeekday = participation
        self.daysByWeekday = days
    }

    public func count(of kind: PottyEventKind) -> Int { countsByKind[kind] ?? 0 }

    public var participationCount: Int {
        PottyEventKind.allCases
            .filter(\.countsAsParticipation)
            .reduce(0) { $0 + count(of: $1) }
    }

    public var accidentCount: Int { count(of: .accident) }

    public var recordedCount: Int {
        PottyEventKind.allCases.reduce(0) { $0 + count(of: $1) }
    }

    /// Calendar days in the window, entries or not.
    public var dayCount: Int { dayTotals.count }

    /// Days carrying at least one entry. This, not `dayCount`, is the
    /// denominator for anything describing how a family's days went: a day
    /// nobody logged is a day with no information, not a day with nothing in it.
    public var observedDayCount: Int { dayTotals.filter(\.hasAnyEntry).count }
}

/// Whether a count moved between two periods.
///
/// Carries no wording. The direction is for an arrow or a colour; the sentence
/// a parent reads states both numbers and lets them draw their own conclusion.
public enum ChangeDirection: String, Hashable, Sendable, CaseIterable {
    case higher, lower, unchanged

    init(difference: Int) {
        self = difference > 0 ? .higher : (difference < 0 ? .lower : .unchanged)
    }
}

/// One period set beside the one before it.
public struct PeriodComparison: Hashable, Sendable {
    public let current: PeriodAggregate
    public let previous: PeriodAggregate

    init(current: PeriodAggregate, previous: PeriodAggregate) {
        self.current = current
        self.previous = previous
    }

    public func difference(of kind: PottyEventKind) -> Int {
        current.count(of: kind) - previous.count(of: kind)
    }

    public var participationDifference: Int {
        current.participationCount - previous.participationCount
    }

    public var participationDirection: ChangeDirection {
        ChangeDirection(difference: participationDifference)
    }

    public var observedDayDifference: Int {
        current.observedDayCount - previous.observedDayCount
    }
}
