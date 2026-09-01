import Foundation
import Observation
import HopPottyCore

/// Bubble Wash: the five beats of hand-washing, one screenful of bubbles each.
///
/// The child rubs across the basin and the bubbles under their finger pop; when
/// the last one goes, the next beat arrives — water, soap, rub, rinse, dry.
/// After the fifth the round ends itself, which is what
/// `MiniGameCompletion.whenTaskComplete` means for this game.
///
/// Every bubble is *also* a button, at `HopHitTarget.childMinimum`. That is not
/// a fallback bolted on for VoiceOver: a two-year-old who cannot yet drag can
/// play the whole game by tapping, and a child using Switch Control or VoiceOver
/// gets the same board rather than a described one.
@MainActor
@Observable
final class BubbleWashSession: MiniGameSession {

    struct Bubble: Identifiable, Hashable {
        let id: Int
        /// Unit position inside the basin, 0...1 on both axes.
        let x: Double
        let y: Double
        let scale: Double
        var isPopped = false
    }

    let game = MiniGameCatalog.bubbleWash

    private(set) var stageIndex = 0
    private(set) var bubbles: [Bubble] = []
    private(set) var isFinished = false

    private let stages = GameCopy.WashStage.allCases
    /// Six is enough to feel like a handful of bubbles and few enough that a
    /// beat is over before a three-year-old's attention is.
    private static let bubblesPerStage = 6

    init(seed: UInt64 = 20_240_601) {
        self.seed = seed
        bubbles = Self.makeBubbles(stage: 0, seed: seed)
    }

    private let seed: UInt64

    var stage: GameCopy.WashStage { stages[min(stageIndex, stages.count - 1)] }

    var completion: Double {
        let done = Double(stageIndex * Self.bubblesPerStage + poppedCount)
        return min(1, done / Double(stages.count * Self.bubblesPerStage))
    }

    private var poppedCount: Int { bubbles.filter(\.isPopped).count }

    // MARK: - Playing

    /// Pops one bubble. Idempotent: popping an already-popped bubble is not a
    /// mistake, it is a child tapping the same nice spot twice.
    func pop(_ id: Int) {
        guard let index = bubbles.firstIndex(where: { $0.id == id }), !bubbles[index].isPopped else { return }
        bubbles[index].isPopped = true
        if bubbles.allSatisfy(\.isPopped) { advanceStage() }
    }

    /// Pops everything the finger is currently over. `radius` is in the same
    /// unit space as the bubbles, so the view passes a size-relative value and
    /// the model stays free of points.
    func rub(at point: CGPoint, radius: Double) {
        for bubble in bubbles where !bubble.isPopped {
            let dx = bubble.x - point.x
            let dy = bubble.y - point.y
            if (dx * dx + dy * dy).squareRoot() <= radius * bubble.scale { pop(bubble.id) }
        }
    }

    private func advanceStage() {
        guard stageIndex + 1 < stages.count else {
            isFinished = true
            return
        }
        stageIndex += 1
        bubbles = Self.makeBubbles(stage: stageIndex, seed: seed)
    }

    // MARK: - Round

    func restart() {
        stageIndex = 0
        isFinished = false
        bubbles = Self.makeBubbles(stage: 0, seed: seed)
    }

    func finish() { isFinished = true }

    /// A seeded scatter, kept away from the edges so no bubble is half off the
    /// basin and none is too small to hit.
    private static func makeBubbles(stage: Int, seed: UInt64) -> [Bubble] {
        var shuffler = GameShuffler(seed: seed &+ UInt64(stage) &* 7919)
        return (0..<bubblesPerStage).map { index in
            Bubble(
                id: stage * 100 + index,
                x: 0.16 + Double(shuffler.next(upperBound: 69)) / 100,
                y: 0.18 + Double(shuffler.next(upperBound: 65)) / 100,
                scale: 0.85 + Double(shuffler.next(upperBound: 40)) / 100
            )
        }
    }
}
