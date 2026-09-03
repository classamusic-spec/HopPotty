import SwiftUI
import HopPottyDesignTokens

/// Hop's pose set. One-to-one with `Art/character/hop-<pose>.svg` and with the
/// `poses` table in `Scripts/hop-art.js`, so the rendered art and the live
/// SwiftUI drawing cannot drift apart.
///
/// The generator's table has fifteen entries; fourteen of them are here. The
/// fifteenth, `face`, is a **crop, not a pose**: the same head, from the same
/// parameters, in a shorter viewBox. Modelling it as a case would mean a pose
/// that cannot interpolate with any other — you cannot tween a whole frog into a
/// headshot — and every `switch` would have to answer questions about arms the
/// crop does not have. It lives instead as ``HopPoseGeometry/faceCrop``, the
/// rectangle of the canvas Hop's head fills, which is what ``HopChip`` uses to
/// show his face inside a circle.
public enum HopPose: String, CaseIterable, Sendable, Identifiable {
    /// The reference pose: ta-da arms, open smile. App icon and dashboard chip.
    case idle
    /// Eyes closed mid-blink; cross-faded with `idle` for the ambient loop.
    case blink
    /// Speaking a line. Smaller mouth, one hand slightly raised toward the child.
    case talk
    /// Waving hello. Onboarding and the shield greeting.
    case wave
    /// Mid-hop, airborne. The celebration.
    case jump
    /// Walking to the bathroom with the pack. Routine step one.
    case walk
    /// Waiting patiently on the potty — sat down, hands resting, calm.
    case wait
    /// Both arms up and out. The star-earned moment.
    case cheer
    /// Resting during quiet hours and "paused until tomorrow".
    case sleep
    /// Landing frame after a jump — the squash before the settle.
    case land

    // Mini-game states.

    /// Frog squat on a lily pad, watching the sky. Fly Snack's resting state.
    case sit
    /// Tongue out for a fly. The same squat, so `sit` tweens straight into it.
    case `catch`
    /// Tummy full, and the body saying so — bigger belly, hand on it, knees
    /// together, a small bashful smile. Kind, never distressed: this is the
    /// moment the child learns to notice.
    case full
    /// Hands held out front, palms up, for washing and wiping games.
    case scrub

    public var id: String { rawValue }

    /// What VoiceOver says about the illustration when Hop is the subject
    /// rather than decoration.
    public var accessibilityDescription: String {
        switch self {
        case .idle, .blink: "Hop the frog, waiting"
        case .talk: "Hop the frog, talking"
        case .wave: "Hop the frog, waving hello"
        case .jump: "Hop the frog, jumping"
        case .walk: "Hop the frog, walking with a backpack"
        case .wait: "Hop the frog, sitting and waiting"
        case .cheer: "Hop the frog, cheering"
        case .sleep: "Hop the frog, asleep"
        case .land: "Hop the frog, landing"
        case .sit: "Hop the frog, sitting on a lily pad"
        case .`catch`: "Hop the frog, catching a fly with his tongue"
        case .full: "Hop the frog, holding his tummy"
        case .scrub: "Hop the frog, hands out ready to wash"
        }
    }

    /// How Hop moves *into* this pose. Arrivals that mean something get the
    /// bouncier token; settling back to idle does not.
    public var arrivalMotion: HopAnimationToken {
        switch self {
        case .jump, .cheer, .land: .childCelebrate
        case .wave, .walk, .talk, .scrub: .childArrive
        // The tongue is a flick, not an arrival: it has to land before the fly
        // moves, which is the one place a character animation is a response.
        case .`catch`: .childTap
        case .idle, .blink, .wait, .sleep, .sit, .full: .parentTransition
        }
    }

    var geometry: HopPoseGeometry { HopPoseGeometry(self) }
}

// MARK: - Legal transitions

/// How Hop is supported in a pose. Two poses in the same stance can hand over
/// to each other directly; two in different stances cannot, because changing
/// footing is a movement and a movement that happens in one frame is a cut.
public enum HopStance: Sendable, Equatable {
    /// On his feet.
    case standing
    /// Sat down — on the potty, on a lily pad, on the floor.
    case seated
    /// Lying down, asleep.
    case resting
}

