import Foundation
import Observation
import HopPottyCore

/// Fly Snack: Hop sits on his lily pad and the child feeds him.
///
/// This is the one game whose *ending* is the lesson. Hop eats, Hop's tummy
/// fills, Hop's tummy says potty time — and the round then hands the child
/// straight to the first step of the routine, because the chain only teaches
/// anything if what happens next is actually going to the potty. That hand-off
/// is reported, not performed: see ``reachedHandOff`` and
/// `MiniGameRoundResult.handOffStep`.
///
/// ## Nothing here can be missed
///
/// A fly that drifts off the edge is simply gone and another one comes; nothing
/// is counted, nothing is faster next time, and the meter never goes down. A
/// child who taps six times in ten seconds and a child who watches for a minute
/// reach the same ending, earn the same star and are taken to the same place.
///
/// ## The outer edge
///
/// `TimedMiniGameSession.roundLimit` is what makes the previous sentence true.
/// If the meter has not filled by then, Hop's tummy fills anyway — a frog who
/// has sat in the sun long enough needs the potty whether or not he caught the
/// flies — and the round ends with the same line, the same star and the same
/// hand-off. Nothing on screen counts down toward it.
@MainActor
@Observable
final class FlySnackSession: TimedMiniGameSession {

    /// One fly, drifting across the sky.
    struct Fly: Identifiable, Hashable {
        let id: Int
        let kind: GameCopy.Fly
        /// Unit position across the board, 0 at the left edge and 1 at the right.
        /// Flies enter and leave a little outside that, so they arrive rather
        /// than appear.
        var x: Double
        /// Unit height. Held in the upper two-thirds, above where Hop sits.
        let y: Double
        /// Units per second, signed: negative drifts left.
        let speed: Double
        /// How far the fly wanders up and down as it goes, in units.
        let wander: Double
        /// Where in its wander the fly started, so three flies do not bob in step.
        let wanderPhase: Double
        var age: TimeInterval = 0

        /// Where the fly is actually drawn: the drift, plus the wander.
        var drawnY: Double {
            y + wander * sin(wanderPhase + age * 1.6)
        }
    }

    /// The cloud a caught fly leaves.
    struct Puff: Identifiable, Hashable {
        /// How long the cloud lasts. On the piece rather than on the session so
        /// the piece can say how far through it is without reaching back into a
        /// main-actor type.
        static let lifetime: TimeInterval = 0.7

        let id: Int
        let x: Double
        let y: Double
        var age: TimeInterval = 0

        /// 0 at the catch, 1 when the puff has finished.
        var progress: Double { min(1, age / Self.lifetime) }
    }

    /// What Hop is doing. The view maps this onto a pose; the model does not
    /// know what a pose is.
    enum Beat: Hashable {
        /// Sitting, watching the sky. `HopPose.sit`.
        case hunting
        /// Tongue out. The associated value is the caught fly's `x`, which is
        /// all the view needs to turn Hop toward it.
        case snapping(towards: Double)
        /// Tummy full, holding it, wiggling. `HopPose.full`.
        case full
        /// Over. `isFinished` is already true by the time this is set.
        case done
    }

    // MARK: - Shape of a round

    /// Six, because it is the largest number of segments a two-year-old reads as
    /// "some, more, nearly, full" rather than counting.
    static let tummySegments = 6
    /// Three at a time: enough that there is always one to reach for, few enough
    /// that the sky is not busy.
    static let fliesOnScreen = 3
    /// How long the tongue is out. Long enough to see, short enough that it
    /// never feels like waiting for a turn.
    static let snapDuration: TimeInterval = 0.7
    /// The beat Hop holds the full pose for before the round hands off.
    static let fullDuration: TimeInterval = 2.6
    /// A caught fly is replaced after the puff has cleared, so the replacement
    /// does not appear inside the cloud the last one left.
    static let respawnDelay: TimeInterval = 0.9
    static let roundLimit: TimeInterval = 75

    let game = MiniGameCatalog.flySnack

    private(set) var flies: [Fly] = []
    private(set) var puffs: [Puff] = []
    private(set) var beat: Beat = .hunting
    /// Filled segments, 0...``tummySegments``. Only ever goes up.
    private(set) var caught = 0
    private(set) var isFinished = false
    private(set) var reachedHandOff = false
    /// Bumped every time a fly is caught, so a view can pulse the spoken line
    /// without diffing the meter.
    private(set) var catches = 0

    private let seed: UInt64
    private var shuffler: GameShuffler
    private var nextIdentifier = 0
    private var elapsed: TimeInterval = 0
    private var beatAge: TimeInterval = 0
    private var respawnCountdown: TimeInterval = 0

    init(seed: UInt64 = 6_180_339) {
        self.seed = seed
        self.shuffler = GameShuffler(seed: seed)
        deal()
    }

