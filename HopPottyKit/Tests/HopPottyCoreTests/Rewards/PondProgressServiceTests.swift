import Foundation
import Testing
@testable import HopPottyCore

/// The pond is the visible half of the reward system. If the ledger keeps the
/// stars but the pond forgets them, the child still experiences a loss — so the
/// "never removed" rule is tested here as well as in the ledger.
@Suite("Pond progress")
struct PondProgressServiceTests {

    static let child = UUID(uuidString: "5A11D000-0000-4000-8000-000000000001")!
    /// 2026-03-10 09:00:00 UTC.
    static let day1 = Date(timeIntervalSince1970: 1_773_133_200)
    static var day2: Date { day1.addingTimeInterval(86_400) }

    let service = PondProgressService()

    // MARK: - Building a pond

    @Test("A star total unlocks exactly the catalog's unlocked set")
    func progressMatchesCatalog() {
        for stars in [0, 1, 3, 4, 20, 100, PondCatalog.totalStarsForCompletePond] {
            let progress = service.progress(forStars: stars, childID: Self.child, at: Self.day1)
            let expected = Set(PondCatalog.unlockedItems(atStars: stars).map(\.id))
            #expect(Set(progress.unlocked.keys) == expected)
            #expect(progress.unlockedCount == expected.count)
        }
    }

    @Test("An empty pond is the honest starting state, not an error")
    func emptyPond() throws {
        let progress = service.progress(forStars: 0, childID: Self.child, at: Self.day1)
        #expect(progress.unlockedCount == 0)

        let next = try #require(service.nextUnlock(after: 0))
        #expect(next.id == PondCatalog.items.first?.id)
    }

    // MARK: - Celebrations

    @Test("Applying a total reports what just appeared")
    func applyDetectsNewUnlocks() throws {
        let first = try #require(PondCatalog.items.first)
        let empty = PondProgress(childID: Self.child)

        let outcome = service.apply(stars: first.starCost, to: empty, at: Self.day1)

        #expect(outcome.hasCelebration)
        #expect(outcome.newlyUnlocked.map(\.id) == [first.id])
        #expect(outcome.headlineItem?.id == first.id)
        #expect(outcome.progress.isUnlocked(first.id))
        #expect(outcome.nextUp.next?.id == PondCatalog.items[1].id)
    }

    @Test("The celebration plays once, not on every recount")
    func celebrationDoesNotRepeat() throws {
        let first = try #require(PondCatalog.items.first)
        let firstApply = service.apply(stars: first.starCost, to: PondProgress(childID: Self.child), at: Self.day1)

        let secondApply = service.apply(stars: first.starCost, to: firstApply.progress, at: Self.day2)

        #expect(secondApply.newlyUnlocked.isEmpty)
        #expect(!secondApply.hasCelebration)
        #expect(secondApply.progress.unlockedCount == firstApply.progress.unlockedCount)
    }

    @Test("Several unlocks at once are reported in unlock order")
    func multipleUnlocksArrivingTogether() {
        let target = PondCatalog.items[4].starCost
        let outcome = service.apply(stars: target, to: PondProgress(childID: Self.child), at: Self.day1)

        #expect(outcome.newlyUnlocked.count == 5)
        #expect(outcome.newlyUnlocked.map(\.id) == PondCatalog.items.prefix(5).map(\.id))
        #expect(outcome.headlineItem?.id == PondCatalog.items[4].id, "The headline is the biggest thing that landed")
    }

    @Test("Unlock dates are kept, so the pond remembers when things arrived")
    func unlockDatesArePreserved() throws {
        let first = try #require(PondCatalog.items.first)
        let second = PondCatalog.items[1]

        let dayOne = service.apply(stars: first.starCost, to: PondProgress(childID: Self.child), at: Self.day1)
        let dayTwo = service.apply(stars: second.starCost, to: dayOne.progress, at: Self.day2)

        #expect(dayTwo.progress.unlocked[first.id] == Self.day1)
        #expect(dayTwo.progress.unlocked[second.id] == Self.day2)
    }

    // MARK: - "What did this star just unlock?"

    @Test("A star that crosses a threshold names what it unlocked")
    func starThatUnlocks() throws {
        let first = try #require(PondCatalog.items.first)
        let transaction = RewardTransaction(
            childID: Self.child,
            timestamp: Self.day1,
            reason: .completedRoutine,
            quantity: 1,
            idempotencyKey: "test"
        )

        let unlocked = service.unlocked(by: transaction, totalAfter: first.starCost)

        #expect(unlocked.map(\.id) == [first.id])
    }

    @Test("A star that does not cross a threshold unlocks nothing, quietly")
    func starThatDoesNotUnlock() {
        let transaction = RewardTransaction(
            childID: Self.child,
            timestamp: Self.day1,
            reason: .triedThePotty,
            quantity: 1,
            idempotencyKey: "test"
        )
        // One star into a three-star first unlock.
        #expect(service.unlocked(by: transaction, totalAfter: 1).isEmpty)
    }

