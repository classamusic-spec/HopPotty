import Foundation
import Observation
import HopPottyCore

/// Potty Path: the walk from where you are playing to the bathroom.
///
/// ## Not a maze
///
/// There is one route and it is the same route every time. No levels, no
/// difficulty ramp, no branching and nothing to fall off, because the game is a
/// *rehearsal* — the trip to the bathroom as a short, friendly journey with a
/// beginning and an end — and a rehearsal that changes under you rehearses
/// nothing. A child who has done it four times knows where the corners are, and
/// knowing is the point.
///
/// An earlier version laid the route out as a 4×5 grid of identical ellipses.
/// That is a puzzle about a grid; this is a walk through a house. The stops are
/// authored at real places in an illustrated home — the toy corner, past the
/// sofa, along the hallway, through the door, to the potty — each in unit
/// coordinates over `scene.games.pottyPath`, each with a name a child hears.
///
/// ## Nothing here can go wrong
///
/// No timer, no lives, no enemies, no failure state and no wrong move. `walk`
/// only ever moves Hop *along* the route, and a drag that wanders is simply
/// projected back onto it, so the path cannot be lost, cannot be walked into a
/// dead end and cannot end anywhere except the bathroom. A tap on the scenery is
/// ignored rather than corrected — a stray finger is not a mistake worth telling
/// a three-year-old about.
@MainActor
@Observable
final class PottyPathSession: MiniGameSession {

    /// One place on the walk.
    struct Stop: Identifiable, Hashable {
        let index: Int
        /// Where it is over the illustrated home, in unit coordinates.
        let x: Double
        let y: Double
        /// What it is called, so VoiceOver can say where Hop is going and the
        /// goal is not "the unlabelled square".
        let name: HopCopyEntry
        var id: Int { index }

        var point: CGPoint { CGPoint(x: x, y: y) }
    }

    /// The route, start to potty.
    ///
    /// Six stops with two turns is a journey a two-year-old can see the whole
    /// of. The coordinates trace the drawn path in `Art/scenes/games-pottyPath.svg`:
    /// out of the toy corner at the bottom left, along the rug, up the hall,
    /// through the bathroom door on the right, and in.
    static let route: [Stop] = [
        Stop(index: 0, x: 0.13, y: 0.86, name: GameCopy.pathStart),
        Stop(index: 1, x: 0.30, y: 0.80, name: GameCopy.pathRug),
        Stop(index: 2, x: 0.47, y: 0.72, name: GameCopy.pathHall),
        Stop(index: 3, x: 0.63, y: 0.64, name: GameCopy.pathHall),
        Stop(index: 4, x: 0.76, y: 0.57, name: GameCopy.pathDoor),
        Stop(index: 5, x: 0.86, y: 0.50, name: GameCopy.pathGoal),
    ]

    let game = MiniGameCatalog.pottyPath

    /// How far along the route Hop is, as a position in `route`'s index space.
    ///
    /// A `Double` rather than an `Int` because a finger dragging him is
    /// continuous: at 2.4 he is four tenths of the way from the third stop to
    /// the fourth, and the view draws him there. Taps move it a whole step;
    /// drags move it smoothly. Both are the same number.
    private(set) var progress: Double = 0
    private(set) var isFinished = false

    /// The last stop Hop has actually reached, for VoiceOver and for the cue.
    var currentStop: Stop { Self.route[min(Self.route.count - 1, max(0, Int(progress.rounded(.down))))] }

    /// The stop the child is being invited toward. `nil` once he has arrived.
    var nextStop: Stop? {
        let next = Int(progress.rounded(.down)) + 1
        guard progress < Double(Self.route.count - 1), next < Self.route.count else { return nil }
        return Self.route[next]
    }

    /// Whether Hop is standing at the potty. Drives his wave.
    var hasArrived: Bool { progress >= Double(Self.route.count - 1) - 0.001 }

    var completion: Double {
        progress / Double(max(1, Self.route.count - 1))
    }

    // MARK: - Playing

    /// Hop's place on the screen right now, in unit coordinates.
    ///
    /// Interpolated along the route rather than snapped to a stop, so a finger
    /// dragging him moves him rather than teleporting him at a threshold.
    var position: CGPoint {
        let clamped = min(max(progress, 0), Double(Self.route.count - 1))
        let low = Int(clamped.rounded(.down))
        let high = min(low + 1, Self.route.count - 1)
        let t = clamped - Double(low)
        let a = Self.route[low]
        let b = Self.route[high]
        return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// A tap on the next stop. Hop walks one whole step.
    func step(to stop: Stop) {
        guard let next = nextStop, stop.index == next.index else { return }
        walk(to: Double(next.index))
    }

    /// A finger dragging Hop. `point` is where the finger is, in unit
    /// coordinates over the scene.
    ///
    /// The finger is *projected onto the route*: whatever it does, Hop stays on
    /// the path. Dragging backwards walks him back, which is allowed — a child
    /// retracing their steps has not made a mistake — but the round only ends at
    /// the far end.
    func drag(to point: CGPoint) {
        walk(to: Self.nearestProgress(to: point))
    }

    /// Moves Hop to a place on the route, and notices if that place is the potty.
    private func walk(to target: Double) {
        progress = min(max(target, 0), Double(Self.route.count - 1))
        if hasArrived { isFinished = true }
    }

    /// Where on the route a point is, as a position in index space.
    ///
    /// Projects onto each segment in turn and keeps the nearest. Six segments of
    /// arithmetic per drag update, no allocation, no trigonometry.
    static func nearestProgress(to point: CGPoint) -> Double {
        var best = 0.0
        var bestDistance = Double.greatestFiniteMagnitude
        for index in 0..<(route.count - 1) {
            let a = route[index]
            let b = route[index + 1]
            let vx = b.x - a.x
            let vy = b.y - a.y
            let lengthSquared = vx * vx + vy * vy
            guard lengthSquared > 0 else { continue }
            let t = min(1, max(0, ((Double(point.x) - a.x) * vx + (Double(point.y) - a.y) * vy) / lengthSquared))
            let dx = Double(point.x) - (a.x + vx * t)
            let dy = Double(point.y) - (a.y + vy * t)
            let distance = dx * dx + dy * dy
            guard distance < bestDistance else { continue }
            bestDistance = distance
            best = Double(index) + t
        }
        return best
    }

    func restart() {
        progress = 0
        isFinished = false
    }

    func finish() { isFinished = true }
}
