import Foundation
import Testing
@testable import HopPottyCore

/// The rules behind a one-off reminder.
///
/// A Quick Reminder is the smallest feature in HopPotty and the one with the
/// most ways to be quietly wrong: a timer that fires immediately, a timer set
/// for next week, two timers for the same child, or — the worst of them — a
/// replaced reminder whose notification nobody cancelled, which arrives for a
/// caregiver who watched the app tell them it was gone.
@Suite("Quick Reminder: planning")
struct QuickReminderPlannerTests {

    /// 2026-03-10 09:00:00 UTC. Fixed, so every expectation below is a date
    /// this file can state rather than a window it has to tolerate.
    static let now = Date(timeIntervalSince1970: 1_773_133_200)
    static let sam = UUID(uuidString: "5A11D000-0000-4000-8000-000000000001")!
    static let maya = UUID(uuidString: "5A11D000-0000-4000-8000-000000000002")!

    static func pending(
        at offset: TimeInterval,
        childID: UUID? = nil,
        state: QuickReminderState = .pending
    ) -> QuickReminder {
        QuickReminder(
            childID: childID,
            fireAt: now.addingTimeInterval(offset),
            createdAt: now,
            state: state
        )
    }

    // MARK: - Timing

    @Test("A preset resolves to the instant Set was tapped plus the delay")
    func presetResolvesFromTheTapNotTheSheet() {
        let request = QuickReminderRequest.after(.minutes20)
        #expect(request.fireDate(setAt: Self.now) == Self.now.addingTimeInterval(20 * 60))
        // Ten minutes later the same request means ten minutes later, which is
        // the whole reason a chip is stored as a duration and not an instant.
        let later = Self.now.addingTimeInterval(600)
        #expect(request.fireDate(setAt: later) == later.addingTimeInterval(20 * 60))
    }

    @Test("A picked time is that time, whenever the sheet was opened")
    func pickedTimeDoesNotMove() {
        let chosen = Self.now.addingTimeInterval(3 * 3600)
        let request = QuickReminderRequest.at(chosen)
        #expect(request.fireDate(setAt: Self.now) == chosen)
        #expect(request.fireDate(setAt: Self.now.addingTimeInterval(600)) == chosen)
    }

    // MARK: - Validation

