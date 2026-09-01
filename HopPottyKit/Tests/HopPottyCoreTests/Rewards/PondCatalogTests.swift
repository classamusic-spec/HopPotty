import Foundation
import Testing
@testable import HopPottyCore

/// The pond is the child's entire sense of progress. These tests hold the shape
/// of that progression: exhaustive, monotonic, always reachable, never
/// retractable, and laid out as a scene rather than a pile.
@Suite("Pond catalog")
struct PondCatalogTests {

    // MARK: - Exhaustiveness

    @Test("Every pond item is in the catalog exactly once")
    func catalogIsExhaustive() {
        let ids = PondCatalog.items.map(\.id)
        let unique = Set(ids)

        #expect(PondCatalog.items.count == PondItemID.allCases.count)
        #expect(unique.count == PondItemID.allCases.count, "An item was priced twice or not at all")
        for id in PondItemID.allCases {
            #expect(unique.contains(id), "\(id.rawValue) has no place in the pond — price it in PondCatalog.placement(for:)")
        }
    }

    @Test("Unlock ranks are a permutation of 0..<count")
    func ranksAreAPermutation() {
        let ranks = PondItemID.allCases.map(PondCatalog.rank(of:)).sorted()
        #expect(ranks == Array(0..<PondItemID.allCases.count), "Two items share an unlock rank, or a rank is skipped")
    }

    @Test("Every layer and every category is used, so the scene has depth and variety")
    func sceneUsesTheWholeVocabulary() {
        let layers = Set(PondCatalog.items.map(\.layer))
        let categories = Set(PondCatalog.items.map(\.category))
        #expect(layers == Set(PondLayer.allCases))
        #expect(categories == Set(PondItemCategory.allCases))
    }

    // MARK: - The curve

    @Test("Star costs never decrease along the unlock order")
    func costsAreMonotonic() {
        var previous = 0
        for item in PondCatalog.items {
            #expect(item.starCost >= previous, "\(item.id.rawValue) is cheaper than the item before it")
            #expect(item.starCost > 0, "Nothing is free; nothing is negative")
            previous = item.starCost
        }
    }

    @Test("Star costs are strictly increasing, so 'next' is never ambiguous")
    func costsAreStrictlyIncreasing() {
        let costs = PondCatalog.items.map(\.starCost)
        for index in 1..<costs.count {
            #expect(costs[index] > costs[index - 1])
        }
    }

    @Test("The first unlock lands within a handful of routines")
    func firstUnlockIsReachableOnDayOne() throws {
        let first = try #require(PondCatalog.items.first)
        // One good routine is: tried the potty, washed hands, finished the
        // routine. Three stars. The pond must visibly change that same day.
        #expect(first.starCost <= 5)
        #expect(first.starCost >= 1)
        #expect(PondCatalog.unlockedItems(atStars: 3).isEmpty == false)
    }

    @Test("Steps grow gently and stay bounded, so the late pond is still reachable")
    func stepsGrowSmoothly() {
        let costs = PondCatalog.items.map(\.starCost)
        let steps = (1..<costs.count).map { costs[$0] - costs[$0 - 1] }

        for index in 1..<steps.count {
            #expect(steps[index] >= steps[index - 1], "The curve must not dip and re-spike")
        }
        // A cap is what makes "never unreachable" true: at a few stars a day,
        // the most expensive single unlock is about a week away, at item 41 as
        // much as at item 4.
        #expect((steps.max() ?? 0) <= 30)
        #expect((steps.min() ?? 0) >= 1)
    }

    @Test("The whole pond is finishable in a training-shaped amount of time")
    func completePondIsFinite() {
        let total = PondCatalog.totalStarsForCompletePond
        #expect(total == PondCatalog.items.last?.starCost)
        // At a modest four stars a day this is roughly five months — a real
        // potty-training arc, not an endless treadmill.
        #expect(total <= 1_000)
        #expect(total >= PondCatalog.items.count)
    }

    // MARK: - "What's next?"

    @Test("nextUnlock at zero stars is the very first item")
    func nextUnlockAtZero() {
        #expect(PondCatalog.nextUnlock(after: 0)?.id == PondCatalog.items.first?.id)
        #expect(PondCatalog.nextUnlock(after: -50)?.id == PondCatalog.items.first?.id, "A nonsense total still points forward")
    }

    @Test("At exactly a threshold, that item is unlocked and 'next' has moved on")
    func nextUnlockAtThreshold() throws {
        for index in 0..<(PondCatalog.items.count - 1) {
            let item = PondCatalog.items[index]
            let following = PondCatalog.items[index + 1]

            #expect(PondCatalog.unlockedItems(atStars: item.starCost).contains { $0.id == item.id })
            #expect(PondCatalog.nextUnlock(after: item.starCost)?.id == following.id)
            // One star short, the item itself is still what is next.
            #expect(PondCatalog.nextUnlock(after: item.starCost - 1)?.id == item.id)
        }

        let last = try #require(PondCatalog.items.last)
        #expect(PondCatalog.nextUnlock(after: last.starCost) == nil)
    }

