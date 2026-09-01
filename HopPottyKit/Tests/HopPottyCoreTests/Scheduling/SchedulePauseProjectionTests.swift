import Foundation
import Testing
@testable import HopPottyCore

@Suite("Scheduling: next pause on screen activity")
struct SchedulingScreenActivityPauseTests {
    typealias F = SchedulingFixtures
    let service = SchedulingFixtures.ny

    @Test("With no activity banked, the pause is a full interval away")
    func fullInterval() throws {
        let state = ScheduleState(schedule: F.schedule(), now: F.wednesday(9, 0))
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.wednesday(9, 45))
        #expect(pause.earliestPossible == F.wednesday(9, 45))
        #expect(pause.basis == .screenActivity)
        #expect(pause.deferredBy == nil)
        #expect(!pause.wasDeferred)
    }

    @Test("Banked activity brings the pause forward")
    func partialActivity() throws {
        let state = ScheduleState(
            schedule: F.schedule(),
            now: F.wednesday(9, 0),
            accumulatedActivity: TimeInterval(30 * 60)
        )
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.wednesday(9, 15))
    }

    @Test("An interval already met means the pause is due now")
    func alreadyDue() throws {
        let state = ScheduleState(
            schedule: F.schedule(),
            now: F.wednesday(9, 0),
            accumulatedActivity: TimeInterval(60 * 60)
        )
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.wednesday(9, 0))
        #expect(pause.earliestPossible == F.wednesday(9, 0))
    }

    @Test("Activity is measured in real seconds, so a projection never goes backwards")
    func negativeRemainingIsClamped() throws {
        let state = ScheduleState(
            schedule: F.schedule(),
            now: F.wednesday(9, 0),
            accumulatedActivity: TimeInterval(10 * 60 * 60)
        )
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.wednesday(9, 0))
    }

    @Test("A pause owed during a nap lands the moment the nap ends")
    func deferredByQuietWindow() throws {
        // Due at 12:40, which is inside the 12:30–14:30 nap.
        let state = ScheduleState(
            schedule: F.schedule(quietWindows: [F.nap]),
            now: F.wednesday(12, 0),
            accumulatedActivity: TimeInterval(5 * 60)
        )
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.earliestPossible == F.wednesday(12, 40))
        #expect(pause.start == F.wednesday(14, 30))
        #expect(pause.wasDeferred)
        #expect(pause.deferredBy?.quietWindow?.id == F.nap.id)
    }

    @Test("A pause owed after the window closes waits for the next morning")
    func deferredPastWindowEnd() throws {
        let state = ScheduleState(schedule: F.schedule(), now: F.wednesday(19, 0))
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.earliestPossible == F.wednesday(19, 45))
        #expect(pause.start == F.nyAt(2025, 6, 12, 7, 0))
        #expect(pause.deferredBy?.testTag == "outsideActiveWindow")
    }

    @Test("A pause owed on a day off waits for the next active day")
    func deferredPastInactiveDay() throws {
        let state = ScheduleState(schedule: F.schedule(days: [.saturday]), now: F.wednesday(9, 0))
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.saturday(7, 0))
        #expect(pause.deferredBy == .inactiveDay(.wednesday))
    }

    @Test("Cooldown pushes an overdue pause out, and says so")
    func cooldownFloor() throws {
        let state = ScheduleState(
            schedule: F.schedule(),
            now: F.wednesday(9, 0),
            lastPauseEnd: F.wednesday(8, 58),
            accumulatedActivity: TimeInterval(60 * 60)
        )
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.wednesday(9, 3))
        #expect(pause.deferredBy == .cooldown(until: F.wednesday(9, 3)))
    }

    @Test("A timed hold pushes the pause to the moment it lifts")
    func suspensionFloor() throws {
        let resumesAt = F.wednesday(11, 0)
        let state = ScheduleState(
            schedule: F.schedule(suspension: .until(resumesAt)),
            now: F.wednesday(9, 0),
            accumulatedActivity: TimeInterval(45 * 60)
        )
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == resumesAt)
        #expect(pause.deferredBy == .suspendedUntil(resumesAt))
    }

    @Test("An indefinite hold or a disabled schedule has no next pause")
    func noProjection() {
        let now = F.wednesday(9, 0)
        #expect(service.nextPause(after: ScheduleState(schedule: F.schedule(isEnabled: false), now: now)) == nil)
        #expect(service.nextPause(after: ScheduleState(schedule: F.schedule(suspension: .indefinite), now: now)) == nil)
    }

    @Test("A pending skip is projected and flagged, not hidden")
    func skipNextIsFlagged() throws {
        let state = ScheduleState(schedule: F.schedule(suspension: .skipNext), now: F.wednesday(9, 0))
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.willBeSkipped)
        #expect(pause.start == F.wednesday(9, 45))
        // Nothing else is pending, so the projection is not deferred by the skip.
        #expect(pause.deferredBy == nil)
    }

    @Test("A pause always ends on its own timer, even past the active window")
    func pauseDurationIsACeiling() throws {
        // Product rule: screen access is never contingent on a biological
        // outcome, so the end instant is start + duration and nothing else can
        // move it — including the active window closing mid-pause.
        let state = ScheduleState(
            schedule: F.schedule(pauseDuration: 300),
            now: F.wednesday(19, 28),
            accumulatedActivity: TimeInterval(45 * 60)
        )
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.wednesday(19, 28))
        #expect(pause.end == F.wednesday(19, 33))
        #expect(pause.duration == TimeInterval(300))
        #expect(pause.end > F.wednesday(19, 30))
    }

    @Test("There is no next pause when quiet hours swallow the whole window")
    func noUsableSlot() {
        let allQuiet = F.window(60, 7, 0, 19, 30, label: .custom)
        let state = ScheduleState(
            schedule: F.schedule(quietWindows: [allQuiet]),
            now: F.wednesday(9, 0)
        )
        #expect(service.nextPause(after: state) == nil)
    }
}