    @Test("A reminder must be in the future")
    func pastInstantsAreRefused() {
        #expect(QuickReminderPlanner.validate(fireAt: Self.now, now: Self.now) == .inThePast)
        #expect(
            QuickReminderPlanner.validate(fireAt: Self.now.addingTimeInterval(-1), now: Self.now) == .inThePast
        )
        #expect(
            QuickReminderPlanner.validate(fireAt: Self.now.addingTimeInterval(-86_400), now: Self.now) == .inThePast
        )
    }

    @Test("A reminder closer than a minute is refused as too soon, not as past")
    func nearInstantsAreRefusedSeparately() {
        #expect(
            QuickReminderPlanner.validate(fireAt: Self.now.addingTimeInterval(1), now: Self.now) == .tooSoon
        )
        #expect(
            QuickReminderPlanner.validate(fireAt: Self.now.addingTimeInterval(59), now: Self.now) == .tooSoon
        )
        // Exactly the minimum lead is allowed: the boundary belongs to the
        // caregiver, and refusing a reminder they can express in the picker
        // would be a limit they cannot see.
        #expect(QuickReminderPlanner.validate(fireAt: Self.now.addingTimeInterval(60), now: Self.now) == nil)
    }

    @Test("A reminder reaches exactly 24 hours and no further")
    func horizonIsADay() {
        #expect(QuickReminderPlanner.maximumHorizon == TimeInterval(24 * 3600))
        let atTheLimit = Self.now.addingTimeInterval(QuickReminderPlanner.maximumHorizon)
        #expect(QuickReminderPlanner.validate(fireAt: atTheLimit, now: Self.now) == nil)
        #expect(
            QuickReminderPlanner.validate(fireAt: atTheLimit.addingTimeInterval(1), now: Self.now) == .beyondHorizon
        )
    }

    @Test("Nothing pending can outlive the window a finished reminder is pruned in")
    func horizonFitsInsideStaleness() {
        // If a reminder could be set further out than `staleAfter`, the launch
        // prune and the pending list would disagree about the same row.
        #expect(QuickReminderPlanner.maximumHorizon <= QuickReminderPlanner.staleAfter)
    }

    @Test("Every preset is inside the horizon")
    func presetsAreAlwaysAdmissible() {
        for duration in QuickReminderDuration.presets {
            let request = QuickReminderRequest.after(duration)
            #expect(
                QuickReminderPlanner.validate(request, at: Self.now) == nil,
                "the \(duration.minutes)-minute chip is not settable"
            )
        }
    }

    // MARK: - Planning

    @Test("A clean request produces a pending reminder at the right instant")
    func planningAClearRequest() throws {
        let outcome = QuickReminderPlanner.plan(.after(.minutes30), at: Self.now)
        let plan = try #require(outcome.plan)
        #expect(plan.reminder.fireAt == Self.now.addingTimeInterval(30 * 60))
        #expect(plan.reminder.createdAt == Self.now)
        #expect(plan.reminder.state == .pending)
        #expect(plan.reminder.requestedDuration == TimeInterval(30 * 60))
        #expect(plan.replaces == nil)
        #expect(plan.collision == nil)
        #expect(plan.replacesAnother == false)
    }

    @Test("The child and the reason are carried through untouched")
    func planCarriesScopeAndLabel() throws {
        let outcome = QuickReminderPlanner.plan(
            .after(.minutes15, childID: Self.sam, label: .beforeLeaving),
            at: Self.now
        )
        let plan = try #require(outcome.plan)
        #expect(plan.reminder.childID == Self.sam)
        #expect(plan.reminder.label == .beforeLeaving)
    }

    @Test("A refused request says which limit it hit")
    func refusalsCarryTheirReason() {
        #expect(
            QuickReminderPlanner.plan(.at(Self.now.addingTimeInterval(-60)), at: Self.now).rejection == .inThePast
        )
        #expect(
            QuickReminderPlanner.plan(.at(Self.now.addingTimeInterval(10)), at: Self.now).rejection == .tooSoon
        )
        #expect(
            QuickReminderPlanner.plan(.at(Self.now.addingTimeInterval(48 * 3600)), at: Self.now).rejection
                == .beyondHorizon
        )
    }

    /// Timing is checked before admission, so a caregiver who typed yesterday
    /// hears about yesterday rather than about a ceiling they were never going
    /// to reach.
    @Test("A request that is both late and over the ceiling is refused for the timing")
    func timingIsReportedBeforeTheCeiling() {
        let full = [
            Self.pending(at: 600, childID: Self.sam),
            Self.pending(at: 1200, childID: Self.maya),
            Self.pending(at: 1800, childID: nil),
        ]
        let outcome = QuickReminderPlanner.plan(
            .at(Self.now.addingTimeInterval(-60), childID: UUID()),
            existing: full,
            at: Self.now
        )
        #expect(outcome.rejection == .inThePast)
    }

    // MARK: - One per child, cancel replaces

    @Test("A second reminder for the same child replaces the first")
    func replacementIsTheOrdinaryCase() throws {
        let existing = Self.pending(at: 900, childID: Self.sam)
        let outcome = QuickReminderPlanner.plan(
            .after(.minutes45, childID: Self.sam),
            existing: [existing],
            at: Self.now
        )
        let plan = try #require(outcome.plan)
        #expect(plan.replaces == existing)
        #expect(plan.reminder.id != existing.id)
    }

    @Test("A reminder for nobody replaces the other reminder for nobody")
    func unscopedRemindersReplaceEachOther() throws {
        let existing = Self.pending(at: 900, childID: nil)
        let plan = try #require(
            QuickReminderPlanner.plan(.after(.minutes20), existing: [existing], at: Self.now).plan
        )
        #expect(plan.replaces == existing)
    }

    @Test("A sibling's reminder is left alone")
    func siblingsDoNotReplaceEachOther() throws {
        let samsReminder = Self.pending(at: 900, childID: Self.sam)
        let plan = try #require(
            QuickReminderPlanner.plan(
                .after(.minutes20, childID: Self.maya),
                existing: [samsReminder],
                at: Self.now
            ).plan
        )
        #expect(plan.replaces == nil)
    }

    /// The failure this models away: the new reminder is saved, the replaced one
    /// keeps its `.pending` row and its scheduled notification, and a caregiver
    /// who was told the reminder moved is interrupted twice.
    @Test("The writes for a replacement include the cancelled copy of the old one")
    func replacementWritesBothRows() throws {
        let existing = Self.pending(at: 900, childID: Self.sam)
        let plan = try #require(
            QuickReminderPlanner.plan(.after(.minutes45, childID: Self.sam), existing: [existing], at: Self.now).plan
        )
        let writes = QuickReminderPlanner.writes(for: plan)
        #expect(writes.count == 2)
        #expect(writes.first?.id == existing.id)
        #expect(writes.first?.state == .cancelled)
        #expect(writes.last?.id == plan.reminder.id)
        #expect(writes.last?.state == .pending)
    }

    @Test("A plan with nothing to replace writes exactly one row")
    func plainPlanWritesOneRow() throws {
        let plan = try #require(QuickReminderPlanner.plan(.after(.minutes10), at: Self.now).plan)
        #expect(QuickReminderPlanner.writes(for: plan) == [plan.reminder])
    }

    @Test("Three reminders is the ceiling, and a fourth child is refused")
    func theCeilingHolds() {
        let full = [
            Self.pending(at: 600, childID: Self.sam),
            Self.pending(at: 1200, childID: Self.maya),
            Self.pending(at: 1800, childID: nil),
        ]
        #expect(QuickReminderPlanner.maximumPending == 3)
        let outcome = QuickReminderPlanner.plan(.after(.minutes15, childID: UUID()), existing: full, at: Self.now)
        #expect(outcome.rejection == .tooManyPending)
    }

    /// Replacement beats the ceiling. Re-setting a timer for a child who
    /// already has one adds nothing to the queue, so a limit on the queue must
    /// not refuse it.
    @Test("A replacement is allowed even when the ceiling is reached")
    func replacementIsNotBlockedByTheCeiling() throws {
        let full = [
            Self.pending(at: 600, childID: Self.sam),
            Self.pending(at: 1200, childID: Self.maya),
            Self.pending(at: 1800, childID: nil),
        ]
        let plan = try #require(
            QuickReminderPlanner.plan(.after(.minutes15, childID: Self.maya), existing: full, at: Self.now).plan
        )
        #expect(plan.replaces?.childID == Self.maya)
    }

    /// A fired or cancelled reminder occupies nothing, however recent it is.
    @Test("Finished reminders do not hold a slot open")
    func terminalRemindersFreeTheirSlot() throws {
        let finished = [
            Self.pending(at: 600, childID: Self.sam, state: .fired),
            Self.pending(at: 1200, childID: Self.maya, state: .cancelled),
            Self.pending(at: 1800, childID: nil, state: .fired),
        ]
        let plan = try #require(
            QuickReminderPlanner.plan(.after(.minutes15, childID: UUID()), existing: finished, at: Self.now).plan
        )
        #expect(plan.replaces == nil)
    }

    /// A pending row whose instant has passed is really a fired one that has
    /// not been reconciled yet. It must not block a new reminder.
    @Test("A pending row that has already come due does not block a new one")
    func overdueRowsDoNotBlock() throws {
        let overdue = Self.pending(at: -60, childID: Self.sam)
        let plan = try #require(
            QuickReminderPlanner.plan(.after(.minutes15, childID: Self.sam), existing: [overdue], at: Self.now).plan
        )
        #expect(plan.replaces == nil, "an overdue row was treated as still waiting")
    }

    // MARK: - Collision

    @Test("A pause landing inside the window is mentioned, and never blocks")
    func nearbyPauseIsAdvisory() throws {
        let fireAt = Self.now.addingTimeInterval(30 * 60)
        let projection = PauseProjection(
            start: fireAt.addingTimeInterval(5 * 60),
            end: fireAt.addingTimeInterval(8 * 60),
            basis: .clockTime,
            warning: nil,
            earliestPossible: fireAt.addingTimeInterval(5 * 60),
            deferredBy: nil,
            willBeSkipped: false
        )
        let outcome = QuickReminderPlanner.plan(.after(.minutes30), projection: projection, at: Self.now)
        let plan = try #require(outcome.plan)
        let collision = try #require(plan.collision)
        #expect(collision.separation == TimeInterval(5 * 60))
        #expect(collision.pauseIsAfterReminder)
        #expect(plan.reminder.fireAt == fireAt, "the note moved the reminder")
    }

    @Test("A pause the caregiver already chose to skip is not a collision")
    func skippedPauseIsNotACollision() throws {
        let fireAt = Self.now.addingTimeInterval(30 * 60)
        let projection = PauseProjection(
            start: fireAt.addingTimeInterval(60),
            end: fireAt.addingTimeInterval(4 * 60),
            basis: .clockTime,
            warning: nil,
            earliestPossible: fireAt.addingTimeInterval(60),
            deferredBy: nil,
            willBeSkipped: true
        )
        let plan = try #require(
            QuickReminderPlanner.plan(.after(.minutes30), projection: projection, at: Self.now).plan
        )
        #expect(plan.collision == nil)
    }

    @Test("A pause well clear of the reminder is not mentioned")
    func distantPauseIsSilent() throws {
        let fireAt = Self.now.addingTimeInterval(30 * 60)
        let projection = PauseProjection(
            start: fireAt.addingTimeInterval(40 * 60),
            end: fireAt.addingTimeInterval(43 * 60),
            basis: .clockTime,
            warning: nil,
            earliestPossible: fireAt.addingTimeInterval(40 * 60),
            deferredBy: nil,
            willBeSkipped: false
        )
        let plan = try #require(
            QuickReminderPlanner.plan(.after(.minutes30), projection: projection, at: Self.now).plan
        )
        #expect(plan.collision == nil)
    }

    // MARK: - Life after firing

    @Test("Reconciling turns a due reminder into a fired one and leaves the rest")
    func reconciliationIsNarrow() {
        let due = Self.pending(at: -30)
        let waiting = Self.pending(at: 300)
        let cancelled = Self.pending(at: -30, state: .cancelled)
        let reconciled = QuickReminderPlanner.reconciled([due, waiting, cancelled], at: Self.now)
        #expect(reconciled[0].state == .fired)
        #expect(reconciled[1].state == .pending)
        #expect(reconciled[2].state == .cancelled, "a cancelled reminder was resurrected")
    }

    @Test("Remaining time is zero once a reminder is finished")
    func remainingIsZeroWhenTerminal() {
        #expect(QuickReminderPlanner.remaining(Self.pending(at: 300), at: Self.now) == TimeInterval(300))
        #expect(QuickReminderPlanner.remaining(Self.pending(at: 300, state: .fired), at: Self.now) == 0)
        #expect(QuickReminderPlanner.remaining(Self.pending(at: -300), at: Self.now) == 0)
    }

    @Test("Only finished reminders go stale, and only after a day")
    func stalenessOnlyAppliesToFinishedReminders() {
        let dayOld = QuickReminder(
            fireAt: Self.now.addingTimeInterval(-(24 * 3600) - 60),
            createdAt: Self.now.addingTimeInterval(-(25 * 3600)),
            state: .fired
        )
        #expect(QuickReminderPlanner.isStale(dayOld, at: Self.now))
        // The same age, still pending — a clock that jumped, or a row nothing
        // reconciled. Pruning it would delete a reminder nobody cancelled.
        var stillPending = dayOld
        stillPending.state = .pending
        #expect(!QuickReminderPlanner.isStale(stillPending, at: Self.now))
        #expect(!QuickReminderPlanner.isStale(Self.pending(at: -300, state: .fired), at: Self.now))
    }
}
