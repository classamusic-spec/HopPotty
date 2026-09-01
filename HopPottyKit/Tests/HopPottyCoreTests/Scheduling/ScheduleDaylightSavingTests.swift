import Foundation
import Testing
@testable import HopPottyCore

/// The cases that make this engine worth having.
///
/// A scheduling bug that only appears at 01:30 on the first Sunday in November
/// is a bug nobody can reproduce on request, so every one of them is pinned to an
/// absolute epoch second here.
@Suite("Scheduling: daylight saving and travel")
struct SchedulingDaylightSavingTests {
    typealias F = SchedulingFixtures
    let ny = SchedulingFixtures.ny
    let kol = SchedulingFixtures.kol

    // MARK: The instants themselves

    @Test("The pinned instants are the wall clocks they claim to be")
    func zoneDatabasePins() {
        let eastern: [(Date, Int, Int, Int, Int)] = [
            // instant, day, hour, minute, offset seconds
            (F.Instant.springMidnight, 9, 0, 0, -18_000),
            (F.Instant.springOne, 9, 1, 0, -18_000),
            (F.Instant.springOneThirty, 9, 1, 30, -18_000),
            (F.Instant.springThree, 9, 3, 0, -14_400),
            (F.Instant.springFour, 9, 4, 0, -14_400),
            (F.Instant.springNoonThirty, 9, 12, 30, -14_400),
            (F.Instant.springTwoThirtyPM, 9, 14, 30, -14_400),
            (F.Instant.preSpringNoonThirty, 8, 12, 30, -18_000),
            (F.Instant.postSpringNoonThirty, 10, 12, 30, -14_400),
            (F.Instant.fallMidnight, 2, 0, 0, -14_400),
            (F.Instant.fallOne, 2, 1, 0, -14_400),
            (F.Instant.fallOneThirtyFirst, 2, 1, 30, -14_400),
            (F.Instant.fallOneThirtySecond, 2, 1, 30, -18_000),
            (F.Instant.fallTwo, 2, 2, 0, -18_000),
            (F.Instant.fallThree, 2, 3, 0, -18_000),
        ]
        for (instant, day, hour, minute, offset) in eastern {
            #expect(F.newYork.component(.day, from: instant) == day)
            #expect(ny.localTime(at: instant) == LocalTimeOfDay(hour: hour, minute: minute))
            #expect(F.newYork.timeZone.secondsFromGMT(for: instant) == offset)
        }
        #expect(kol.localTime(at: F.Instant.kolkataFallOneThirty) == LocalTimeOfDay(hour: 1, minute: 30))
        #expect(F.kolkata.timeZone.secondsFromGMT(for: F.Instant.kolkataFallOneThirty) == 19_800)
        // The two 01:30s on the fall-back morning are an hour of real time apart
        // and both read 01:30 on the wall.
        #expect(F.Instant.fallOneThirtySecond.timeIntervalSince(F.Instant.fallOneThirtyFirst) == TimeInterval(3600))
    }

    // MARK: Spring forward — 02:00 does not exist

    @Test("A 01:00–03:00 quiet window survives the hour that does not exist")
    func springForwardQuietWindow() throws {
        let schedule = F.allDaySchedule(quietWindows: [F.smallHours])
        #expect(ny.isQuiet(at: F.Instant.springOne, in: schedule))
        #expect(ny.isQuiet(at: F.Instant.springOneThirty, in: schedule))
        // 03:00 is the exclusive end, and on this day it is the very next instant
        // after 01:59:59.
        #expect(!ny.isQuiet(at: F.Instant.springThree, in: schedule))
        #expect(!ny.isQuiet(at: F.Instant.springFour, in: schedule))

        let quiet = try #require(ny.activeQuietWindow(at: F.Instant.springOneThirty, in: schedule))
        #expect(quiet.start == F.Instant.springOne)
        #expect(quiet.end == F.Instant.springThree)
        // Two wall-clock hours, one real hour. The wall clock is what the family
        // set, so the wall clock is what wins.
        #expect(quiet.duration == TimeInterval(3600))
    }

    @Test("The same window is two real hours on an ordinary day")
    func ordinaryDayComparison() throws {
        let schedule = F.allDaySchedule(quietWindows: [F.smallHours])
        let quiet = try #require(ny.activeQuietWindow(at: F.nyAt(2025, 3, 12, 1, 30), in: schedule))
        #expect(quiet.duration == TimeInterval(7200))
    }

