import Foundation
import Testing
@testable import HopPottyCore

@Suite("Scheduling: canStartPause and its blocked reasons")
struct SchedulingPauseGateTests {
    typealias F = SchedulingFixtures
    let service = SchedulingFixtures.ny

    @Test("In the clear, a pause may start")
    func allowedInTheClear() {
        let decision = service.canStartPause(at: F.wednesday(13, 0), in: F.schedule())
        #expect(decision.isAllowed)
        #expect(decision.reason == nil)
        #expect(decision.retryAfter == nil)
    }

    /// The whole precedence ladder in one walk.
    ///
    /// Every condition below blocks at 02:00 on Wednesday 11 June. Removing them
    /// one at a time must reveal the next reason in exactly the documented order,
    /// which is the only way to be sure the order is real and not accidental.
    @Test("Blocked reasons are reported in strict precedence order")
    func precedenceLadder() throws {
        let now = F.wednesday(2, 0)
        let lastPauseEnd = F.wednesday(1, 59)
        let future = F.wednesday(18, 0)

        // Everything blocking at once.
        var schedule = F.schedule(
            quietWindows: [F.smallHours],
            days: [.monday],
            isEnabled: false,
            suspension: .indefinite
        )
        func reason(_ schedule: PottySchedule) -> PauseBlockReason? {
            service.canStartPause(at: now, in: schedule, lastPauseEnd: lastPauseEnd).reason
        }

        #expect(reason(schedule) == .scheduleDisabled)

        schedule.isEnabled = true
        #expect(reason(schedule) == .suspendedIndefinitely)

        schedule.suspension = .until(future)
        #expect(reason(schedule) == .suspendedUntil(future))

        schedule.suspension = .untilTomorrow(from: F.wednesday(1, 0))
        #expect(reason(schedule) == .suspendedUntilTomorrow(resumesAt: F.nyAt(2025, 6, 12, 0, 0)))

        // A caregiver hold outranks configuration, but `skipNext` does not: it is
        // spent on a pause that would otherwise have fired, so it must wait until
        // every other check has passed.
        schedule.suspension = .skipNext
        #expect(reason(schedule) == .inactiveDay(.wednesday))

        schedule.suspension = .none
        #expect(reason(schedule) == .inactiveDay(.wednesday))

        schedule.activeDays = Weekday.everyDay
        #expect(reason(schedule)?.testTag == "outsideActiveWindow")

        schedule.activeWindowStart = F.midnight
        schedule.activeWindowEnd = F.midnight
        #expect(reason(schedule)?.testTag == "quietWindow")

        schedule.quietWindows = []
        #expect(reason(schedule) == .cooldown(until: F.wednesday(2, 4)))

        schedule.suspension = .skipNext
        #expect(reason(schedule) == .cooldown(until: F.wednesday(2, 4)))

        schedule.suspension = .none
        #expect(reason(schedule) == .cooldown(until: F.wednesday(2, 4)))

        let clear = service.canStartPause(at: now, in: schedule, lastPauseEnd: nil)
        #expect(clear.isAllowed)

        schedule.suspension = .skipNext
        #expect(service.canStartPause(at: now, in: schedule, lastPauseEnd: nil).reason == .skippingNextPause)
    }

