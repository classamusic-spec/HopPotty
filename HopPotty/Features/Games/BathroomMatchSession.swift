import Foundation
import Observation
import HopPottyCore

/// Bathroom Match: put each thing where it goes.
///
/// ## A drag, not a memory game
///
/// Three large objects sit on a shelf — soap, toilet paper, a towel — and three
/// places wait above them: the sink, the toilet, a pair of wet hands. The child
/// picks an object up and carries it to a place. That is the whole game.
///
/// An earlier version was a pairs game: six identical cards in two columns, tap
/// one then tap another. It taught the same three facts but it taught them as a
/// *memory task*, and the thing a two-year-old actually knows about soap is
/// where soap lives, not which card it was under.
///
/// ## Nothing here can be got wrong
///
/// An object put somewhere it does not belong floats back to the shelf and Hop
/// says "Almost! Try another spot." — the same sentence the quizzes use, once,
/// warmly. There is no cross, no red, no sound, no shake, no count, no attempt
/// tally and nothing that could be summed into a score. `place(_:on:)` returns
/// whether the object stayed, and the only thing that ever reads that is the
/// animation.
///
/// The calm one of the three. `MiniGameCompletion.whenChildIsDone` means it has
/// no ending of its own: when the last object lands the board quietly deals
/// another set, and the round ends when the child taps "All done".
@MainActor
@Observable
final class BathroomMatchSession: MiniGameSession {

    /// One thing on the shelf.
    struct Object: Identifiable, Hashable {
        let pairID: String
        let illustration: HopIllustrationKey
        let label: HopCopyEntry
        /// True once it is sitting where it belongs.
        var isPlaced = false

        var id: String { pairID }
    }

    /// One place it could go.
    struct Destination: Identifiable, Hashable {
        let pairID: String
        let illustration: HopIllustrationKey
        let label: HopCopyEntry
        /// The object that has landed here, if any.
        var holds: HopIllustrationKey?

        var id: String { pairID }
        var isFilled: Bool { holds != nil }
    }

    /// What just happened, so the board can answer once and then be quiet.
    enum Answer: Equatable {
        /// The object stayed. `pairID` names it, for the settle animation.
        case landed(String)
        /// The object floated back. `pairID` names it, for the bounce.
        case returned(String)
    }

    let game = MiniGameCatalog.bathroomMatch

    /// Three of the four pairs, dealt.
    private(set) var objects: [Object] = []
    private(set) var destinations: [Destination] = []
    /// The most recent answer, or `nil` when nothing has happened yet. Cleared
    /// by the view once it has been shown, so it never lingers on the board.
    private(set) var lastAnswer: Answer?
    private(set) var isFinished = false
    /// How many boards the child has cleared. Drives nothing but the reshuffle —
    /// it is never shown, and it is not a score.
    private(set) var boardsCleared = 0

    /// How many pairs are on one board. Three: a shelf a two-year-old can take
    /// in at a glance, and three drop targets big enough to hit with a fist.
    static let boardSize = 3

    private var shuffleSeed: UInt64

    init(seed: UInt64 = 424_242) {
        shuffleSeed = seed
        deal()
    }

    var completion: Double {
        let placed = objects.filter(\.isPlaced).count
        return Double(placed) / Double(max(1, objects.count))
    }

    // MARK: - Playing

    /// Puts `object` on `destination`.
    ///
    /// Returns whether it stayed there, which is the only thing the caller needs
    /// in order to choose an animation. Nothing else is recorded either way.
    @discardableResult
    func place(_ object: Object, on destination: Destination) -> Bool {
        guard !object.isPlaced, !destination.isFilled else { return false }

        guard object.pairID == destination.pairID else {
            lastAnswer = .returned(object.pairID)
            return false
        }

        if let index = objects.firstIndex(where: { $0.id == object.id }) {
            objects[index].isPlaced = true
        }
        if let index = destinations.firstIndex(where: { $0.id == destination.id }) {
            destinations[index].holds = object.illustration
        }
        lastAnswer = .landed(object.pairID)

        if objects.allSatisfy(\.isPlaced) {
            boardsCleared += 1
            // A fresh board rather than an ending: this game finishes when the
            // child says so, and taking the toy away mid-play is not a reward.
            shuffleSeed = shuffleSeed &+ 7_919
            deal(keepingAnswer: true)
        }
        return true
    }

    /// A drop that landed on no destination at all — on the floor, on the wall,
    /// half off the screen. Not an error and not an attempt: the object goes
    /// back and nothing is said.
    func returnToShelf(_ object: Object) {
        lastAnswer = nil
    }

    /// Clears the answer once the board has finished showing it.
    func acknowledgeAnswer() { lastAnswer = nil }

    func restart() {
        boardsCleared = 0
        isFinished = false
        deal()
    }

    func finish() { isFinished = true }

    private func deal(keepingAnswer: Bool = false) {
        if !keepingAnswer { lastAnswer = nil }
        var shuffler = GameShuffler(seed: shuffleSeed)
        let pairs = Array(shuffler.shuffled(GameCopy.matchPairs).prefix(Self.boardSize))
        // The destinations are shuffled again against the objects, so the answer
        // is never "the one straight above it".
        objects = pairs.map {
            Object(pairID: $0.id, illustration: $0.objectIllustration, label: $0.objectLabel)
        }
        destinations = shuffler.shuffled(pairs).map {
            Destination(
                pairID: $0.id,
                illustration: $0.destinationIllustration,
                label: $0.destinationLabel
            )
        }
    }
}
