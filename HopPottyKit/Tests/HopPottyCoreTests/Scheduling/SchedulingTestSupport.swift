import Foundation
import Testing
@testable import HopPottyCore

/// Shared fixtures for the scheduling suites.
///
/// Everything is namespaced inside this enum on purpose. The test target is one
/// module shared with every other area's tests, so a bare `nap` or `date(...)`
/// at file scope would be a collision waiting to happen.
enum SchedulingFixtures {
    static let childID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    // MARK: Calendars

    static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        // Force-unwrapped: a host without a zone database cannot run these tests
        // meaningfully, and a silent fallback to UTC would turn every DST
        // assertion into a false pass.
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    /// Observes daylight saving.
    static let newYork = calendar("America/New_York")
    /// +05:30 all year, and a half-hour offset — the case that catches arithmetic
    /// written in whole hours.
    static let kolkata = calendar("Asia/Kolkata")

    static let ny = PottyScheduleService(calendar: newYork)
    static let kol = PottyScheduleService(calendar: kolkata)

    // MARK: Instants

    static func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0,
        in calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    /// A wall-clock instant in New York. 2025-06-11 is an ordinary Wednesday well
    /// clear of any transition.
    static func nyAt(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        date(year, month, day, hour, minute, in: newYork)
    }

    static func kolAt(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        date(year, month, day, hour, minute, in: kolkata)
    }

    /// Wednesday 11 June 2025, New York.
    static func wednesday(_ hour: Int, _ minute: Int = 0) -> Date { nyAt(2025, 6, 11, hour, minute) }
    /// Friday 13 June 2025, New York.
    static func friday(_ hour: Int, _ minute: Int = 0) -> Date { nyAt(2025, 6, 13, hour, minute) }
    /// Saturday 14 June 2025, New York.
    static func saturday(_ hour: Int, _ minute: Int = 0) -> Date { nyAt(2025, 6, 14, hour, minute) }
    /// Sunday 15 June 2025, New York.
    static func sunday(_ hour: Int, _ minute: Int = 0) -> Date { nyAt(2025, 6, 15, hour, minute) }

    /// Instants pinned to absolute epoch seconds.
    ///
    /// Written as raw `timeIntervalSince1970` values rather than built from
    /// components because on a DST day the components are exactly what is in
    /// dispute: `02:30` on a spring-forward morning does not name an instant at
    /// all, and `01:30` on a fall-back morning names two. `ZoneDatabaseTests`
    /// checks each of these against the wall clock it is meant to be.
    enum Instant {
        // Sunday 9 March 2025, America/New_York: 02:00 EST jumps to 03:00 EDT.
        static let springMidnight = Date(timeIntervalSince1970: 1_741_496_400) // 00:00 EST
        static let springOne = Date(timeIntervalSince1970: 1_741_500_000)      // 01:00 EST
        static let springOneThirty = Date(timeIntervalSince1970: 1_741_501_800) // 01:30 EST
        static let springThree = Date(timeIntervalSince1970: 1_741_503_600)     // 03:00 EDT
        static let springFour = Date(timeIntervalSince1970: 1_741_507_200)      // 04:00 EDT
        static let springNoonThirty = Date(timeIntervalSince1970: 1_741_537_800) // 12:30 EDT
        static let springTwoThirtyPM = Date(timeIntervalSince1970: 1_741_545_000) // 14:30 EDT
        /// The day before, still EST.
        static let preSpringNoonThirty = Date(timeIntervalSince1970: 1_741_455_000) // 8 Mar 12:30 EST
        /// The day after, EDT.
        static let postSpringNoonThirty = Date(timeIntervalSince1970: 1_741_624_200) // 10 Mar 12:30 EDT

        // Sunday 2 November 2025, America/New_York: 02:00 EDT falls back to 01:00 EST.
        static let fallMidnight = Date(timeIntervalSince1970: 1_762_056_000)   // 00:00 EDT
        static let fallOne = Date(timeIntervalSince1970: 1_762_059_600)        // 01:00 EDT (first)
        static let fallOneThirtyFirst = Date(timeIntervalSince1970: 1_762_061_400)  // 01:30 EDT
        static let fallOneThirtySecond = Date(timeIntervalSince1970: 1_762_065_000) // 01:30 EST
        static let fallTwo = Date(timeIntervalSince1970: 1_762_066_800)        // 02:00 EST
        static let fallThree = Date(timeIntervalSince1970: 1_762_070_400)      // 03:00 EST

