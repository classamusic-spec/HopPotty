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
    /// The reference pose: arms wide, open smile. App icon and dashboard chip.
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
    /// Both arms straight up. The star-earned moment.
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
    ///    that joins standing to sitting — knees bent, hands down — so standing
    ///    up and sitting down both pass through it rather than snapping between
    ///    two silhouettes that share no shape.
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
/// The generator draws the foot from the ankle rather than storing a foot
/// centre, so a leg is fully described by its two ends.
struct HopLegGeometry: Equatable {
    var hip: CGPoint
    var ankle: CGPoint
    /// Multiplies the toe reach. Wider on a landing, narrower mid-stride.
    var toeSpread: Double = 1
    /// The limb's width where it leaves the body, and where it meets the foot.
    ///
    /// A leg is not a pipe: it is thicker at the root. Carrying both widths is
    /// also what lets a crouched haunch be a *leg* rather than a new part —
    /// Hop's folded back leg is this same shape with a much wider root.
    var rootWidth: Double = 26
    var tipWidth: Double = 18
}

/// The cream belly's own ellipse, for the poses that place it explicitly.
///
/// `bellyScale` covers the common case — a full tummy is the standing belly,
/// bigger. A crouch cannot use it: sitting makes the belly taller *and*
/// narrower than the body it sits on, and "narrower than the body" is the whole
/// point. Without it the belly grows to the torso's own width and there is no
/// green left around it, which is precisely how the old crouch came to read as
/// a cream patch floating between two pipes.
struct HopBellyGeometry: Equatable {
    var cy: Double
    var rx: Double
    var ry: Double
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
    /// The reference's wide smile, with the tongue showing.
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

/// Every number a pose sets, in the 150 × 160 reference space of
/// `hop_mascot.svg` — the space `Scripts/hop-art.js` works in, so a parameter
/// can be checked against the generator line for line.
///
/// Keeping it a flat value type is what lets SwiftUI interpolate between two
/// poses: ``animationVector`` flattens the whole set into one
/// `VectorArithmetic` value, which every shape declares as its
/// `animatableData`. Changing the pose inside an animation therefore moves Hop
/// rather than cutting to him.
struct HopPoseGeometry: Equatable {
    /// How far off the ground the whole figure is lifted.
    var lift: Double
    /// Vertical compression of the torso. Negative stretches (mid-air).
    var squash: Double
    /// Head rotation, degrees, about the face centre.
    var tilt: Double
    /// Whole-body rotation, degrees, about the hips.
    var lean: Double
    /// Where the left hand is. The shoulder is fixed; the arm follows the hand.
    var armL: CGPoint
    /// Where the right hand is.
    var armR: CGPoint
    /// 0 the arms hang at Hop's sides, 1 they cross in front of the body.
    ///
    /// A number rather than a `Bool` because it decides which green the arms are
    /// painted — ``HopCharacterPalette/armRest`` behind, ``HopCharacterPalette/armForward``
    /// in front — and a colour that changed in one frame while the arm was still
    /// travelling would read as a flicker. It rides in ``animationVector`` with
    /// everything else, so the tone arrives as the arm does.
    var armsForward: Double
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
    /// The torso's width in reference units. Wider when the belly is full.
    var torsoWidth: Double
    /// Where the torso's lower edge sits, or `nil` for the standing default
    /// (which derives it from `squash`). A crouch sets it: the body has to end
    /// above the ground so the forelimbs read below it.
    var torsoBottom: Double?
    /// The belly's own ellipse, or `nil` to derive it from `bellyScale`.
    var belly: HopBellyGeometry?
    /// The forelimb's root and tip widths, as `HopLegGeometry` carries the leg's.
    var armWidth: Double
    var armTipWidth: Double
    /// Above 0, the hands are planted as webbed paws flat on the ground rather
    /// than hanging fingers off the wrist, and the number is their toe spread.
    /// A sitting frog plants its forelimbs the way it plants its hind ones.
    var pawSpread: Double
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
        lift: Double = 0,
        squash: Double = 0,
        tilt: Double = 0,
        lean: Double = 0,
        armL: CGPoint = CGPoint(x: 22, y: 103),
        armR: CGPoint = CGPoint(x: 128, y: 103),
        armsForward: Double = 0,
        legL: HopLegGeometry = HopLegGeometry(hip: CGPoint(x: 56, y: 124), ankle: CGPoint(x: 52, y: 146)),
        legR: HopLegGeometry = HopLegGeometry(hip: CGPoint(x: 94, y: 124), ankle: CGPoint(x: 98, y: 146)),
        eyes: HopEyeGeometry = HopEyeGeometry(),
        mouth: HopMouthKind = .open,
        bellyScale: Double = 1,
        torsoWidth: Double = 58,
        torsoBottom: Double? = nil,
        belly: HopBellyGeometry? = nil,
        armWidth: Double = 15,
        armTipWidth: Double = 11.5,
        pawSpread: Double = 0,
        tongueTo: CGPoint? = nil,
        withPack: Bool = false,
        wiggling: Bool = false,
        sleeping: Bool = false,
        showsShadow: Bool = true
    ) {
        self.lift = lift
        self.squash = squash
        self.tilt = tilt
        self.lean = lean
        self.armL = armL
        self.armR = armR
        self.armsForward = armsForward
        self.legL = legL
        self.legR = legR
        self.eyes = eyes
        self.mouth = mouth
        self.mouthOpenScale = mouth.openScale
        self.mouthSmileDepth = mouth.smileDepth
        self.bellyScale = bellyScale
        self.torsoWidth = torsoWidth
        self.torsoBottom = torsoBottom
        self.belly = belly
        self.armWidth = armWidth
        self.armTipWidth = armTipWidth
        self.pawSpread = pawSpread
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
                armR: CGPoint(x: 131, y: 84),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 1)),
                mouth: .talk
            )

        case .wave:
            HopPoseGeometry(
                tilt: -3,
                armL: CGPoint(x: 24, y: 108),
                armR: CGPoint(x: 134, y: 38),
                eyes: HopEyeGeometry(gaze: CGSize(width: 1, height: 0))
            )

        case .walk:
            HopPoseGeometry(
                lean: 4,
                armL: CGPoint(x: 26, y: 114),
                armR: CGPoint(x: 128, y: 76),
                legL: HopLegGeometry(hip: CGPoint(x: 55, y: 122), ankle: CGPoint(x: 38, y: 146), toeSpread: 1),
                legR: HopLegGeometry(hip: CGPoint(x: 95, y: 122), ankle: CGPoint(x: 120, y: 134), toeSpread: 1.1),
                eyes: HopEyeGeometry(gaze: CGSize(width: 2, height: 0)),
                mouth: .talk,
                withPack: true
            )

        case .wait:
            HopPoseGeometry(
                lift: -6,
                squash: 0.3,
                armL: CGPoint(x: 26, y: 122),
                armR: CGPoint(x: 124, y: 122),
                legL: HopLegGeometry(hip: CGPoint(x: 55, y: 122), ankle: CGPoint(x: 38, y: 140), toeSpread: 1.1),
                legR: HopLegGeometry(hip: CGPoint(x: 95, y: 122), ankle: CGPoint(x: 112, y: 140), toeSpread: 1.1),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 3), lidDrop: 0.35),
                mouth: .small
            )

        case .jump:
            HopPoseGeometry(
                lift: 8,
                squash: -0.15,
                armL: CGPoint(x: 14, y: 74),
                armR: CGPoint(x: 136, y: 74),
                legL: HopLegGeometry(hip: CGPoint(x: 55, y: 122), ankle: CGPoint(x: 28, y: 128), toeSpread: 1.15),
                legR: HopLegGeometry(hip: CGPoint(x: 95, y: 122), ankle: CGPoint(x: 118, y: 140), toeSpread: 1.15),
                eyes: HopEyeGeometry(blink: 1, mood: .happy),
                mouth: .open
            )

        case .cheer:
            HopPoseGeometry(
                lift: 2,
                armL: CGPoint(x: 15, y: 30),
                armR: CGPoint(x: 135, y: 30),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: -2)),
                mouth: .open
            )

        case .sleep:
            HopPoseGeometry(
                lift: -4,
                squash: 0.2,
                tilt: 4,
                armL: CGPoint(x: 26, y: 120),
                armR: CGPoint(x: 124, y: 120),
                legL: HopLegGeometry(hip: CGPoint(x: 56, y: 124), ankle: CGPoint(x: 50, y: 142), toeSpread: 1),
                legR: HopLegGeometry(hip: CGPoint(x: 94, y: 124), ankle: CGPoint(x: 100, y: 142), toeSpread: 1),
                eyes: HopEyeGeometry(blink: 1, mood: .rest),
                mouth: .small,
                sleeping: true
            )

        case .land:
            HopPoseGeometry(
                squash: 0.5,
                armL: CGPoint(x: 18, y: 122),
                armR: CGPoint(x: 132, y: 122),
                legL: HopLegGeometry(hip: CGPoint(x: 55, y: 120), ankle: CGPoint(x: 42, y: 146), toeSpread: 1.2),
                legR: HopLegGeometry(hip: CGPoint(x: 95, y: 120), ankle: CGPoint(x: 108, y: 146), toeSpread: 1.2),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 2)),
                mouth: .open
            )

        case .sit:
            HopPoseGeometry(
                lift: -10,
                squash: 0.35,
                armL: CGPoint(x: 52, y: 142),
                armR: CGPoint(x: 98, y: 142),
                armsForward: 1,
                legL: HopLegGeometry(hip: CGPoint(x: 46, y: 110), ankle: CGPoint(x: 28, y: 132), toeSpread: 1, rootWidth: 46, tipWidth: 24),
                legR: HopLegGeometry(hip: CGPoint(x: 104, y: 110), ankle: CGPoint(x: 122, y: 132), toeSpread: 1, rootWidth: 46, tipWidth: 24),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: -3)),
                mouth: .small,
                torsoBottom: 128,
                belly: HopBellyGeometry(cy: 102, rx: 18, ry: 24),
                armWidth: 16,
                armTipWidth: 12,
                pawSpread: 0.9
            )

        // Deliberately identical to `sit` apart from the eyes, the mouth and the
        // tongue: the two are meant to be tweened, and a body that also moved
        // would read as a lunge rather than a flick.
        case .`catch`:
            HopPoseGeometry(
                lift: -10,
                squash: 0.35,
                armL: CGPoint(x: 52, y: 142),
                armR: CGPoint(x: 98, y: 142),
                armsForward: 1,
                legL: HopLegGeometry(hip: CGPoint(x: 46, y: 110), ankle: CGPoint(x: 28, y: 132), toeSpread: 1, rootWidth: 46, tipWidth: 24),
                legR: HopLegGeometry(hip: CGPoint(x: 104, y: 110), ankle: CGPoint(x: 122, y: 132), toeSpread: 1, rootWidth: 46, tipWidth: 24),
                eyes: HopEyeGeometry(gaze: CGSize(width: 3, height: -4)),
                mouth: .open,
                torsoBottom: 128,
                belly: HopBellyGeometry(cy: 102, rx: 18, ry: 24),
                armWidth: 16,
                armTipWidth: 12,
                pawSpread: 0.9,
                tongueTo: CGPoint(x: 138, y: 53)
            )

        case .full:
            HopPoseGeometry(
                squash: 0.1,
                armL: CGPoint(x: 42, y: 120),
                armR: CGPoint(x: 112, y: 126),
                armsForward: 1,
                legL: HopLegGeometry(hip: CGPoint(x: 55, y: 124), ankle: CGPoint(x: 58, y: 146), toeSpread: 1.1),
                legR: HopLegGeometry(hip: CGPoint(x: 95, y: 124), ankle: CGPoint(x: 92, y: 146), toeSpread: 1.1),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 3), lidDrop: 0.15),
                mouth: .small,
                bellyScale: 1.28,
                torsoWidth: 68,
                wiggling: true
            )

        case .scrub:
            HopPoseGeometry(
                armL: CGPoint(x: 38, y: 118),
                armR: CGPoint(x: 112, y: 108),
                armsForward: 1,
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 4)),
                mouth: .talk
            )
        }
    }

    /// The generator's `face` entry — `hop-face.svg` — as the rectangle of the
    /// 512 × 512 canvas Hop's head fills. It is the bounding box of the crown,
    /// jaw and eye sockets, computed from the same anatomy constants the head is
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
                armL.x, armL.y, armR.x, armR.y, armsForward,
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
            armsForward = newValue.value(8)
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
            torsoWidth = newValue.value(27, default: 58)
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
///
/// These are illustration colours, not semantic tokens: Hop is the same green
/// frog in light mode, dark mode and increased contrast, the way a character in
/// a picture book does not change colour when you turn on a lamp. The *stage*
/// around him is themed; he is not. That is why this enum reaches into
/// ``HopPalette`` directly rather than through `HopSemanticPalette` — there is
/// no appearance to resolve.
///
/// ## The green is a depth ramp, not a colour
///
/// Hop used to be one flat `hopGreen` everywhere, and that single fact is what
/// produced every complaint about him: arms disappeared into the head, hands
/// disappeared into the torso, and two legs mid-jump were one leg. Four values
/// now carry depth — front surfaces, a limb in front, a limb at rest, and the
/// legs — and they are assigned by *where a part sits*, never by what it is
/// called. Turn the outline off and Hop is still legible; that is the test, and
/// `node Scripts/hop-lab.js` is where it is run.
///
/// Four colours still have no brand token and are declared here as raw values,
/// exactly as the generator does: the tongue, the pack's two browns, and the
/// mouth interior's partner. None of them appears in UI.
enum HopCharacterPalette {
    /// `HopPalette.hopFill` — the head and the torso, the front surfaces.
    static let body = Color(HopPalette.hopFill)
    /// `HopPalette.hopFillShadow` — an arm or a hand hanging at Hop's side.
    static let armRest = Color(HopPalette.hopFillShadow)
    /// `HopPalette.hopFillHighlight` — an arm or a hand crossing in front of the
    /// body. Lighter, because the nearer thing is the lit one.
    static let armForward = Color(HopPalette.hopFillHighlight)
    /// `HopPalette.hopFillDeep` — the legs, furthest back in the figure.
    static let leg = Color(HopPalette.hopFillDeep)
    /// `HopPalette.hopFillShadow` — the top of a foot, which faces up and so
    /// comes forward again from the leg above it.
    static let foot = Color(HopPalette.hopFillShadow)
    /// One value step down, for spots, toe creases and wiggle marks. The same
    /// value as ``leg``: the deepest green in the character, wherever it lands.
    static let bodyDeep = Color(HopPalette.hopFillDeep)

