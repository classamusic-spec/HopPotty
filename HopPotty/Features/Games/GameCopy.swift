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
            + boardEntries
    }
}

// MARK: - The five newer boards

/// Names for the things the newer boards move around.
///
/// `MiniGameCatalog` names each game, its opening line, its closing line and
/// everything Hop says out loud. It does not name *a fly*, *the flusher* or *the
/// third spot on the path*, because those are properties of a board rather than
/// of the catalog — and a child using VoiceOver needs every one of them.
///
/// Same rule as the section above: real `HopCopyEntry` values under `games.`
/// keys, never literals in a view (`Docs/CONTRACTS.md` §5), and they move into
/// `HopCopy` unchanged the day Core grows a home for per-board strings.
extension GameCopy {

    // MARK: Fly Snack

    /// One fly, whatever colour it is drawn in. The three sprites are three
    /// drawings of the same thing, so they get one word: colour is decoration
    /// here and never meaning (`Docs/CONTRACTS.md` §6).
    enum Fly: String, CaseIterable, Identifiable, Sendable {
        case blue, green, gold

        var id: String { rawValue }
        var illustration: HopIllustrationKey { HopIllustrationKey(rawValue: "icon.games.fly." + rawValue) }
    }

    static let fly = HopCopyEntry.child("games.flySnack.a11y.fly", "A fly")
    static let flySnackHop = HopCopyEntry.child("games.flySnack.a11y.hop", "Hop on his lily pad")
    static let flySnackHopFull = HopCopyEntry.child("games.flySnack.a11y.hopFull", "Hop, with a full tummy")
    /// The meter is labelled but never given a value: a running tally read out
    /// after every catch is a score, and this game does not have one.
    static let tummyMeter = HopCopyEntry.child("games.flySnack.a11y.tummy", "Hop's tummy")

    // MARK: Mud Off

    /// One patch on Hop's hands. Three kinds so that two patches side by side
    /// are distinguishable by name rather than by colour.
    enum Mess: String, CaseIterable, Identifiable, Sendable {
        case brown, green, paint

        var id: String { rawValue }
        var illustration: HopIllustrationKey { HopIllustrationKey(rawValue: "icon.games.mud." + rawValue) }

        var label: HopCopyEntry {
            switch self {
            case .brown: .child("games.mudOff.a11y.mud.brown", "A patch of mud")
            case .green: .child("games.mudOff.a11y.mud.green", "A patch of pond weed")
            case .paint: .child("games.mudOff.a11y.mud.paint", "A patch of paint")
            }
        }
    }

    /// Every patch is a button as well as a swipe target, so a child who cannot
    /// yet drag — or who is using VoiceOver or Switch Control — plays the same
    /// board rather than a described one.
    static let wipeHint = HopCopyEntry.child("games.mudOff.a11y.wipeHint", "Swipe across it, or tap it")
    static let mudOffHop = HopCopyEntry.child("games.mudOff.a11y.hop", "Hop, holding out his hands")
    static let sparkle = HopCopyEntry.child("games.mudOff.a11y.sparkle", "Sparkles")
    static let waterTap = HopCopyEntry.child("games.mudOff.a11y.tap", "The tap")

    // MARK: Listen to Your Body

    static let ball = HopCopyEntry.child("games.bodySignal.a11y.ball", "Hop's ball")
    static let thoughtBubble = HopCopyEntry.child("games.bodySignal.a11y.bubble", "Hop's bubble")
    static let bodySignalHop = HopCopyEntry.child("games.bodySignal.a11y.hop", "Hop, playing")

    // MARK: Flush and Wave

    static let flusher = HopCopyEntry.child("games.flushWave.a11y.flusher", "The flusher")
    static let swirl = HopCopyEntry.child("games.flushWave.a11y.swirl", "The water, swirling")
    static let flushWaveTap = HopCopyEntry.child("games.flushWave.a11y.tap", "The tap")
    static let flushWaveHop = HopCopyEntry.child("games.flushWave.a11y.hop", "Hop, by the toilet")

