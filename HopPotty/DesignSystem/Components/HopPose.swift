import SwiftUI
import HopPottyDesignTokens

/// Hop's pose set. One-to-one with `Art/character/hop-<pose>.svg` and with the
/// pose table in `Scripts/hop-art.js`, so the rendered art and the live SwiftUI
/// drawing cannot drift apart.
public enum HopPose: String, CaseIterable, Sendable, Identifiable {
    /// Resting. The app icon and the parent dashboard chip.
    case idle
    /// Eyes closed. The far end of the ambient blink, and a pose in its own right.
    case blink
    /// Waving hello. Onboarding, and the greeting on the shield.
    case wave
    /// Mid-hop, airborne. The celebration.
    case jump
    /// Walking to the bathroom with the adventure bag. Routine step one.
    case walk
    /// Waiting patiently — calm, never impatient. The "give it a try" step.
    case wait
    /// Cheering with both arms up. The awarded-a-star moment.
    case cheer

    public var id: String { rawValue }

    /// What VoiceOver says about the illustration when Hop is the subject
    /// rather than decoration.
    public var accessibilityDescription: String {
        switch self {
        case .idle, .blink: "Hop the frog, waiting"
        case .wave: "Hop the frog, waving hello"
        case .jump: "Hop the frog, jumping"
        case .walk: "Hop the frog, walking with a backpack"
        case .wait: "Hop the frog, sitting and waiting"
        case .cheer: "Hop the frog, cheering"
        }
    }

    /// How Hop moves *into* this pose. Arrivals that mean something get the
    /// bouncier token; settling back to idle does not.
    public var arrivalMotion: HopAnimationToken {
        switch self {
        case .jump, .cheer: .childCelebrate
        case .wave, .walk: .childArrive
        case .idle, .blink, .wait: .parentTransition
        }
    }

    var geometry: HopPoseGeometry { HopPoseGeometry(self) }
}

/// One arm, as a tapered capsule pinned at the shoulder.
struct HopArmGeometry: Equatable {
    var origin: CGPoint
    /// Degrees, clockwise from pointing right — the SVG convention.
    var angle: Double
    var length: Double
    var width: Double = 30
}

/// One foot. `flip` mirrors the sole; `lift` raises it off the ground line.
struct HopFootGeometry: Equatable {
    var centre: CGPoint
    var flip: Double = 1
    var lift: Double = 0

    /// Where the foot actually draws, once the lift is applied.
    var resolvedCentre: CGPoint {
        CGPoint(x: centre.x, y: centre.y - lift)
    }
}

/// Every number a pose sets, in the 512 × 512 design canvas.
///
/// Ported directly from the `poses` table in `Scripts/hop-art.js`. Keeping it a
/// flat value type is what lets SwiftUI interpolate between two poses: each
/// field feeds a shape that declares `animatableData`, so changing the pose
/// inside a `withAnimation` moves Hop rather than cutting to him.
struct HopPoseGeometry: Equatable {
    var squash: Double = 0
    /// Vertical offset applied to the whole character group.
    var groupOffsetY: Double = 0
    /// How far off the ground Hop is, which shrinks and softens the shadow.
    var lift: Double = 0
    var leftArm: HopArmGeometry
    var rightArm: HopArmGeometry
    var leftFoot: HopFootGeometry
    var rightFoot: HopFootGeometry
    var gaze: CGSize = CGSize(width: 0, height: 10)
    var blink: Double = 0
    var mouthOpen: Double = 0
    var mouthSmile: Double = 1
    var showsBag: Bool = false

