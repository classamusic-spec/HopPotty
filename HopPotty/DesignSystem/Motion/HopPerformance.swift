import SwiftUI
import Observation
import HopPottyDesignTokens

// Hop's performance layer: the state machine that turns "what Hop is doing"
// into "what is drawn, where it is, and how it got there".
//
// ## Why a machine and not fifteen animations
//
// `HopPose` is a *drawing*. Fourteen drawings that cut between each other look
// like fourteen drawings. What makes a character read as authored is the space
// between them: a small counter-move before an action (anticipation), a settle
// after it (recovery), and a rule that says some changes are not allowed to
// happen in one frame — Hop cannot be asleep and then cheering, he has to wake
// up first (``HopPose/route(to:)``).
//
// So one type owns all of it. ``HopPerformer`` publishes a single
// ``HopFrame`` — pose, expression, and the body's offset, squash, lean and
// opacity — plus the spring that carries Hop *into* that frame. The view renders
// the frame and nothing else. Two consequences fall out for free:
//
// * **Interrupt safety.** Every frame is a complete, valid configuration. An
//   act that is cancelled mid-beat does not leave a half-applied transform
//   behind, because the next frame is absolute rather than a delta, and the
//   generation guard means a stale run can never write over a live one.
// * **Reduce Motion.** ``HopFrame/resolved(reduceMotion:)`` zeroes every
//   travelling quantity at *render* time, not at schedule time. Turning Reduce
//   Motion on mid-hop therefore puts Hop on the ground on the next frame rather
//   than at the end of the beat.
//
// ## What this layer may never do
//
// Nothing here escalates and nothing here nags. There is no timer that makes
// Hop do something bigger the longer nobody taps, no idle behaviour that grows,
// and no act that a screen does not explicitly ask for. Ambient life keeps Hop
// alive; it never performs to win attention back (`Docs/ChildSafety.md` §1.4).

// MARK: - Expression

/// The small, continuous adjustments that ride on top of a pose: where the eyes
/// are pointed, how much they are squeezed shut with pleasure, how open the
/// mouth is, and a degree or two of head tilt.
///
/// Kept apart from ``HopPose`` on purpose. The poses are one-to-one with
/// `Scripts/hop-art.js` and with the shipped SVGs, so "Hop looks slightly left"
/// cannot be a pose without inventing art that does not exist. It is an
/// adjustment to a pose instead, which is also what lets gaze survive a pose
/// change instead of being lost by it.
struct HopExpression: Equatable, Sendable {
    /// Extra eye offset, in the 150 × 160 reference units the poses use.
    var gaze: CGSize = .zero
    /// 0…1 of a happy squeeze — the eyes closing upward with delight, which is
    /// a different shape from the resting blink.
    var squint: Double = 0
    /// Overrides the pose's own mouth opening while speaking. `nil` leaves the
    /// pose's mouth alone.
    var mouthOpen: Double? = nil
    /// Extra head rotation, degrees, on top of the pose's own tilt.
    var tilt: Double = 0

    static let neutral = HopExpression()
}

extension HopPoseGeometry {
    /// Folds an expression into a pose's parameters.
    ///
    /// The squint and a blink cannot simply add: a pose whose eyes are already
    /// shut cannot be shut further, so both close what is *left* of the eye.
    /// The closed-eye arc is blended rather than switched, so a resting blink
    /// that turns into a delighted squint bends through flat instead of
    /// flipping.
    mutating func apply(_ expression: HopExpression) {
        eyes.gaze.width += expression.gaze.width
        eyes.gaze.height += expression.gaze.height
        tilt += expression.tilt

        if expression.squint > 0 {
            let happy = HopEyeMood.happy.closedArcDirection
            eyes.closedArcDirection += (happy - eyes.closedArcDirection) * expression.squint
            close(eyesBy: expression.squint)
        }
        if let open = expression.mouthOpen {
            mouthOpenScale = open
        }
    }

