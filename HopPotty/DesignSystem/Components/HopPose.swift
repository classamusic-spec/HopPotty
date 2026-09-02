import SwiftUI
import HopPottyDesignTokens

/// Hop's pose set. One-to-one with `Art/character/hop-<pose>.svg` and with the
/// `poses` table in `Scripts/hop-art.js`, so the rendered art and the live
/// SwiftUI drawing cannot drift apart.
///
/// The generator's table has eleven entries; ten of them are here. The
/// eleventh, `face`, is a **crop, not a pose**: it is the same head, drawn from
/// the same parameters, in a shorter viewBox with the neck omitted. Modelling it
/// as a case would mean a pose that cannot interpolate with any other — you
/// cannot tween a whole frog into a headshot — and every `switch` would have to
/// answer questions about arms that the crop does not have. It lives instead as
/// ``HopPoseGeometry/faceCrop``, the rectangle of the canvas the head occupies,
/// which is what ``HopChip`` uses to show Hop's face inside a circle.
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
        }
    }

    /// How Hop moves *into* this pose. Arrivals that mean something get the
    /// bouncier token; settling back to idle does not.
    public var arrivalMotion: HopAnimationToken {
        switch self {
        case .jump, .cheer, .land: .childCelebrate
        case .wave, .walk, .talk: .childArrive
        case .idle, .blink, .wait, .sleep: .parentTransition
        }
    }

    var geometry: HopPoseGeometry { HopPoseGeometry(self) }
}

// MARK: - Pose parameters

/// One leg: a hip, an ankle, and how far the toes fan.
///
/// The generator draws the foot at the ankle rather than storing a foot centre,
/// so a leg is fully described by its two ends.
struct HopLegGeometry: Equatable {
    var hip: CGPoint
    var ankle: CGPoint
    /// Multiplies the toe reach. Wider on a landing, narrower mid-stride.
    var toeSpread: Double = 1
}

/// Which closed-eye line a blink draws.
enum HopEyeMood: Equatable {
    /// An upward arc — delight, used when the eyes shut because Hop is happy.
    case happy
    /// A downward arc — rest, used when the eyes shut because Hop is settling.
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
/// `hop_mascot.svg` — the same space `Scripts/hop-art.js` works in, so a
/// parameter can be checked against the generator line for line.
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
    var legL: HopLegGeometry
    var legR: HopLegGeometry
    var eyes: HopEyeGeometry
    /// The authored mouth, kept so a pose reads the way the generator writes it.
    /// The drawing uses ``mouthOpenScale`` and ``mouthSmileDepth``, which are
    /// numbers and therefore interpolate.
    var mouth: HopMouthKind
    var mouthOpenScale: Double
    var mouthSmileDepth: Double
    /// The adventure pack, worn on the back.
    var withPack: Bool
    /// Draws the two `z`s above Hop's shoulder.
    var sleeping: Bool
    /// The ground shadow. Off only where a caller has its own surface.
    var showsShadow: Bool

    /// Defaults are the generator's defaults, so a pose only writes what it
    /// changes — exactly as the `poses` table does.
    init(
        lift: Double = 0,
        squash: Double = 0,
        tilt: Double = 0,
        lean: Double = 0,
        armL: CGPoint = CGPoint(x: 10, y: 97),
        armR: CGPoint = CGPoint(x: 140, y: 97),
        legL: HopLegGeometry = HopLegGeometry(hip: CGPoint(x: 55, y: 122), ankle: CGPoint(x: 54, y: 148)),
        legR: HopLegGeometry = HopLegGeometry(hip: CGPoint(x: 95, y: 122), ankle: CGPoint(x: 96, y: 148)),
        eyes: HopEyeGeometry = HopEyeGeometry(),
        mouth: HopMouthKind = .open,
        withPack: Bool = false,
        sleeping: Bool = false,
        showsShadow: Bool = true
    ) {
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
        self.withPack = withPack
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
            HopPoseGeometry(eyes: HopEyeGeometry(blink: 1, mood: .rest))

        case .talk:
            HopPoseGeometry(
                armR: CGPoint(x: 136, y: 84),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 1)),
                mouth: .talk
            )

        case .wave:
            HopPoseGeometry(
                tilt: -3,
                armL: CGPoint(x: 12, y: 100),
                armR: CGPoint(x: 143, y: 38),
                eyes: HopEyeGeometry(gaze: CGSize(width: 1, height: 0))
            )

        case .walk:
            HopPoseGeometry(
                lean: 4,
                armL: CGPoint(x: 24, y: 112),
                armR: CGPoint(x: 122, y: 78),
                legL: HopLegGeometry(hip: CGPoint(x: 55, y: 122), ankle: CGPoint(x: 44, y: 146), toeSpread: 1),
                legR: HopLegGeometry(hip: CGPoint(x: 95, y: 122), ankle: CGPoint(x: 104, y: 140), toeSpread: 0.8),
                eyes: HopEyeGeometry(gaze: CGSize(width: 2, height: 0)),
                mouth: .talk,
                withPack: true
            )

        case .wait:
            HopPoseGeometry(
                lift: -6,
                squash: 0.3,
                armL: CGPoint(x: 32, y: 124),
                armR: CGPoint(x: 118, y: 124),
                legL: HopLegGeometry(hip: CGPoint(x: 55, y: 122), ankle: CGPoint(x: 42, y: 138), toeSpread: 1.1),
                legR: HopLegGeometry(hip: CGPoint(x: 95, y: 122), ankle: CGPoint(x: 108, y: 138), toeSpread: 1.1),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 3), lidDrop: 0.35),
                mouth: .small
            )

        case .jump:
            HopPoseGeometry(
                lift: 10,
                squash: -0.15,
                armL: CGPoint(x: 14, y: 58),
                armR: CGPoint(x: 136, y: 58),
                legL: HopLegGeometry(hip: CGPoint(x: 55, y: 122), ankle: CGPoint(x: 48, y: 136), toeSpread: 0.9),
                legR: HopLegGeometry(hip: CGPoint(x: 95, y: 122), ankle: CGPoint(x: 102, y: 136), toeSpread: 0.9),
                eyes: HopEyeGeometry(blink: 1, mood: .happy),
                mouth: .open
            )

        case .cheer:
            HopPoseGeometry(
                lift: 2,
                armL: CGPoint(x: 30, y: 30),
                armR: CGPoint(x: 120, y: 30),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: -2)),
                mouth: .open
            )

        case .sleep:
            HopPoseGeometry(
                lift: -4,
                squash: 0.2,
                tilt: 4,
                armL: CGPoint(x: 34, y: 122),
                armR: CGPoint(x: 116, y: 122),
                eyes: HopEyeGeometry(blink: 1, mood: .rest),
                mouth: .small,
                sleeping: true
            )

        case .land:
            HopPoseGeometry(
                squash: 0.5,
                armL: CGPoint(x: 14, y: 108),
                armR: CGPoint(x: 136, y: 108),
                legL: HopLegGeometry(hip: CGPoint(x: 55, y: 120), ankle: CGPoint(x: 46, y: 146), toeSpread: 1.2),
                legR: HopLegGeometry(hip: CGPoint(x: 95, y: 120), ankle: CGPoint(x: 104, y: 146), toeSpread: 1.2),
                eyes: HopEyeGeometry(gaze: CGSize(width: 0, height: 2)),
                mouth: .open
            )
        }
    }

    /// The eleventh entry in the generator's pose table, `hop-face.svg`, as the
    /// rectangle of the 512 × 512 canvas Hop's head fills. It is the bounding
    /// box of the crown, jaw and eye sockets — the same geometry the head is
    /// drawn from, not a hand-measured crop — so it stays true if the head moves.
    static let faceCrop = CGRect(x: 48, y: 20, width: 416, height: 236)
}

