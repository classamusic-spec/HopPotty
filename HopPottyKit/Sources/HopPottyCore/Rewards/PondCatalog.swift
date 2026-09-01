import Foundation

/// The complete, fixed unlock progression for Hop's Pond.
///
/// ## What this is not
///
/// There is no randomness here, no crate, no roll, no "chance of a rare item",
/// no limited-time item and no item that can be taken away. Every price is a
/// constant a caregiver could read out loud, and the order is the same for every
/// child on every install. A four-year-old can ask "what comes next?" and get
/// the same answer today, tomorrow and after a reinstall.
///
/// ## The curve
///
/// The first decoration costs **3 stars** — reachable in a single good routine
/// (tried the potty, washed hands, finished the routine), so the pond visibly
/// changes on day one. Prices then rise by a step that itself grows slowly:
/// +2, +3, +4, +4, +5 … up to +28 for the very last item. The step growth is
/// capped, which is the property that keeps the late pond *achievable*: no
/// single unlock ever costs more than about a week of ordinary use, even at
/// item 41. The whole pond is 616 stars — a few months of a real potty-training
/// arc, not an endless treadmill.
///
/// Because the step is monotonic and bounded, the curve has no wall and no
/// cliff. It gets calmer, never impossible.
///
/// ## Layout
///
/// Each item carries a `PondAnchor` in unit coordinates and a `PondLayer`.
/// Coordinates are `x` from 0 (left) to 1 (right) and `y` from 0 (top of the
/// scene, the sky) to 1 (bottom of the scene, nearest the viewer) — the same
/// orientation SwiftUI draws in, so the renderer needs no flip.
///
/// The scene reads as a real place: sky at the top, a far bank behind, the water
/// body as an ellipse roughly centred on (0.5, 0.62), the shore ringing it, and
/// the nearest things at the bottom. Items are placed where the thing itself
/// would be — reeds and stones at the waterline, fish and lilies inside the
/// water, butterflies and fireflies in front of everything, a rainbow in the sky.
///
/// The unlock *order* alternates sides on purpose. Consecutive unlocks land
/// left, right, left, so the pond grows outward from the middle instead of
/// filling one corner first; `PondCatalogTests` asserts that the centroid of
/// every partially-unlocked pond stays near the middle of the scene.
public enum PondCatalog {

    // MARK: - The curve

    /// Star price by unlock rank. Strictly increasing, with a bounded, gently
    /// growing step. Index 0 is the first thing a child ever unlocks.
    public static let starCosts: [Int] = [
        3, 5, 8, 12, 16, 21, 27, 33, 40, 48,
        56, 65, 75, 85, 96, 108, 120, 133, 147, 161,
        176, 192, 208, 225, 243, 261, 280, 300, 320, 341,
        363, 385, 408, 432, 456, 481, 507, 533, 560, 588,
        616,
    ]

    /// Price for a rank, extended smoothly past the table.
    ///
    /// The table is sized to `PondItemID.allCases`. If a future item is added,
    /// the exhaustive `placement(for:)` switch below stops compiling until it is
    /// placed — but its price should not depend on someone also remembering to
    /// grow this array, so a rank past the end simply continues the final step.
    /// That keeps the curve monotonic and finite instead of trapping.
    public static func starCost(forRank rank: Int) -> Int {
        if rank <= 0 { return starCosts[0] }
        if rank < starCosts.count { return starCosts[rank] }
        let last = starCosts[starCosts.count - 1]
        let finalStep = last - starCosts[starCosts.count - 2]
        return last + finalStep * (rank - starCosts.count + 1)
    }

    // MARK: - The catalog

    /// Every pond item, in unlock order. Built from `PondItemID.allCases`, so it
    /// is exhaustive by construction.
    public static let items: [PondItem] = PondItemID.allCases
        .map(item(_:))
        .sorted { rank(of: $0.id) < rank(of: $1.id) }

    /// Item ids in unlock order.
    public static var unlockOrder: [PondItemID] { items.map(\.id) }

    /// The stars needed to finish the entire pond.
    public static var totalStarsForCompletePond: Int { items.last?.starCost ?? 0 }

    /// The full definition of one item. Total by construction — there is no
    /// lookup that can miss, so no optional and no crash path.
    public static func item(_ id: PondItemID) -> PondItem {
        let placement = placement(for: id)
        return PondItem(
            id: id,
            category: placement.category,
            starCost: starCost(forRank: placement.rank),
            layer: placement.layer,
            anchor: placement.anchor
        )
    }

    /// Zero-based position in the unlock order.
    public static func rank(of id: PondItemID) -> Int { placement(for: id).rank }

    /// Stars needed to unlock this item.
    public static func starCost(of id: PondItemID) -> Int { item(id).starCost }

    // MARK: - Answering "what's next?"

    /// Everything a child with `stars` stars has unlocked, in unlock order.
    public static func unlockedItems(atStars stars: Int) -> [PondItem] {
        items.filter { $0.starCost <= stars }
    }

    /// Everything still ahead, in unlock order. Named `upcoming` rather than
    /// "locked" because the child-facing framing is "coming next", never
    /// "you don't have this".
    public static func upcomingItems(atStars stars: Int) -> [PondItem] {
        items.filter { $0.starCost > stars }
    }