    /// Closes the eyes by `amount` of whatever they still have open.
    mutating func close(eyesBy amount: Double) {
        guard amount > 0 else { return }
        eyes.blink = min(1, eyes.blink + amount * (1 - eyes.blink))
    }
}

// MARK: - Gaze

/// Where Hop is looking.
///
/// Cheap to apply and out of all proportion to its cost: eyes that point at the
/// thing the child is being asked to touch are most of what makes a drawing
/// read as *watching* rather than as printed. The target is expressed in the
/// coordinates of the square Hop is drawn in — `(0.5, 0.5)` is his own centre —
/// so a caller can point him at a button by its position in his frame without
/// knowing anything about his anatomy.
///
/// The eyes travel a few reference units at most, and the head follows by at
/// most a couple of degrees. Bigger than that and he stops looking *at*
/// something and starts staring.
public struct HopGaze: Equatable, Sendable {
    public let x: CGFloat
    public let y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    /// Points Hop at a place in his own frame.
    public static func at(_ point: UnitPoint) -> HopGaze {
        HopGaze(x: point.x, y: point.y)
    }

    /// Straight out of the screen at the child. The default everywhere.
    public static var forward: HopGaze { HopGaze(x: 0.5, y: 0.5) }
    public static var left: HopGaze { HopGaze(x: -0.1, y: 0.5) }
    public static var right: HopGaze { HopGaze(x: 1.1, y: 0.5) }
    public static var up: HopGaze { HopGaze(x: 0.5, y: -0.1) }
    /// Down at his own hands — washing, wiping, holding something.
    public static var down: HopGaze { HopGaze(x: 0.5, y: 1.1) }

    /// Reference units of eye travel per unit of frame, and the ceiling on it.
    private static let reach: CGFloat = 7
    private static let ceiling: CGFloat = 4.5
    private static let tiltCeiling: Double = 2.4

    var expression: HopExpression {
        let dx = HopGaze.clamped((x - 0.5) * HopGaze.reach, to: HopGaze.ceiling)
        let dy = HopGaze.clamped((y - 0.5) * HopGaze.reach, to: HopGaze.ceiling)
        return HopExpression(
            gaze: CGSize(width: dx, height: dy),
            tilt: HopGaze.clamped(Double(x - 0.5) * 5, to: HopGaze.tiltCeiling)
        )
    }

    private static func clamped(_ value: CGFloat, to limit: CGFloat) -> CGFloat {
        min(max(value, -limit), limit)
    }

    private static func clamped(_ value: Double, to limit: Double) -> Double {
        min(max(value, -limit), limit)
    }
}

// MARK: - One frame of the performance

/// Everything the drawing needs, for one instant.
///
/// Absolute, never a delta. That is what makes an interrupt safe: whatever Hop
/// was doing, handing him a new frame is a complete instruction, and the spring
/// carries him there from wherever he actually is.
struct HopFrame: Equatable, Sendable {
    var pose: HopPose
    var expression: HopExpression = .neutral
    /// 0…1 of the jump height, upward.
    var elevation: CGFloat = 0
    /// Sideways travel as a fraction of Hop's own height. Positive is the
    /// viewer's right.
    var drift: CGFloat = 0
    /// Vertical scale about the ground line. Below 1 is a squash.
    var squash: CGFloat = 1
    /// Rotation about the ground line, degrees.
    var lean: Double = 0
    var opacity: Double = 1
    /// The spring that carries Hop *into* this frame.
    var spring: HopSpring

    /// Standing still in a pose.
    static func rest(_ pose: HopPose, spring: HopSpring) -> HopFrame {
        HopFrame(pose: pose, spring: spring)
    }

    /// How far off-stage an entrance starts and an exit ends, as a fraction of
    /// Hop's height — just past his own width, so he is genuinely gone.
    static let offStageDrift: CGFloat = 1.15

    /// Squash and stretch conserve *some* width, not all of it. Full volume
    /// conservation on a character this round reads as a balloon being pressed.
    var horizontalScale: CGFloat { 1 + (1 - squash) * 0.75 }