public extension HopPose {
    var stance: HopStance {
        switch self {
        case .idle, .blink, .talk, .wave, .walk, .jump, .cheer, .land, .full, .scrub: .standing
        case .wait, .sit, .`catch`: .seated
        case .sleep: .resting
        }
    }

    /// The poses to pass through to get from here to `target`, in order, ending
    /// with `target` itself. Empty when Hop is already there.
    ///
    /// This is the legal-transition table, and it exists because the ugliest
    /// thing a mascot can do is teleport. Two rules, and they are the whole
    /// table:
    ///
    /// 1. **Waking is not instant.** From ``sleep`` Hop sits up (``wait``) and
    ///    stands (``idle``) before he does anything else. He is never asleep in
    ///    one frame and cheering in the next.
    /// 2. **Changing footing goes through the crouch.** ``wait`` is the pose
    ///    that joins standing to sitting — haunches down, hands on the ground —
    ///    so standing up and sitting down both pass through it rather than
    ///    snapping between two silhouettes that share no shape.
    ///
    /// Everything else is a direct hand-over: two standing poses differ only in
    /// where the arms and the face are, and ``HopPoseGeometry`` interpolates
    /// those, so the drawing itself does the work.
    ///
    /// Under Reduce Motion the route is not used at all — the intermediate
    /// poses exist to make a change readable *as movement*, and there is no
    /// movement to read.
    func route(to target: HopPose) -> [HopPose] {
        guard self != target else { return [] }

        var path: [HopPose] = []
        func step(_ pose: HopPose) {
            guard pose != self, pose != target, path.last != pose else { return }
            path.append(pose)
        }

        if self == .sleep {
            // Sit up first, and only stand if the target is standing.
            step(.wait)
            if target.stance == .standing { step(.idle) }
        } else if target == .sleep {
            step(.wait)
        } else if stance != target.stance {
            step(.wait)
        }

        path.append(target)
        return path
    }
}

// MARK: - Ambient life, per pose

public extension HopPose {
    /// How long one breath takes in this pose.
    ///
    /// A sleeping frog breathes slower than a waiting one, and a waiting one
    /// slower than a standing one. It is a small thing that a child will never
    /// name and would notice immediately if it were wrong.
    var breathPeriod: Double {
        switch self {
        case .sleep: HopMotion.breathePeriod * 1.7
        case .wait, .sit, .`catch`, .full: HopMotion.breathePeriod * 1.25
        default: HopMotion.breathePeriod
        }
    }

    /// How far the body swells on a breath, as a fraction of Hop's height.
    var breathAmplitude: CGFloat {
        switch self {
        case .sleep: 0.024
        case .full: 0.021
        default: 0.016
        }
    }

    /// Whether the ambient blink runs here. Poses that already hold the eyes
    /// shut have nothing to blink, and a sleeping frog does not blink at all.
    var blinks: Bool {
        switch self {
        case .sleep, .blink, .jump: false
        default: true
        }
    }
}

// MARK: - Pose parameters

/// One leg: a hip, an ankle, and how far the toes fan.
///
/// Standing, `hip` is inside the torso and `ankle` is where the foot hangs.
/// Crouching, `hip` is the haunch's centre and `ankle` is where the back foot
/// sits. The generator draws the foot from the ankle rather than storing a foot
/// centre, so a leg is fully described by its two ends.
struct HopLegGeometry: Equatable {
    var hip: CGPoint
    var ankle: CGPoint
    /// Multiplies the toe reach. Wider on a landing, narrower mid-stride.
    var toeSpread: Double = 1
}

/// Which closed-eye line a blink draws.
enum HopEyeMood: Equatable {
    /// An upward arc — delight, for eyes that shut because Hop is happy.
    case happy
    /// A downward arc — rest, for eyes that shut because Hop is settling.
    case rest

    /// The sign of the closed arc's control point, as `hop-art.js` writes it.
    var closedArcDirection: Double {
        switch self {
        case .happy: -1
        case .rest: 1
        }
    }
}

