import Foundation
import Testing
@testable import HopPottyCore

@Suite("Scheduling: suspension resolution")
struct SchedulingSuspensionTests {
    typealias F = SchedulingFixtures
    let service = SchedulingFixtures.ny

    @Test("No suspension blocks nothing and changes nothing")
    func none() {
        let resolved = service.resolveSuspension(.none, at: F.wednesday(9, 0))
        #expect(resolved.suspension == .none)
        #expect(!resolved.isBlocking)
        #expect(!resolved.didChange)
        #expect(resolved.resumesAt == nil)
    }

    @Test("An indefinite hold never expires on its own")
    func indefinite() {
        let resolved = service.resolveSuspension(.indefinite, at: F.wednesday(9, 0))
        #expect(resolved.suspension == .indefinite)
        #expect(resolved.isBlocking)
        #expect(!resolved.didChange)
        #expect(resolved.resumesAt == nil)
    }

    @Test("An until-hold blocks up to its instant and then collapses")
    func untilExpiry() {
        let deadline = F.wednesday(15, 0)
        let before = service.resolveSuspension(.until(deadline), at: F.wednesday(14, 59))
        #expect(before.isBlocking)
        #expect(before.resumesAt == deadline)
        #expect(!before.didChange)

        // Exactly at the deadline it is over — half-open, like every other
        // boundary in the engine.
        let at = service.resolveSuspension(.until(deadline), at: deadline)
        #expect(!at.isBlocking)
        #expect(at.suspension == .none)
        #expect(at.didChange)

        let after = service.resolveSuspension(.until(deadline), at: F.wednesday(16, 0))
        #expect(after.suspension == .none)
        #expect(after.didChange)
    }

    @Test("Until-tomorrow resumes at the next local midnight")
    func untilTomorrow() {
        let from = F.wednesday(22, 0)
        let midnight = F.nyAt(2025, 6, 12, 0, 0)
        let before = service.resolveSuspension(.untilTomorrow(from: from), at: F.wednesday(23, 30))
        #expect(before.isBlocking)
        #expect(before.resumesAt == midnight)

        let after = service.resolveSuspension(.untilTomorrow(from: from), at: F.nyAt(2025, 6, 12, 0, 1))
        #expect(!after.isBlocking)
        #expect(after.suspension == .none)
        #expect(after.didChange)
    }

    @Test("Until-tomorrow set just after midnight still resumes the following day")
    func untilTomorrowFromSmallHours() {
        // A parent who taps "not until tomorrow" at 00:30 means the day they are
        // awake in, so the hold runs to the next midnight, not thirty minutes.
        let from = F.wednesday(0, 30)
        let resolved = service.resolveSuspension(.untilTomorrow(from: from), at: F.wednesday(23, 0))
        #expect(resolved.isBlocking)
        #expect(resolved.resumesAt == F.nyAt(2025, 6, 12, 0, 0))
    }

    @Test("Resolution agrees with the model's own expiry rule")
    func agreesWithModel() {
        let cases: [(ScheduleSuspension, Date)] = [
            (.none, F.wednesday(9, 0)),
            (.indefinite, F.wednesday(9, 0)),
            (.skipNext, F.wednesday(9, 0)),
            (.until(F.wednesday(15, 0)), F.wednesday(14, 0)),
            (.until(F.wednesday(15, 0)), F.wednesday(16, 0)),
            (.untilTomorrow(from: F.wednesday(22, 0)), F.wednesday(23, 0)),
            (.untilTomorrow(from: F.wednesday(22, 0)), F.nyAt(2025, 6, 12, 1, 0)),
        ]
        for (suspension, now) in cases {
            let resolved = service.resolveSuspension(suspension, at: now)
            let modelSaysExpired = suspension.hasExpired(at: now, calendar: F.newYork)
            // `.skipNext` is the one case where the two differ by design: the
            // model has no notion of "expired" for it, and the engine treats it as
            // blocking until something consumes it.
            if case .skipNext = suspension {
                #expect(resolved.isBlocking)
                #expect(!modelSaysExpired)
            } else {
                #expect(resolved.isBlocking == !modelSaysExpired, "\(suspension) at \(now)")
            }
        }
    }

