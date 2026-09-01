import Foundation
import HopPottyCore

/// What each pond decoration is called.
///
/// ## Why this is not in `HopCopy`
///
/// `PondCatalog` gives every item a price, a layer and an anchor, but no name,
/// while `HopCopy.pond.nextUnlock` needs one for its `itemName` slot ("3 more
/// stars and *a dragonfly* hops in!") and VoiceOver needs one for every
/// silhouette in the scene. Rather than put 41 bare string literals in a view —
/// which `Docs/CONTRACTS.md` §5 forbids, and rightly — the names are declared
/// here as real `HopCopyEntry` values with proper `pond.item.<id>.name` keys.
///
/// This follows the precedent `DesignSystem/Foundation/HopPresentationModels.swift`
/// already sets: a value the API contract needs, shaped exactly as it will be
/// when it lands in Core, living in the app layer until it does. **These entries
/// move into `HopCopy` unchanged**, at which point this file becomes a lookup
/// against the catalog and nothing else changes.
///
/// The names are written with their article ("a dragonfly", "an orange fish")
/// because that is the shape the sentence needs. Every one of them is a warm,
/// concrete noun a three-year-old can picture — the picture is the real name,
/// and this is what the picture is called out loud.
enum PondItemNaming {

    static func name(for id: PondItemID) -> HopCopyEntry {
        HopCopyEntry.child(
            "pond.item.\(id.rawValue).name",
            englishName(for: id),
            comment: "Name of one pond decoration, spoken aloud and used in \"N more stars and %@ hops in!\". Keep the article the target language needs for that sentence."
        )
    }

    /// Every name, for the copy-safety tests to sweep once these move to Core.
    static var allEntries: [HopCopyEntry] { PondItemID.allCases.map(name(for:)) }

    /// Exhaustive by construction: a new decoration cannot ship unnamed,
    /// because this switch stops compiling until it is given words.
    private static func englishName(for id: PondItemID) -> String {
        switch id {
        case .lilyPadSmall: "a little lily pad"
        case .lilyPadLarge: "a big lily pad"
        case .lilyFlower: "a lily flower"
        case .reedsLeft: "some tall reeds"
        case .reedsRight: "more tall reeds"
        case .cattails: "some cattails"
        case .stoneSmall: "a smooth stone"
        case .stoneStack: "a stack of stones"
        case .flowerYellow: "a yellow flower"
        case .flowerPink: "a pink flower"
        case .flowerPurple: "a purple flower"
        case .fishOrange: "an orange fish"
        case .fishBlue: "a blue fish"
        case .tadpoleFriend: "a tiny tadpole"
        case .butterflyBlue: "a blue butterfly"
        case .butterflyYellow: "a yellow butterfly"
        case .dragonfly: "a dragonfly"
        case .snail: "a slow snail"
        case .ladybug: "a ladybug"
        case .rainbow: "a rainbow"
        case .sunbeam: "a warm sunbeam"
        case .cloudPuff: "a puffy cloud"
        case .frogFriendGreen: "a green frog friend"
        case .frogFriendBlue: "a blue frog friend"
        case .clubhouse: "a pond clubhouse"
        case .lantern: "a little lantern"
        case .signpost: "a wooden signpost"
        case .waterLilyCluster: "a bunch of water lilies"
        case .mushroomCluster: "a cluster of mushrooms"
        case .fernPatch: "a patch of ferns"
        case .duckling: "a duckling"
        case .turtleRock: "a turtle on a rock"
        case .starLantern: "a star lantern"
        case .windChime: "a wind chime"
        case .birdhouse: "a birdhouse"
        case .pebblePath: "a pebble path"
        case .driftwood: "a piece of driftwood"
        case .blossomTree: "a blossom tree"
        case .fireflies: "some fireflies"
        case .moonReflection: "the moon on the water"
        case .pondSwing: "a pond swing"
        }
    }
}
