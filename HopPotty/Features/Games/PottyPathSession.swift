import Foundation
import Observation
import HopPottyCore

/// Potty Path: hop along the lily pads to the bathroom.
///
/// One path, the same one every time. There are no levels, no difficulty ramp
/// and no branching, because the game is a *rehearsal* — the trip to the
/// bathroom as a short, friendly journey with a beginning and an end — and a
/// rehearsal that changes under you rehearses nothing. A child who has done it
/// four times knows where the corners are, and knowing is the point.
///
/// There is also nothing to fall off. Only the next pad accepts a tap, so the
/// path cannot be lost, cannot be walked backwards into a dead end, and cannot
/// end anywhere except the bathroom.
@MainActor
@Observable
final class PottyPathSession: MiniGameSession {

    /// A pad's place on the little grid. Column and row, from the top-left.
    struct Pad: Identifiable, Hashable {
        let index: Int
        let column: Int
        let row: Int
        var id: Int { index }
    }

    static let columns = 4
    static let rows = 5

    /// The path, start to bathroom. Authored rather than generated: eight pads
    /// with two turns is a journey a two-year-old can see the whole of.
    static let path: [Pad] = [
        Pad(index: 0, column: 0, row: 4),
        Pad(index: 1, column: 1, row: 4),
        Pad(index: 2, column: 1, row: 3),
        Pad(index: 3, column: 1, row: 2),
        Pad(index: 4, column: 2, row: 2),
        Pad(index: 5, column: 2, row: 1),
        Pad(index: 6, column: 3, row: 1),
        Pad(index: 7, column: 3, row: 0),
    ]

    let game = MiniGameCatalog.pottyPath

    /// Where Hop is standing, as an index into `path`.
    private(set) var position = 0
    private(set) var isFinished = false

    var completion: Double {
        Double(position) / Double(max(1, Self.path.count - 1))
    }

    /// The only pad that accepts a tap. `nil` once Hop has arrived.
    var nextPad: Pad? {
        position + 1 < Self.path.count ? Self.path[position + 1] : nil
    }

    func isGoal(_ pad: Pad) -> Bool { pad.index == Self.path.count - 1 }

    // MARK: - Playing

    /// Hops forward one pad. Anything else is ignored rather than corrected —
    /// a stray tap on scenery is not a mistake worth telling a child about.
    func hop(to pad: Pad) {
        guard pad.index == position + 1 else { return }
        position = pad.index
        if position == Self.path.count - 1 { isFinished = true }
    }

    func restart() {
        position = 0
        isFinished = false
    }

    func finish() { isFinished = true }
}