    // MARK: Potty Order

    /// One card, and the place it belongs on the path. `order` is the whole
    /// rule of the game, so it lives on the case rather than in the board.
    enum OrderCard: String, CaseIterable, Identifiable, Sendable {
        case pantsDown, sit, wipe, wash

        var id: String { rawValue }
        var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
        var illustration: HopIllustrationKey { HopIllustrationKey(rawValue: "icon.games.card." + rawValue) }

        var label: HopCopyEntry {
            switch self {
            case .pantsDown: .child("games.pottyOrder.card.pantsDown", "Pants down")
            case .sit: .child("games.pottyOrder.card.sit", "Sit on the potty")
            case .wipe: .child("games.pottyOrder.card.wipe", "Wipe")
            case .wash: .child("games.pottyOrder.card.wash", "Wash hands")
            }
        }

        /// What the empty slot for this card is called. Words rather than
        /// numbers, because "spot three of four" is a fact about a list and
        /// "then" is a fact about a story.
        var slotLabel: HopCopyEntry {
            switch self {
            case .pantsDown: .child("games.pottyOrder.slot.first", "First")
            case .sit: .child("games.pottyOrder.slot.second", "Next")
            case .wipe: .child("games.pottyOrder.slot.third", "Then")
            case .wash: .child("games.pottyOrder.slot.fourth", "Last")
            }
        }
    }

    static let pickUpHint = HopCopyEntry.child(
        "games.pottyOrder.a11y.pickUpHint",
        "Drag it to a spot, or pick it up and tap a spot"
    )
    static let slotFilled = HopCopyEntry.child("games.pottyOrder.a11y.slotFilled", "Filled")

    // MARK: The hand-off ending

    /// The button that ends a `MiniGameCompletion.handOffToRoutine` round.
    ///
    /// It names where the child is going rather than saying "All done", because
    /// that ending does not go back to the game list — it goes to the bathroom.
    /// Same words as the shield's invitation, on purpose: a child who has
    /// learned what "Let's go!" leads to should find the same phrase here.
    static let handOffButton = HopCopyEntry.child(
        "games.handOff.button",
        "Let's go!",
        comment: "Ends a mini-game that finishes by starting the guided routine. Should match the shield's invitation in tone."
    )

    /// The entries declared in this extension, folded into ``allEntries``.
    static var boardEntries: [HopCopyEntry] {
        [fly, flySnackHop, flySnackHopFull, tummyMeter]
            + Mess.allCases.map(\.label)
            + [wipeHint, mudOffHop, sparkle, waterTap]
            + [ball, thoughtBubble, bodySignalHop]
            + [flusher, swirl, flushWaveTap, flushWaveHop]
            + OrderCard.allCases.flatMap { [$0.label, $0.slotLabel] }
            + [pickUpHint, slotFilled]
            + [handOffButton]
    }
}

// MARK: - Reaching a game's spoken lines by name

extension MiniGame {
    /// The voice line whose id ends in `name` — `line("tummyFull")` finds
    /// `games.flySnack.spoken.tummyFull`.
    ///
    /// By name rather than by index into `voiceLines`, because an index is a
    /// crash waiting for the day someone inserts a line in the middle, and
    /// because `voiceLines[2]` tells a reader nothing about what Hop says. When
    /// no line matches, the game's own closing line stands in: a renamed line
    /// should degrade to a warm sentence, never to an empty bubble.
    func line(_ name: String) -> HopPottyCore.HopVoiceLine {
        if let match = voiceLines.first(where: { $0.id.rawValue.hasSuffix("." + name) }) {
            return match
        }
        return voiceLines.first ?? HopPottyCore.HopVoiceLine(
            id: HopVoiceLineID(rawValue: id.rawValue + ".spoken.fallback"),
            text: (done ?? childDescription).value
        )
    }
}