    @Test("Past the final item there is nothing next, and nothing breaks")
    func nextUnlockPastTheEnd() {
        let beyond = PondCatalog.totalStarsForCompletePond + 5_000
        #expect(PondCatalog.nextUnlock(after: beyond) == nil)
        #expect(PondCatalog.upcomingItems(atStars: beyond).isEmpty)
        #expect(PondCatalog.unlockedItems(atStars: beyond).count == PondItemID.allCases.count)

        let progress = PondCatalog.progressTowardNext(stars: beyond)
        #expect(progress.isComplete)
        #expect(progress.starsRemaining == 0)
        #expect(progress.fraction == 1)
    }

    @Test("nextUnlock(after: item) walks the order and stops at the end")
    func nextUnlockAfterItem() throws {
        for index in 0..<(PondCatalog.items.count - 1) {
            let current = PondCatalog.items[index]
            #expect(PondCatalog.nextUnlock(after: current.id)?.id == PondCatalog.items[index + 1].id)
        }
        let last = try #require(PondCatalog.items.last)
        #expect(PondCatalog.nextUnlock(after: last.id) == nil)
    }

    @Test("Progress toward the next unlock reads forward at every point")
    func progressTowardNextIsWellFormed() throws {
        let first = try #require(PondCatalog.items.first)

        let atZero = PondCatalog.progressTowardNext(stars: 0)
        #expect(atZero.next?.id == first.id)
        #expect(atZero.previousThreshold == 0)
        #expect(atZero.starsRemaining == first.starCost)
        #expect(atZero.fraction == 0)

        let midway = PondCatalog.progressTowardNext(stars: first.starCost - 1)
        #expect(midway.next?.id == first.id)
        #expect(midway.starsRemaining == 1)
        #expect(midway.fraction > 0 && midway.fraction < 1)

        // At a threshold the bar resets against the *next* step rather than
        // sitting near-full, so the child can see it move again immediately.
        let atThreshold = PondCatalog.progressTowardNext(stars: first.starCost)
        #expect(atThreshold.previousThreshold == first.starCost)
        #expect(atThreshold.starsEarnedTowardNext == 0)
        #expect(atThreshold.fraction == 0)

        // Every step is a sane bar at every star total up the whole curve.
        for stars in 0...PondCatalog.totalStarsForCompletePond {
            let progress = PondCatalog.progressTowardNext(stars: stars)
            #expect(progress.fraction >= 0 && progress.fraction <= 1)
            #expect(progress.starsRemaining >= 0)
            #expect(progress.starsInCurrentStep >= 0)
        }
    }

    // MARK: - Nothing ever locks again

    @Test("The unlocked set only grows as stars grow")
    func unlockedSetIsMonotonic() {
        var previous = Set<PondItemID>()
        for stars in 0...PondCatalog.totalStarsForCompletePond {
            let current = Set(PondCatalog.unlockedItems(atStars: stars).map(\.id))
            #expect(previous.isSubset(of: current), "An item disappeared between \(stars - 1) and \(stars) stars")
            previous = current
        }
        #expect(previous.count == PondItemID.allCases.count)
    }

    /// Swift has no runtime reflection over a type's method list on Linux, so
    /// "no API exists to re-lock an item" is asserted the way it is actually
    /// experienced: every catalog entry point is a pure read, and no sequence of
    /// star totals — including totals that fall — can produce a smaller pond.
    /// The absence itself is enforced at review time by there being no `lock`,
    /// `remove`, `expire` or `decay` anywhere in `PondCatalog`.
    @Test("A falling star total cannot shrink the pond")
    func fallingTotalsCannotRelock() {
        let peak = PondCatalog.totalStarsForCompletePond
        let atPeak = Set(PondCatalog.unlockedItems(atStars: peak).map(\.id))
        #expect(atPeak.count == PondItemID.allCases.count)

        // The catalog is a pure function of stars, so a lower total describes a
        // smaller pond — which is exactly why PondProgressService unions rather
        // than replaces. Here we assert the catalog itself never *reports* an
        // unlock it previously withheld, i.e. the mapping is a step function
        // with no gaps.
        for stars in stride(from: peak, through: 0, by: -37) {
            let unlocked = PondCatalog.unlockedItems(atStars: stars)
            let prefix = Array(PondCatalog.items.prefix(unlocked.count))
            #expect(unlocked.map(\.id) == prefix.map(\.id), "Unlocks must be a prefix of the order — no holes, no shuffling")
        }
    }