    /// The next thing this child will unlock, or `nil` once the pond is complete.
    ///
    /// Boundary behaviour is deliberate: at *exactly* an item's price that item
    /// is already unlocked, so the answer is the one after it.
    public static func nextUnlock(after stars: Int) -> PondItem? {
        items.first { $0.starCost > stars }
    }

    /// The item that follows a given item in the unlock order.
    public static func nextUnlock(after id: PondItemID) -> PondItem? {
        let next = rank(of: id) + 1
        guard next < items.count else { return nil }
        return items[next]
    }

    /// How far this child is toward their next unlock.
    ///
    /// Always returns a value, including when the pond is finished, so the UI
    /// never has to render an "empty" state for a child who has everything.
    public static func progressTowardNext(stars: Int) -> PondUnlockProgress {
        let earned = max(0, stars)
        let next = nextUnlock(after: earned)
        // The bar starts filling from the last thing they unlocked, not from
        // zero, so a child at 590 stars sees a nearly-empty bar toward 616
        // rather than a bar that looks 96% full and then barely moves.
        let previousThreshold = unlockedItems(atStars: earned).last?.starCost ?? 0
        return PondUnlockProgress(
            stars: earned,
            next: next,
            previousThreshold: previousThreshold
        )
    }

    // MARK: - Scene geometry

    /// The vertical band a layer's items live in, in unit coordinates.
    ///
    /// Bands overlap on purpose — a reed rooted at the shore rises over the
    /// water, and a butterfly in the foreground may be level with the far bank.
    /// The band is a sanity envelope for layout, not a clipping rectangle.
    public static func verticalBand(for layer: PondLayer) -> ClosedRange<Double> {
        switch layer {
        case .sky: 0.02...0.24
        case .backdrop: 0.20...0.44
        case .water: 0.44...0.84
        case .shore: 0.40...0.92
        case .decoration: 0.28...0.86
        case .character: 0.46...0.82
        case .foreground: 0.46...0.98
        }
    }

    /// Minimum unit distance between two items drawn into the same layer.
    ///
    /// Items in the same layer are composited without depth, so two anchors on
    /// top of each other read as one broken sprite rather than two decorations.
    /// Different layers may share a point — that is how a frog sits on a lily
    /// pad and a chime hangs in a tree.
    public static let minimumSameLayerSeparation = 0.05

    // MARK: - Placement table

    private struct Placement {
        let rank: Int
        let category: PondItemCategory
        let layer: PondLayer
        let anchor: PondAnchor

        init(_ rank: Int, _ category: PondItemCategory, _ layer: PondLayer, x: Double, y: Double, scale: Double) {
            self.rank = rank
            self.category = category
            self.layer = layer
            self.anchor = PondAnchor(x: x, y: y, scale: scale)
        }
    }

