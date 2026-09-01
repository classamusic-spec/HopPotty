import Foundation
import Testing
@testable import HopPottyCore

@Suite("Scheduling: active window and active days")
struct SchedulingActiveWindowTests {
    typealias F = SchedulingFixtures
    let service = SchedulingFixtures.ny

    @Test("The active window includes its start and excludes its end")
    func boundaries() {
        let schedule = F.schedule()
        #expect(!service.isWithinActiveWindow(at: F.wednesday(6, 59), in: schedule))
        #expect(service.isWithinActiveWindow(at: F.wednesday(7, 0), in: schedule))
        #expect(service.isWithinActiveWindow(at: F.wednesday(19, 29), in: schedule))
        #expect(!service.isWithinActiveWindow(at: F.wednesday(19, 30), in: schedule))
    }

    @Test("An active window can wrap midnight")
    func wrappingActiveWindow() throws {
        let schedule = F.schedule(
            start: LocalTimeOfDay(hour: 20, minute: 0),
            end: LocalTimeOfDay(hour: 6, minute: 0)
        )
        #expect(service.isWithinActiveWindow(at: F.wednesday(20, 0), in: schedule))
        #expect(service.isWithinActiveWindow(at: F.wednesday(23, 59), in: schedule))
        #expect(service.isWithinActiveWindow(at: F.nyAt(2025, 6, 12, 5, 59), in: schedule))
        #expect(!service.isWithinActiveWindow(at: F.nyAt(2025, 6, 12, 6, 0), in: schedule))
        #expect(!service.isWithinActiveWindow(at: F.wednesday(12, 0), in: schedule))

        let occurrence = try #require(
            service.activeWindowOccurrence(at: F.nyAt(2025, 6, 12, 5, 0), in: schedule)
        )
        #expect(occurrence.start == F.wednesday(20, 0))
        #expect(occurrence.end == F.nyAt(2025, 6, 12, 6, 0))
        // Thursday 05:00 sits in the occurrence that began on Wednesday.
        #expect(occurrence.weekday == .wednesday)
    }

    @Test("Equal window bounds mean the whole day")
    func wholeDayWindow() {
        let schedule = F.allDaySchedule()
        for hour in 0..<24 {
            #expect(service.isWithinActiveWindow(at: F.wednesday(hour, 0), in: schedule), "hour \(hour)")
        }
    }

    @Test("Active-day membership follows the day the window occurrence began")
    func dayMembershipFollowsOccurrenceStart() {
        // Wednesday-only schedule with a window running 20:00 → 06:00.
        let schedule = F.schedule(
            days: [.wednesday],
            start: LocalTimeOfDay(hour: 20, minute: 0),
            end: LocalTimeOfDay(hour: 6, minute: 0)
        )
        #expect(service.isActiveDay(at: F.wednesday(21, 0), in: schedule))
        // Thursday 02:00 is still Wednesday's evening as far as the caregiver is
        // concerned.
        #expect(service.isActiveDay(at: F.nyAt(2025, 6, 12, 2, 0), in: schedule))
        #expect(service.governingWeekday(at: F.nyAt(2025, 6, 12, 2, 0), in: schedule) == .wednesday)
        // Outside any occurrence it falls back to the instant's own weekday.
        #expect(service.governingWeekday(at: F.nyAt(2025, 6, 12, 12, 0), in: schedule) == .thursday)
        #expect(!service.isActiveDay(at: F.nyAt(2025, 6, 12, 12, 0), in: schedule))
    }

    @Test("An empty activeDays set means every day")
    func emptyActiveDaysMeansEveryDay() {
        // The initialiser normalises an empty set, but Codable bypasses it, so a
        // decoded schedule can still arrive empty. Mutating the property models
        // exactly that.
        var schedule = F.schedule()
        schedule.activeDays = []
        for day in 11...17 {
            #expect(service.isActiveDay(at: F.nyAt(2025, 6, day, 12, 0), in: schedule), "June \(day)")
        }
        #expect(service.canStartPause(at: F.wednesday(13, 0), in: schedule).isAllowed)
    }

    @Test("The next window start skips days the schedule does not run on")
    func nextStartSkipsInactiveDays() throws {
        let schedule = F.schedule(days: [.saturday])
        let next = try #require(service.nextActiveWindowStart(after: F.wednesday(12, 0), in: schedule))
        #expect(next == F.saturday(7, 0))
    }

    @Test("The next window start is today when the day has not begun yet")
    func nextStartIsToday() throws {
        let schedule = F.schedule()
        let next = try #require(service.nextActiveWindowStart(after: F.wednesday(5, 0), in: schedule))
        #expect(next == F.wednesday(7, 0))
    }

    @Test("The next window start is tomorrow once today's window has opened")
    func nextStartIsTomorrow() throws {
        let schedule = F.schedule()
        let next = try #require(service.nextActiveWindowStart(after: F.wednesday(9, 0), in: schedule))
        #expect(next == F.nyAt(2025, 6, 12, 7, 0))
    }

    @Test("A single active day is still found, a week out if need be")
    func singleActiveDayWithinHorizon() {
        var schedule = F.schedule()
        schedule.activeDays = [.monday]
        #expect(service.nextActiveWindowStart(after: F.wednesday(9, 0), in: schedule) == F.nyAt(2025, 6, 16, 7, 0))
    }
}