// MARK: - Interpolation

/// A flat list of doubles that SwiftUI can animate.
///
/// A pose carries about two dozen numbers. Expressing that as nested
/// `AnimatablePair`s is unreadable and breaks the moment a parameter is added,
/// so the whole set travels as one array instead. Mismatched lengths are padded
/// rather than trapped, because SwiftUI starts every interpolation from
/// ``zero``, which is empty.
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
                armL.x, armL.y, armR.x, armR.y,
                legL.hip.x, legL.hip.y, legL.ankle.x, legL.ankle.y, legL.toeSpread,
                legR.hip.x, legR.hip.y, legR.ankle.x, legR.ankle.y, legR.toeSpread,
                eyes.gaze.width, eyes.gaze.height, eyes.blink, eyes.lidDrop, eyes.closedArcDirection,
                mouthOpenScale, mouthSmileDepth,
            ])
        }
        set {
            lift = newValue.value(0)
            squash = newValue.value(1)
            tilt = newValue.value(2)
            lean = newValue.value(3)
            armL = CGPoint(x: newValue.value(4), y: newValue.value(5))
            armR = CGPoint(x: newValue.value(6), y: newValue.value(7))
            legL = HopLegGeometry(
                hip: CGPoint(x: newValue.value(8), y: newValue.value(9)),
                ankle: CGPoint(x: newValue.value(10), y: newValue.value(11)),
                toeSpread: newValue.value(12, default: 1)
            )
            legR = HopLegGeometry(
                hip: CGPoint(x: newValue.value(13), y: newValue.value(14)),
                ankle: CGPoint(x: newValue.value(15), y: newValue.value(16)),
                toeSpread: newValue.value(17, default: 1)
            )
            eyes.gaze = CGSize(width: newValue.value(18), height: newValue.value(19))
            eyes.blink = newValue.value(20)
            eyes.lidDrop = newValue.value(21)
            eyes.closedArcDirection = newValue.value(22, default: HopEyeMood.happy.closedArcDirection)
            mouthOpenScale = newValue.value(23)
            mouthSmileDepth = newValue.value(24, default: 12)
        }
    }
}

// MARK: - Palette

/// Hop's own palette, matching the `C` table at the top of `Scripts/hop-art.js`.
///
/// These are illustration colours, not semantic tokens: Hop is the same green
/// frog in light mode, dark mode and increased contrast, the way a character in
/// a picture book does not change colour when you turn on a lamp. The *stage*
/// around him is themed; he is not. That is why this enum reaches into
/// ``HopPalette`` directly rather than through ``HopSemanticPalette`` — there is
/// no appearance to resolve.
///
/// Three colours have no brand token and are declared here as raw values,
/// exactly as the generator does: the mid-green Hop's spots and toe creases are
/// stepped down to, the tongue, and the pack's browns. They never appear in UI.
enum HopCharacterPalette {
    /// `HopPalette.hopGreen` — the body, everywhere.
    static let body = Color(HopPalette.hopGreen)
    /// One value step down, for spots and toe creases. Character-only.
    static let bodyDeep = Color(HopColorValue(hex: 0x45A971))
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
}
