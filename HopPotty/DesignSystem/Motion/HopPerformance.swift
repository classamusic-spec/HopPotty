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
// ``HopFrame`` — pose, expression, the parts of the body still catching up with
// them (``HopSecondary``), and the body's offset, squash, lean and opacity —
// plus the spring that carries Hop *into* that frame. The view renders the
// frame and nothing else. Two consequences fall out for free:
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

        close(eyesBy: expression.squint, toward: .happy)
        if let open = expression.mouthOpen {
            mouthOpenScale = open
        }
    }

    /// Closes the eyes by `amount` of whatever they still have open, bending the
    /// shut-eye line toward `mood` by exactly as much as this closure
    /// contributed.
    ///
    /// Weighting the bend by the closure it actually caused is what keeps two
    /// sources of eye-closing from fighting. A resting blink lands on the
    /// resting arc; the same blink arriving on top of a delighted squeeze barely
    /// moves the arc at all, because there is almost no eye left for it to
    /// close and so almost none of the line is its to claim.
    mutating func close(eyesBy amount: Double, toward mood: HopEyeMood) {
        guard amount > 0 else { return }
        let closed = amount * (1 - eyes.blink)
        guard closed > 0 else { return }
        eyes.closedArcDirection += (mood.closedArcDirection - eyes.closedArcDirection) * closed
        eyes.blink = min(1, eyes.blink + closed)
    }

    /// Folds in the parts of the body that arrive after the rest of it.
    mutating func apply(_ secondary: HopSecondary) {
        guard secondary != .settled else { return }
        armL.x += secondary.hands.width
        armL.y += secondary.hands.height
        armR.x += secondary.hands.width
        armR.y += secondary.hands.height
        bellyScale = max(0.1, bellyScale + secondary.belly)
    }
}

// MARK: - Secondary motion

/// The parts of Hop that arrive a beat after the rest of him.
///
/// A body that moves as one piece reads as a picture being transformed. What
/// separates *animated* from *moved* is that the soft, heavy and far-from-centre
/// parts lag the main action and then overshoot it: hands that have not dropped
/// yet when the body crouches, and that swing down past the pose when it lands;
/// a belly that spreads a moment after the squash that spread it.
///
/// Expressed as an offset from the pose rather than as a pose of its own,
/// because it has to compose with *any* pose — there is no authored drawing of
/// "cheering with the arms slightly behind", and there should not be.
///
/// Zeroed under Reduce Motion by ``HopFrame/resolved(reduceMotion:)`` along with
/// every other travelling quantity: a hand arriving late is still a hand
/// travelling.
struct HopSecondary: Equatable, Sendable {
    /// Where the hands are, relative to where the pose puts them, in the
    /// 150 × 160 reference units. Positive `height` is downward.
    var hands: CGSize = .zero
    /// Added to the pose's belly scale. Positive is spread.
    var belly: Double = 0

    static let settled = HopSecondary()
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

    // MARK: How a look arrives

    /// How the eyes travel to a new target.
    ///
    /// Flat, and it has to be. Bounce on a pupil is an eye that overshoots the
    /// thing it is looking at and comes back, which reads as a wobble rather
    /// than as attention — and before this existed a gaze change inherited
    /// whichever beat's spring happened to be current, so pointing Hop at a
    /// button just after he landed carried the settle's 0.46 bounce.
    ///
    /// TODO: belongs in `HopMotion` as `hopGaze`; defined here because this
    /// layer does not own HopPottyKit.
    static let eyeSpring = HopSpring(duration: 0.24, bounce: 0)

    /// How the head follows. Slower than the eyes, and flat for the same reason.
    ///
    /// TODO: belongs in `HopMotion` as `hopGazeFollow`.
    static let headSpring = HopSpring(duration: 0.42, bounce: 0)

    /// How long the head waits before starting after the eyes.
    ///
    /// Eyes reach a target first and the head turns to catch up; a head and a
    /// pair of eyes that set off together read as a doll being turned. Under a
    /// tenth of a second, which is small enough that nobody will see the delay
    /// and large enough that everybody will see the difference.
    ///
    /// TODO: belongs in `HopMotion` as `hopGazeFollowDelay`.
    static let headFollowDelay: Double = 0.09