    @Test("Precedence ranks are unique and ordered as documented")
    func precedenceRanks() {
        let ordered: [PauseBlockReason] = [
            .scheduleDisabled,
            .suspendedIndefinitely,
            .suspendedUntil(F.wednesday(9, 0)),
            .inactiveDay(.wednesday),
            .outsideActiveWindow(resumesAt: nil),
            .quietWindow(F.nap, resumesAt: F.wednesday(14, 30)),
            .cooldown(until: F.wednesday(9, 0)),
            .skippingNextPause,
        ]
        for (earlier, later) in zip(ordered, ordered.dropFirst()) {
            #expect(earlier.precedence < later.precedence, "\(earlier.testTag) before \(later.testTag)")
        }
        // The two time-boxed holds are deliberately the same rank.
        #expect(
            PauseBlockReason.suspendedUntil(F.wednesday(9, 0)).precedence
                == PauseBlockReason.suspendedUntilTomorrow(resumesAt: F.wednesday(9, 0)).precedence
        )
    }

    @Test("The blocked reason carries what the copy layer needs")
    func reasonPayloads() throws {
        let schedule = F.schedule(quietWindows: [F.nap])
        let decision = service.canStartPause(at: F.wednesday(13, 0), in: schedule)
        let reason = try #require(decision.reason)
        #expect(reason.quietWindow?.label == .nap)
        #expect(reason.quietWindow?.id == F.nap.id)
        #expect(reason.resumesAt == F.wednesday(14, 30))
        #expect(decision.retryAfter == F.wednesday(14, 30))
        #expect(!reason.needsCaregiverAction)
    }

    @Test("Reasons that only a caregiver can clear say so")
    func caregiverActionFlag() {
        #expect(PauseBlockReason.scheduleDisabled.needsCaregiverAction)
        #expect(PauseBlockReason.suspendedIndefinitely.needsCaregiverAction)
        #expect(PauseBlockReason.scheduleDisabled.resumesAt == nil)
        #expect(PauseBlockReason.suspendedIndefinitely.resumesAt == nil)
        #expect(!PauseBlockReason.cooldown(until: F.wednesday(9, 0)).needsCaregiverAction)
        #expect(!PauseBlockReason.inactiveDay(.friday).needsCaregiverAction)
        // An inactive day resolves only when the calendar rolls over, which is
        // not an instant this reason can name.
        #expect(PauseBlockReason.inactiveDay(.friday).resumesAt == nil)
    }

    @Test("Outside the active window, retry is the next window start")
    func outsideWindowRetry() {
        let schedule = F.schedule()
        let evening = service.canStartPause(at: F.wednesday(20, 0), in: schedule)
        #expect(evening.reason?.testTag == "outsideActiveWindow")
        #expect(evening.retryAfter == F.nyAt(2025, 6, 12, 7, 0))

        let dawn = service.canStartPause(at: F.wednesday(6, 0), in: schedule)
        #expect(dawn.retryAfter == F.wednesday(7, 0))
    }

    @Test("Cooldown blocks up to but not including its end")
    func cooldownBoundary() {
        let schedule = F.schedule(cooldown: 300)
        let lastPauseEnd = F.wednesday(13, 0)
        #expect(service.canStartPause(at: F.wednesday(13, 4), in: schedule, lastPauseEnd: lastPauseEnd).reason
            == .cooldown(until: F.wednesday(13, 5)))
        #expect(service.canStartPause(at: F.wednesday(13, 5), in: schedule, lastPauseEnd: lastPauseEnd).isAllowed)
    }

    @Test("A zero cooldown never blocks")
    func zeroCooldown() {
        let schedule = F.schedule(cooldown: 0)
        let lastPauseEnd = F.wednesday(13, 0)
        #expect(service.canStartPause(at: F.wednesday(13, 0), in: schedule, lastPauseEnd: lastPauseEnd).isAllowed)
    }

    @Test("Gentle mode is gated exactly like the shielding modes")
    func gentleModeIsGatedIdentically() {
        // Gentle mode never shields, but it still must not interrupt a nap.
        let gentle = F.schedule(mode: .gentle, quietWindows: [F.nap])
        let pause = F.schedule(mode: .pause, quietWindows: [F.nap])
        #expect(service.canStartPause(at: F.wednesday(13, 0), in: gentle).reason?.testTag
            == service.canStartPause(at: F.wednesday(13, 0), in: pause).reason?.testTag)
    }

    @Test("The state-based and explicit forms agree")
    func stateFormAgrees() {
        let schedule = F.schedule(quietWindows: [F.nap])
        let state = ScheduleState(
            schedule: schedule,
            now: F.wednesday(13, 0),
            lastPauseEnd: F.wednesday(12, 0),
            accumulatedActivity: 0
        )
        #expect(service.canStartPause(at: state) ==
            service.canStartPause(at: F.wednesday(13, 0), in: schedule, lastPauseEnd: F.wednesday(12, 0)))
    }

    @Test("An expired hold does not block")
    func expiredHoldDoesNotBlock() {
        let schedule = F.schedule(suspension: .until(F.wednesday(10, 0)))
        #expect(service.canStartPause(at: F.wednesday(9, 59), in: schedule).reason?.testTag == "suspendedUntil")
        // The hold is inclusive of its end instant only in the sense that it stops
        // blocking there; a pause at exactly 10:00 is allowed.
        #expect(service.canStartPause(at: F.wednesday(10, 0), in: schedule).isAllowed)
    }
}
