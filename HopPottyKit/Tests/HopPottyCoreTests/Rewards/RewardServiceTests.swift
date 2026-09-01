import Foundation
import Testing
@testable import HopPottyCore

/// The reward ledger is where two of the contract's hardest rules live: stars
/// are never removed, and an accident never reaches the reward system. These
/// tests are the enforcement, not the documentation.
@Suite("Reward service")
struct RewardServiceTests {

    // MARK: - Fixtures

    static let child = UUID(uuidString: "5A11D000-0000-4000-8000-000000000001")!
    static let sibling = UUID(uuidString: "5A11D000-0000-4000-8000-000000000002")!

    /// 2026-03-10 09:00:00 UTC.
    static let morning = Date(timeIntervalSince1970: 1_773_133_200)
    static var evening: Date { morning.addingTimeInterval(10 * 3_600) }
    static var nextDay: Date { morning.addingTimeInterval(26 * 3_600) }

    /// A fixed UTC calendar so day-scoped keys do not depend on the machine.
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func service() -> RewardService {
        RewardService(calendar: Self.utc)
    }

    private func event(
        _ kind: PottyEventKind,
        id: UUID = UUID(),
        child: UUID = RewardServiceTests.child,
        at date: Date = RewardServiceTests.morning
    ) -> PottyEvent {
        PottyEvent(id: id, childID: child, timestamp: date, kind: kind, source: .childRoutine)
    }

    // MARK: - Idempotency

    @Test("Awarding the same key twice yields exactly one transaction")
    func duplicateAwardCollapses() {
        var service = service()
        let eventID = UUID()

        let first = service.award(
            reason: .triedThePotty,
            childID: Self.child,
            sourceEventID: eventID,
            at: Self.morning
        )
        let second = service.award(
            reason: .triedThePotty,
            childID: Self.child,
            sourceEventID: eventID,
            at: Self.evening
        )

        #expect(first != nil)
        #expect(second == nil, "A second attempt at the same award must be refused, not stacked")
        #expect(service.ledger.count == 1)
        #expect(service.totalStars(for: Self.child) == 1)
    }

    @Test("A retry after the app is killed mid-write still awards once")
    func replayAfterRelaunchCollapses() {
        // The event row is written before the star, so its id survives the
        // crash. Rebuilding the service from the persisted ledger — exactly what
        // a relaunch does — must recompute the same key.
        let routineEvent = event(.tried, id: UUID(uuidString: "E0E0E0E0-0000-4000-8000-000000000001")!)

        var beforeCrash = service()
        beforeCrash.award(for: routineEvent)
        let persisted = beforeCrash.ledger

        var afterRelaunch = RewardService(ledger: persisted, calendar: Self.utc)
        let retry = afterRelaunch.award(for: routineEvent)

        #expect(retry == nil)
        #expect(afterRelaunch.ledger.count == 1)
        #expect(afterRelaunch.totalStars(for: Self.child) == 1)
    }

    @Test("A ledger round-tripped through Codable still refuses the duplicate")
    func idempotencySurvivesEncoding() throws {
        var service = service()
        let routineEvent = event(.tried)
        service.award(for: routineEvent)

        let data = try JSONEncoder().encode(service.ledger)
        let decoded = try JSONDecoder().decode(RewardLedger.self, from: data)

        var restored = RewardService(ledger: decoded, calendar: Self.utc)
        #expect(restored.award(for: routineEvent) == nil)
        #expect(restored.ledger.count == 1)
    }

    @Test("The key is a pure function of child, reason and scope")
    func keysAreDeterministic() {
        let eventID = UUID()
        let a = RewardIdempotency.key(reason: .washedHands, childID: Self.child, scope: .event(eventID))
        let b = RewardIdempotency.key(reason: .washedHands, childID: Self.child, scope: .event(eventID))
        #expect(a == b)

        // Nothing about the attempt leaks in: no timestamp, no fresh UUID.
        #expect(!a.contains(Self.morning.description))

        // Different child, different reason and different scope are all distinct
        // awards; two siblings must both be rewarded for the same routine.
        #expect(a != RewardIdempotency.key(reason: .washedHands, childID: Self.sibling, scope: .event(eventID)))
        #expect(a != RewardIdempotency.key(reason: .triedThePotty, childID: Self.child, scope: .event(eventID)))
        #expect(a != RewardIdempotency.key(reason: .washedHands, childID: Self.child, scope: .session(eventID)))
    }

    @Test("Day-scoped keys collapse within a day and reopen the next day")
    func dayScopedAwards() {
        var service = service()

        let first = service.award(reason: .completedQuiz, childID: Self.child, at: Self.morning)
        let sameDay = service.award(reason: .completedQuiz, childID: Self.child, at: Self.evening)
        let tomorrow = service.award(reason: .completedQuiz, childID: Self.child, at: Self.nextDay)

        #expect(first != nil)
        #expect(sameDay == nil)
        #expect(tomorrow != nil)
        #expect(service.totalStars(for: Self.child) == 2)
    }

