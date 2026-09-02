import Foundation
import Observation
import HopPottyCore

/// Bubble Wash: rubbing foam across Hop's hands until they are clean.
///
/// ## What this is, and what it stopped being
///
/// It was six bubbles floating in a box, popped one at a time, five times over.
/// That is a mini-game, and this screen is not supposed to be one. It is the
/// signature moment of the whole app: a close-up of Hop's hands, and a child
/// rubbing them with a finger while foam appears under it.
///
/// So the model is not a list of targets to clear. It is a **field of patches
/// with coverage**:
///
/// * every patch of hand holds a `foam` value between 0 and 1;
/// * ``rub(on:at:radius:speed:)`` raises the foam on the patches under the finger,
///   by more when the finger is moving faster — a scrub, not a click;
/// * ``coverage`` is the mean of all of them, which is the only number this game
///   has and it is never shown as one. What the child sees is the foam.
///
/// ## What the type cannot express
///
/// There is no score, no points, no combo, no timer on screen and no failure.
/// `foam` only rises; there is no decay, nothing to lose, and no way to rub in
/// the "wrong" place — every patch is somewhere that needs washing.
///
/// The round ends by itself. At ``rinseThreshold`` coverage the water takes
/// over, Hop shakes his hands, and the screen leaves — nothing asks the child to
/// play again. `roundLimit` is the outer edge for a child who only watches: a
/// toy that waits forever for a tap is a toy a child can be stuck in.
///
/// ## Every patch is a button
///
/// Not a fallback bolted on for VoiceOver. A two-year-old who cannot yet drag,
/// and a child using Switch Control, play the same board by tapping patches
/// rather than a described version of it — which is the same promise the older
/// bubble board made, kept by ``cover(_:)``.
@MainActor
@Observable
final class BubbleWashSession: MiniGameSession, TimedMiniGameSession {

    /// Which hand a patch belongs to.
    ///
    /// Carried so the view never has to infer it from an x coordinate, and so a
    /// VoiceOver user hears "the back of Hop's left hand" rather than "patch 7".
    enum Hand: String, CaseIterable, Sendable {
        case left
        case right
    }

    /// One region of hand, and how much foam is on it.
    struct Patch: Identifiable, Hashable, Sendable {
        let id: Int
        let hand: Hand
        /// Position inside that hand's own box, 0...1 on both axes, so the view
        /// can move the hands around without the model knowing where they are.
        let x: Double
        let y: Double
        /// Relative size, for a field that does not look like graph paper.
        let scale: Double
        /// 0 = untouched, 1 = fully covered. Only ever rises.
        var foam: Double = 0

        var isCovered: Bool { foam >= 0.999 }
    }

    /// The beats of a wash, in the order they happen.
    enum Beat: Equatable, Sendable {
        /// Hands under the water, waiting for a pump of soap.
        case soap
        /// The whole of the game: rubbing foam across both hands.
        case rub
        /// The water takes over. Nothing to do; it lasts ``rinseDuration``.
        case rinse
        /// Hop shakes his hands, sparkles, "Squeaky clean!", and it ends.
        case done
    }

    let game = MiniGameCatalog.bubbleWash

    private(set) var beat: Beat = .soap
    private(set) var patches: [Patch] = []
    private(set) var isFinished = false
    /// Seconds spent in ``Beat/rinse``, for the view to draw the water with.
    private(set) var rinseElapsed: TimeInterval = 0

    private var elapsed: TimeInterval = 0
    private let seed: UInt64

    // MARK: - The numbers

    /// Eight patches a hand: enough that coverage feels continuous under a
    /// finger, few enough that each one is comfortably bigger than a fingertip.
    private static let patchesPerHand = 8
    /// Coverage at which the water takes over. Not 1: asking a three-year-old to
    /// find the last untouched pixel is the kind of completionism this game has
    /// no business teaching.
    static let rinseThreshold: Double = 0.9
    /// How long the rinse lasts. Long enough to read as water doing the work,
    /// short enough that nobody is waiting.
    static let rinseDuration: TimeInterval = 2.6
    /// The outer edge, comfortably inside `MiniGameCatalog.targetDurationRange`.
    /// A round that reaches it rinses like any other and earns the same star.
    static let roundLimit: TimeInterval = 55

