import Foundation
import Testing
@testable import HopPottyCore

@Suite("Scheduling: quiet windows")
struct SchedulingQuietWindowTests {
    typealias F = SchedulingFixtures
    let service = SchedulingFixtures.ny

    // MARK: Boundaries

    @Test("A quiet window includes its start and excludes its end")
    func halfOpenBoundaries() {
        let schedule = F.allDaySchedule(quietWindows: [F.nap])
        #expect(!service.isQuiet(at: F.wednesday(12, 29), in: schedule))
        #expect(service.isQuiet(at: F.wednesday(12, 30), in: schedule))
        #expect(service.isQuiet(at: F.wednesday(14, 29), in: schedule))
        // Half-open, so a pause scheduled exactly at wake-up is not suppressed.
        #expect(!service.isQuiet(at: F.wednesday(14, 30), in: schedule))
    }

    @Test("A disabled window is not quiet")
    func disabledWindowIgnored() {
        let disabled = F.window(1, 12, 30, 14, 30, label: .nap, isEnabled: false)
        let schedule = F.allDaySchedule(quietWindows: [disabled])
        #expect(!service.isQuiet(at: F.wednesday(13, 0), in: schedule))
        #expect(service.activeQuietWindow(at: F.wednesday(13, 0), in: schedule) == nil)
    }

    @Test("No quiet windows means never quiet")
    func noWindows() {
        let schedule = F.allDaySchedule()
        #expect(!service.isQuiet(at: F.wednesday(13, 0), in: schedule))
        #expect(service.quietPeriodEnd(from: F.wednesday(13, 0), in: schedule) == F.wednesday(13, 0))
    }

    // MARK: Midnight wrapping

    @Test("A window that wraps midnight covers both sides of it")
    func wrappingWindow() {
        let schedule = F.allDaySchedule(quietWindows: [F.bedtime])
        #expect(!service.isQuiet(at: F.wednesday(19, 29), in: schedule))
        #expect(service.isQuiet(at: F.wednesday(19, 30), in: schedule))
        #expect(service.isQuiet(at: F.wednesday(23, 59), in: schedule))
        #expect(service.isQuiet(at: F.wednesday(0, 0), in: schedule))
        #expect(service.isQuiet(at: F.wednesday(6, 59), in: schedule))
        #expect(!service.isQuiet(at: F.wednesday(7, 0), in: schedule))
    }

    @Test("A wrapping occurrence spans two calendar days and resumes on the second")
    func wrappingOccurrenceBounds() throws {
        let schedule = F.allDaySchedule(quietWindows: [F.bedtime])
        let quiet = try #require(service.activeQuietWindow(at: F.wednesday(23, 0), in: schedule))
        #expect(quiet.start == F.wednesday(19, 30))
        #expect(quiet.end == F.nyAt(2025, 6, 12, 7, 0))
        #expect(quiet.resumesAt == F.nyAt(2025, 6, 12, 7, 0))
        // The occurrence that covers 03:00 is the one that began the evening before.
        let earlyHours = try #require(service.activeQuietWindow(at: F.nyAt(2025, 6, 12, 3, 0), in: schedule))
        #expect(earlyHours.start == F.wednesday(19, 30))
        #expect(earlyHours.weekdayIsWednesday)
    }

    @Test("Equal start and end means the window covers the whole day")
    func degenerateWindowIsAllDay() {
        let allDay = F.window(9, 8, 0, 8, 0)
        let schedule = F.allDaySchedule(quietWindows: [allDay])
        for hour in 0..<24 {
            #expect(service.isQuiet(at: F.wednesday(hour, 0), in: schedule), "hour \(hour)")
        }
    }

    // MARK: Weekday restriction

    @Test("A weekday-restricted window does not apply at the weekend")
    func weekdayRestriction() {
        let schedule = F.allDaySchedule(quietWindows: [F.school])
        #expect(service.isQuiet(at: F.wednesday(10, 0), in: schedule))
        #expect(service.isQuiet(at: F.friday(10, 0), in: schedule))
        #expect(!service.isQuiet(at: F.saturday(10, 0), in: schedule))
        #expect(!service.isQuiet(at: F.sunday(10, 0), in: schedule))
    }

    @Test("A wrapping window's day membership follows the day it started on")
    func wrappingWindowAnchorsToStartDay() {
        // Friday 22:00 → Saturday 06:00. Ticking "Friday" means Friday night,
        // which is the reading a caregiver has in mind.
        let schedule = F.allDaySchedule(quietWindows: [F.fridayNight])
        #expect(service.isQuiet(at: F.friday(23, 0), in: schedule))
        #expect(service.isQuiet(at: F.saturday(2, 0), in: schedule))
        #expect(service.isQuiet(at: F.saturday(5, 59), in: schedule))
        #expect(!service.isQuiet(at: F.saturday(6, 0), in: schedule))
        // Saturday night belongs to Saturday's (non-existent) occurrence.
        #expect(!service.isQuiet(at: F.saturday(23, 0), in: schedule))
        #expect(!service.isQuiet(at: F.sunday(2, 0), in: schedule))
        // Friday's small hours belong to Thursday's occurrence, which is not set.
        #expect(!service.isQuiet(at: F.friday(2, 0), in: schedule))
    }

    @Test("An empty day set means every day")
    func emptyDaysMeansEveryDay() {
        let schedule = F.allDaySchedule(quietWindows: [F.nap])
        #expect(F.nap.days.isEmpty)
        for day in 11...17 {
            #expect(service.isQuiet(at: F.nyAt(2025, 6, day, 13, 0), in: schedule), "June \(day)")
        }
    }