    @Test("A session scope separates two runs on the same day")
    func sessionScopedAwards() {
        var service = service()
        let morningPause = UUID()
        let afternoonPause = UUID()

        let a = service.awardResult(
            reason: .answeredPottyPause,
            childID: Self.child,
            scope: .session(morningPause),
            at: Self.morning
        )
        let b = service.awardResult(
            reason: .answeredPottyPause,
            childID: Self.child,
            scope: .session(afternoonPause),
            at: Self.evening
        )
        let replayOfA = service.awardResult(
            reason: .answeredPottyPause,
            childID: Self.child,
            scope: .session(morningPause),
            at: Self.evening
        )

        #expect(a.isNewlyAwarded)
        #expect(b.isNewlyAwarded)
        #expect(!replayOfA.isNewlyAwarded)
        #expect(replayOfA.transaction?.id == a.transaction?.id, "A duplicate returns the star the child already has")
        #expect(service.totalStars(for: Self.child) == 2)
    }

    // MARK: - Totals

    @Test("The total is derived from a mixed ledger, per child")
    func totalAcrossMixedLedger() {
        var service = service()
        let visit = event(.pee)

        service.award(for: visit)
        service.award(reason: .washedHands, childID: Self.child, sourceEventID: visit.id, at: Self.morning)
        service.award(reason: .completedRoutine, childID: Self.child, sourceEventID: visit.id, at: Self.morning)
        service.award(reason: .completedGame, childID: Self.child, at: Self.morning)
        service.awardResult(
            reason: .toldAGrownUp,
            childID: Self.child,
            scope: .session(UUID()),
            quantity: 2,
            at: Self.evening
        )
        // A second child's stars must not leak into the first child's pond.
        service.award(reason: .triedThePotty, childID: Self.sibling, sourceEventID: UUID(), at: Self.morning)

        #expect(service.totalStars(for: Self.child) == 6)
        #expect(service.totalStars(for: Self.sibling) == 1)
        #expect(service.ledger.totalStars == 7)
        #expect(RewardService.totalStars(for: Self.child, in: service.ledger) == 6)
        #expect(RewardService.totalStars(for: Self.child, in: service.ledger.transactions) == 6)
    }

    @Test("The total only ever goes up as stars are appended")
    func totalIsMonotonicUnderAppends() {
        var service = service()
        var previous = 0
        for index in 0..<25 {
            service.award(
                reason: .triedThePotty,
                childID: Self.child,
                sourceEventID: UUID(),
                at: Self.morning.addingTimeInterval(Double(index) * 3_600)
            )
            let total = service.totalStars(for: Self.child)
            #expect(total >= previous)
            previous = total
        }
        #expect(previous == 25)
    }

    // MARK: - Quantities

    @Test("Zero and negative quantities are refused, never stored as a penalty")
    func nonPositiveQuantitiesRejected() {
        var service = service()

        let zero = service.awardResult(
            reason: .completedGame,
            childID: Self.child,
            scope: .custom("zero"),
            quantity: 0,
            at: Self.morning
        )
        let negative = service.awardResult(
            reason: .completedGame,
            childID: Self.child,
            scope: .custom("negative"),
            quantity: -5,
            at: Self.morning
        )

        #expect(zero == .rejectedNonPositiveQuantity)
        #expect(negative == .rejectedNonPositiveQuantity)
        #expect(service.ledger.isEmpty)
        #expect(service.totalStars(for: Self.child) == 0)
    }

    @Test("A stored row with a non-positive quantity is dropped on load")
    func nonPositiveRowsDroppedOnLoad() {
        let noise = RewardTransaction(
            childID: Self.child,
            timestamp: Self.morning,
            reason: .completedGame,
            quantity: 0,
            idempotencyKey: "legacy-zero"
        )
        let real = RewardTransaction(
            childID: Self.child,
            timestamp: Self.morning,
            reason: .triedThePotty,
            quantity: 1,
            idempotencyKey: "legacy-one"
        )
        let ledger = RewardLedger([noise, real])

        #expect(ledger.count == 1)
        #expect(ledger.totalStars == 1)
    }

    @Test("A duplicate key in stored rows keeps the first, not both")
    func duplicateRowsCollapseOnLoad() {
        let key = "hop.reward.v1|duplicate"
        let first = RewardTransaction(childID: Self.child, timestamp: Self.morning, reason: .triedThePotty, idempotencyKey: key)
        let second = RewardTransaction(childID: Self.child, timestamp: Self.evening, reason: .triedThePotty, idempotencyKey: key)
        let ledger = RewardLedger([first, second])

        #expect(ledger.count == 1)
        #expect(ledger.transactions.first?.id == first.id)
    }

    // MARK: - Accidents