    // MARK: - Scene layout

    @Test("Every anchor is inside the unit square with a usable scale")
    func anchorsAreInUnitSpace() {
        for item in PondCatalog.items {
            #expect(item.anchor.x >= 0 && item.anchor.x <= 1, "\(item.id.rawValue) x is outside the scene")
            #expect(item.anchor.y >= 0 && item.anchor.y <= 1, "\(item.id.rawValue) y is outside the scene")
            #expect(item.anchor.scale > 0, "\(item.id.rawValue) would render at zero size")
            #expect(item.anchor.scale <= 2)
        }
    }

    @Test("No two items in the same layer sit on top of each other")
    func sameLayerItemsDoNotCollide() {
        for layer in PondLayer.allCases {
            let inLayer = PondCatalog.items.filter { $0.layer == layer }
            for outer in 0..<inLayer.count {
                for inner in (outer + 1)..<inLayer.count {
                    let a = inLayer[outer].anchor
                    let b = inLayer[inner].anchor
                    #expect(!(a.x == b.x && a.y == b.y), "\(inLayer[outer].id.rawValue) and \(inLayer[inner].id.rawValue) share an anchor")

                    let distance = ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
                    #expect(
                        distance >= PondCatalog.minimumSameLayerSeparation,
                        "\(inLayer[outer].id.rawValue) and \(inLayer[inner].id.rawValue) are \(distance) apart in \(layer)"
                    )
                }
            }
        }
    }

    @Test("Items sit at the depth they belong to")
    func itemsRespectTheirLayerBand() {
        for item in PondCatalog.items {
            let band = PondCatalog.verticalBand(for: item.layer)
            #expect(
                band.contains(item.anchor.y),
                "\(item.id.rawValue) is at y=\(item.anchor.y), outside the \(item.layer) band \(band)"
            )
        }
    }

    @Test("Water creatures are in the water and sky things are in the sky")
    func sceneReadsAsAPlace() {
        func item(_ id: PondItemID) -> PondItem { PondCatalog.item(id) }

        #expect(item(.reedsLeft).layer == .shore)
        #expect(item(.reedsRight).layer == .shore)
        #expect(item(.cattails).layer == .shore)
        #expect(item(.fishOrange).layer == .water)
        #expect(item(.fishBlue).layer == .water)
        #expect(item(.tadpoleFriend).layer == .water)
        #expect(item(.duckling).layer == .water)
        #expect(item(.butterflyBlue).layer == .foreground)
        #expect(item(.butterflyYellow).layer == .foreground)
        #expect(item(.dragonfly).layer == .foreground)
        #expect(item(.fireflies).layer == .foreground)
        #expect(item(.rainbow).layer == .sky)
        #expect(item(.sunbeam).layer == .sky)
        #expect(item(.cloudPuff).layer == .sky)
        #expect(item(.frogFriendGreen).layer == .character)
        #expect(item(.frogFriendBlue).layer == .character)
        #expect(item(.clubhouse).layer == .backdrop)
        #expect(item(.blossomTree).layer == .backdrop)

        // Sky sits above the water, which sits above the near bank.
        let skyY = PondCatalog.items.filter { $0.layer == .sky }.map(\.anchor.y)
        let waterY = PondCatalog.items.filter { $0.layer == .water }.map(\.anchor.y)
        #expect((skyY.max() ?? 1) < (waterY.min() ?? 0))
    }

    @Test("The pond fills out evenly instead of piling into one corner")
    func partiallyUnlockedPondsStayBalanced() {
        var runningX = 0.0
        for (index, item) in PondCatalog.items.enumerated() {
            runningX += item.anchor.x
            // The first three unlocks are single objects; balance only becomes a
            // meaningful idea once there is a small group on screen.
            guard index >= 3 else { continue }
            let centroid = runningX / Double(index + 1)
            #expect(
                centroid >= 0.38 && centroid <= 0.62,
                "After \(index + 1) unlocks the scene leans to \(centroid)"
            )
        }
    }

    @Test("Consecutive unlocks do not stack in the same spot")
    func consecutiveUnlocksAreSpreadOut() {
        for index in 1..<PondCatalog.items.count {
            let previous = PondCatalog.items[index - 1].anchor
            let current = PondCatalog.items[index].anchor
            let distance = ((previous.x - current.x) * (previous.x - current.x)
                + (previous.y - current.y) * (previous.y - current.y)).squareRoot()
            #expect(
                distance >= 0.08,
                "\(PondCatalog.items[index].id.rawValue) appears right on top of the previous unlock"
            )
        }
    }
}