    // MARK: Overlap precedence

    @Test("Overlapping windows are governed by the one that ends latest")
    func overlapGovernedByLatestEnd() throws {
        // 12:00–13:00 lunch and 12:30–14:30 nap both cover 12:45.
        let schedule = F.allDaySchedule(quietWindows: [F.lunch, F.nap])
        let quiet = try #require(service.activeQuietWindow(at: F.wednesday(12, 45), in: schedule))
        #expect(quiet.window.id == F.nap.id)
        #expect(quiet.overlapping.count == 2)
        #expect(quiet.overlapping.first?.id == F.nap.id)
        #expect(quiet.resumesAt == F.wednesday(14, 30))
    }

    @Test("Precedence does not depend on the order windows were stored in")
    func overlapOrderIndependent() throws {
        let forwards = F.allDaySchedule(quietWindows: [F.lunch, F.nap])
        let backwards = F.allDaySchedule(quietWindows: [F.nap, F.lunch])
        let a = try #require(service.activeQuietWindow(at: F.wednesday(12, 45), in: forwards))
        let b = try #require(service.activeQuietWindow(at: F.wednesday(12, 45), in: backwards))
        #expect(a.window.id == b.window.id)
        #expect(a.resumesAt == b.resumesAt)
    }

    @Test("Quiet resumes at the end of a chain of back-to-back windows")
    func chainedResume() throws {
        let schedule = F.allDaySchedule(quietWindows: [F.lunch, F.nap])
        // At 12:15 only lunch is in force, but nap starts before lunch ends, so
        // quiet does not actually lift until 14:30.
        let quiet = try #require(service.activeQuietWindow(at: F.wednesday(12, 15), in: schedule))
        #expect(quiet.window.id == F.lunch.id)
        #expect(quiet.end == F.wednesday(13, 0))
        #expect(quiet.resumesAt == F.wednesday(14, 30))
    }

    @Test("A gap between windows is not chained over")
    func gapIsNotChained() throws {
        let morning = F.window(10, 12, 0, 13, 0)
        let afternoon = F.window(11, 14, 0, 15, 0)
        let schedule = F.allDaySchedule(quietWindows: [morning, afternoon])
        let quiet = try #require(service.activeQuietWindow(at: F.wednesday(12, 30), in: schedule))
        #expect(quiet.resumesAt == F.wednesday(13, 0))
        #expect(!service.isQuiet(at: F.wednesday(13, 30), in: schedule))
    }

    @Test("Windows with identical bounds tie-break on label, then on id")
    func identicalWindowsTieBreak() throws {
        // Same bounds, different labels: the more protective label is named.
        let custom = F.window(20, 12, 0, 13, 0, label: .custom)
        let bedtime = F.window(21, 12, 0, 13, 0, label: .bedtime)
        let schedule = F.allDaySchedule(quietWindows: [custom, bedtime])
        let quiet = try #require(service.activeQuietWindow(at: F.wednesday(12, 30), in: schedule))
        #expect(quiet.window.label == .bedtime)

        // Same bounds and same label: the id breaks the tie, so the answer is
        // stable rather than dependent on array order.
        let lowID = F.window(30, 12, 0, 13, 0, label: .nap)
        let highID = F.window(31, 12, 0, 13, 0, label: .nap)
        let forwards = F.allDaySchedule(quietWindows: [lowID, highID])
        let backwards = F.allDaySchedule(quietWindows: [highID, lowID])
        let a = try #require(service.activeQuietWindow(at: F.wednesday(12, 30), in: forwards))
        let b = try #require(service.activeQuietWindow(at: F.wednesday(12, 30), in: backwards))
        #expect(a.window.id == lowID.id)
        #expect(b.window.id == lowID.id)
    }

    @Test("A window covering another is preferred over the one it swallows")
    func containingWindowGoverns() throws {
        let outer = F.window(40, 12, 0, 16, 0, label: .custom)
        let inner = F.window(41, 13, 0, 14, 0, label: .nap)
        let schedule = F.allDaySchedule(quietWindows: [inner, outer])
        let quiet = try #require(service.activeQuietWindow(at: F.wednesday(13, 30), in: schedule))
        #expect(quiet.window.id == outer.id)
        #expect(quiet.resumesAt == F.wednesday(16, 0))
    }

    @Test("A wrapping window chains into the next day's window")
    func wrappingChainsIntoNextDay() {
        // Bedtime runs 19:30–07:00 and school starts at 09:00; the two do not
        // touch, so quiet lifts at 07:00, not 15:00.
        let schedule = F.allDaySchedule(quietWindows: [F.bedtime, F.school])
        #expect(service.quietPeriodEnd(from: F.wednesday(23, 0), in: schedule) == F.nyAt(2025, 6, 12, 7, 0))

        // Butt them together and the chain runs through.
        let earlySchool = F.window(50, 7, 0, 15, 0, label: .school)
        let joined = F.allDaySchedule(quietWindows: [F.bedtime, earlySchool])
        #expect(service.quietPeriodEnd(from: F.wednesday(23, 0), in: joined) == F.nyAt(2025, 6, 12, 15, 0))
    }
}

private extension ActiveQuietWindow {
    /// Small readability helper: the occurrence that covers Thursday's small
    /// hours began on Wednesday.
    var weekdayIsWednesday: Bool {
        SchedulingFixtures.ny.weekday(at: start) == .wednesday
    }
}