    /// `HopPalette.hopOutline` — the exterior silhouette.
    static let outline = Color(HopPalette.hopOutline)
    /// The same colour, used where two similarly coloured parts overlap. The
    /// opacity comes from ``HopOutlineStyle`` rather than from here, because it
    /// changes with the size Hop is drawn at.
    static let outlineHue = HopPalette.hopOutline

    /// `HopPalette.hopGreenInk` — nostrils, closed-eye lines, closed mouths.
    static let ink = Color(HopPalette.hopGreenInk)
    /// `HopPalette.sunshineSoft` — the warm cream belly.
    static let belly = Color(HopPalette.sunshineSoft)
    /// `HopPalette.peachPop` — cheeks.
    static let cheek = Color(HopPalette.peachPop)
    static let eyeWhite = Color(HopPalette.white)
    /// `HopPalette.midnight` — pupils, and the ground shadow.
    static let pupil = Color(HopPalette.midnight)
    static let highlight = Color(HopPalette.white)
    /// `HopPalette.peachInk` — the inside of an open mouth.
    static let mouthInterior = Color(HopPalette.peachInk)
    /// Character-only. A brighter pink than any brand hue, and deliberately so.
    static let tongue = Color(HopColorValue(hex: 0xFF6F7D))
    /// Character-only. Wood browns for the adventure pack.
    static let bagBody = Color(HopColorValue(hex: 0xC98A5B))
    static let bagStrap = Color(HopColorValue(hex: 0xA76F46))
    static let groundShadow = Color(HopPalette.midnight)

    /// An arm's green at a given ``HopPoseGeometry/armsForward``, so the tone
    /// travels with the arm instead of switching under it.
    static func arm(forward: Double) -> Color {
        let t = min(1, max(0, forward))
        let back = HopPalette.hopFillShadow
        let front = HopPalette.hopFillHighlight
        return Color(HopColorValue(
            red: back.red + (front.red - back.red) * t,
            green: back.green + (front.green - back.green) * t,
            blue: back.blue + (front.blue - back.blue) * t
        ))
    }
}