/// Everything the eyes do in a pose.
///
/// `mood` is stored as its arc direction rather than as the enum, because that
/// is the number the drawing needs and a `Double` interpolates: a blink that
/// starts happy and ends resting bends through flat instead of snapping.
struct HopEyeGeometry: Equatable {
    /// Where the pupils look, in reference units. The pupil is 83% of the
    /// white, so there are only 1.9 units of travel before it is cut off.
    var gaze: CGSize = .zero
    /// 0 open … 1 shut. Continuous here, where the generator only needs 0 or 1,
    /// because the ambient blink passes through every value in between.
    var blink: Double = 0
    /// How far the upper lid hangs over the eye, 0…1. Sleepy, not shut.
    var lidDrop: Double = 0
    /// −1 for a happy arc, +1 for a resting one. See ``HopEyeMood``.
    var closedArcDirection: Double = HopEyeMood.happy.closedArcDirection

    init(gaze: CGSize = .zero, blink: Double = 0, mood: HopEyeMood = .happy, lidDrop: Double = 0) {
        self.gaze = gaze
        self.blink = blink
        self.lidDrop = lidDrop
        self.closedArcDirection = mood.closedArcDirection
    }
}

/// The four mouths the generator draws.
enum HopMouthKind: Equatable {
    /// The reference's wide open smile, with the tongue showing.
    case open
    /// The same mouth at 72%, for speech.
    case talk
    /// A calm smile line.
    case closed
    /// A smaller resting smile line.
    case small

    /// How far the open mouth is scaled about its centre. Zero means the mouth
    /// is a line instead, and the two cross-fade rather than swap.
    var openScale: Double {
        switch self {
        case .open: 1
        case .talk: 0.72
        case .closed, .small: 0
        }
    }

    /// How deep the closed smile line bows, in reference units.
    var smileDepth: Double {
        switch self {
        case .small: 8
        case .open, .talk, .closed: 12
        }
    }
}

/// Every number a pose sets, in the reference space `Scripts/hop-art.js` works
/// in, so a parameter can be checked against the generator line for line.
///
/// Keeping it a flat value type is what lets SwiftUI interpolate between two
/// poses: ``animationVector`` flattens the whole set into one
/// `VectorArithmetic` value, which every shape declares as its
/// `animatableData`. Changing the pose inside an animation therefore moves Hop
/// rather than cutting to him.
struct HopPoseGeometry: Equatable {
    /// Which reference body the pose is drawn on.
    var body: HopBodyKind
    /// ``body`` as a number — 0 standing, 1 crouching — so that it rides in
    /// ``animationVector`` and a tween between the two bodies swaps at its
    /// midpoint rather than at either end. The drawing reads
    /// ``isCrouch``, never ``body``.
    var crouch: Double
    /// How far off the ground the whole figure is lifted.
    var lift: Double
    /// Vertical compression of the torso. Negative stretches (mid-air).
    var squash: Double
    /// Head rotation, degrees, about the face centre.
    var tilt: Double
    /// Whole-body rotation, degrees, about the hips.
    var lean: Double
    /// Where the left hand is. The shoulder is fixed by the body; the arm
    /// follows the hand.
    var armL: CGPoint
    /// Where the right hand is.
    var armR: CGPoint
    var legL: HopLegGeometry
    var legR: HopLegGeometry
    var eyes: HopEyeGeometry
    /// The authored mouth, kept so a pose reads the way the generator writes it.
    /// The drawing uses ``mouthOpenScale`` and ``mouthSmileDepth``, which are
    /// numbers and therefore interpolate.
    var mouth: HopMouthKind
    var mouthOpenScale: Double
    var mouthSmileDepth: Double
    /// Multiplies the belly. Above 1 for the full-tummy state.
    var bellyScale: Double
    /// The standing torso's width in reference units. Wider when the belly is
    /// full. The crouch torso has fixed sides and ignores it.
    var torsoWidth: Double
    /// Where the tongue's tip reaches. Collapsed onto the mouth when the tongue
    /// is in, so `sit → catch` extends it rather than popping it into place.
    var tongueTip: CGPoint
    /// 0 tongue in, 1 tongue out. Fades the tongue as the tip travels.
    var tongueExtension: Double
    /// The adventure pack, worn on the back.
    var withPack: Bool
    /// Soft motion marks either side of the body.
    var wiggling: Bool
    /// Draws the two `z`s above Hop's shoulder.
    var sleeping: Bool
    /// The ground shadow. Off only where a caller has its own surface.
    var showsShadow: Bool