    @Test("newlyUnlocked is half-open below and closed above")
    func newlyUnlockedBoundaries() throws {
        let first = try #require(PondCatalog.items.first)
        let second = PondCatalog.items[1]

        #expect(service.newlyUnlocked(from: 0, to: first.starCost).map(\.id) == [first.id])
        #expect(service.newlyUnlocked(from: first.starCost, to: first.starCost).isEmpty)
        #expect(service.newlyUnlocked(from: first.starCost, to: second.starCost).map(\.id) == [second.id])
        #expect(service.newlyUnlocked(from: 10, to: 3).isEmpty, "A total going backwards unlocks nothing — and un-locks nothing")
    }

    // MARK: - Nothing ever locks again

    @Test("Applying a smaller total never takes an item away")
    func smallerTotalNeverRelocks() {
        let full = service.progress(forStars: PondCatalog.totalStarsForCompletePond, childID: Self.child, at: Self.day1)
        #expect(full.unlockedCount == PondItemID.allCases.count)

        // This is the shape of a real recount: a caregiver deletes events, the
        // app recomputes, and the number it hands the pond is smaller. The pond
        // must not notice.
        let recounted = service.apply(stars: 3, to: full, at: Self.day2)

        #expect(recounted.progress.unlockedCount == PondItemID.allCases.count)
        #expect(recounted.newlyUnlocked.isEmpty)
        #expect(recounted.progress.unlocked[PondCatalog.items.last!.id] == Self.day1, "Even the dates survive")
    }

    @Test("No sequence of star totals, however erratic, can shrink the pond")
    func pondIsMonotonicUnderAnySequence() {
        // Deliberately adversarial: up, down, to zero, to negative, back up.
        let totals = [0, 3, 16, 5, 96, 0, 40, -20, 616, 1, 300, 616, 0]
        var progress = PondProgress(childID: Self.child)
        var previousCount = 0

        for total in totals {
            let outcome = service.apply(stars: total, to: progress, at: Self.day1)
            #expect(outcome.progress.unlockedCount >= previousCount, "The pond shrank at \(total) stars")
            previousCount = outcome.progress.unlockedCount
            progress = outcome.progress
        }

        #expect(previousCount == PondItemID.allCases.count)
    }

    // MARK: - End to end

    @Test("A child sees their first unlock on day one")
    func firstDayProducesAnUnlock() {
        var rewards = RewardService(calendar: RewardServiceTests.utc)
        var pond = PondProgress(childID: Self.child)

        // One good visit: told a grown-up, tried, washed hands, finished.
        let visit = PottyEvent(childID: Self.child, timestamp: Self.day1, kind: .tried, source: .childRoutine)
        rewards.award(for: visit)
        rewards.award(reason: .washedHands, childID: Self.child, sourceEventID: visit.id, at: Self.day1)
        rewards.award(reason: .completedRoutine, childID: Self.child, sourceEventID: visit.id, at: Self.day1)

        let outcome = PondProgressService().apply(
            stars: rewards.totalStars(for: Self.child),
            to: pond,
            at: Self.day1
        )
        pond = outcome.progress

        #expect(rewards.totalStars(for: Self.child) == 3)
        #expect(outcome.hasCelebration, "The pond must visibly change on day one")
        #expect(pond.unlockedCount == 1)
    }

    @Test("Deleting every event leaves the pond exactly as it was")
    func deletingEventsLeavesThePondIntact() {
        var rewards = RewardService(calendar: RewardServiceTests.utc)
        var events: [PottyEvent] = []
        for index in 0..<20 {
            let event = PottyEvent(
                childID: Self.child,
                timestamp: Self.day1.addingTimeInterval(Double(index) * 3_600),
                kind: .tried,
                source: .childRoutine
            )
            events.append(event)
            rewards.award(for: event)
        }

        let before = rewards.totalStars(for: Self.child)
        let pondBefore = service.progress(forStars: before, childID: Self.child, at: Self.day1)
        #expect(pondBefore.unlockedCount > 0)

        // The caregiver clears the whole timeline.
        rewards.reconcile(against: [])
        let after = rewards.totalStars(for: Self.child)
        let pondAfter = service.apply(stars: after, to: pondBefore, at: Self.day2)

        #expect(after == before)
        #expect(pondAfter.progress.unlockedCount == pondBefore.unlockedCount)
        #expect(Set(pondAfter.progress.unlocked.keys) == Set(pondBefore.unlocked.keys))
        #expect(pondAfter.newlyUnlocked.isEmpty)
    }

    @Test("A star at a time, the pond only ever grows")
    func starByStarGrowth() {
        var pond = PondProgress(childID: Self.child)
        var celebrations = 0
        var previousCount = 0

        for stars in 0...PondCatalog.totalStarsForCompletePond {
            let outcome = service.apply(stars: stars, to: pond, at: Self.day1)
            celebrations += outcome.newlyUnlocked.count
            #expect(outcome.progress.unlockedCount >= previousCount)
            previousCount = outcome.progress.unlockedCount
            pond = outcome.progress
        }

        #expect(celebrations == PondItemID.allCases.count, "Every item is celebrated exactly once on the way up")
        #expect(pond.unlockedCount == PondItemID.allCases.count)
    }
}
