import Foundation

/// A decoration a child can unlock for Hop's Pond.
public struct PondItem: Identifiable, Hashable, Codable, Sendable {
    public let id: PondItemID
    public let category: PondItemCategory
    /// Stars required to unlock. Deterministic and visible in advance — the child
    /// always knows what is next and how far away it is. No randomness, no crates.
    public let starCost: Int
    /// The layer this item draws into, which fixes its depth in the scene.
    public let layer: PondLayer
    /// Where the item sits, in unit coordinates within the pond scene.
    public let anchor: PondAnchor

    public init(id: PondItemID, category: PondItemCategory, starCost: Int, layer: PondLayer, anchor: PondAnchor) {
        self.id = id
        self.category = category
        self.starCost = starCost
        self.layer = layer
        self.anchor = anchor
    }
}

/// Stable identifiers for pond decorations. A string-backed enum keeps saved
/// progress readable and survives reordering the catalog.
public enum PondItemID: String, Codable, CaseIterable, Sendable, Identifiable {
    case lilyPadSmall, lilyPadLarge, lilyFlower
    case reedsLeft, reedsRight, cattails
    case stoneSmall, stoneStack
    case flowerYellow, flowerPink, flowerPurple
    case fishOrange, fishBlue, tadpoleFriend
    case butterflyBlue, butterflyYellow, dragonfly
    case snail, ladybug
    case rainbow, sunbeam, cloudPuff
    case frogFriendGreen, frogFriendBlue
    case clubhouse, lantern, signpost
    case waterLilyCluster, mushroomCluster, fernPatch
    case duckling, turtleRock
    case starLantern, windChime, birdhouse
    case pebblePath, driftwood, blossomTree
    case fireflies, moonReflection, pondSwing

    public var id: String { rawValue }
}

public enum PondItemCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case plants, creatures, structures, weather, stones
    public var id: String { rawValue }
}

/// Draw order within the pond scene, back to front.
public enum PondLayer: Int, Codable, CaseIterable, Sendable, Comparable {
    case sky = 0
    case backdrop = 1
    case water = 2
    case shore = 3
    case decoration = 4
    case character = 5
    case foreground = 6

    public static func < (lhs: PondLayer, rhs: PondLayer) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A position inside the pond scene, in unit space (0...1 on both axes) so the
/// same layout works at every size class without a second set of coordinates.
public struct PondAnchor: Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double
    /// Relative scale applied to the item's intrinsic size.
    public let scale: Double

    public init(x: Double, y: Double, scale: Double = 1) {
        self.x = x
        self.y = y
        self.scale = scale
    }
}

/// A child's unlocked pond state.
public struct PondProgress: Hashable, Codable, Sendable {
    public let childID: UUID
    public var unlocked: [PondItemID: Date]

    public init(childID: UUID, unlocked: [PondItemID: Date] = [:]) {
        self.childID = childID
        self.unlocked = unlocked
    }

    public func isUnlocked(_ item: PondItemID) -> Bool { unlocked[item] != nil }
    public var unlockedCount: Int { unlocked.count }
}