@Suite("Scheduling: next pause on the wall clock")
struct SchedulingClockTimePauseTests {
    typealias F = SchedulingFixtures
    let service = SchedulingFixtures.ny

    func hourly(quietWindows: [QuietWindow] = [], days: Set<Weekday> = Weekday.everyDay) -> PottySchedule {
        F.schedule(basis: .clockTime, interval: .minutes60, quietWindows: quietWindows, days: days)
    }

    @Test("Slots run on the wall clock from the window start")
    func gridFromWindowStart() throws {
        let state = ScheduleState(schedule: hourly(), now: F.wednesday(8, 30))
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.wednesday(9, 0))
        #expect(pause.basis == .clockTime)
    }

    @Test("An instant that is exactly a slot is that slot")
    func exactSlot() throws {
        let state = ScheduleState(schedule: hourly(), now: F.wednesday(9, 0))
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.wednesday(9, 0))
        #expect(!pause.wasDeferred)
    }

    @Test("A slot that already fired is not offered again")
    func lastPauseEndExcludesItsOwnSlot() throws {
        let state = ScheduleState(
            schedule: hourly(),
            now: F.wednesday(9, 0),
            lastPauseEnd: F.wednesday(9, 0)
        )
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.wednesday(10, 0))
    }

    @Test("The cadence ignores accumulated screen activity entirely")
    func ignoresActivity() throws {
        let idle = ScheduleState(schedule: hourly(), now: F.wednesday(8, 30))
        let busy = ScheduleState(
            schedule: hourly(),
            now: F.wednesday(8, 30),
            accumulatedActivity: TimeInterval(10 * 60 * 60)
        )
        #expect(service.nextPause(after: idle)?.start == service.nextPause(after: busy)?.start)
    }

    @Test("A slot lost to quiet hours is skipped, not dragged forward")
    func quietSlotIsSkipped() throws {
        // The two bases genuinely differ here, and that is the point: an activity
        // pause is owed to the child and lands at 14:30; a clock pause is a
        // cadence the family can predict, so it keeps the grid and waits for 15:00.
        let clockState = ScheduleState(schedule: hourly(quietWindows: [F.nap]), now: F.wednesday(12, 45))
        let clockPause = try #require(service.nextPause(after: clockState))
        #expect(clockPause.start == F.wednesday(15, 0))
        #expect(clockPause.deferredBy?.quietWindow?.id == F.nap.id)

        let activityState = ScheduleState(
            schedule: F.schedule(quietWindows: [F.nap]),
            now: F.wednesday(12, 45),
            accumulatedActivity: TimeInterval(45 * 60)
        )
        let activityPause = try #require(service.nextPause(after: activityState))
        #expect(activityPause.start == F.wednesday(14, 30))
    }

    @Test("After the last slot of the day, the next is tomorrow's first")
    func rollsOverToTomorrow() throws {
        // 07:00 + n×60 puts the last slot at 19:00; 19:30 closes the window.
        let state = ScheduleState(schedule: hourly(), now: F.wednesday(19, 10))
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.nyAt(2025, 6, 12, 7, 0))
    }

    @Test("An interval that does not divide the window leaves a short tail")
    func intervalDoesNotDivideWindow() throws {
        let state = ScheduleState(schedule: hourly(), now: F.wednesday(18, 30))
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.wednesday(19, 0))
    }

    @Test("Days off are skipped and named")
    func inactiveDay() throws {
        let state = ScheduleState(schedule: hourly(days: [.saturday]), now: F.wednesday(9, 0))
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.start == F.saturday(7, 0))
        #expect(pause.deferredBy == .inactiveDay(.wednesday))
    }

    @Test("A cadence in a window that wraps midnight keeps counting past midnight")
    func wrappingWindowGrid() throws {
        let schedule = F.schedule(
            basis: .clockTime,
            interval: .custom(minutes: 120),
            start: LocalTimeOfDay(hour: 20, minute: 0),
            end: LocalTimeOfDay(hour: 6, minute: 0)
        )
        // Slots: 20:00, 22:00, 00:00, 02:00, 04:00.
        #expect(service.nextPause(after: ScheduleState(schedule: schedule, now: F.wednesday(21, 0)))?.start
            == F.wednesday(22, 0))
        #expect(service.nextPause(after: ScheduleState(schedule: schedule, now: F.wednesday(23, 0)))?.start
            == F.nyAt(2025, 6, 12, 0, 0))
        #expect(service.nextPause(after: ScheduleState(schedule: schedule, now: F.nyAt(2025, 6, 12, 3, 0)))?.start
            == F.nyAt(2025, 6, 12, 4, 0))
        // 06:00 closes the window, so after 04:00 the next slot is the evening's.
        #expect(service.nextPause(after: ScheduleState(schedule: schedule, now: F.nyAt(2025, 6, 12, 5, 0)))?.start
            == F.nyAt(2025, 6, 12, 20, 0))
    }

    @Test("A whole-day cadence has a slot at midnight")
    func wholeDayGrid() throws {
        let schedule = F.allDaySchedule(basis: .clockTime, interval: .minutes60, cooldown: 0)
        let state = ScheduleState(schedule: schedule, now: F.wednesday(23, 30))
        #expect(service.nextPause(after: state)?.start == F.nyAt(2025, 6, 12, 0, 0))
    }
}