    /// Reference units of eye travel per unit of frame, and the ceiling on it.
    /// The pupil is 83% of the white (`HopAnatomy.pupilRadius`), which leaves
    /// 1.9 units before it is cut off by the eye's edge; the ceiling sits just
    /// inside that.
    private static let reach: CGFloat = 3
    private static let ceiling: CGFloat = 1.8
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
    /// The parts of the body that have not caught up with the pose yet.
    var secondary: HopSecondary = .settled
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
        // A hand arriving a beat late is still a hand travelling, and it is the
        // one that travels furthest on screen.
        flat.secondary = .settled
        return flat
    }

    /// Whether Hop is somewhere the child cannot see him.
    ///
    /// True only where an act has deliberately put him there — off-stage after
    /// an exit, or waiting in the wings before an entrance. It is what lets the
    /// *next* act put him back on his mark without the child watching him slide
    /// across the screen to reach it.
    var isOffStage: Bool { opacity < 1 }
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

    /// Whether this beat's *first* frame has Hop off-stage and invisible.
    ///
    /// ``HopCharacterView`` needs the answer before the performer has run, and
    /// it can only run one render after the view first appears. Without this,
    /// the single frame in between draws Hop standing on his mark — and the
    /// entrance then begins by sliding that visible drawing off the side of the
    /// screen before hopping it back on.
    var opensOffStage: Bool {
        if case .entrance = self { return true }
        return false
    }
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
            // One hop's worth of beats, because that is literally what it is:
            // the same crouch, rise, hang, fall and settle, with the ground
            // moving under him.
            return reduceMotion
                ? HopMotion.reducedMotionFade * 2
                : HopJump.duration(hops: 1)
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

    /// Whether the performer has published a frame of its own yet.
    ///
    /// Read by the view so that an act which opens off-stage is not preceded by
    /// one rendered frame of Hop standing on his mark.
    private(set) var hasStarted = false

    /// Bumped by every run. A run whose generation is stale has been replaced
    /// and must not write another frame — which is what stops a cancelled act
    /// from clobbering the one that replaced it.
    private var generation = 0

    /// How far off the ground counts as *in the air* for the purpose of
    /// interrupting.
    ///
    /// A hop is at 1 and the delight's happy bob is at 0.18. Dropping the bob
    /// without a landing beat costs nothing — it is eleven points at the size
    /// Hop is usually drawn — while dropping a whole hop that way is a character
    /// with no weight in him.
    private static let airborne: CGFloat = 0.5

    /// The mouth's own beat while speaking. Short and flat: a syllable is not
    /// a bounce, and any overshoot here reads as chewing.
    ///
    /// TODO: belongs in `HopMotion` as `hopSyllable`; defined here because this
    /// layer does not own HopPottyKit.
    private static let syllable = HopSpring(duration: 0.12, bounce: 0)

    /// How far the head turns on a phrase, in degrees, and how many syllables a
    /// phrase is. Under a degree: the point is that the head is *not* on the
    /// syllable clock, not that it is doing something big.
    ///
    /// TODO: both belong in `HopMotion`; defined here for the same reason.
    private static let speechTilt: Double = 0.7
    private static let syllablesPerPhrase = 5

    /// Plays `act`. Safe to call again at any moment, including mid-beat.
    func perform(_ act: HopAct, reduceMotion: Bool) async {
        generation &+= 1
        let mine = generation
        defer { settle(after: act, generation: mine) }

        guard hasStarted else {
            // First appearance. Hop is simply already here — routing in from a
            // pose he was never in would make every screen animate on arrival,
            // which is a different design decision and not this one's to make.
            //
            // The frame is published *before* `hasStarted`, and with no `await`
            // between them, so there is no instant at which the view can see
            // "the performer has started" alongside a frame it did not write.
            frame = openingFrame(for: act)
            hasStarted = true
            await play(act, reduceMotion: reduceMotion, generation: mine)
            return
        }

        // An act that opens off-stage says where it starts. There is nothing to
        // route from, and routing to the mark first would put Hop on it only to
        // slide him straight back off.
        if !act.beat.opensOffStage {
            await travel(to: act.pose, reduceMotion: reduceMotion, generation: mine)
            guard isCurrent(mine) else { return }
        }
        await play(act, reduceMotion: reduceMotion, generation: mine)
    }

    /// The frame an act begins on — the first thing the view will ever draw.
    ///
    /// Everything rests on its mark except an entrance, which begins in the
    /// wings. Getting that one right at *frame zero* is the difference between
    /// Hop hopping on and Hop appearing, sliding off and hopping back on.
    private func openingFrame(for act: HopAct) -> HopFrame {
        if case .entrance(let drift) = act.beat {
            return HopPerformer.wings(side: HopPerformer.side(of: drift))
        }
        return HopFrame.rest(act.pose, spring: act.pose.arrivalMotion.spring)
    }

    /// Which side of the stage a drift belongs to.
    ///
    /// `inPlace` has no side, and is treated as the right. The entrance, the
    /// exit and the rest frame an exit leaves behind all ask this one function,
    /// because an exit that leaves by one side and rests off the other would put
    /// Hop back on screen the moment anything re-read the frame.
    private static func side(of drift: HopJumpDrift) -> CGFloat {
        drift.apexTravel < 0 ? -1 : 1
    }

    /// Hop waiting in the wings: off-stage, invisible, and already crouched, so
    /// the first thing the child sees of him is a body pushing off rather than a
    /// drawing appearing.
    private static func wings(side: CGFloat) -> HopFrame {
        HopFrame(
            pose: .land,
            secondary: HopJumpBeat.crouch.secondary,
            drift: side * HopFrame.offStageDrift,
            squash: HopMotion.jumpSquash,
            opacity: 0,
            spring: HopMotion.jumpCrouch
        )
    }

    /// One jump beat, as a complete frame.
    private static func beatFrame(
        for beat: HopJumpBeat,
        drift: HopJumpDrift,
        restingOn rest: HopPose
    ) -> HopFrame {
        HopFrame(
            pose: beat.pose(restingOn: rest),
            secondary: beat.secondary,
            elevation: beat.elevation,
            drift: drift.apexTravel * beat.driftFactor,
            squash: beat.squash,
            spring: beat.spring
        )
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
                drift: HopPerformer.side(of: drift) * HopFrame.offStageDrift,
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
        // Two states the previous act can have left Hop in that no route knows
        // how to start from. Both are read off the *resolved* frame, so under
        // Reduce Motion — where nothing ever leaves the ground — neither can
        // fire spuriously.
        let standing = frame.resolved(reduceMotion: reduceMotion)

        if standing.elevation > HopPerformer.airborne {
            // Interrupted mid-hop. Whatever the new act is, he comes down
            // through the landing first: a character who floats to the floor in
            // his new pose has no weight, and it costs one beat to give him some.
            frame = HopFrame(
                pose: .land,
                secondary: HopJumpBeat.impact.secondary,
                squash: HopMotion.jumpSquash,
                spring: HopMotion.jumpFall
            )
            await hold(HopMotion.jumpFall.duration(reduceMotion: reduceMotion))
            guard isCurrent(mine) else { return }
        }

        if standing.isOffStage {
            // An exit left him in the wings. Put him back on his mark while he
            // is still invisible and then fade him in, rather than sliding a
            // visible drawing back across the screen to reach it.
            frame = HopFrame(pose: pose, opacity: 0, spring: HopMotion.jumpCrouch)
            await hold(HopMotion.jumpCrouch.duration(reduceMotion: reduceMotion))
            guard isCurrent(mine) else { return }

            let spring = pose.arrivalMotion.spring
            frame = HopFrame.rest(pose, spring: spring)
            await hold(spring.duration(reduceMotion: reduceMotion))
            return
        }

        // Under Reduce Motion the route collapses to the destination — but to
        // *nothing at all* when Hop is already in the pose, or every act would
        // start with a cross-fade from a drawing to itself.
        let route: [HopPose] = reduceMotion
            ? (frame.pose == pose ? [] : [pose])
            : frame.pose.route(to: pose)

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

    /// Crouch, rise, hang, fall, impact — once, or a few times in a burst.
    ///
    /// Hops inside a burst do not settle between them, and do not crouch again
    /// either: the impact of one hop *is* the crouch of the next. That is the
    /// difference between one happy burst and a queue of jumps, and it is also
    /// the difference between a burst and a burst with a quarter of a second of
    /// stillness in the middle of it.
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
            for beat in (index == 0 ? HopJumpBeat.opening : HopJumpBeat.repeated) {
                guard isCurrent(mine) else { return }
                frame = HopPerformer.beatFrame(for: beat, drift: jump.drift, restingOn: rest)
                await hold(beat.hold)
            }
        }

        guard isCurrent(mine) else { return }
        frame = HopFrame.rest(rest, spring: HopJumpBeat.grounded.spring)
        await hold(HopJumpBeat.grounded.hold)
    }

    /// Wind up away from the wave, bring the arm up, rock twice, settle.
    ///
    /// The rocks move the *hand* as well as the body, and against it: a wave in
    /// which only the torso rotates is a sway, and a hand that swings with the
    /// body it is attached to has no wrist. The offset is small — the arm is
    /// drawn from a fixed shoulder to the hand, so a few reference units at the
    /// hand swings the whole forearm through several degrees.
    ///
    /// It moves the hand *vertically*. The raised hand in `wave` is already
    /// close to the right edge of the reference box, and pushing it further out
    /// would take the fingertips off the canvas; raising and dropping it rotates
    /// the arm by just as much with the whole 150-unit height to do it in.
    private func playWave(restingOn rest: HopPose, reduceMotion: Bool, generation mine: Int) async {
        guard !reduceMotion else {
            await crossFade(to: .wave, restingOn: rest, generation: mine)
            return
        }

        // Anticipation: away from the movement, and down onto the feet.
        frame = HopFrame(
            pose: rest,
            secondary: HopSecondary(hands: CGSize(width: 0, height: 4)),
            squash: 0.97,
            lean: 1.6,
            spring: HopMotion.jumpCrouch
        )
        await hold(HopMotion.jumpCrouch.duration)
        guard isCurrent(mine) else { return }

        // The arm arrives behind the body, which is what an arm thrown up does.
        frame = HopFrame(
            pose: .wave,
            secondary: HopSecondary(hands: CGSize(width: 0, height: 12)),
            lean: -2.2,
            spring: HopAnimationToken.childTap.spring
        )
        await hold(HopAnimationToken.childTap.spring.duration)

        // Two rocks, borrowing the fall beat: short, flat, and the same length
        // each way, which is what stops a wave reading as a wobble. The leans
        // decay and so does the hand's swing, because a wave that keeps the same
        // amplitude is a metronome.
        for lean in [1.4, -1.8] {
            guard isCurrent(mine) else { return }
            // The hand goes the way the body is not.
            let swing = CGFloat(-lean * 2.6)
            frame = HopFrame(
                pose: .wave,
                secondary: HopSecondary(hands: CGSize(width: 0, height: swing)),
                lean: lean,
                spring: HopMotion.jumpFall
            )
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
            secondary: HopSecondary(hands: CGSize(width: 0, height: -4), belly: 0.04),
            squash: 0.95,
            spring: HopMotion.jumpCrouch
        )
        await hold(HopMotion.jumpCrouch.duration)
        guard isCurrent(mine) else { return }

        frame = HopFrame(
            pose: rest,
            expression: HopExpression(squint: 0.95),
            secondary: HopSecondary(hands: CGSize(width: 0, height: 5), belly: -0.03),
            elevation: 0.18,
            squash: 1.04,
            spring: HopAnimationToken.childTap.spring
        )
        await hold(HopAnimationToken.childTap.spring.duration)
        guard isCurrent(mine) else { return }

        // The squint releases more slowly than it arrived, which is the whole
        // difference between a smile and a twitch. The hands come down through
        // where the pose puts them rather than stopping dead on it.
        frame = HopFrame(
            pose: rest,
            expression: HopExpression(squint: 0.25),
            secondary: HopSecondary(hands: CGSize(width: 0, height: -2)),
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
    ///
    /// Two frequencies, and they are deliberately far apart. The **mouth** moves
    /// at syllable rate, and by a varying amount rather than between two fixed
    /// positions, because a jaw that alternates between exactly two openings is
    /// a puppet's hinge. The **head** moves at roughly phrase rate — once every
    /// few syllables — because that is what heads do. Nodding on every syllable
    /// is not liveliness, it is a vibration.
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
        var spoken = 0
        var tilt = -HopPerformer.speechTilt
        while isCurrent(mine) {
            if let deadline, ContinuousClock.now >= deadline { return }
            if spoken % HopPerformer.syllablesPerPhrase == 0 {
                tilt = -tilt
            }
            frame = HopFrame(
                pose: rest,
                expression: HopExpression(
                    mouthOpen: isOpen
                        ? Double.random(in: 0.72...0.95)
                        : Double.random(in: 0.22...0.45),
                    tilt: tilt
                ),
                spring: HopPerformer.syllable
            )
            await hold(Double.random(in: 0.11...0.19))
            isOpen.toggle()
            spoken += 1
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
        let side = HopPerformer.side(of: drift)

        guard !reduceMotion else {
            // He was never here: the opening frame already has him at zero
            // opacity on his mark, so this is a fade in and nothing else. It
            // must not begin by fading him *out*, which is what setting an
            // invisible frame from a visible one would do.
            frame = HopFrame.rest(rest, spring: HopMotion.jumpRise)
            await hold(HopMotion.reducedMotionFade * 2)
            return
        }

        // In the wings, crouched. Held for the crouch beat, which is both the
        // anticipation and the frame that guarantees the fade has somewhere to
        // start. Usually already the current frame — ``openingFrame(for:)`` put
        // him here before the view drew anything — in which case nothing moves.
        frame = HopPerformer.wings(side: side)
        await hold(HopJumpBeat.crouch.hold)
        guard isCurrent(mine) else { return }

        // The same air as any hop, with the ground moving under him. Most of
        // the distance is covered at the top of the arc, because that is where a
        // hop actually covers ground; the fall is nearly vertical onto the mark.
        let arc: [(beat: HopJumpBeat, distance: CGFloat)] = [
            (.rise, 0.44), (.hang, 0.26), (.fall, 0.08), (.impact, 0),
        ]
        for step in arc {
            guard isCurrent(mine) else { return }
            frame = HopFrame(
                pose: step.beat.pose(restingOn: rest),
                secondary: step.beat.secondary,
                elevation: step.beat.elevation,
                drift: side * HopFrame.offStageDrift * step.distance,
                squash: step.beat.squash,
                spring: step.beat.spring
            )
            await hold(step.beat.hold)
        }

        guard isCurrent(mine) else { return }
        frame = HopFrame.rest(rest, spring: HopJumpBeat.grounded.spring)
        await hold(HopJumpBeat.grounded.hold)
    }

    /// Hop leaves: crouch, one hop out, gone. The last frame is off-stage and
    /// transparent, and ``settle(after:)`` holds it there.
    private func playExit(
        _ drift: HopJumpDrift,
        from rest: HopPose,
        reduceMotion: Bool,
        generation mine: Int
    ) async {
        let side = HopPerformer.side(of: drift)

        guard !reduceMotion else {
            frame = HopFrame(pose: rest, opacity: 0, spring: HopMotion.jumpFall)
            await hold(HopMotion.reducedMotionFade)
            return
        }

        frame = HopFrame(
            pose: .land,
            secondary: HopJumpBeat.crouch.secondary,
            squash: HopMotion.jumpSquash,
            spring: HopJumpBeat.crouch.spring
        )
        await hold(HopJumpBeat.crouch.hold)
        guard isCurrent(mine) else { return }

        // The entrance's arc, run backwards, and the fade held back until he is
        // most of the way off: a character who dissolves at the top of his own
        // hop has not left, he has stopped existing.
        let arc: [(beat: HopJumpBeat, distance: CGFloat, opacity: Double)] = [
            (.rise, 0.42, 1), (.hang, 0.66, 1), (.fall, 0.88, 0.5), (.impact, 1, 0),
        ]
        for step in arc {
            guard isCurrent(mine) else { return }
            frame = HopFrame(
                pose: step.beat.pose(restingOn: rest),
                secondary: step.beat.secondary,
                elevation: step.beat.elevation,
                drift: side * HopFrame.offStageDrift * step.distance,
                squash: step.beat.squash,
                opacity: step.opacity,
                spring: step.beat.spring
            )
            await hold(step.beat.hold)
        }
    }
}