    /// The frame as it may actually be drawn.
    ///
    /// Under Reduce Motion every travelling quantity is zeroed here rather than
    /// at the point the beat was scheduled, so the setting takes effect on the
    /// next drawn frame even if it is switched on mid-hop. Opacity survives: a
    /// cross-fade is exactly what Reduce Motion asks a movement to become.
    func resolved(reduceMotion: Bool) -> HopFrame {
        guard reduceMotion else { return self }
        var flat = self
        flat.elevation = 0
        flat.drift = 0
        flat.squash = 1
        flat.lean = 0
        return flat
    }
}

// MARK: - Acts

/// What Hop does on arriving at a pose. The verb; ``HopAct/pose`` is the noun.
public enum HopBeatKind: Equatable, Sendable {
    /// Stand there and be alive. The overwhelmingly common case.
    case none
    /// A greeting: wind up, arm up, two rocks, settle. Not a loop — a loop that
    /// keeps waving is a mascot asking to be looked at.
    case wave
    /// The short warm beat that means *he noticed you*. A squint, a small lift
    /// and a settle; smaller than a celebration on purpose, so the celebration
    /// still has somewhere to go.
    case delight
    /// Mouth movement for as long as a line is being delivered. `nil` runs
    /// until the act changes, which is how a screen that does not know the
    /// length of its own line drives it.
    case speak(TimeInterval?)
    /// A physical hop, or a burst of them.
    case hop(HopJump)
    /// Hop arrives from off-stage, landing on his mark.
    case entrance(HopJumpDrift)
    /// Hop leaves, and stays gone.
    case exit(HopJumpDrift)
}

/// What Hop is doing: a pose to rest in, and a beat to play on the way there.
///
/// One value drives the whole character. A screen sets it and forgets it —
/// changing it at any moment is safe, including mid-beat.
public struct HopAct: Equatable, Sendable {
    /// Where Hop comes to rest, and what assistive technology is told he is
    /// doing. A beat never changes this: the label must not move while he does.
    public let pose: HopPose
    public let beat: HopBeatKind

    public init(pose: HopPose, beat: HopBeatKind = .none) {
        self.pose = pose
        self.beat = beat
    }

    // MARK: One-liners for call sites

    /// Hold a pose. Ambient life still runs.
    public static func holding(_ pose: HopPose) -> HopAct { HopAct(pose: pose) }

    /// The default: standing, breathing, blinking, shifting his weight.
    public static var idle: HopAct { HopAct(pose: .idle) }

    /// Waving hello. Onboarding, the hub, the pause shield.
    public static var greeting: HopAct { HopAct(pose: .idle, beat: .wave) }

    /// *He noticed you.* A tap acknowledged, an answer accepted, a step done.
    public static func delighted(_ pose: HopPose = .idle) -> HopAct {
        HopAct(pose: pose, beat: .delight)
    }

    /// Speaking. Pass the length of the line if it is known; otherwise leave it
    /// `nil` and set another act when the line finishes.
    public static func speaking(for seconds: TimeInterval? = nil, pose: HopPose = .talk) -> HopAct {
        HopAct(pose: pose, beat: .speak(seconds))
    }

    /// Arms up and hopping. The full celebration.
    public static func celebrating(_ jump: HopJump = HopJump(hops: 2)) -> HopAct {
        HopAct(pose: .cheer, beat: .hop(jump))
    }

    /// A hop, resting back on `pose` afterwards.
    public static func hopping(_ jump: HopJump = HopJump(), restingOn pose: HopPose = .idle) -> HopAct {
        HopAct(pose: pose, beat: .hop(jump))
    }

    /// Hopping into the scene. `drift` is the side he comes *from*.
    public static func entering(from drift: HopJumpDrift = .left, restingOn pose: HopPose = .idle) -> HopAct {
        HopAct(pose: pose, beat: .entrance(drift))
    }

    /// Hopping out of the scene, and staying out.
    public static func exiting(toward drift: HopJumpDrift = .right, from pose: HopPose = .idle) -> HopAct {
        HopAct(pose: pose, beat: .exit(drift))
    }

