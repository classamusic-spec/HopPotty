import Foundation
import Observation
import HopPottyCore

/// Listen to Your Body: the signal arrives in the middle of playing.
///
/// That is the whole design. A child who is told "go before we leave" is being
/// asked to obey a clock; a child who notices a feeling while they are busy is
/// learning the thing this app exists for. So Hop bounces his ball, and three
/// times a bubble appears beside him, and the child's job is only to notice.
///
/// ## There is no wrong tap
///
/// Tapping Hop when no bubble is showing gets a giggle, not a correction —
/// exploring the screen is what a two-year-old does with a screen, and it should
/// find warmth. Tapping nothing at all is fine too: after
/// ``signalPatience`` Hop notices his own body and goes, and the round carries on
/// exactly as if the child had tapped. Nothing is counted either way, and there
/// is nothing on screen that could be read as a tally.
@MainActor
@Observable
final class BodySignalSession: TimedMiniGameSession {

    /// Where the round is in its loop.
    enum Beat: Hashable {
        /// Ball in the air, no bubble.
        case playing
        /// The bubble is up and Hop is wiggling.
        case signalling
        /// The hop that starts the trip. `HopPose.jump`.
        case hoppingOut
        /// Off the right-hand edge. `HopPose.walk`.
        case away
        /// Coming back. `HopPose.walk`.
        case returning
    }

    // MARK: - Shape of a round

    /// Three, and the game says so on the tin. Fewer is not a game; more is a
    /// chore.
    static let signalCount = 3
    /// Ball-bouncing time before a signal. Long enough that the bubble
    /// interrupts play rather than punctuating it.
    static let playGap: TimeInterval = 5
    /// How long the bubble waits before Hop notices it himself.
    static let signalPatience: TimeInterval = 8
    static let hopOutDuration: TimeInterval = 0.6
    static let awayDuration: TimeInterval = 1.6
    static let returnDuration: TimeInterval = 1.2
    /// The backstop. Three signals at their most patient come in under fifty
    /// seconds; this exists so the sentence "ends by itself" has no asterisk.
    static let roundLimit: TimeInterval = 85

    let game = MiniGameCatalog.bodySignal

    private(set) var beat: Beat = .playing
    /// How many signals have been seen through to Hop coming back. 0...3.
    private(set) var signalsAnswered = 0
    /// How many bubbles have appeared so far, answered or not.
    private(set) var signalsShown = 0
    /// Bumped by a tap on Hop with no bubble up. Drives nothing but a giggle.
    private(set) var giggles = 0
    private(set) var isFinished = false

    /// Which half of the bounce the ball is in. The model says up or down; the
    /// distance between the two is drawn by a motion token.
    private(set) var bounceStep = 0

    private var beatAge: TimeInterval = 0
    private var elapsed: TimeInterval = 0

    init() {}

    var completion: Double {
        Double(signalsAnswered) / Double(Self.signalCount)
    }

    /// Whether the thought bubble is on screen and tappable.
    var isSignalShowing: Bool { beat == .signalling }

    /// The ball's height, 0 at the ground and 1 at the top of the bounce.
    var ballHeight: Double { bounceStep.isMultiple(of: 2) ? 0.12 : 1 }

    /// Where Hop is across the board, in unit coordinates. Past 1 is off the
    /// right-hand edge, which is where the bathroom is in this game's fiction.
    var hopPosition: Double {
        switch beat {
        case .playing, .signalling: 0.42
        case .hoppingOut: 0.66
        case .away: 1.35
        case .returning: 0.42
        }
    }

    // MARK: - Playing

    /// The bubble was tapped. Hop says his line and goes.
    func answerSignal() {
        guard beat == .signalling else { return }
        beat = .hoppingOut
        beatAge = 0
    }

    /// Hop was tapped with no bubble up. A giggle, and nothing else at all.
    func tickle() {
        guard beat == .playing else { return }
        giggles += 1
    }

    // MARK: - The board moving on its own

    func advance(by seconds: TimeInterval) {
        guard !isFinished else { return }
        elapsed += seconds
        beatAge += seconds
        // The ball keeps bouncing through every beat, including the ones where
        // Hop has left: a ball that stopped dead when he walked off would read
        // as the game having broken.
        bounceStep += 1

        guard elapsed < Self.roundLimit else {
            isFinished = true
            return
        }

        switch beat {
        case .playing:
            guard beatAge >= Self.playGap else { return }
            beat = .signalling
            beatAge = 0
            signalsShown += 1
        case .signalling:
            // Not a deadline and not a miss: Hop's body is talking to Hop, and
            // he can hear it perfectly well on his own.
            guard beatAge >= Self.signalPatience else { return }
            answerSignal()
        case .hoppingOut:
            guard beatAge >= Self.hopOutDuration else { return }
            beat = .away
            beatAge = 0
        case .away:
            guard beatAge >= Self.awayDuration else { return }
            beat = .returning
            beatAge = 0
        case .returning:
            guard beatAge >= Self.returnDuration else { return }
            signalsAnswered += 1
            beatAge = 0
            if signalsAnswered >= Self.signalCount {
                isFinished = true
            } else {
                beat = .playing
            }
        }
    }

    // MARK: - Round

    func restart() {
        beat = .playing
        beatAge = 0
        elapsed = 0
        bounceStep = 0
        signalsAnswered = 0
        signalsShown = 0
        giggles = 0
        isFinished = false
    }

    func finish() { isFinished = true }
}
