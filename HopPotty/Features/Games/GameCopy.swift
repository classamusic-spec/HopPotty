import Foundation
import HopPottyCore

/// The words the three mini-games need that `MiniGameCatalog` does not carry.
///
/// `MiniGameCatalog` names each game, describes it to the child and states what
/// it practises for the caregiver. It does not name the *steps inside* Bubble
/// Wash or the *pairs* in Bathroom Match, because those are properties of the
/// boards rather than of the catalog.
///
/// As with `PondItemNaming`, these are declared as real `HopCopyEntry` values
/// with proper `games.` keys rather than as literals in a view
/// (`Docs/CONTRACTS.md` §5), and they move into `HopCopy` unchanged the moment
/// Core grows a home for them. Every one is child audience, so the copy-safety
/// sweep covers them the day they land.
enum GameCopy {

    // MARK: - Bubble Wash

    /// One beat of hand-washing. Five, in the order the routine teaches them,
    /// matching `PottyRoutineContent.washStep`: soap, scrub, rinse, with wetting
    /// before and drying after.
    enum WashStage: String, CaseIterable, Identifiable {
        case water, soap, rub, rinse, dry

        var id: String { rawValue }

        var label: HopCopyEntry {
            switch self {
            case .water: .child("games.bubbleWash.stage.water", "Wet your hands")
            case .soap: .child("games.bubbleWash.stage.soap", "Pump the soap")
            case .rub: .child("games.bubbleWash.stage.rub", "Rub, rub, rub!")
            case .rinse: .child("games.bubbleWash.stage.rinse", "Rinse them off")
            case .dry: .child("games.bubbleWash.stage.dry", "Dry them well")
            }
        }

        /// The drawing for this beat, by the key Core already declares for the
        /// quiz pictures of the same objects.
        var illustration: HopIllustrationKey {
            switch self {
            case .water: "icon.quiz.quickSplash"
            case .soap: "icon.quiz.soap"
            case .rub: "icon.quiz.washHands"
            case .rinse: "icon.quiz.sink"
            case .dry: "icon.quiz.towel"
            }
        }
    }

    /// One bubble, for the child popping them with VoiceOver on.
    static let bubble = HopCopyEntry.child("games.bubbleWash.bubble", "A bubble")

    // MARK: - Bathroom Match

    /// One pair to find. Three of them, and they are the three the routine
    /// already taught: soap goes with hands, paper goes with wiping, towel goes
    /// with drying.
    struct MatchPair: Identifiable, Hashable {
        let id: String
        let toolIllustration: HopIllustrationKey
        let useIllustration: HopIllustrationKey
        let toolLabel: HopCopyEntry
        let useLabel: HopCopyEntry
    }

    /// The state of a card whose partner has been found. Announced by
    /// VoiceOver and drawn as a check mark, so the state never rests on the
    /// border colour alone.
    static let matched = HopCopyEntry.child("games.bathroomMatch.matched", "Found!")

    static let matchPairs: [MatchPair] = [
        MatchPair(
            id: "soap",
            toolIllustration: "icon.quiz.soap",
            useIllustration: "icon.quiz.washHands",
            toolLabel: .child("games.bathroomMatch.pair.soap.tool", "Soap"),
            useLabel: .child("games.bathroomMatch.pair.soap.use", "Washing hands")
        ),
        MatchPair(
            id: "paper",
            toolIllustration: "icon.quiz.toiletPaper",
            useIllustration: "icon.quiz.wipe",
            toolLabel: .child("games.bathroomMatch.pair.paper.tool", "Toilet paper"),
            useLabel: .child("games.bathroomMatch.pair.paper.use", "Wiping")
        ),
        MatchPair(
            id: "towel",
            toolIllustration: "icon.quiz.towel",
            // The only key here Core has not already declared for a quiz
            // picture: there is no existing drawing of hands being dried, and
            // reusing the wiping-direction picture for it would teach the wrong
            // thing. Until the art lands, `HopArtwork` draws its placeholder.
            useIllustration: "icon.games.dryHands",
            toolLabel: .child("games.bathroomMatch.pair.towel.tool", "Towel"),
            useLabel: .child("games.bathroomMatch.pair.towel.use", "Drying hands")
        ),
    ]

    // MARK: - Potty Path

    /// What is at the end of the path. Named so VoiceOver can say where Hop is
    /// heading and so the goal is not "the unlabelled square".
    static let pathGoal = HopCopyEntry.child("games.pottyPath.goal.bathroom", "The bathroom")
    static let pathHop = HopCopyEntry.child("games.pottyPath.hopHere", "Hop is here")
    static let pathStep = HopCopyEntry.child("games.pottyPath.lilyPad", "A lily pad")

    /// Every entry here, so the copy-safety tests sweep them once they move.
    static var allEntries: [HopCopyEntry] {
        WashStage.allCases.map(\.label)
            + [bubble]
            + [matched]
            + matchPairs.flatMap { [$0.toolLabel, $0.useLabel] }
            + [pathGoal, pathHop, pathStep]
    }
}
