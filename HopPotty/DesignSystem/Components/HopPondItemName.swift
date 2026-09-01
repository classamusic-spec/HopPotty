import Foundation
import HopPottyCore

/// Child-facing names for pond decorations.
///
/// Table rather than a derived string: "waterLilyCluster" split on capitals
/// gives "water lily cluster", which is a debug label, not something you read
/// to a four-year-old. Moves to `HopCopy` with the rest of the child copy.
public extension PondItemID {
    var displayName: String {
        Self.names[self] ?? "a new friend"
    }

    private static let names: [PondItemID: String] = [
        .lilyPadSmall: "a little lily pad",
        .lilyPadLarge: "a big lily pad",
        .lilyFlower: "a lily flower",
        .reedsLeft: "some tall reeds",
        .reedsRight: "more tall reeds",
        .cattails: "cattails",
        .stoneSmall: "a smooth stone",
        .stoneStack: "a stack of stones",
        .flowerYellow: "a yellow flower",
        .flowerPink: "a pink flower",
        .flowerPurple: "a purple flower",
        .fishOrange: "an orange fish",
        .fishBlue: "a blue fish",
        .tadpoleFriend: "a tadpole friend",
        .butterflyBlue: "a blue butterfly",
        .butterflyYellow: "a yellow butterfly",
        .dragonfly: "a dragonfly",
        .snail: "a snail",
        .ladybug: "a ladybug",
        .rainbow: "a rainbow",
        .sunbeam: "a sunbeam",
        .cloudPuff: "a fluffy cloud",
        .frogFriendGreen: "a green frog friend",
        .frogFriendBlue: "a blue frog friend",
        .clubhouse: "the clubhouse",
        .lantern: "a lantern",
        .signpost: "a signpost",
        .waterLilyCluster: "a patch of water lilies",
        .mushroomCluster: "a cluster of mushrooms",
        .fernPatch: "a patch of ferns",
        .duckling: "a duckling",
        .turtleRock: "turtle rock",
        .starLantern: "a star lantern",
        .windChime: "a wind chime",
        .birdhouse: "a birdhouse",
        .pebblePath: "a pebble path",
        .driftwood: "a piece of driftwood",
        .blossomTree: "a blossom tree",
        .fireflies: "fireflies",
        .moonReflection: "the moon on the water",
        .pondSwing: "a pond swing",
    ]
}
