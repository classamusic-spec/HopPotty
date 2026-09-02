import Foundation
import Testing
@testable import HopPottyCore

/// Fixtures for the widget suites.
///
/// Namespaced in an enum for the same reason `SchedulingFixtures` is: the test
/// target is one module shared with every other area, and a bare `now` at file
/// scope would collide sooner or later.
enum WidgetFixtures {

    /// An arbitrary fixed instant. Nothing in the widget layer reads a calendar,
    /// so this needs no time zone to be meaningful — only to be stable.
    static let now = Date(timeIntervalSince1970: 1_760_000_000)

    static func at(_ minutes: Double) -> Date {
        now.addingTimeInterval(minutes * 60)
    }

    static func projection(
        start: Date,
        duration: TimeInterval = 180,
        willBeSkipped: Bool = false,
        deferredBy: PauseBlockReason? = nil
    ) -> PauseProjection {
        PauseProjection(
            start: start,
            end: start.addingTimeInterval(duration),
            basis: .clockTime,
            warning: start.addingTimeInterval(-120),
            earliestPossible: start,
            deferredBy: deferredBy,
            willBeSkipped: willBeSkipped
        )
    }

    static func reminder(
        fireAt: Date,
        createdAt: Date = WidgetFixtures.now,
        state: QuickReminderState = .pending
    ) -> QuickReminder {
        QuickReminder(fireAt: fireAt, createdAt: createdAt, state: state)
    }

    /// The gaps between consecutive entries, in seconds. What most of the
    /// timeline assertions are really about.
    static func gaps(_ dates: [Date]) -> [TimeInterval] {
        guard dates.count > 1 else { return [] }
        return zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) }
    }
}
