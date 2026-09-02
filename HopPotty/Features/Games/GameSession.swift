import Foundation
import HopPottyCore

/// The little that all the mini-games share.
///
/// This is deliberately not a game engine. There is no scene graph, no entity
/// system, no scheduler and no shared physics — a handful of thirty-second toys
/// do not need one, and the one that gets built anyway is the thing nobody can
/// change later. What they genuinely share is the *shape of a round*, which is
/// four properties and two methods.
///
/// ## What the type forbids
///
/// There is no score, no lives, no timer and no failure case, and there is
/// nowhere to add one without changing this protocol:
///
/// * `completion` is how much of the board is done, for the host's quiet
///   progress dots. It is never rendered as a number, a percentage or a
///   ranking — see `GameHostView`.
/// * `isFinished` is the only terminal state. `MiniGameCompletion` has three
///   cases and all of them end well.
/// * nothing counts a mistake, because none of the games has one. A mismatched
///   pair simply floats back; a bubble that is missed stays put; a fly that
///   drifts off the screen comes round again.
@MainActor
protocol MiniGameSession: AnyObject {
    /// The catalog entry this round is playing.
    var game: MiniGame { get }
    /// Whether the board has nothing left to offer. For a `.whenChildIsDone`
    /// game this stays false until the child says so.
    var isFinished: Bool { get }
    /// 0...1 of the board completed. Host chrome only; never shown as a score.
    var completion: Double { get }
    /// Whether this round reached the ending that walks the child into the
    /// guided routine. See ``MiniGameRoundResult/handOffStep``.
    var reachedHandOff: Bool { get }
    /// Puts the board back to a fresh state. Used by "Play again".
    func restart()
    /// Ends the round now, at the child's request. Always legal.
    func finish()
}

extension MiniGameSession {
    /// Almost no game hands off. Only Fly Snack overrides this, and only when it
    /// reached the full-tummy ending rather than being left early.
    var reachedHandOff: Bool { false }
}

/// A game whose board keeps moving while the child watches it.
///
/// Flies drift, a ball bounces, water swirls. The model owns those positions in
/// unit space and steps them forward when the view's clock says how much time
/// passed; the model itself imports no SwiftUI and holds no timer, so it can be
/// typechecked and unit-tested on Linux like every other piece of logic.
///
/// ## Why a coarse tick, and how Reduce Motion is honoured
///
/// The clock ticks at ``GameClock/tick`` — twice a second, not sixty times.
/// Movement between two ticks is drawn by a motion *token*
/// (`.hopAnimation(.childArrive, value:)`), which means the one Reduce Motion
/// reader in the app decides how a fly gets from A to B: a spring when motion is
/// on, a two-tenths cross-fade when it is not. No game reads
/// `accessibilityReduceMotion`, and no game can forget to.
///
/// ## The outer edge
///
/// Every conforming game finishes on its own within ``roundLimit`` even if the
/// child only watches. That is a product rule, not a convenience: a toy that
/// waits forever for a tap is a toy a child can be stuck in. Nothing counts
/// down on screen and nothing is taken away — the board simply finishes the
/// story it started, and earns the same star it would have earned anyway.
@MainActor
protocol TimedMiniGameSession: MiniGameSession {
    /// The longest a round may run before the board finishes itself. Held at or
    /// under `MiniGameCatalog.targetDurationRange.upperBound`.
    static var roundLimit: TimeInterval { get }
    /// Steps the board forward. Called from the view's clock with the real
    /// elapsed time, so a dropped frame or a backgrounded app does not desync
    /// the board from the story it is telling.
    func advance(by seconds: TimeInterval)
}

/// What a finished round produces.
///
/// One reason, one star, whatever happened on the board. A round that a child
/// left after four seconds and a round they played to the last bubble earn the
/// same thing, because the star is for having a go.
struct MiniGameRoundResult: Equatable, Sendable {
    let gameID: MiniGameID
    let rewardReason: RewardReason
    /// The routine step the caller should open next, or `nil` to go back to the
    /// game list.
    ///
    /// This is the whole hand-off mechanism. Fly Snack's story is *eat, feel it,
    /// go*, and it only lands if going to the potty is what actually happens
    /// next — so the round reports where it wants the child taken instead of
    /// navigating there itself. The step comes from
    /// `MiniGameCompletion.handOffStep`, which reads the first step off
    /// `PottyRoutineContent`, so reordering the routine moves the hand-off with
    /// it rather than stranding it on a step that is no longer first.
    ///
    /// It is `nil` for every other game, and `nil` for a hand-off game the child
    /// left early: being walked into the bathroom is the *ending* of that story,
    /// not a toll for having opened the game.
    let handOffStep: PottyRoutineStepID?

    init(game: MiniGame, reachedHandOff: Bool = false) {
        self.gameID = game.id
        self.rewardReason = game.rewardReason
        self.handOffStep = reachedHandOff ? game.completion.handOffStep : nil
    }

    init(session: some MiniGameSession) {
        self.init(game: session.game, reachedHandOff: session.reachedHandOff)
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

    /// A value in `0...1`, to `1/1000`. Enough resolution for a position on a
    /// board and coarse enough to stay readable in a debugger.
    mutating func unit() -> Double {
        Double(next(upperBound: 1001)) / 1000
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
