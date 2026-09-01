import Foundation
import HopPottyCore

/// The little that all three mini-games share.
///
/// This is deliberately not a game engine. There is no scene graph, no entity
/// system, no scheduler and no shared physics — three thirty-second toys do not
/// need one, and the one that gets built anyway is the thing nobody can change
/// later. What they genuinely share is the *shape of a round*, which is four
/// properties and two methods.
///
/// ## What the type forbids
///
/// There is no score, no lives, no timer and no failure case, and there is
/// nowhere to add one without changing this protocol:
///
/// * `completion` is how much of the board is done, for the host's quiet
///   progress dots. It is never rendered as a number, a percentage or a
///   ranking — see `GameHostView`.
/// * `isFinished` is the only terminal state. `MiniGameCompletion` has exactly
///   two cases and both of them end well.
/// * nothing counts a mistake, because none of the three games has one. A
///   mismatched pair simply floats back; a bubble that is missed stays put.
@MainActor
protocol MiniGameSession: AnyObject {
    /// The catalog entry this round is playing.
    var game: MiniGame { get }
    /// Whether the board has nothing left to offer. For a `.whenChildIsDone`
    /// game this stays false until the child says so.
    var isFinished: Bool { get }
    /// 0...1 of the board completed. Host chrome only; never shown as a score.
    var completion: Double { get }
    /// Puts the board back to a fresh state. Used by "Play again".
    func restart()
    /// Ends the round now, at the child's request. Always legal.
    func finish()
}

/// What a finished round produces.
///
/// One reason, one star, whatever happened on the board. A round that a child
/// left after four seconds and a round they played to the last bubble earn the
/// same thing, because the star is for having a go.
struct MiniGameRoundResult: Equatable, Sendable {
    let gameID: MiniGameID
    let rewardReason: RewardReason

    init(game: MiniGame) {
        self.gameID = game.id
        self.rewardReason = game.rewardReason
    }
}

/// Deterministic small-integer randomness for board layout.
///
/// Games lay out with this rather than `Int.random(in:)` so a preview, a
/// screenshot and a failing test all show the same board. It is the same
/// xorshift64 `QuizQuestion.options(shuffledBy:)` uses, for the same reason.
struct GameShuffler {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    }

    mutating func next(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Int(state % UInt64(upperBound))
    }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var result = items
        var index = result.count - 1
        while index > 0 {
            result.swapAt(index, next(upperBound: index + 1))
            index -= 1
        }
        return result
    }
}