    init(seed: UInt64 = 20_240_601) {
        self.seed = seed
        patches = Self.makePatches(seed: seed)
    }

    // MARK: - Reading the board

    /// Mean coverage across both hands, 0...1.
    ///
    /// Host chrome only, and never rendered as a number, a percentage or a
    /// ranking — `GameHostView` draws it as five quiet dots. On this screen it
    /// is not drawn at all: the foam is the readout.
    var coverage: Double {
        guard !patches.isEmpty else { return 0 }
        return patches.reduce(0) { $0 + $1.foam } / Double(patches.count)
    }

    var completion: Double { coverage }

    /// The patches of one hand, in the order they were laid out.
    func patches(on hand: Hand) -> [Patch] {
        patches.filter { $0.hand == hand }
    }

    /// How much Hop is enjoying this, 0...1.
    ///
    /// Drives how far down at his own hands he looks and how much of a smile he
    /// has — the "Hop tracks the interaction" half of the brief. It is a
    /// *presentation* value derived from coverage, deliberately not a state: it
    /// cannot get stuck, and nothing waits for it.
    var delight: Double {
        switch beat {
        case .soap: 0.2
        case .rub: min(1, coverage * 1.1)
        case .rinse, .done: 1
        }
    }

    /// The line above the basin.
    ///
    /// The ending is not a wash stage — it is a *description of the hands*, and
    /// "Squeaky clean!" is the whole reward this game gives out. Everything
    /// before it names the beat the child is in.
    var line: HopCopyEntry {
        beat == .done ? GameCopy.bubbleWashDone : stage.label
    }

    /// The named beat, for the board's accessibility label.
    var stage: GameCopy.WashStage {
        switch beat {
        case .soap: .soap
        case .rub: .rub
        case .rinse: .rinse
        case .done: .dry
        }
    }

    // MARK: - Playing

    /// A pump of soap. The only thing to do on the first beat, and tapping
    /// anywhere on the basin counts as one — a child aiming at a bottle with a
    /// whole hand should not have to hit it.
    func pump() {
        guard beat == .soap else { return }
        beat = .rub
    }

    /// Covers one patch completely. Idempotent, and never a mistake: a child
    /// tapping the same nice spot twice is a child playing.
    func cover(_ id: Int) {
        guard beat == .soap || beat == .rub else { return }
        if beat == .soap { beat = .rub }
        guard let index = patches.firstIndex(where: { $0.id == id }) else { return }
        patches[index].foam = 1
        settleIfCovered()
    }

    /// Foams everything the finger is over, on one hand.
    ///
    /// `point` and `radius` are in that hand's own unit space, so the view
    /// passes size-relative values and the model never learns where on the
    /// screen a hand happens to be. The hand is a parameter rather than
    /// something inferred from `x`, because the two hands share a coordinate
    /// space and a finger on one of them must not foam the other.
    ///
    /// `speed` is how fast the finger is travelling in that space per event: a
    /// scrub lays down more foam than a finger resting, which is what makes the
    /// gesture feel like rubbing rather than like painting.
    func rub(on hand: Hand, at point: CGPoint, radius: Double, speed: Double = 0) {
        guard beat == .soap || beat == .rub else { return }
        if beat == .soap { beat = .rub }
        // A resting finger still works — a child who cannot drag holds still and
        // the foam still arrives, just more slowly.
        let strength = 0.22 + min(0.5, speed * 2.2)
        for index in patches.indices where patches[index].hand == hand && patches[index].foam < 1 {
            let dx = patches[index].x - point.x
            let dy = patches[index].y - point.y
            let distance = (dx * dx + dy * dy).squareRoot()
            let reach = radius * patches[index].scale
            guard distance <= reach else { continue }
            // Softer at the edge of the finger than under the middle of it, so
            // foam grows outward from the path rather than in hard discs.
            let falloff = 1 - (distance / max(reach, 0.0001)) * 0.55
            patches[index].foam = min(1, patches[index].foam + strength * falloff)
        }
        settleIfCovered()
    }