    /// Where a retracted tongue lives: the mouth itself.
    static let tongueOrigin = CGPoint(x: 75, y: 60)

    /// Defaults are the generator's defaults, so a pose only writes what it
    /// changes — exactly as the `poses` table does.
    init(
        body: HopBodyKind = .standing,
        lift: Double = 0,
        squash: Double = 0,
        tilt: Double = 0,
        lean: Double = 0,
        armL: CGPoint = CGPoint(x: 9, y: 98),
        armR: CGPoint = CGPoint(x: 141, y: 98),
        legL: HopLegGeometry = HopLegGeometry(hip: CGPoint(x: 54, y: 128), ankle: CGPoint(x: 54, y: 150)),
        legR: HopLegGeometry = HopLegGeometry(hip: CGPoint(x: 96, y: 128), ankle: CGPoint(x: 96, y: 150)),
        eyes: HopEyeGeometry = HopEyeGeometry(),
        mouth: HopMouthKind = .open,
        bellyScale: Double = 1,
        torsoWidth: Double = 57,
        tongueTo: CGPoint? = nil,
        withPack: Bool = false,
        wiggling: Bool = false,
        sleeping: Bool = false,
        showsShadow: Bool = true
    ) {
        self.body = body
        self.crouch = body == .crouch ? 1 : 0
        self.lift = lift
        self.squash = squash
        self.tilt = tilt
        self.lean = lean
        self.armL = armL
        self.armR = armR
        self.legL = legL
        self.legR = legR
        self.eyes = eyes
        self.mouth = mouth
        self.mouthOpenScale = mouth.openScale
        self.mouthSmileDepth = mouth.smileDepth
        self.bellyScale = bellyScale
        self.torsoWidth = torsoWidth
        self.tongueTip = tongueTo ?? HopPoseGeometry.tongueOrigin
        self.tongueExtension = tongueTo == nil ? 0 : 1
        self.withPack = withPack
        self.wiggling = wiggling
        self.sleeping = sleeping
        self.showsShadow = showsShadow
    }

    init(_ pose: HopPose) {
        self = HopPoseGeometry.parameters(for: pose)
    }

    /// The `poses` table from `Scripts/hop-art.js`, transcribed. Every number
    /// here appears in that file; nothing is re-tuned on this side.
    ///
    /// The five crouch poses share one body — the generator's `CROUCH` spread —
    /// written out in full here because the contract check reads each case on
    /// its own.
    static func parameters(for pose: HopPose) -> HopPoseGeometry {
        switch pose {
        case .idle:
            HopPoseGeometry()

        case .blink:
            HopPoseGeometry(
                eyes: HopEyeGeometry(blink: 1, mood: .rest)
            )

        case .talk:
            HopPoseGeometry(
                armR: CGPoint(x: 141, y: 82),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 0.5)),
                mouth: .talk
            )