    var completion: Double {
        Double(caught) / Double(Self.tummySegments)
    }

    /// Whether Hop's tummy is full. The view uses it to choose the closing line.
    var isTummyFull: Bool {
        switch beat {
        case .full, .done: true
        case .hunting, .snapping: false
        }
    }

    // MARK: - Playing

    /// Catches a fly. The only thing a child can do on this board.
    ///
    /// A tap that arrives while the tongue is already out is ignored rather than
    /// queued: two tongues at once is not a thing a frog does, and a dropped tap
    /// during a 0.7-second flick costs a child nothing.
    func catchFly(_ id: Int) {
        guard !isFinished, case .hunting = beat else { return }
        guard let index = flies.firstIndex(where: { $0.id == id }) else { return }

        let fly = flies.remove(at: index)
        puffs.append(Puff(id: takeIdentifier(), x: fly.x, y: fly.drawnY))
        caught = min(Self.tummySegments, caught + 1)
        catches += 1
        beat = .snapping(towards: fly.x)
        beatAge = 0
        respawnCountdown = Self.respawnDelay
    }

    // MARK: - The board moving on its own

    func advance(by seconds: TimeInterval) {
        guard !isFinished else { return }
        elapsed += seconds
        beatAge += seconds

        drift(by: seconds)
        agePuffs(by: seconds)

        switch beat {
        case .hunting:
            replenish(by: seconds)
            if elapsed >= Self.roundLimit { fillTummy() }
        case .snapping:
            guard beatAge >= Self.snapDuration else { return }
            if caught >= Self.tummySegments || elapsed >= Self.roundLimit {
                fillTummy()
            } else {
                beat = .hunting
                beatAge = 0
            }
        case .full:
            guard beatAge >= Self.fullDuration else { return }
            beat = .done
            // The two lines that matter, in this order: the round is over, and
            // it is over in the way that hands the child on.
            reachedHandOff = true
            isFinished = true
        case .done:
            break
        }
    }

    /// Every fly moves; the ones that have left the sky are replaced rather than
    /// wrapped, so a fly never slides backwards across the board to re-enter.
    private func drift(by seconds: TimeInterval) {
        for index in flies.indices {
            flies[index].x += flies[index].speed * seconds
            flies[index].age += seconds
        }
        flies.removeAll { $0.x < -0.2 || $0.x > 1.2 }
    }

    private func agePuffs(by seconds: TimeInterval) {
        for index in puffs.indices { puffs[index].age += seconds }
        puffs.removeAll { $0.age >= Puff.lifetime }
    }

    private func replenish(by seconds: TimeInterval) {
        guard flies.count < Self.fliesOnScreen else { return }
        respawnCountdown -= seconds
        guard respawnCountdown <= 0 else { return }
        flies.append(makeFly())
        respawnCountdown = Self.respawnDelay
    }

    /// The ending, however it is reached. Same pose, same line, same hand-off.
    private func fillTummy() {
        caught = Self.tummySegments
        beat = .full
        beatAge = 0
    }

    // MARK: - Round

    func restart() {
        shuffler = GameShuffler(seed: seed)
        nextIdentifier = 0
        elapsed = 0
        beatAge = 0
        respawnCountdown = 0
        caught = 0
        catches = 0
        beat = .hunting
        isFinished = false
        reachedHandOff = false
        puffs = []
        deal()
    }

    /// The child tapping "All done". No hand-off: being walked to the bathroom
    /// is the ending of Hop's story, not a toll for having opened the game.
    func finish() {
        isFinished = true
        beat = .done
    }

    // MARK: - Layout

    private func deal() {
        flies = (0..<Self.fliesOnScreen).map { _ in makeFly(placedInSky: true) }
    }

    /// A fly entering from one edge, or — for the opening board — already part
    /// way across, so the game does not begin with three flies in a queue.
    private func makeFly(placedInSky: Bool = false) -> Fly {
        let travelsRight = shuffler.next(upperBound: 2) == 0
        // 7 to 10 seconds to cross, which is slow enough for a two-year-old's
        // finger and quick enough that the sky is never static.
        let speed = (0.10 + shuffler.unit() * 0.04) * (travelsRight ? 1 : -1)
        let entry = travelsRight ? -0.12 : 1.12
        return Fly(
            id: takeIdentifier(),
            kind: GameCopy.Fly.allCases[shuffler.next(upperBound: GameCopy.Fly.allCases.count)],
            x: placedInSky ? 0.15 + shuffler.unit() * 0.7 : entry,
            y: 0.14 + shuffler.unit() * 0.34,
            speed: speed,
            wander: 0.012 + shuffler.unit() * 0.02,
            wanderPhase: shuffler.unit() * 6.28,
            age: 0
        )
    }

    private func takeIdentifier() -> Int {
        defer { nextIdentifier += 1 }
        return nextIdentifier
    }
}
