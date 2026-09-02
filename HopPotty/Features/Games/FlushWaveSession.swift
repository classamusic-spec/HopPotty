import Foundation
import Observation
import HopPottyCore

/// Flush and Wave: one cause, one effect, under the child's own finger.
///
/// This is the game for the child who finds the flush frightening. Everything
/// about it is arranged so that the loud thing happens *because they did it* and
/// stops when it is finished: nothing starts on its own while they are looking
/// away, nothing repeats unless they ask, and there is nowhere they have to be
/// when it does. That is also why the routine's Flush step is skippable —
/// familiarity is built here, in play.
///
/// The board is a toy rather than a task: once the water has gone round and Hop
/// has waved, the flusher is still there to press again. Washing is what ends
/// the round, because washing is what ends a real visit.
@MainActor
@Observable
final class FlushWaveSession: TimedMiniGameSession {

    enum Beat: Hashable {
        /// The flusher is the only thing to do.
        case ready
        /// Water going round.
        case swirling
        /// Hop waving it goodbye. `HopPose.wave`.
        case waving
        /// Both the flusher and the tap are offered. The tap ends the round.
        case washReady
        case washing
        case done
    }

    // MARK: - Shape of a round

    static let swirlDuration: TimeInterval = 2.0
    static let waveDuration: TimeInterval = 2.2
    static let washDuration: TimeInterval = 2.4
    /// How long the flusher waits to be pressed before it goes round by itself.
    /// A child watching rather than tapping still sees the whole thing.
    static let readyPatience: TimeInterval = 20
    /// The shortest round limit in the catalog, because this is the shortest
    /// game: one cause, one effect, and hands.
    static let roundLimit: TimeInterval = 60

    let game = MiniGameCatalog.flushWave

    private(set) var beat: Beat = .ready
    private(set) var isFinished = false
    /// How many times the water has gone round. Drives the spoken line and
    /// nothing else — it is not shown, not compared and not remembered.
    private(set) var flushes = 0

    private var beatAge: TimeInterval = 0
    private var elapsed: TimeInterval = 0

    init() {}

    var completion: Double {
        switch beat {
        case .ready: return 0
        case .swirling: return 0.3
        case .waving: return 0.55
        case .washReady: return 0.75
        case .washing, .done: return 1
        }
    }

    /// 0...1 through one turn of the water.
    var swirlProgress: Double {
        guard beat == .swirling else { return 0 }
        return min(1, beatAge / Self.swirlDuration)
    }

    /// 0...1 through the hand-washing at the end.
    var washProgress: Double {
        switch beat {
        case .washing: return min(1, beatAge / Self.washDuration)
        case .done: return 1
        case .ready, .swirling, .waving, .washReady: return 0
        }
    }

    /// Whether the flusher is on screen and pressable.
    var isFlusherOffered: Bool { beat == .ready || beat == .washReady }
    /// Whether the tap is on screen. Only after the water has been round once,
    /// so the order a child learns here is the order of a real visit.
    var isTapOffered: Bool { beat == .washReady }

    // MARK: - Playing

    func flush() {
        guard isFlusherOffered else { return }
        flushes += 1
        beat = .swirling
        beatAge = 0
    }

    func wash() {
        guard beat == .washReady else { return }
        beat = .washing
        beatAge = 0
    }

    // MARK: - The board moving on its own

    func advance(by seconds: TimeInterval) {
        guard !isFinished else { return }
        elapsed += seconds
        beatAge += seconds

        // The outer edge. A round that has been sitting on the flusher or the
        // tap for a minute finishes itself, with the same ending it would have
        // had anyway.
        if elapsed >= Self.roundLimit, beat == .ready || beat == .washReady {
            beat = .washing
            beatAge = 0
            return
        }

        switch beat {
        case .ready:
            guard beatAge >= Self.readyPatience else { return }
            flush()
        case .swirling:
            guard beatAge >= Self.swirlDuration else { return }
            beat = .waving
            beatAge = 0
        case .waving:
            guard beatAge >= Self.waveDuration else { return }
            beat = .washReady
            beatAge = 0
        case .washReady:
            break
        case .washing:
            guard beatAge >= Self.washDuration else { return }
            beat = .done
            isFinished = true
        case .done:
            break
        }
    }

    // MARK: - Round

    func restart() {
        beat = .ready
        beatAge = 0
        elapsed = 0
        flushes = 0
        isFinished = false
    }

    func finish() {
        isFinished = true
        beat = .done
    }
}