    /// Whether this act moves Hop's body, and so should hold the ambient
    /// breath and weight shift while it runs.
    var movesBody: Bool {
        switch beat {
        case .none, .speak: false
        case .wave, .delight, .hop, .entrance, .exit: true
        }
    }

    /// The whole act, end to end, for a caller that has to sequence around it.
    /// Routing beats are not counted: they depend on where Hop happens to be.
    public func duration(reduceMotion: Bool) -> Double {
        switch beat {
        case .none:
            return 0
        case .wave:
            return reduceMotion
                ? HopMotion.reducedMotionFade * 2
                : HopMotion.jumpCrouch.duration
                    + HopAnimationToken.childTap.spring.duration
                    + HopMotion.jumpFall.duration * 2
                    + HopMotion.jumpSettle.duration
        case .delight:
            return reduceMotion
                ? HopMotion.reducedMotionFade * 2
                : HopMotion.jumpCrouch.duration
                    + HopAnimationToken.childTap.spring.duration
                    + HopMotion.jumpSettle.duration
        case .speak(let seconds):
            return seconds ?? 0
        case .hop(let jump):
            return jump.duration(reduceMotion: reduceMotion)
        case .entrance, .exit:
            return reduceMotion
                ? HopMotion.reducedMotionFade * 2
                : HopMotion.jumpCrouch.duration
                    + HopMotion.jumpRise.duration
                    + HopMotion.jumpHang
                    + HopMotion.jumpFall.duration
                    + HopMotion.jumpSettle.duration
        }
    }
}

// MARK: - The performer

/// Runs an act and publishes the frame it produces.
///
/// One instance per drawn character, held as `@State` by ``HopCharacterView``.
/// It never reads the environment and never touches a view: it is handed the
/// act and the Reduce Motion answer, and it emits frames.
@MainActor
@Observable
final class HopPerformer {
    /// What to draw, right now.
    private(set) var frame: HopFrame = HopFrame(pose: .idle, spring: HopMotion.parentTransition)
    /// True while a beat is moving Hop's body, so the ambient breath and weight
    /// shift can stand down rather than fight the squash.
    private(set) var suspendsAmbient = false

    /// Bumped by every run. A run whose generation is stale has been replaced
    /// and must not write another frame — which is what stops a cancelled act
    /// from clobbering the one that replaced it.
    private var generation = 0
    private var hasStarted = false

    /// The mouth's own beat while speaking. Short and flat: a syllable is not
    /// a bounce, and any overshoot here reads as chewing.
    private static let syllable = HopSpring(duration: 0.12, bounce: 0)

    /// Plays `act`. Safe to call again at any moment, including mid-beat.
    func perform(_ act: HopAct, reduceMotion: Bool) async {
        generation &+= 1
        let mine = generation
        defer { settle(after: act, generation: mine) }

        guard hasStarted else {
            // First appearance. Hop is simply already here — routing in from a
            // pose he was never in would make every screen animate on arrival,
            // which is a different design decision and not this one's to make.
            hasStarted = true
            frame = HopFrame.rest(act.pose, spring: act.pose.arrivalMotion.spring)
            await play(act, reduceMotion: reduceMotion, generation: mine)
            return
        }

        await travel(to: act.pose, reduceMotion: reduceMotion, generation: mine)
        guard isCurrent(mine) else { return }
        await play(act, reduceMotion: reduceMotion, generation: mine)
    }

    // MARK: Landing cleanly

    /// Where the act leaves Hop. Runs on every exit from ``perform(_:reduceMotion:)``
    /// — normal end, cancellation, or the view going away — and is skipped when
    /// a newer run has already taken over.
    private func settle(after act: HopAct, generation mine: Int) {
        guard generation == mine else { return }
        suspendsAmbient = false
        if case .exit(let drift) = act.beat {
            // An exit's rest state is off-stage. Nothing strands here: the
            // frame is complete, Hop is simply not on screen.
            frame = HopFrame(
                pose: act.pose,
                drift: drift.apexTravel < 0 ? -HopFrame.offStageDrift : HopFrame.offStageDrift,
                opacity: 0,
                spring: HopMotion.jumpFall
            )
        } else {
            frame = HopFrame.rest(act.pose, spring: HopMotion.jumpSettle)
        }
    }