    init(_ pose: HopPose) {
        switch pose {
        case .idle, .blink:
            leftArm = HopArmGeometry(origin: CGPoint(x: 118, y: 338), angle: 160, length: 54)
            rightArm = HopArmGeometry(origin: CGPoint(x: 394, y: 338), angle: 20, length: 54)
            leftFoot = HopFootGeometry(centre: CGPoint(x: 190, y: 436))
            rightFoot = HopFootGeometry(centre: CGPoint(x: 322, y: 436), flip: -1)
            blink = pose == .blink ? 1 : 0

        case .wave:
            leftArm = HopArmGeometry(origin: CGPoint(x: 118, y: 338), angle: 160, length: 54)
            rightArm = HopArmGeometry(origin: CGPoint(x: 392, y: 300), angle: -64, length: 52)
            leftFoot = HopFootGeometry(centre: CGPoint(x: 190, y: 436))
            rightFoot = HopFootGeometry(centre: CGPoint(x: 322, y: 436), flip: -1)
            gaze = CGSize(width: 5, height: 7)
            mouthOpen = 0.6

        case .jump:
            squash = -0.22
            groupOffsetY = -50
            lift = 50
            leftArm = HopArmGeometry(origin: CGPoint(x: 126, y: 302), angle: -128, length: 50)
            rightArm = HopArmGeometry(origin: CGPoint(x: 386, y: 302), angle: -52, length: 50)
            leftFoot = HopFootGeometry(centre: CGPoint(x: 196, y: 442), lift: -6)
            rightFoot = HopFootGeometry(centre: CGPoint(x: 316, y: 442), flip: -1, lift: -6)
            blink = 1
            mouthOpen = 1

        case .walk:
            squash = 0.05
            leftArm = HopArmGeometry(origin: CGPoint(x: 122, y: 330), angle: 142, length: 54)
            rightArm = HopArmGeometry(origin: CGPoint(x: 392, y: 344), angle: 46, length: 54)
            leftFoot = HopFootGeometry(centre: CGPoint(x: 204, y: 442), lift: 16)
            rightFoot = HopFootGeometry(centre: CGPoint(x: 330, y: 436), flip: -1)
            gaze = CGSize(width: 13, height: 6)
            mouthOpen = 0.35
            showsBag = true

        case .wait:
            squash = 0.18
            groupOffsetY = 24
            leftArm = HopArmGeometry(origin: CGPoint(x: 128, y: 348), angle: 152, length: 54)
            rightArm = HopArmGeometry(origin: CGPoint(x: 384, y: 348), angle: 28, length: 54)
            leftFoot = HopFootGeometry(centre: CGPoint(x: 198, y: 430))
            rightFoot = HopFootGeometry(centre: CGPoint(x: 314, y: 430), flip: -1)
            gaze = CGSize(width: 0, height: 13)
            blink = 0.38
            mouthSmile = 0.7

        case .cheer:
            squash = -0.08
            leftArm = HopArmGeometry(origin: CGPoint(x: 128, y: 296), angle: -108, length: 54)
            rightArm = HopArmGeometry(origin: CGPoint(x: 384, y: 296), angle: -72, length: 54)
            leftFoot = HopFootGeometry(centre: CGPoint(x: 190, y: 436))
            rightFoot = HopFootGeometry(centre: CGPoint(x: 322, y: 436), flip: -1)
            blink = 1
            mouthOpen = 1
        }
    }
}

/// Hop's own palette.
///
/// These are illustration colours, not semantic tokens: Hop is the same green
/// frog in light mode, dark mode and increased contrast, the way a character in
/// a picture book does not change colour when you turn on a lamp. The *stage*
/// around him is themed; he is not.
enum HopCharacterPalette {
    static let bodyLight = Color(HopColorValue(hex: 0x9FE3B9))
    static let bodyMid = Color(HopColorValue(hex: 0x63C88A))
    static let bodyDeep = Color(HopColorValue(hex: 0x45A971))
    static let bodyShadow = Color(HopColorValue(hex: 0x37905F))
    static let belly = Color(HopColorValue(hex: 0xF0FBF4))
    static let bellyEdge = Color(HopColorValue(hex: 0xDCF3E5))
    static let ink = Color(HopColorValue(hex: 0x25603F))
    static let mouth = Color(HopColorValue(hex: 0x2F7D52))
    static let cheek = Color(HopColorValue(hex: 0xFF9F8F))
    static let cheekCore = Color(HopColorValue(hex: 0xFF8E86))
    static let eyeWhite = Color(HopColorValue(hex: 0xFFFFFF))
    static let pupil = Color(HopColorValue(hex: 0x243047))
    static let domeLight = Color(HopColorValue(hex: 0xA9E8C2))
    static let domeDeep = Color(HopColorValue(hex: 0x4FB47B))
    static let bagBody = Color(HopColorValue(hex: 0xC98A5B))
    static let bagStrap = Color(HopColorValue(hex: 0xA76F46))
    static let bagFlap = Color(HopColorValue(hex: 0xE0A472))
    static let groundShadow = Color(HopColorValue(hex: 0x243047))
}