        /// 01:30 on 2 November 2025 in Asia/Kolkata — the same wall clock, in a
        /// zone that has no transition to argue about.
        static let kolkataFallOneThirty = Date(timeIntervalSince1970: 1_762_027_200)
    }

    // MARK: Quiet windows

    /// Stable ids so overlap tie-breaks are reproducible.
    static func windowID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "AAAAAAAA-0000-0000-0000-%012d", number))!
    }

    static func window(
        _ number: Int,
        _ startHour: Int, _ startMinute: Int,
        _ endHour: Int, _ endMinute: Int,
        label: QuietWindowLabel = .custom,
        days: Set<Weekday> = [],
        isEnabled: Bool = true
    ) -> QuietWindow {
        QuietWindow(
            id: windowID(number),
            start: LocalTimeOfDay(hour: startHour, minute: startMinute),
            end: LocalTimeOfDay(hour: endHour, minute: endMinute),
            label: label,
            isEnabled: isEnabled,
            days: days
        )
    }

    /// 12:30–14:30, every day.
    static let nap = window(1, 12, 30, 14, 30, label: .nap)
    /// 19:30–07:00, wraps midnight.
    static let bedtime = window(2, 19, 30, 7, 0, label: .bedtime)
    /// 12:00–13:00 — overlaps the front of `nap`.
    static let lunch = window(3, 12, 0, 13, 0, label: .mealtime)
    /// 22:00–06:00 on Fridays only.
    static let fridayNight = window(4, 22, 0, 6, 0, label: .bedtime, days: [.friday])
    /// 01:00–03:00 — straddles both US transitions.
    static let smallHours = window(5, 1, 0, 3, 0, label: .bedtime)
    /// 09:00–15:00 on weekdays.
    static let school = window(6, 9, 0, 15, 0, label: .school, days: Weekday.weekdays)

    // MARK: Schedules

    static let dayStart = LocalTimeOfDay(hour: 7, minute: 0)
    static let dayEnd = LocalTimeOfDay(hour: 19, minute: 30)
    static let midnight = LocalTimeOfDay(hour: 0, minute: 0)

    static func schedule(
        mode: PottyPauseMode = .pause,
        basis: PottyTriggerBasis = .screenActivity,
        interval: PottyInterval = .minutes45,
        warningOffset: TimeInterval = 120,
        pauseDuration: TimeInterval = 180,
        cooldown: TimeInterval = 300,
        quietWindows: [QuietWindow] = [],
        days: Set<Weekday> = Weekday.everyDay,
        start: LocalTimeOfDay = dayStart,
        end: LocalTimeOfDay = dayEnd,
        isEnabled: Bool = true,
        suspension: ScheduleSuspension = .none
    ) -> PottySchedule {
        PottySchedule(
            childID: childID,
            mode: mode,
            triggerBasis: basis,
            interval: interval,
            warningOffset: warningOffset,
            pauseDuration: pauseDuration,
            cooldown: cooldown,
            quietWindows: quietWindows,
            activeDays: days,
            activeWindowStart: start,
            activeWindowEnd: end,
            isEnabled: isEnabled,
            suspension: suspension
        )
    }

    /// A schedule whose active window is the whole day, so a test can isolate one
    /// rule instead of tripping over the 07:00–19:30 default.
    static func allDaySchedule(
        basis: PottyTriggerBasis = .screenActivity,
        interval: PottyInterval = .minutes45,
        quietWindows: [QuietWindow] = [],
        days: Set<Weekday> = Weekday.everyDay,
        cooldown: TimeInterval = 300,
        suspension: ScheduleSuspension = .none
    ) -> PottySchedule {
        schedule(
            basis: basis,
            interval: interval,
            cooldown: cooldown,
            quietWindows: quietWindows,
            days: days,
            start: midnight,
            end: midnight,
            suspension: suspension
        )
    }
}

// MARK: - Assertion helpers

extension PauseBlockReason {
    /// Case identity without the associated values, so a test can assert "it was
    /// the quiet window" without restating the resume instant.
    var testTag: String {
        switch self {
        case .scheduleDisabled: "scheduleDisabled"
        case .suspendedIndefinitely: "suspendedIndefinitely"
        case .suspendedUntil: "suspendedUntil"
        case .suspendedUntilTomorrow: "suspendedUntilTomorrow"
        case .inactiveDay: "inactiveDay"
        case .outsideActiveWindow: "outsideActiveWindow"
        case .quietWindow: "quietWindow"
        case .cooldown: "cooldown"
        case .skippingNextPause: "skippingNextPause"
        }
    }
}