@Suite("Scheduling: warnings")
struct SchedulingWarningTests {
    typealias F = SchedulingFixtures
    let service = SchedulingFixtures.ny

    @Test("The warning is the pause minus the effective offset")
    func warningDerivation() throws {
        let state = ScheduleState(schedule: F.schedule(), now: F.wednesday(9, 0))
        let warning = try #require(service.nextWarning(for: state))
        #expect(warning.pauseAt == F.wednesday(9, 45))
        #expect(warning.fireAt == F.wednesday(9, 43))
        #expect(warning.leadTime == TimeInterval(120))
        #expect(!warning.hasElapsed)
        #expect(warning.shouldNotify)
    }

    @Test("A zero offset means no warning at all")
    func warningDisabled() {
        let schedule = F.schedule(warningOffset: 0)
        #expect(service.warningTime(forPauseAt: F.wednesday(9, 45), in: schedule) == nil)
        #expect(service.nextWarning(for: ScheduleState(schedule: schedule, now: F.wednesday(9, 0))) == nil)
    }

    @Test("The offset is clamped below the interval so warnings cannot overlap pauses")
    func warningClampedToInterval() throws {
        // A 15-minute interval with a 15-minute warning would fire the warning at
        // the previous pause. `effectiveWarningOffset` clamps it to interval − 60s.
        let schedule = F.schedule(interval: .minutes15, warningOffset: 900)
        #expect(schedule.effectiveWarningOffset == TimeInterval(840))
        let state = ScheduleState(schedule: schedule, now: F.wednesday(9, 0))
        let warning = try #require(service.nextWarning(for: state))
        #expect(warning.pauseAt == F.wednesday(9, 15))
        #expect(warning.fireAt == F.wednesday(9, 1))
    }

    @Test("A warning that would land inside quiet hours is suppressed")
    func warningSuppressedByQuietHours() throws {
        // The pause itself is legal at 14:30, the instant the nap ends, but the
        // 14:28 warning would reach a sleeping child.
        let state = ScheduleState(
            schedule: F.schedule(quietWindows: [F.nap]),
            now: F.wednesday(13, 45),
            accumulatedActivity: TimeInterval(45 * 60)
        )
        let warning = try #require(service.nextWarning(for: state))
        #expect(warning.pauseAt == F.wednesday(14, 30))
        #expect(warning.fireAt == F.wednesday(14, 28))
        #expect(warning.suppressedBy?.id == F.nap.id)
        #expect(!warning.shouldNotify)
    }

    @Test("A warning already in the past is reported as elapsed")
    func warningElapsed() throws {
        let state = ScheduleState(
            schedule: F.schedule(),
            now: F.wednesday(9, 0),
            accumulatedActivity: TimeInterval(44 * 60)
        )
        let warning = try #require(service.nextWarning(for: state))
        #expect(warning.pauseAt == F.wednesday(9, 1))
        // 08:59 is behind `now`, so the caller schedules the pause and drops the
        // warning rather than firing one in the past.
        #expect(warning.fireAt == F.wednesday(8, 59))
        #expect(warning.hasElapsed)
        #expect(!warning.shouldNotify)
    }

    @Test("The projection carries the same warning instant")
    func projectionCarriesWarning() throws {
        let state = ScheduleState(schedule: F.schedule(), now: F.wednesday(9, 0))
        let pause = try #require(service.nextPause(after: state))
        #expect(pause.warning == service.warningTime(forPauseAt: pause.start, in: F.schedule()))
        #expect(pause.warning == F.wednesday(9, 43))
    }
}