    @Test("Reading a pending skip does not spend it; consuming does")
    func skipNextConsumption() {
        let now = F.wednesday(9, 0)
        let read = service.resolveSuspension(.skipNext, at: now)
        #expect(read.isBlocking)
        #expect(read.suspension == .skipNext)
        #expect(!read.didChange)

        let consumed = service.resolveSuspension(.skipNext, at: now, consumingSkip: true)
        #expect(consumed.isBlocking)
        #expect(consumed.suspension == .none)
        #expect(consumed.didChange)
    }

    @Test("A dashboard refresh cannot silently spend a skip")
    func gateDoesNotConsumeSkip() {
        // `canStartPause` is a query. Asking it a hundred times must leave the
        // caregiver's "skip the next one" exactly where it was.
        let schedule = F.schedule(suspension: .skipNext)
        for minute in 0..<60 {
            let decision = service.canStartPause(at: F.wednesday(13, minute), in: schedule)
            #expect(decision.reason == .skippingNextPause)
        }
        #expect(schedule.suspension == .skipNext)
    }

    @Test("Until-tomorrow crosses a spring-forward boundary to the right midnight")
    func untilTomorrowAcrossSpringForward() {
        // Saturday 22:00 EST → the next midnight is 2025-03-09 00:00 EST, which is
        // still five hours before the clocks jump. Calendar arithmetic, not +86400.
        let from = F.nyAt(2025, 3, 8, 22, 0)
        let resolved = service.resolveSuspension(.untilTomorrow(from: from), at: F.nyAt(2025, 3, 8, 23, 0))
        #expect(resolved.resumesAt == F.Instant.springMidnight)
    }

    @Test("Until-tomorrow set before a fall-back day still resumes at midnight")
    func untilTomorrowAcrossFallBack() {
        let from = F.nyAt(2025, 11, 1, 21, 0)
        let resolved = service.resolveSuspension(.untilTomorrow(from: from), at: F.nyAt(2025, 11, 1, 23, 0))
        #expect(resolved.resumesAt == F.Instant.fallMidnight)
        // The following day is 25 hours long; the hold still ends at its midnight.
        #expect(!service.resolveSuspension(.untilTomorrow(from: from), at: F.Instant.fallOne).isBlocking)
    }

    @Test("Until-tomorrow follows the family to a new time zone")
    func untilTomorrowAfterTravel() {
        // Set at 22:00 in New York. In Kolkata that same instant is already 07:30
        // the next morning, so "tomorrow" is the Kolkata day after that one.
        let from = F.nyAt(2025, 6, 11, 22, 0)
        let newYorkView = SchedulingFixtures.ny.resolveSuspension(.untilTomorrow(from: from), at: from)
        let kolkataView = SchedulingFixtures.kol.resolveSuspension(.untilTomorrow(from: from), at: from)
        #expect(newYorkView.resumesAt == F.nyAt(2025, 6, 12, 0, 0))
        #expect(kolkataView.resumesAt == F.kolAt(2025, 6, 13, 0, 0))
        #expect(newYorkView.resumesAt != kolkataView.resumesAt)
    }

    @Test("A held schedule reports the hold, not a downstream reason")
    func holdOutranksConfiguration() {
        let schedule = F.schedule(quietWindows: [F.nap], suspension: .until(F.wednesday(18, 0)))
        let decision = service.canStartPause(at: F.wednesday(13, 0), in: schedule)
        #expect(decision.reason == .suspendedUntil(F.wednesday(18, 0)))
        #expect(decision.retryAfter == F.wednesday(18, 0))
    }
}