        case .wave:
            HopPoseGeometry(
                tilt: -3,
                armL: CGPoint(x: 12, y: 118),
                armR: CGPoint(x: 144, y: 38),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0.6, height: 0))
            )

        case .walk:
            HopPoseGeometry(
                lean: 4,
                armL: CGPoint(x: 14, y: 120),
                armR: CGPoint(x: 138, y: 82),
                legL: HopLegGeometry(hip: CGPoint(x: 54, y: 128), ankle: CGPoint(x: 40, y: 152), toeSpread: 1.1),
                legR: HopLegGeometry(hip: CGPoint(x: 96, y: 128), ankle: CGPoint(x: 112, y: 140), toeSpread: 1.1),
                eyes: HopEyeGeometry(gaze: CGSize(width: 1, height: 0)),
                mouth: .talk,
                withPack: true
            )

        case .wait:
            HopPoseGeometry(
                body: .crouch,
                lift: -6,
                armL: CGPoint(x: 49, y: 142),
                armR: CGPoint(x: 101, y: 142),
                legL: HopLegGeometry(hip: CGPoint(x: 26, y: 117.5), ankle: CGPoint(x: 28.5, y: 143.5), toeSpread: 1),
                legR: HopLegGeometry(hip: CGPoint(x: 124, y: 117.5), ankle: CGPoint(x: 121.5, y: 143.5), toeSpread: 1),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 1.2), lidDrop: 0.35),
                mouth: .small
            )

        case .jump:
            HopPoseGeometry(
                lift: 7.5,
                squash: -0.15,
                armL: CGPoint(x: 9, y: 118),
                armR: CGPoint(x: 141, y: 118),
                legL: HopLegGeometry(hip: CGPoint(x: 54, y: 128), ankle: CGPoint(x: 38, y: 140), toeSpread: 1.15),
                legR: HopLegGeometry(hip: CGPoint(x: 96, y: 128), ankle: CGPoint(x: 106, y: 147), toeSpread: 1.15),
                eyes: HopEyeGeometry(blink: 1, mood: .happy),
                mouth: .open
            )

        case .cheer:
            HopPoseGeometry(
                lift: 2,
                armL: CGPoint(x: 8, y: 34),
                armR: CGPoint(x: 142, y: 34),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: -1)),
                mouth: .open
            )

        case .sleep:
            HopPoseGeometry(
                body: .crouch,
                lift: -6,
                tilt: 4,
                armL: CGPoint(x: 49, y: 142),
                armR: CGPoint(x: 101, y: 142),
                legL: HopLegGeometry(hip: CGPoint(x: 26, y: 117.5), ankle: CGPoint(x: 28.5, y: 143.5), toeSpread: 1),
                legR: HopLegGeometry(hip: CGPoint(x: 124, y: 117.5), ankle: CGPoint(x: 121.5, y: 143.5), toeSpread: 1),
                eyes: HopEyeGeometry(blink: 1, mood: .rest),
                mouth: .small,
                sleeping: true
            )

        case .land:
            HopPoseGeometry(
                body: .crouch,
                lift: -6,
                squash: 0.5,
                armL: CGPoint(x: 44, y: 142),
                armR: CGPoint(x: 106, y: 142),
                legL: HopLegGeometry(hip: CGPoint(x: 26, y: 117.5), ankle: CGPoint(x: 28.5, y: 143.5), toeSpread: 1),
                legR: HopLegGeometry(hip: CGPoint(x: 124, y: 117.5), ankle: CGPoint(x: 121.5, y: 143.5), toeSpread: 1),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 1)),
                mouth: .open
            )

        case .sit:
            HopPoseGeometry(
                body: .crouch,
                lift: -6,
                armL: CGPoint(x: 49, y: 142),
                armR: CGPoint(x: 101, y: 142),
                legL: HopLegGeometry(hip: CGPoint(x: 26, y: 117.5), ankle: CGPoint(x: 28.5, y: 143.5), toeSpread: 1),
                legR: HopLegGeometry(hip: CGPoint(x: 124, y: 117.5), ankle: CGPoint(x: 121.5, y: 143.5), toeSpread: 1),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: -1.2)),
                mouth: .small
            )

        // Deliberately identical to `sit` apart from the eyes, the mouth and the
        // tongue: the two are meant to be tweened, and a body that also moved
        // would read as a lunge rather than a flick.
        case .`catch`:
            HopPoseGeometry(
                body: .crouch,
                lift: -6,
                armL: CGPoint(x: 49, y: 142),
                armR: CGPoint(x: 101, y: 142),
                legL: HopLegGeometry(hip: CGPoint(x: 26, y: 117.5), ankle: CGPoint(x: 28.5, y: 143.5), toeSpread: 1),
                legR: HopLegGeometry(hip: CGPoint(x: 124, y: 117.5), ankle: CGPoint(x: 121.5, y: 143.5), toeSpread: 1),
                eyes: HopEyeGeometry(gaze: CGSize(width: 1.2, height: -1.2)),
                mouth: .open,
                tongueTo: CGPoint(x: 142, y: 56)
            )

        case .full:
            HopPoseGeometry(
                squash: 0.1,
                armL: CGPoint(x: 40, y: 120),
                armR: CGPoint(x: 110, y: 126),
                legL: HopLegGeometry(hip: CGPoint(x: 54, y: 128), ankle: CGPoint(x: 58, y: 150), toeSpread: 1),
                legR: HopLegGeometry(hip: CGPoint(x: 96, y: 128), ankle: CGPoint(x: 92, y: 150), toeSpread: 1),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 1.2), lidDrop: 0.15),
                mouth: .small,
                bellyScale: 1.22,
                torsoWidth: 64,
                wiggling: true
            )

        case .scrub:
            HopPoseGeometry(
                armL: CGPoint(x: 36, y: 122),
                armR: CGPoint(x: 114, y: 114),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 1.4)),
                mouth: .talk
            )
        }
    }

    /// The generator's `face` entry — `hop-face.svg` — as the rectangle of the
    /// 512 × 512 canvas Hop's head fills. It is the bounding box of the crown,
    /// jaw and domes, computed from the same anatomy constants the head is
    /// drawn from rather than measured off a render, so it stays true if the
    /// head moves.
    static let faceCrop: CGRect = HopAnatomy.headBoundsOnCanvas
}

