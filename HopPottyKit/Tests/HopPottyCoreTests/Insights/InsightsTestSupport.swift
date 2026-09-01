import Foundation
@testable import HopPottyCore

/// Fixed clock and event builders shared by the insights suites.
///
/// Every date in these tests is built through here, against an explicit
/// calendar and an explicit time zone. Nothing reads the machine's locale, so
/// a suite that passes in London passes in Auckland and passes on CI.
enum InsightsFixture {

    /// A zone with a daylight-saving transition inside the test month, so the
    /// day- and week-boundary tests exercise a real one rather than a
    /// convenient fixed offset.
    static let timeZone = TimeZone(identifier: "America/New_York")!

    /// Sunday-first, matching `Weekday`'s numbering.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 1
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// Monday-first, for the week-boundary test that proves the engine honours
    /// the caller's calendar rather than assuming Sunday.
    static var mondayFirstCalendar: Calendar {
        var calendar = self.calendar
        calendar.firstWeekday = 2
        return calendar
    }

    static let childID = UUID(uuidString: "C0FFEE00-0000-4000-8000-000000000001")!
    static let siblingID = UUID(uuidString: "C0FFEE00-0000-4000-8000-000000000002")!

    /// 2025-03-12 is a Wednesday; the week containing it starts Sunday the 9th,
    /// which is also the day the local clocks go forward.
    static let wednesdayEvening = date(2025, 3, 12, 18, 0)

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        guard let resolved = calendar.date(from: components) else {
            fatalError("Fixture date \(year)-\(month)-\(day) \(hour):\(minute) does not exist")
        }
        return resolved
    }

    static func event(
        at timestamp: Date,
        kind: PottyEventKind = .tried,
        source: PottyEventSource = .childRoutine,
        childID: UUID = InsightsFixture.childID
    ) -> PottyEvent {
        PottyEvent(childID: childID, timestamp: timestamp, kind: kind, source: source)
    }

    /// Visits starting at `start`, separated by `gaps` minutes cycled in order.
    static func series(
        from start: Date,
        gaps: [Int],
        count: Int,
        kind: PottyEventKind = .tried,
        source: PottyEventSource = .childRoutine,
        childID: UUID = InsightsFixture.childID
    ) -> [PottyEvent] {
        guard count > 0 else { return [] }
        var events = [event(at: start, kind: kind, source: source, childID: childID)]
        var cursor = start
        for index in 0..<(count - 1) {
            cursor = cursor.addingTimeInterval(TimeInterval(gaps[index % gaps.count] * 60))
            events.append(event(at: cursor, kind: kind, source: source, childID: childID))
        }
        return events
    }

    /// Exactly `gapCount` same-day gaps, spread over as many days as needed.
    ///
    /// Built from the threshold rather than from a hard-coded number so the
    /// boundary tests keep testing the boundary if a threshold is ever revised.
    static func sameDayGaps(
        _ gapCount: Int,
        gaps: [Int] = [45, 50, 55],
        endingOn lastDay: Int = 12,
        source: PottyEventSource = .childRoutine
    ) -> [PottyEvent] {
        let perDay = 8
        let dayCount = max(1, Int((Double(gapCount) / Double(perDay)).rounded(.up)))
        var remaining = gapCount
        var events: [PottyEvent] = []
        for offset in 0..<dayCount where remaining > 0 {
            let day = lastDay - (dayCount - 1 - offset)
            let take = min(remaining, perDay)
            events += series(from: date(2025, 3, day, 7, 0), gaps: gaps, count: take + 1, source: source)
            remaining -= take
        }
        return events
    }
}
