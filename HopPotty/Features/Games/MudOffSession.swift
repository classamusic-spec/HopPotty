import Foundation
import Observation
import HopPottyCore

/// Mud Off: Hop played by the pond, and his hands show it.
///
/// The point of the game is the *reason* for washing, not the washing: a child
/// who can see something on their hands and take it off has a reason for the
/// twenty seconds at the sink that is not "because I said so". So the mud comes
/// off first and the water comes second, in that order, every time.
///
/// ## Nothing here can be got wrong
///
/// A swipe that misses does nothing at all. A patch cannot be made worse, cannot
/// come back, and is never counted. The board has one direction and it is
/// forward.
///
/// ## Two ways to wipe
///
/// A swipe across a patch wipes it, and so does a tap on it. That is not a
/// fallback bolted on for VoiceOver: a two-year-old whose finger cannot yet
/// drag, a child using Switch Control and a child using VoiceOver all play the
/// same board rather than a described one.
@MainActor
@Observable
final class MudOffSession: TimedMiniGameSession {

    /// One patch on Hop's hands.
    struct Patch: Identifiable, Hashable {
        let id: Int
        let kind: GameCopy.Mess
        /// Unit position on the board.
        let x: Double
        let y: Double
        /// Relative size, so four patches do not read as a row of stamps.
        let scale: Double
        /// 0 untouched, 1 gone.
        var wipe: Double = 0
        /// Where the finger was heading the last time it crossed this patch, in
        /// radians. The patch shrinks and fades *along* that line, which is what
        /// makes the wipe look like the child's own movement rather than a fade.
        var wipeAngle: Double = 0

        var isGone: Bool { wipe >= 1 }
    }

    /// The board's one direction.
    enum Beat: Hashable {
        /// Mud on the hands. The only beat with anything to swipe.
        case wiping
        /// Hands clean, tap not yet turned on.
        case tapReady
        /// Water running, bubbles rising.
        case water
        /// The finish.
        case sparkle
        case done
    }

    // MARK: - Shape of a round

    /// How far a finger has to travel across a patch to take it off, in board
    /// widths. About a thumb's width on a phone: one decisive swipe.
    static let wipeDistance: Double = 0.12
    /// How close the finger has to be, relative to the patch's own size.
    static let wipeRadius: Double = 0.09
    static let waterDuration: TimeInterval = 2.0
    static let sparkleDuration: TimeInterval = 1.4
    /// After this much swiping, any mud still on Hop's hands rinses off by
    /// itself and the tap becomes the thing to do. Not a deadline — nothing
    /// counts down and nothing is withdrawn — just the promise that a child who
    /// is watching rather than swiping still gets to the sparkle.
    static let wipingLimit: TimeInterval = 55
    /// The same promise for the tap.
    static let tapPatience: TimeInterval = 15
    static let roundLimit: TimeInterval = 80

    let game = MiniGameCatalog.mudOff

    private(set) var patches: [Patch] = []
    private(set) var beat: Beat = .wiping
    private(set) var isFinished = false
    /// Bumped whenever a patch comes off, so the view can pulse Hop's line.
    private(set) var patchesCleared = 0

    private let seed: UInt64
    private var beatAge: TimeInterval = 0

    init(seed: UInt64 = 1_414_213) {
        self.seed = seed
        patches = Self.makePatches(seed: seed)
    }

    var completion: Double {
        switch beat {
        case .wiping:
            let cleaned = Double(patches.filter(\.isGone).count) / Double(max(1, patches.count))
            return cleaned * 0.7
        case .tapReady: return 0.7
        case .water: return 0.85
        case .sparkle, .done: return 1
        }
    }

    /// 0...1 through the running water, for the bubbles.
    var waterProgress: Double {
        guard beat == .water else { return beat == .wiping || beat == .tapReady ? 0 : 1 }
        return min(1, beatAge / Self.waterDuration)
    }

    /// 0...1 through the sparkle at the end.
    var sparkleProgress: Double {
        switch beat {
        case .sparkle: min(1, beatAge / Self.sparkleDuration)
        case .done: 1
        case .wiping, .tapReady, .water: 0
        }
    }

    // MARK: - Playing

    /// Wipes across the board.
    ///
    /// `travelled` is how far the finger moved since the last report, in board
    /// widths, so the amount of mud a movement takes off is a property of the
    /// movement rather than of how often the system delivered it.
    func wipe(at point: CGPoint, travelled: Double, angle: Double) {
        guard beat == .wiping, travelled > 0 else { return }
        for index in patches.indices where !patches[index].isGone {
            let dx = patches[index].x - point.x
            let dy = patches[index].y - point.y
            guard (dx * dx + dy * dy).squareRoot() <= Self.wipeRadius * patches[index].scale else { continue }
            patches[index].wipeAngle = angle
            patches[index].wipe = min(1, patches[index].wipe + travelled / Self.wipeDistance)
            if patches[index].isGone { noteCleared() }
        }
    }

    /// Takes a patch off in one go. What a tap does, and what a swipe that
    /// already crossed most of the patch amounts to.
    func wipeAway(_ id: Int) {
        guard beat == .wiping else { return }
        guard let index = patches.firstIndex(where: { $0.id == id }), !patches[index].isGone else { return }
        patches[index].wipe = 1
        noteCleared()
    }

    /// Turns the water on. Only ever offered once the hands are clean, because
    /// the order is the lesson.
    func turnOnWater() {
        guard beat == .tapReady else { return }
        beat = .water
        beatAge = 0
    }

    private func noteCleared() {
        patchesCleared += 1
        if patches.allSatisfy(\.isGone) {
            beat = .tapReady
            beatAge = 0
        }
    }

    // MARK: - The board moving on its own

    func advance(by seconds: TimeInterval) {
        guard !isFinished else { return }
        beatAge += seconds

        switch beat {
        case .wiping:
            guard beatAge >= Self.wipingLimit else { return }
            for index in patches.indices { patches[index].wipe = 1 }
            beat = .tapReady
            beatAge = 0
        case .tapReady:
            guard beatAge >= Self.tapPatience else { return }
            turnOnWater()
        case .water:
            guard beatAge >= Self.waterDuration else { return }
            beat = .sparkle
            beatAge = 0
        case .sparkle:
            guard beatAge >= Self.sparkleDuration else { return }
            beat = .done
            isFinished = true
        case .done:
            break
        }
    }

    // MARK: - Round

    func restart() {
        patches = Self.makePatches(seed: seed)
        beat = .wiping
        beatAge = 0
        patchesCleared = 0
        isFinished = false
    }

    func finish() {
        isFinished = true
        beat = .done
    }

    // MARK: - Layout

    /// Three to five patches, scattered across the band where Hop's hands are.
    /// Seeded, so a screenshot and a failing test show the same hands.
    private static func makePatches(seed: UInt64) -> [Patch] {
        var shuffler = GameShuffler(seed: seed)
        let count = 3 + shuffler.next(upperBound: 3)
        let kinds = GameCopy.Mess.allCases
        return (0..<count).map { index in
            Patch(
                id: index,
                kind: kinds[shuffler.next(upperBound: kinds.count)],
                // The band across Hop's outstretched hands, kept clear of the
                // edges so no patch is half off the board.
                x: 0.28 + shuffler.unit() * 0.44,
                y: 0.50 + shuffler.unit() * 0.24,
                scale: 0.85 + shuffler.unit() * 0.45
            )
        }
    }
}