// MARK: - Interpolation

/// A flat list of doubles that SwiftUI can animate.
///
/// A pose carries thirty numbers. Expressing that as nested `AnimatablePair`s is
/// unreadable and breaks the moment a parameter is added — and the generator
/// added four in one afternoon — so the whole set travels as one array instead.
/// Mismatched lengths are padded rather than trapped, because SwiftUI starts
/// every interpolation from ``zero``, which is empty.
struct HopAnimatableVector: VectorArithmetic {
    var values: [Double]

    init(_ values: [Double]) {
        self.values = values
    }

    static var zero: HopAnimatableVector { HopAnimatableVector([]) }

    static func + (lhs: HopAnimatableVector, rhs: HopAnimatableVector) -> HopAnimatableVector {
        HopAnimatableVector.combine(lhs, rhs, +)
    }

    static func - (lhs: HopAnimatableVector, rhs: HopAnimatableVector) -> HopAnimatableVector {
        HopAnimatableVector.combine(lhs, rhs, -)
    }

    private static func combine(
        _ lhs: HopAnimatableVector,
        _ rhs: HopAnimatableVector,
        _ op: (Double, Double) -> Double
    ) -> HopAnimatableVector {
        let count = max(lhs.values.count, rhs.values.count)
        var result = [Double]()
        result.reserveCapacity(count)
        for index in 0..<count {
            let a = index < lhs.values.count ? lhs.values[index] : 0
            let b = index < rhs.values.count ? rhs.values[index] : 0
            result.append(op(a, b))
        }
        return HopAnimatableVector(result)
    }

    mutating func scale(by rhs: Double) {
        for index in values.indices {
            values[index] *= rhs
        }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 }
    }

    /// Reads a slot, or a sensible default when the vector arrived short.
    func value(_ index: Int, default fallback: Double = 0) -> Double {
        index < values.count ? values[index] : fallback
    }
}

extension HopPoseGeometry {
    /// The whole parameter set as one animatable value.
    ///
    /// Order matters only in that the getter and setter agree; it is written to
    /// read top-to-bottom like the pose table.
    var animationVector: HopAnimatableVector {
        get {
            HopAnimatableVector([
                lift, squash, tilt, lean,
                armL.x, armL.y, armR.x, armR.y, crouch,
                legL.hip.x, legL.hip.y, legL.ankle.x, legL.ankle.y, legL.toeSpread,
                legR.hip.x, legR.hip.y, legR.ankle.x, legR.ankle.y, legR.toeSpread,
                eyes.gaze.width, eyes.gaze.height, eyes.blink, eyes.lidDrop, eyes.closedArcDirection,
                mouthOpenScale, mouthSmileDepth,
                bellyScale, torsoWidth,
                tongueTip.x, tongueTip.y, tongueExtension,
            ])
        }
        set {
            lift = newValue.value(0)
            squash = newValue.value(1)
            tilt = newValue.value(2)
            lean = newValue.value(3)
            armL = CGPoint(x: newValue.value(4), y: newValue.value(5))
            armR = CGPoint(x: newValue.value(6), y: newValue.value(7))
            crouch = newValue.value(8)
            legL = HopLegGeometry(
                hip: CGPoint(x: newValue.value(9), y: newValue.value(10)),
                ankle: CGPoint(x: newValue.value(11), y: newValue.value(12)),
                toeSpread: newValue.value(13, default: 1)
            )
            legR = HopLegGeometry(
                hip: CGPoint(x: newValue.value(14), y: newValue.value(15)),
                ankle: CGPoint(x: newValue.value(16), y: newValue.value(17)),
                toeSpread: newValue.value(18, default: 1)
            )
            eyes.gaze = CGSize(width: newValue.value(19), height: newValue.value(20))
            eyes.blink = newValue.value(21)
            eyes.lidDrop = newValue.value(22)
            eyes.closedArcDirection = newValue.value(23, default: HopEyeMood.happy.closedArcDirection)
            mouthOpenScale = newValue.value(24)
            mouthSmileDepth = newValue.value(25, default: 12)
            bellyScale = newValue.value(26, default: 1)
            torsoWidth = newValue.value(27, default: 57)
            tongueTip = CGPoint(
                x: newValue.value(28, default: HopPoseGeometry.tongueOrigin.x),
                y: newValue.value(29, default: HopPoseGeometry.tongueOrigin.y)
            )
            tongueExtension = newValue.value(30)
        }
    }
}