    /// Moves to the rinse once the hands are covered enough.
    private func settleIfCovered() {
        guard beat == .rub, coverage >= Self.rinseThreshold else { return }
        beat = .rinse
        rinseElapsed = 0
    }

    // MARK: - Time

    /// Steps the rinse, and holds the outer edge of the round.
    ///
    /// Nothing here counts down on screen and nothing is taken away: reaching
    /// `roundLimit` rinses the hands exactly as finishing them would, and earns
    /// the same single star.
    func advance(by seconds: TimeInterval) {
        elapsed += seconds
        switch beat {
        case .soap, .rub:
            if elapsed >= Self.roundLimit {
                beat = .rinse
                rinseElapsed = 0
            }
        case .rinse:
            rinseElapsed += seconds
            if rinseElapsed >= Self.rinseDuration {
                beat = .done
                isFinished = true
            }
        case .done:
            break
        }
    }

    // MARK: - Round

    func restart() {
        beat = .soap
        isFinished = false
        elapsed = 0
        rinseElapsed = 0
        patches = Self.makePatches(seed: seed)
    }

    /// Ends the round now, at the child's request. Always legal, and it ends the
    /// same way every other round of this game ends.
    func finish() {
        beat = .done
        isFinished = true
    }

    // MARK: - Layout

    /// A seeded scatter over each hand.
    ///
    /// Seeded rather than random so a preview, a screenshot and a failing test
    /// all show the same hands. Kept inside 0.16…0.84 on both axes so no patch
    /// lands half off the drawing, and no patch is smaller than a fingertip.
    private static func makePatches(seed: UInt64) -> [Patch] {
        var shuffler = GameShuffler(seed: seed)
        var result: [Patch] = []
        for (handIndex, hand) in Hand.allCases.enumerated() {
            for index in 0..<patchesPerHand {
                result.append(
                    Patch(
                        id: handIndex * 100 + index,
                        hand: hand,
                        x: 0.18 + Double(shuffler.next(upperBound: 65)) / 100,
                        y: 0.20 + Double(shuffler.next(upperBound: 60)) / 100,
                        scale: 0.85 + Double(shuffler.next(upperBound: 40)) / 100
                    )
                )
            }
        }
        return result
    }
}

// MARK: - Words

extension GameCopy {
    /// What Hop says when the hands are clean.
    ///
    /// Declared here beside the game rather than as a literal in the view
    /// (`Docs/CONTRACTS.md` §5), under the same `games.` key shape as the rest of
    /// `GameCopy`, and it moves into `HopCopy` unchanged the day Core grows a
    /// home for per-board strings.
    static let bubbleWashDone = HopCopyEntry.child(
        "games.bubbleWash.done",
        "Squeaky clean!",
        comment: "The end of Bubble Wash. A description of the hands, never a score."
    )

    /// One patch of hand, for a child playing with VoiceOver or Switch Control.
    static let bubbleWashPatch = HopCopyEntry.child(
        "games.bubbleWash.a11y.patch",
        "A part of Hop's hand that still needs washing"
    )

    /// The soap dispenser, which is the whole of the first beat.
    static let bubbleWashSoap = HopCopyEntry.child("games.bubbleWash.a11y.soap", "The soap")

    /// Hop's hands, named separately so two green shapes side by side are two
    /// things to a screen reader as well as to an eye.
    static let bubbleWashLeftHand = HopCopyEntry.child("games.bubbleWash.a11y.leftHand", "Hop's left hand")
    static let bubbleWashRightHand = HopCopyEntry.child("games.bubbleWash.a11y.rightHand", "Hop's right hand")
}