    /// Order, category, depth and position for every decoration.
    ///
    /// This switch is exhaustive with no `default`, which is the real
    /// enforcement behind "every item is priced": adding a `PondItemID` case
    /// fails to compile until it is given a rank and a place in the scene.
    /// `PondCatalogTests` covers the rest — that the ranks are a permutation,
    /// that prices only ever rise, and that no two anchors collide.
    private static func placement(for id: PondItemID) -> Placement {
        switch id {
        // -- Day one. The pond becomes recognisably a pond. --
        case .lilyPadSmall:     Placement(0, .plants, .water, x: 0.46, y: 0.640, scale: 1.00)
        case .reedsLeft:        Placement(1, .plants, .shore, x: 0.13, y: 0.600, scale: 1.00)
        case .fishOrange:       Placement(2, .creatures, .water, x: 0.66, y: 0.710, scale: 0.90)
        case .cloudPuff:        Placement(3, .weather, .sky, x: 0.74, y: 0.110, scale: 1.00)
        case .flowerYellow:     Placement(4, .plants, .shore, x: 0.26, y: 0.830, scale: 0.85)

        // -- First week. Both banks come in, so the scene stops leaning. --
        case .lilyPadLarge:     Placement(5, .plants, .water, x: 0.59, y: 0.570, scale: 1.10)
        case .reedsRight:       Placement(6, .plants, .shore, x: 0.87, y: 0.580, scale: 1.00)
        case .stoneSmall:       Placement(7, .stones, .shore, x: 0.19, y: 0.760, scale: 0.80)
        case .tadpoleFriend:    Placement(8, .creatures, .water, x: 0.40, y: 0.740, scale: 0.75)
        case .flowerPink:       Placement(9, .plants, .shore, x: 0.78, y: 0.830, scale: 0.85)

        // -- The scene gains life and depth. --
        case .butterflyBlue:    Placement(10, .creatures, .foreground, x: 0.30, y: 0.550, scale: 0.80)
        case .lilyFlower:       Placement(11, .plants, .water, x: 0.49, y: 0.585, scale: 0.70)
        case .cattails:         Placement(12, .plants, .shore, x: 0.08, y: 0.700, scale: 1.00)
        case .fishBlue:         Placement(13, .creatures, .water, x: 0.72, y: 0.660, scale: 0.85)
        case .sunbeam:          Placement(14, .weather, .sky, x: 0.22, y: 0.090, scale: 1.00)

        // -- Small creatures, close in, where a child looks first. --
        case .mushroomCluster:  Placement(15, .plants, .shore, x: 0.33, y: 0.880, scale: 0.80)
        case .snail:            Placement(16, .creatures, .shore, x: 0.65, y: 0.870, scale: 0.60)
        case .frogFriendGreen:  Placement(17, .creatures, .character, x: 0.44, y: 0.620, scale: 1.00)
        case .butterflyYellow:  Placement(18, .creatures, .foreground, x: 0.70, y: 0.520, scale: 0.80)
        case .flowerPurple:     Placement(19, .plants, .shore, x: 0.90, y: 0.740, scale: 0.85)

        // -- The rainbow: the first unmistakable "look what I made" moment. --
        case .rainbow:          Placement(20, .weather, .sky, x: 0.50, y: 0.160, scale: 1.00)
        case .stoneStack:       Placement(21, .stones, .shore, x: 0.11, y: 0.840, scale: 0.90)
        case .dragonfly:        Placement(22, .creatures, .foreground, x: 0.52, y: 0.500, scale: 0.70)
        case .waterLilyCluster: Placement(23, .plants, .water, x: 0.28, y: 0.680, scale: 1.00)
        case .duckling:         Placement(24, .creatures, .water, x: 0.62, y: 0.790, scale: 0.80)

        // -- The far bank fills in; the pond gets a horizon. --
        case .fernPatch:        Placement(25, .plants, .backdrop, x: 0.16, y: 0.380, scale: 1.00)
        case .ladybug:          Placement(26, .creatures, .foreground, x: 0.24, y: 0.900, scale: 0.50)
        case .signpost:         Placement(27, .structures, .shore, x: 0.80, y: 0.900, scale: 0.90)
        case .lantern:          Placement(28, .structures, .decoration, x: 0.86, y: 0.460, scale: 0.80)
        case .turtleRock:       Placement(29, .creatures, .water, x: 0.38, y: 0.550, scale: 0.90)

        // -- Built things: a pond somebody lives beside. --
        case .birdhouse:        Placement(30, .structures, .backdrop, x: 0.82, y: 0.320, scale: 0.90)
        case .pebblePath:       Placement(31, .stones, .shore, x: 0.48, y: 0.900, scale: 1.20)
        case .frogFriendBlue:   Placement(32, .creatures, .character, x: 0.60, y: 0.545, scale: 1.00)
        case .driftwood:        Placement(33, .stones, .shore, x: 0.06, y: 0.500, scale: 0.90)
        case .blossomTree:      Placement(34, .plants, .backdrop, x: 0.10, y: 0.280, scale: 1.30)

        // -- The long tail: big, slow, and worth the wait. --
        case .windChime:        Placement(35, .structures, .decoration, x: 0.16, y: 0.400, scale: 0.70)
        case .clubhouse:        Placement(36, .structures, .backdrop, x: 0.50, y: 0.330, scale: 1.20)
        case .pondSwing:        Placement(37, .structures, .decoration, x: 0.28, y: 0.520, scale: 1.10)
        case .starLantern:      Placement(38, .structures, .decoration, x: 0.68, y: 0.400, scale: 0.80)
        case .fireflies:        Placement(39, .creatures, .foreground, x: 0.86, y: 0.660, scale: 0.90)
        case .moonReflection:   Placement(40, .weather, .water, x: 0.52, y: 0.800, scale: 1.00)
        }
    }
}

/// How close a child is to their next pond unlock.
///
/// Everything here is phrased forwards — what is coming, how much of the way
/// there they are. There is no "missing", no deficit and no countdown that can
/// run out.
public struct PondUnlockProgress: Hashable, Sendable {
    /// Stars the child has now.
    public let stars: Int
    /// The next item, or `nil` when the pond is complete.
    public let next: PondItem?
    /// The price of the last item they unlocked, or 0 before the first one.
    public let previousThreshold: Int

    public init(stars: Int, next: PondItem?, previousThreshold: Int) {
        self.stars = stars
        self.next = next
        self.previousThreshold = previousThreshold
    }

    /// Whether every item in the catalog is unlocked.
    public var isComplete: Bool { next == nil }

    /// Stars still to earn before the next unlock. Zero when complete.
    public var starsRemaining: Int {
        guard let next else { return 0 }
        return max(0, next.starCost - stars)
    }

    /// Stars earned since the previous unlock.
    public var starsEarnedTowardNext: Int { max(0, stars - previousThreshold) }

    /// Size of the current step, used to draw the progress bar.
    public var starsInCurrentStep: Int {
        guard let next else { return 0 }
        return max(1, next.starCost - previousThreshold)
    }

    /// 0...1 fill for the progress bar. 1 when the pond is complete.
    public var fraction: Double {
        guard next != nil else { return 1 }
        return min(1, max(0, Double(starsEarnedTowardNext) / Double(starsInCurrentStep)))
    }
}