// MARK: - Palette

/// Hop's own palette, matching the `T` table at the top of `Scripts/hop-art.js`.
/// `node Scripts/hop-lab.js --contracts` reads the raw values below and checks
/// them against it.
///
/// These are illustration colours, not semantic tokens: Hop is the same green
/// frog in light mode, dark mode and increased contrast, the way a character in
/// a picture book does not change colour when you turn on a lamp. The *stage*
/// around him is themed; he is not. That is why this enum reaches into
/// ``HopPalette`` directly rather than through `HopSemanticPalette` — there is
/// no appearance to resolve.
///
/// ## One green, one outline
///
/// The reference is a flat sticker: every part of Hop is the same brand green,
/// and what separates one part from another is the outline, drawn on every
/// boundary at the same weight in the same colour. There is no tonal ramp —
/// there used to be a four-step one, and it read as shading the reference does
/// not have. Turn the outline off and Hop still reads by pose and depth order
/// alone; that is the test, and `node Scripts/hop-lab.js --silhouette` is where
/// it is run.
///
/// Three colours are brand tokens: the body, the outline and the ink of the
/// line features. The rest are the reference drawing's own values and belong
/// to the character alone, declared here as raw values exactly as the
/// generator declares them.
enum HopCharacterPalette {
    /// `HopPalette.hopFill` — the one body green: head, torso, every limb.
    static let body = Color(HopPalette.hopFill)
    /// `HopPalette.hopOutline` — every boundary, outside and in.
    static let outline = Color(HopPalette.hopOutline)
    /// `HopPalette.hopGreenInk` — nostrils, closed-eye lines, closed mouths, z's.
    static let ink = Color(HopPalette.hopGreenInk)
    /// Character-only. The forehead spots and the wiggle marks, a step darker
    /// than the body and unoutlined.
    static let spot = Color(HopColorValue(hex: 0x45A971))
    /// Character-only. The warm cream belly.
    static let belly = Color(HopColorValue(hex: 0xF5E6A3))
    /// Character-only. The cheeks.
    static let cheek = Color(HopColorValue(hex: 0xF4A0A0))
    static let eyeWhite = Color(HopPalette.white)
    /// Character-only. Navy pupils.
    static let pupil = Color(HopColorValue(hex: 0x0D1B3E))
    static let highlight = Color(HopPalette.white)
    /// Character-only. The dark red inside an open mouth.
    static let mouthInterior = Color(HopColorValue(hex: 0x8B1A1A))
    /// Character-only. The tongue.
    static let tongue = Color(HopColorValue(hex: 0xE84A5F))
    /// Character-only. Wood browns for the adventure pack.
    static let bagBody = Color(HopColorValue(hex: 0xC98A5B))
    static let bagStrap = Color(HopColorValue(hex: 0xA76F46))
    /// `HopPalette.midnight` — the ground shadow.
    static let groundShadow = Color(HopPalette.midnight)
}