    @Test("No instant on a spring-forward morning reads 02:xx")
    func skippedHourHasNoInstants() {
        // Foundation resolves a nonexistent wall-clock time forward, so a naive
        // boundary comparison would place a 02:30 event at 03:30. The engine tests
        // membership on the instant's own wall clock instead, which is why the gap
        // simply contains nothing.
        let resolved = F.newYork.resolving(LocalTimeOfDay(hour: 2, minute: 30), on: F.Instant.springMidnight)
        #expect(resolved != nil)
        #expect(ny.localTime(at: resolved!) == LocalTimeOfDay(hour: 3, minute: 30))

        var instant = F.Instant.springOne
        while instant < F.Instant.springFour {
            #expect(ny.localTime(at: instant).hour != 2, "no instant may read 02:xx")
            instant = instant.addingTimeInterval(60)
        }
    }

    @Test("A clock cadence skips the slot that does not exist and does not double up")
    func springForwardClockGrid() {
        let schedule = F.allDaySchedule(basis: .clockTime, interval: .minutes60, cooldown: 0)
        var starts: [Date] = []
        var cursor = F.Instant.springMidnight
        for _ in 0..<5 {
            guard let pause = ny.nextPause(after: ScheduleState(
                schedule: schedule, now: cursor, lastPauseEnd: cursor.addingTimeInterval(-1)
            )) else { break }
            starts.append(pause.start)
            cursor = pause.start.addingTimeInterval(60)
        }
        #expect(starts == [
            F.Instant.springMidnight,
            F.Instant.springOne,
            // 02:00 is skipped: it does not exist, and resolving it forward would
            // fire the same pause twice at 03:00.
            F.Instant.springThree,
            F.Instant.springFour,
            F.nyAt(2025, 3, 9, 5, 0),
        ])
    }

    @Test("Screen activity is measured in real seconds, not wall-clock ones")
    func springForwardActivityInterval() throws {
        // 45 minutes of use starting at 01:30 EST ends at 03:15 EDT: the clock
        // jumped an hour mid-session, the child's screen time did not.
        let schedule = F.allDaySchedule()
        let state = ScheduleState(schedule: schedule, now: F.Instant.springOneThirty)
        let pause = try #require(ny.nextPause(after: state))
        #expect(pause.start == F.Instant.springOneThirty.addingTimeInterval(TimeInterval(45 * 60)))
        #expect(ny.localTime(at: pause.start) == LocalTimeOfDay(hour: 3, minute: 15))
        // On an ordinary day the same 45 minutes lands on 02:15.
        let ordinary = ScheduleState(schedule: schedule, now: F.nyAt(2025, 3, 12, 1, 30))
        #expect(ny.localTime(at: try #require(ny.nextPause(after: ordinary)).start)
            == LocalTimeOfDay(hour: 2, minute: 15))
    }

    // MARK: Fall back — 01:30 happens twice

    @Test("Both occurrences of a repeated 01:30 are quiet")
    func fallBackQuietWindow() throws {
        let schedule = F.allDaySchedule(quietWindows: [F.smallHours])
        #expect(ny.isQuiet(at: F.Instant.fallOneThirtyFirst, in: schedule))
        #expect(ny.isQuiet(at: F.Instant.fallOneThirtySecond, in: schedule))
        #expect(ny.isQuiet(at: F.Instant.fallTwo, in: schedule))
        #expect(!ny.isQuiet(at: F.Instant.fallThree, in: schedule))

        let quiet = try #require(ny.activeQuietWindow(at: F.Instant.fallOneThirtyFirst, in: schedule))
        #expect(quiet.start == F.Instant.fallOne)
        #expect(quiet.end == F.Instant.fallThree)
        // Two wall-clock hours, three real ones.
        #expect(quiet.duration == TimeInterval(3 * 3600))
        // Resolved from the second 01:30, the window is the same occurrence.
        let second = try #require(ny.activeQuietWindow(at: F.Instant.fallOneThirtySecond, in: schedule))
        #expect(second.start == quiet.start)
        #expect(second.resumesAt == F.Instant.fallThree)
    }

    @Test("A clock cadence fires once in the repeated hour, not twice")
    func fallBackClockGrid() {
        let schedule = F.allDaySchedule(basis: .clockTime, interval: .minutes60, cooldown: 0)
        var starts: [Date] = []
        var cursor = F.Instant.fallMidnight
        for _ in 0..<4 {
            guard let pause = ny.nextPause(after: ScheduleState(
                schedule: schedule, now: cursor, lastPauseEnd: cursor.addingTimeInterval(-1)
            )) else { break }
            starts.append(pause.start)
            cursor = pause.start.addingTimeInterval(60)
        }
        // 01:00 fires once — on the first pass. The repeated hour does not earn
        // the child a second interruption.
        #expect(starts == [F.Instant.fallMidnight, F.Instant.fallOne, F.Instant.fallTwo, F.Instant.fallThree])
        #expect(!starts.contains(F.Instant.fallOneThirtySecond))
    }

    @Test("An activity interval that lands in the repeated hour is still deferred")
    func fallBackActivityLandsInRepeatedHour() throws {
        // 45 minutes from 01:30 EDT lands at 01:15 EST — the wall clock has gone
        // backwards, and 01:15 is inside the quiet window, so the pause waits for
        // 03:00.
        let schedule = F.allDaySchedule(quietWindows: [F.smallHours])
        let state = ScheduleState(schedule: schedule, now: F.Instant.fallOneThirtyFirst)
        let pause = try #require(ny.nextPause(after: state))
        #expect(ny.localTime(at: pause.earliestPossible) == LocalTimeOfDay(hour: 1, minute: 15))
        #expect(pause.start == F.Instant.fallThree)
        #expect(pause.deferredBy?.quietWindow?.id == F.smallHours.id)
    }

    @Test("A whole-day window is 23 hours in spring and 25 in autumn")
    func windowDurationsFollowTheDay() throws {
        let schedule = F.allDaySchedule()
        let spring = try #require(ny.activeWindowOccurrence(at: F.Instant.springNoonThirty, in: schedule))
        #expect(spring.duration == TimeInterval(23 * 3600))
        let fall = try #require(ny.activeWindowOccurrence(at: F.nyAt(2025, 11, 2, 12, 30), in: schedule))
        #expect(fall.duration == TimeInterval(25 * 3600))
        // The wall-clock bounds are identical on both days regardless.
        #expect(ny.localTime(at: spring.start) == LocalTimeOfDay(hour: 0, minute: 0))
        #expect(ny.localTime(at: fall.start) == LocalTimeOfDay(hour: 0, minute: 0))
    }

    // MARK: Wall-clock times stay put

    @Test("A 12:30 nap is 12:30 on both sides of a transition")
    func napStaysAtHalfPastTwelve() throws {
        let schedule = F.allDaySchedule(quietWindows: [F.nap])
        let days: [Date] = [
            F.Instant.preSpringNoonThirty,
            F.Instant.springNoonThirty,
            F.Instant.postSpringNoonThirty,
            F.nyAt(2025, 11, 1, 12, 30),
            F.nyAt(2025, 11, 2, 12, 30),
            F.nyAt(2025, 11, 3, 12, 30),
        ]
        for instant in days {
            let quiet = try #require(ny.activeQuietWindow(at: instant, in: schedule), "\(instant)")
            #expect(ny.localTime(at: quiet.start) == LocalTimeOfDay(hour: 12, minute: 30))
            #expect(ny.localTime(at: quiet.end) == LocalTimeOfDay(hour: 14, minute: 30))
            // Away from the transition itself the nap is a plain two hours.
            #expect(quiet.duration == TimeInterval(7200))
        }
        #expect(ny.isQuiet(at: F.Instant.springNoonThirty, in: schedule))
        #expect(!ny.isQuiet(at: F.Instant.springTwoThirtyPM, in: schedule))
    }

    @Test("The active window keeps its wall-clock bounds across a transition")
    func activeWindowStaysPut() throws {
        let schedule = F.schedule()
        for instant in [F.Instant.preSpringNoonThirty, F.Instant.springNoonThirty, F.Instant.postSpringNoonThirty] {
            let occurrence = try #require(ny.activeWindowOccurrence(at: instant, in: schedule))
            #expect(ny.localTime(at: occurrence.start) == LocalTimeOfDay(hour: 7, minute: 0))
            #expect(ny.localTime(at: occurrence.end) == LocalTimeOfDay(hour: 19, minute: 30))
        }
    }

    @Test("Cooldown is real seconds, so it does not stretch when the clocks change")
    func cooldownIsRealTime() {
        let schedule = F.allDaySchedule(cooldown: 600)
        // A pause that ended at 01:55 EST is still in cooldown at 03:00 EDT,
        // because only five real minutes have passed.
        let lastPauseEnd = F.Instant.springOneThirty.addingTimeInterval(TimeInterval(25 * 60))
        let decision = ny.canStartPause(at: F.Instant.springThree, in: schedule, lastPauseEnd: lastPauseEnd)
        #expect(decision.reason == .cooldown(until: lastPauseEnd.addingTimeInterval(TimeInterval(600))))
        #expect(ny.canStartPause(
            at: lastPauseEnd.addingTimeInterval(TimeInterval(600)), in: schedule, lastPauseEnd: lastPauseEnd
        ).isAllowed)
    }

    // MARK: A zone with no transitions and a half-hour offset

    @Test("Kolkata applies the same wall-clock rules with no transition to argue about")
    func kolkataQuietWindow() throws {
        let schedule = F.allDaySchedule(quietWindows: [F.smallHours])
        #expect(kol.isQuiet(at: F.Instant.kolkataFallOneThirty, in: schedule))
        let quiet = try #require(kol.activeQuietWindow(at: F.Instant.kolkataFallOneThirty, in: schedule))
        #expect(kol.localTime(at: quiet.start) == LocalTimeOfDay(hour: 1, minute: 0))
        #expect(quiet.duration == TimeInterval(7200))
        // Same wall clock on the US transition days, because +05:30 never moves.
        for day in 1...3 {
            let instant = F.kolAt(2025, 11, day, 1, 30)
            #expect(kol.isQuiet(at: instant, in: schedule), "November \(day)")
        }
        for day in 8...10 {
            let instant = F.kolAt(2025, 3, day, 1, 30)
            #expect(kol.isQuiet(at: instant, in: schedule), "March \(day)")
        }
    }

    @Test("A half-hour offset does not shift a cadence off the half hour")
    func kolkataClockGrid() throws {
        let schedule = F.schedule(
            basis: .clockTime,
            interval: .minutes30,
            start: LocalTimeOfDay(hour: 7, minute: 0),
            end: LocalTimeOfDay(hour: 19, minute: 30)
        )
        let pause = try #require(kol.nextPause(after: ScheduleState(schedule: schedule, now: F.kolAt(2025, 6, 11, 9, 10))))
        #expect(pause.start == F.kolAt(2025, 6, 11, 9, 30))
        #expect(kol.localTime(at: pause.start) == LocalTimeOfDay(hour: 9, minute: 30))
    }

    // MARK: Travel

    @Test("Quiet hours follow the new wall clock when a family travels")
    func quietHoursFollowTheWallClock() {
        // One instant, two zones. 13:00 in New York is 22:30 in Kolkata, so the
        // nap window catches it in one place and not the other.
        let schedule = F.allDaySchedule(quietWindows: [F.nap])
        let instant = F.nyAt(2025, 6, 11, 13, 0)
        #expect(ny.localTime(at: instant) == LocalTimeOfDay(hour: 13, minute: 0))
        #expect(kol.localTime(at: instant) == LocalTimeOfDay(hour: 22, minute: 30))
        #expect(ny.isQuiet(at: instant, in: schedule))
        #expect(!kol.isQuiet(at: instant, in: schedule))

        // And the reverse: 03:00 in New York is 12:30 in Kolkata, squarely in the
        // nap the family kept when they landed.
        let morning = F.nyAt(2025, 6, 11, 3, 0)
        #expect(!ny.isQuiet(at: morning, in: schedule))
        #expect(kol.isQuiet(at: morning, in: schedule))
    }

    @Test("The active window and the day both follow the new zone")
    func activeWindowFollowsTravel() {
        let schedule = F.schedule(days: [.wednesday])
        // 21:00 Wednesday in New York is already 06:30 Thursday in Kolkata: past
        // the window, and on a day the schedule does not run.
        let instant = F.nyAt(2025, 6, 11, 21, 0)
        #expect(!ny.isWithinActiveWindow(at: instant, in: schedule))
        #expect(ny.isActiveDay(at: instant, in: schedule))
        #expect(!kol.isWithinActiveWindow(at: instant, in: schedule))
        #expect(!kol.isActiveDay(at: instant, in: schedule))
        #expect(kol.governingWeekday(at: instant, in: schedule) == .thursday)
        #expect(ny.canStartPause(at: instant, in: schedule).reason?.testTag == "outsideActiveWindow")
        #expect(kol.canStartPause(at: instant, in: schedule).reason == .inactiveDay(.thursday))
    }

    @Test("A pause projected mid-flight is recomputed against the new zone")
    func projectionFollowsTravel() throws {
        // Midday in New York with five minutes of use banked, so the interval
        // comes due at 12:40 — inside the nap the family kept when they flew.
        let schedule = F.allDaySchedule(quietWindows: [F.nap])
        let now = F.nyAt(2025, 6, 11, 12, 0)
        let state = ScheduleState(schedule: schedule, now: now, accumulatedActivity: TimeInterval(5 * 60))

        let atHome = try #require(ny.nextPause(after: state))
        #expect(atHome.earliestPossible == F.nyAt(2025, 6, 11, 12, 40))
        #expect(atHome.start == F.nyAt(2025, 6, 11, 14, 30))
        #expect(atHome.deferredBy?.quietWindow?.id == F.nap.id)

        // The same instants read 21:30 and 22:10 in Kolkata: nowhere near a nap,
        // so the pause happens the moment the interval comes due.
        let away = try #require(kol.nextPause(after: state))
        #expect(kol.localTime(at: away.start) == LocalTimeOfDay(hour: 22, minute: 10))
        #expect(away.start == now.addingTimeInterval(TimeInterval(40 * 60)))
        #expect(away.deferredBy == nil)
    }
}