    private func isCurrent(_ mine: Int) -> Bool {
        !Task.isCancelled && generation == mine
    }

    private func hold(_ seconds: Double) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(for: .seconds(seconds))
    }

    // MARK: Getting there

    /// Walks the legal route from where Hop is to where the act wants him,
    /// one beat per pose on the way.
    ///
    /// Under Reduce Motion the route collapses: the intermediate poses exist to
    /// make a change *readable as movement*, and there is no movement to read.
    private func travel(to pose: HopPose, reduceMotion: Bool, generation mine: Int) async {
        let route = reduceMotion ? [pose] : frame.pose.route(to: pose)

        guard !route.isEmpty else {
            // Already in the pose — but possibly still mid-transform from a beat
            // that was interrupted, so put him back on the ground either way.
            let settled = HopFrame.rest(pose, spring: frame.spring)
            if frame != settled {
                frame = HopFrame.rest(pose, spring: HopMotion.jumpSettle)
                await hold(HopMotion.jumpSettle.duration(reduceMotion: reduceMotion))
            }
            return
        }

        for step in route {
            guard isCurrent(mine) else { return }
            let spring = step.arrivalMotion.spring
            frame = HopFrame.rest(step, spring: spring)
            await hold(spring.duration(reduceMotion: reduceMotion))
        }
    }

    // MARK: Beats

    private func play(_ act: HopAct, reduceMotion: Bool, generation mine: Int) async {
        suspendsAmbient = act.movesBody
        switch act.beat {
        case .none:
            return
        case .wave:
            await playWave(restingOn: act.pose, reduceMotion: reduceMotion, generation: mine)
        case .delight:
            await playDelight(restingOn: act.pose, reduceMotion: reduceMotion, generation: mine)
        case .speak(let seconds):
            await playSpeech(for: seconds, restingOn: act.pose, reduceMotion: reduceMotion, generation: mine)
        case .hop(let jump):
            await playHop(jump, restingOn: act.pose, reduceMotion: reduceMotion, generation: mine)
        case .entrance(let drift):
            await playEntrance(drift, restingOn: act.pose, reduceMotion: reduceMotion, generation: mine)
        case .exit(let drift):
            await playExit(drift, from: act.pose, reduceMotion: reduceMotion, generation: mine)
        }
    }

    /// A beat, as Reduce Motion asks for it: the drawing changes and comes back,
    /// and not one thing on screen travels.
    private func crossFade(to pose: HopPose, restingOn rest: HopPose, generation mine: Int) async {
        frame = HopFrame.rest(pose, spring: HopMotion.jumpRise)
        await hold(HopMotion.reducedMotionFade)
        guard isCurrent(mine) else { return }
        frame = HopFrame.rest(rest, spring: HopMotion.jumpSettle)
        await hold(HopMotion.reducedMotionFade)
    }

    /// Crouch, rise, hang, land — once, or a few times in a burst.
    ///
    /// Hops inside a burst do not settle between them; only the last one does.
    /// That is the difference between one happy burst and a queue of jumps.
    private func playHop(
        _ jump: HopJump,
        restingOn rest: HopPose,
        reduceMotion: Bool,
        generation mine: Int
    ) async {
        guard !reduceMotion else {
            await crossFade(to: .jump, restingOn: rest, generation: mine)
            return
        }

        for index in 0..<jump.hops {
            if index > 0 {
                await hold(HopMotion.jumpRepeatGap)
                guard isCurrent(mine) else { return }
            }
            for beat in [HopJumpBeat.crouch, .airborne, .landing] {
                guard isCurrent(mine) else { return }
                frame = HopFrame(
                    pose: beat.pose(restingOn: rest),
                    elevation: beat.elevation,
                    drift: jump.drift.apexTravel * beat.elevation,
                    squash: beat.squash,
                    spring: beat.spring
                )
                await hold(beat.hold)
            }
        }

        guard isCurrent(mine) else { return }
        frame = HopFrame.rest(rest, spring: HopMotion.jumpSettle)
        await hold(HopMotion.jumpSettle.duration)
    }

    /// Wind up away from the wave, bring the arm up, rock twice, settle.
    private func playWave(restingOn rest: HopPose, reduceMotion: Bool, generation mine: Int) async {
        guard !reduceMotion else {
            await crossFade(to: .wave, restingOn: rest, generation: mine)
            return
        }

        // Anticipation: away from the movement, and down onto the feet.
        frame = HopFrame(pose: rest, squash: 0.97, lean: 1.6, spring: HopMotion.jumpCrouch)
        await hold(HopMotion.jumpCrouch.duration)
        guard isCurrent(mine) else { return }

        frame = HopFrame(pose: .wave, lean: -2.2, spring: HopAnimationToken.childTap.spring)
        await hold(HopAnimationToken.childTap.spring.duration)

        // Two rocks, borrowing the fall beat: short, flat, and the same length
        // each way, which is what stops a wave reading as a wobble.
        for lean in [1.4, -1.8] {
            guard isCurrent(mine) else { return }
            frame = HopFrame(pose: .wave, lean: lean, spring: HopMotion.jumpFall)
            await hold(HopMotion.jumpFall.duration)
        }

        guard isCurrent(mine) else { return }
        frame = HopFrame.rest(rest, spring: HopMotion.jumpSettle)
        await hold(HopMotion.jumpSettle.duration)
    }

    /// The warm react: eyes squeezing up, a small lift, and a slow release.
    /// Deliberately smaller than a hop — this is *noticing*, not celebrating.
    private func playDelight(restingOn rest: HopPose, reduceMotion: Bool, generation mine: Int) async {
        guard !reduceMotion else {
            frame = HopFrame(
                pose: rest,
                expression: HopExpression(squint: 0.9),
                spring: HopAnimationToken.childTap.spring
            )
            await hold(HopMotion.reducedMotionFade * 2)
            return
        }

        frame = HopFrame(
            pose: rest,
            expression: HopExpression(squint: 0.3),
            squash: 0.95,
            spring: HopMotion.jumpCrouch
        )
        await hold(HopMotion.jumpCrouch.duration)
        guard isCurrent(mine) else { return }

        frame = HopFrame(
            pose: rest,
            expression: HopExpression(squint: 0.95),
            elevation: 0.18,
            squash: 1.04,
            spring: HopAnimationToken.childTap.spring
        )
        await hold(HopAnimationToken.childTap.spring.duration)
        guard isCurrent(mine) else { return }

        // The squint releases more slowly than it arrived, which is the whole
        // difference between a smile and a twitch.
        frame = HopFrame(
            pose: rest,
            expression: HopExpression(squint: 0.25),
            spring: HopMotion.jumpSettle
        )
        await hold(HopMotion.jumpSettle.duration)
    }

    /// Mouth movement for the length of a line.
    ///
    /// No recorded audio ships yet (`ChildVoiceLine.swift`), so in practice the
    /// caller drives this from however long the caption is on screen. The shapes
    /// are held for a jittered slice rather than a fixed one: speech is not a
    /// metronome, and a mouth on a fixed beat reads as a machine.
    private func playSpeech(
        for seconds: TimeInterval?,
        restingOn rest: HopPose,
        reduceMotion: Bool,
        generation mine: Int
    ) async {
        guard !reduceMotion else {
            // Talking as a state rather than as movement: the talk mouth, held.
            frame = HopFrame.rest(rest, spring: HopAnimationToken.parentTransition.spring)
            await waitOut(seconds)
            return
        }

        let deadline = seconds.map { ContinuousClock.now.advanced(by: .seconds($0)) }
        var isOpen = true
        while isCurrent(mine) {
            if let deadline, ContinuousClock.now >= deadline { return }
            frame = HopFrame(
                pose: rest,
                expression: HopExpression(
                    mouthOpen: isOpen ? 0.88 : 0.34,
                    tilt: isOpen ? -0.5 : 0.4
                ),
                spring: HopPerformer.syllable
            )
            await hold(Double.random(in: 0.11...0.19))
            isOpen.toggle()
        }
    }

    /// Waits `seconds`, or until the act changes if there is no known length.
    private func waitOut(_ seconds: TimeInterval?) async {
        if let seconds {
            await hold(seconds)
        } else {
            // Cancelled when the act changes, which is the only thing that ends
            // a line of unknown length.
            try? await Task.sleep(for: .seconds(60 * 60))
        }
    }

    /// Hop arrives: off-stage and invisible, one hop in, land on the mark.
    private func playEntrance(
        _ drift: HopJumpDrift,
        restingOn rest: HopPose,
        reduceMotion: Bool,
        generation mine: Int
    ) async {
        let side: CGFloat = drift.apexTravel > 0 ? 1 : -1

        guard !reduceMotion else {
            frame = HopFrame(pose: rest, opacity: 0, spring: HopMotion.jumpCrouch)
            await hold(HopMotion.reducedMotionFade)
            guard isCurrent(mine) else { return }
            frame = HopFrame.rest(rest, spring: HopMotion.jumpRise)
            await hold(HopMotion.reducedMotionFade)
            return
        }

        // Off-stage. Held for the crouch beat, which is both the anticipation
        // and the frame that guarantees the fade has somewhere to start.
        frame = HopFrame(
            pose: .land,
            elevation: 0,
            drift: side * HopFrame.offStageDrift,
            squash: HopMotion.jumpSquash,
            opacity: 0,
            spring: HopMotion.jumpCrouch
        )
        await hold(HopMotion.jumpCrouch.duration)
        guard isCurrent(mine) else { return }

        frame = HopFrame(
            pose: .jump,
            elevation: 1,
            drift: side * HopFrame.offStageDrift * 0.45,
            squash: HopMotion.jumpStretch,
            spring: HopMotion.jumpRise
        )
        await hold(HopMotion.jumpRise.duration + HopMotion.jumpHang)
        guard isCurrent(mine) else { return }

        frame = HopFrame(pose: .land, squash: HopMotion.jumpSquash, spring: HopMotion.jumpFall)
        await hold(HopMotion.jumpFall.duration)
        guard isCurrent(mine) else { return }

        frame = HopFrame.rest(rest, spring: HopMotion.jumpSettle)
        await hold(HopMotion.jumpSettle.duration)
    }

    /// Hop leaves: crouch, one hop out, gone. The last frame is off-stage and
    /// transparent, and ``settle(after:)`` holds it there.
    private func playExit(
        _ drift: HopJumpDrift,
        from rest: HopPose,
        reduceMotion: Bool,
        generation mine: Int
    ) async {
        let side: CGFloat = drift.apexTravel < 0 ? -1 : 1

        guard !reduceMotion else {
            frame = HopFrame(pose: rest, opacity: 0, spring: HopMotion.jumpFall)
            await hold(HopMotion.reducedMotionFade)
            return
        }

        frame = HopFrame(pose: .land, squash: HopMotion.jumpSquash, spring: HopMotion.jumpCrouch)
        await hold(HopMotion.jumpCrouch.duration)
        guard isCurrent(mine) else { return }

        frame = HopFrame(
            pose: .jump,
            elevation: 1,
            drift: side * HopFrame.offStageDrift * 0.45,
            squash: HopMotion.jumpStretch,
            spring: HopMotion.jumpRise
        )
        await hold(HopMotion.jumpRise.duration + HopMotion.jumpHang)
        guard isCurrent(mine) else { return }

        frame = HopFrame(
            pose: .land,
            drift: side * HopFrame.offStageDrift,
            squash: HopMotion.jumpSquash,
            opacity: 0,
            spring: HopMotion.jumpFall
        )
        await hold(HopMotion.jumpFall.duration)
    }
}