    @Test("An accident never produces a reward", arguments: PottyEventKind.allCases)
    func accidentsNeverReward(kind: PottyEventKind) {
        var service = service()
        let logged = event(kind, id: UUID(), at: Self.morning)

        let transaction = service.award(for: logged)

        if kind == .accident {
            #expect(transaction == nil, "An accident is a neutral timeline fact, never a reward decision")
            #expect(service.ledger.isEmpty)
            #expect(service.totalStars(for: Self.child) == 0)
            #expect(RewardService.reason(for: .accident) == nil)
        } else {
            #expect(transaction != nil)
            #expect(service.totalStars(for: Self.child) == 1)
        }
    }

    @Test("An accident logged alongside real visits changes nothing")
    func accidentDoesNotDisturbExistingStars() {
        var service = service()
        service.award(for: event(.tried))
        let before = service.totalStars(for: Self.child)

        service.award(for: event(.accident, child: Self.child, at: Self.evening))

        #expect(service.totalStars(for: Self.child) == before)
        #expect(service.ledger.count == 1)
    }

    @Test("Trying, peeing and pooping are worth exactly the same")
    func outcomeDoesNotChangeTheReward() {
        for kind in [PottyEventKind.tried, .pee, .poop] {
            var service = service()
            service.award(for: event(kind, id: UUID()))
            #expect(service.totalStars(for: Self.child) == 1, "\(kind) must not pay more or less than trying")
            #expect(service.ledger.transactions.first?.reason == .triedThePotty)
        }
    }

    // MARK: - Reconciliation

    @Test("Deleting a source event never reduces the total")
    func deletingAnEventKeepsTheStars() {
        var service = service()
        let kept = event(.tried, id: UUID(), at: Self.morning)
        let deleted = event(.pee, id: UUID(), at: Self.evening)
        service.award(for: kept)
        service.award(for: deleted)
        service.award(reason: .washedHands, childID: Self.child, sourceEventID: deleted.id, at: Self.evening)
        let before = service.totalStars(for: Self.child)
        #expect(before == 3)

        // The caregiver deletes the second visit from the timeline.
        let result = service.reconcile(against: Set([kept.id]))

        #expect(result.starsRemoved == 0, "Stars are never taken from a child")
        #expect(result.starsAfter == before)
        #expect(service.totalStars(for: Self.child) == before)
        #expect(service.ledger.count == 3, "Rows are orphaned, never deleted")
        #expect(result.orphanedCount == 2)
    }

    @Test("Orphaning clears the link and nothing else")
    func orphaningPreservesEverythingButTheLink() throws {
        var service = service()
        let deleted = event(.tried, id: UUID(), at: Self.morning)
        let issued = service.award(for: deleted)
        let awarded = try #require(issued)

        service.reconcile(against: [])
        let after = try #require(service.ledger.transactions.first)

        #expect(after.id == awarded.id)
        #expect(after.quantity == awarded.quantity)
        #expect(after.timestamp == awarded.timestamp)
        #expect(after.reason == awarded.reason)
        #expect(after.idempotencyKey == awarded.idempotencyKey, "Keeping the key keeps a queued retry idempotent")
        #expect(after.sourceEventID == nil, "A nil link on an event-linked reason is the orphan marker")
        #expect(service.ledger.orphanedTransactions.count == 1)
    }

    @Test("A queued retry for a deleted event still cannot double-award")
    func retryAfterDeletionStillCollapses() {
        var service = service()
        let deleted = event(.tried, id: UUID())
        service.award(for: deleted)
        service.reconcile(against: [])

        let retry = service.award(for: deleted)

        #expect(retry == nil)
        #expect(service.totalStars(for: Self.child) == 1)
    }

    @Test("Reconciling against the surviving events gives the same answer")
    func reconcileAgainstEvents() {
        var service = service()
        let kept = event(.tried, id: UUID())
        let deleted = event(.pee, id: UUID(), at: Self.evening)
        service.award(for: kept)
        service.award(for: deleted)

        let result = RewardService.reconcile(ledger: service.ledger, against: [kept])

        #expect(result.starsRemoved == 0)
        #expect(result.orphanedCount == 1)
        #expect(result.ledger.transactions(linkedTo: kept.id).count == 1)
        #expect(result.ledger.transactions(linkedTo: deleted.id).isEmpty)
    }

    @Test("Reconciling repeatedly is stable and still never removes a star")
    func reconcileIsIdempotent() {
        var service = service()
        for _ in 0..<5 { service.award(for: event(.tried, id: UUID(), at: Self.morning)) }
        let before = service.totalStars(for: Self.child)

        for _ in 0..<3 {
            let result = service.reconcile(against: [])
            #expect(result.starsRemoved == 0)
        }

        #expect(service.totalStars(for: Self.child) == before)
        #expect(service.ledger.count == 5)
    }
}
