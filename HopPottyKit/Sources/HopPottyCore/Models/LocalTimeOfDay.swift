import Foundation

/// A wall-clock time of day, with no date and no time zone attached.
///
/// Quiet hours, bedtime and nap windows are stored this way on purpose. "Naps
/// start at 12:30" means 12:30 on the wall clock in whatever zone the family is
/// in today — not a fixed instant. Storing an absolute `Date` would silently
/// shift every window by an hour on a daylight-saving boundary and by the whole
/// offset when a family travels.
public struct LocalTimeOfDay: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    /// 0...23.
    public let hour: Int
    /// 0...59.
    public let minute: Int

    public init(hour: Int, minute: Int) {
        // Normalise rather than trap: a corrupted persisted value should degrade
        // to a sane time, not crash a parenting app on launch.
        let total = ((hour * 60 + minute) % (24 * 60) + (24 * 60)) % (24 * 60)
        self.hour = total / 60
        self.minute = total % 60
    }

    /// Minutes elapsed since midnight, 0..<1440.
    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public init(minutesSinceMidnight: Int) {
        self.init(hour: 0, minute: minutesSinceMidnight)
    }

    public static func < (lhs: LocalTimeOfDay, rhs: LocalTimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    public var description: String { String(format: "%02d:%02d", hour, minute) }

    public static let midnight = LocalTimeOfDay(hour: 0, minute: 0)
    public static let endOfDay = LocalTimeOfDay(hour: 23, minute: 59)
}

public extension Calendar {
    /// Resolves a wall-clock time against a specific day.
    ///
    /// Returns `nil` only when the time does not exist on that day — the hour
    /// skipped by a spring-forward transition. Callers decide what that means;
    /// treating a nonexistent quiet-hour boundary as "the window has started" is
    /// the safe reading, since it errs toward *not* interrupting a child.
    func resolving(_ time: LocalTimeOfDay, on day: Date) -> Date? {
        var components = dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        return date(from: components)
    }
}
