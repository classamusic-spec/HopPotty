import Foundation
import Observation
import HopPottyCore

/// Bathroom Match: find the two that go together.
///
/// Soap goes with washing hands, paper goes with wiping, towel goes with
/// drying — the three pairings the routine has already taught, so the game is
/// recognition rather than instruction.
///
/// The calm one of the three. `MiniGameCompletion.whenChildIsDone` means it has
/// no ending of its own: when the last pair lands the board quietly offers
/// another set, and the round ends when the child taps "All done". There is
/// nothing to get wrong — two cards that do not go together simply let go of
/// each other, with no sound, no shake and nothing counted.
@MainActor
@Observable
final class BathroomMatchSession: MiniGameSession {

    /// One side of a pair on the board.
    struct Card: Identifiable, Hashable {
        enum Side: Hashable { case tool, use }

        let pairID: String
        let side: Side
        let illustration: HopIllustrationKey
        let label: HopCopyEntry
        var isMatched = false

        var id: String { pairID + "." + (side == .tool ? "tool" : "use") }
    }

    let game = MiniGameCatalog.bathroomMatch

    private(set) var tools: [Card] = []
    private(set) var uses: [Card] = []
    /// The card the child has picked up, if any. One at a time, so there is no
    /// state where three things are half-selected.
    private(set) var selected: Card?
    private(set) var isFinished = false
    /// How many boards the child has cleared. Drives nothing but the reshuffle.
    private(set) var boardsCleared = 0

    private var shuffleSeed: UInt64

    init(seed: UInt64 = 424_242) {
        shuffleSeed = seed
        deal()
    }

    var completion: Double {
        let matched = tools.filter(\.isMatched).count
        return Double(matched) / Double(max(1, tools.count))
    }

    // MARK: - Playing

    /// Picks a card up, or tries it against the one already held.
    func choose(_ card: Card) {
        guard !card.isMatched else { return }

        guard let held = selected else {
            selected = card
            return
        }

        // Tapping the same card again puts it back down. A child changing their
        // mind is not a wrong answer.
        if held.id == card.id {
            selected = nil
            return
        }

        if held.side != card.side, held.pairID == card.pairID {
            match(held.pairID)
        }
        // Anything else: both cards are simply released. Nothing is recorded,
        // nothing is said, and the same two can be tried again immediately.
        selected = nil
    }

    private func match(_ pairID: String) {
        for index in tools.indices where tools[index].pairID == pairID { tools[index].isMatched = true }
        for index in uses.indices where uses[index].pairID == pairID { uses[index].isMatched = true }

        if tools.allSatisfy(\.isMatched) {
            boardsCleared += 1
            // A fresh board rather than an ending: this game finishes when the
            // child says so, and taking the toy away mid-play is not a reward.
            shuffleSeed = shuffleSeed &+ 7_919
            deal()
        }
    }

    func restart() {
        boardsCleared = 0
        isFinished = false
        deal()
    }

    func finish() { isFinished = true }

    private func deal() {
        selected = nil
        var shuffler = GameShuffler(seed: shuffleSeed)
        let pairs = GameCopy.matchPairs
        tools = shuffler.shuffled(pairs).map {
            Card(pairID: $0.id, side: .tool, illustration: $0.toolIllustration, label: $0.toolLabel)
        }
        uses = shuffler.shuffled(pairs).map {
            Card(pairID: $0.id, side: .use, illustration: $0.useIllustration, label: $0.useLabel)
        }
    }
}
