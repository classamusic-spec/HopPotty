import SwiftUI
import HopPottyDesignTokens

// Hop's jump.
//
// A jump is four beats — crouch, rise (with a hang at the apex), fall, settle —
// not one curve, and not a picture sliding up and back. What sells it is that
// the *drawing* changes with the movement (`HopPose.jump` in the air,
// `HopPose.land` on the way down and on impact) and that the squash and stretch
// are anchored at Hop's feet, so he flattens **onto the ground** rather than
// about his own middle.
//
// The numbers all come from `HopMotion`'s `jump*` group. Nothing here re-tunes
// them; this file is the sequencing and the geometry around them.

// MARK: - Degrading a spring

public extension HopSpring {
    /// This spring as an animation, degraded under Reduce Motion exactly as
    /// ``HopAnimationToken/animation(reduceMotion:)`` degrades a token's.
    ///
    /// ``HopAnimationToken`` is a closed set of *named* motions and the jump
    /// beats are not one of them: they are four springs that only mean anything
    /// in sequence, and a token per beat would invite feature code to pick one
    /// on its own. So the beats name springs directly — but the *substitution*
    /// is not repeated here; it delegates to the one implementation of that rule
    /// so the two can never drift apart.
    func animation(reduceMotion: Bool) -> Animation {
        HopAnimationToken.animation(for: self, reduceMotion: reduceMotion)
    }

    /// Wall-clock length, for code that has to sequence around this spring.
    func duration(reduceMotion: Bool) -> Double {
        reduceMotion ? HopMotion.reducedMotionFade : self.duration
    }
}

// MARK: - Which way a hop goes

/// The direction a hop leans into.
///
/// **Flavour, never magnitude.** Every case is the same height, the same
/// squash, the same number of hops and the same duration; the only thing that
/// changes is a small sideways sway at the apex, and `inPlace` is the hop that
/// goes straight up rather than a smaller one. Nothing in HopPotty may use this
/// to make one outcome's celebration bigger than another's
/// (`Docs/ChildSafety.md` §2).
public enum HopJumpDrift: String, CaseIterable, Sendable, Equatable {
    case inPlace
    case left
    case right

    /// Sideways travel at the apex, as a fraction of Hop's own height. The two
    /// sided cases are the same distance with opposite signs.
    var apexTravel: CGFloat {
        switch self {
        case .inPlace: 0
        case .left: -HopJumpDrift.travel
        case .right: HopJumpDrift.travel
        }
    }

    /// A garnish, deliberately small: the hop has to read as a hop, not as
    /// travel across the screen.
    static let travel: CGFloat = 0.10

    /// The mirror of this drift, for a hop that comes back the way it went.
    var mirrored: HopJumpDrift {
        switch self {
        case .inPlace: .inPlace
        case .left: .right
        case .right: .left
        }
    }
}

// MARK: - A hop, as a plan

/// A request for Hop to hop: how many times, and which way he leans.
///
/// Values are the trigger. Handing ``HopCharacterView`` a new `HopJump` starts
/// the sequence; handing it `nil` cancels one in flight and lands Hop cleanly.
/// An *identical* value does not replay — bump ``replay`` when the same plan
/// has to happen twice.
public struct HopJump: Equatable, Sendable {
    /// How many hops in the burst. Clamped to ``maxHops`` so a caller cannot
    /// build a celebration that outlives ``HopMotion/celebrationMaxDuration``.
    public let hops: Int
    public let drift: HopJumpDrift
    /// Bump to play the same plan again.
    public let replay: Int

    public init(hops: Int = 1, drift: HopJumpDrift = .inPlace, replay: Int = 0) {
        self.hops = min(max(1, hops), HopJump.maxHops)
        self.drift = drift
        self.replay = replay
    }

    /// The same plan, leaning the other way. The *only* supported way to vary a
    /// hop between two situations, because it is the only field that cannot
    /// change how big or how long the hop is.
    public func drifting(_ drift: HopJumpDrift) -> HopJump {
        HopJump(hops: hops, drift: drift, replay: replay)
    }

    /// One hop, crouch through impact, without the settle that ends the burst.
    static let burstBeat = HopMotion.jumpCrouch.duration
        + HopMotion.jumpRise.duration
        + HopMotion.jumpHang
        + HopMotion.jumpFall.duration

    /// Wall-clock length of a burst of `hops`.
    ///
    /// Hops inside a burst do not settle between them — they run crouch to
    /// impact and straight into the next crouch after ``HopMotion/jumpRepeatGap``
    /// — so a double hop reads as one happy burst rather than as a queue. Only
    /// the last one settles.
    public static func duration(hops: Int) -> Double {
        let count = Double(max(1, hops))
        return count * burstBeat
            + (count - 1) * HopMotion.jumpRepeatGap
            + HopMotion.jumpSettle.duration
    }

    /// The most hops that fit inside ``HopMotion/celebrationMaxDuration``.
    ///
    /// Derived rather than written down, so retuning a beat cannot quietly
    /// produce a celebration that overruns the product's own ceiling.
    public static let maxHops: Int = {
        var count = 1
        while HopJump.duration(hops: count + 1) <= HopMotion.celebrationMaxDuration {
            count += 1
        }
        return count
    }()

    /// How long this plan takes. Under Reduce Motion the whole burst collapses
    /// to a single cross-fade in and out, which is much shorter.
    public func duration(reduceMotion: Bool) -> Double {
        reduceMotion ? HopMotion.reducedMotionFade * 2 : HopJump.duration(hops: hops)
    }

    /// How far above his own frame Hop reaches at the apex, in points, for a
    /// character drawn at `size`.
    ///
    /// Call sites reserve this much headroom above the character so a hop never
    /// pushes the layout around and never overruns the card it sits in.
    public static func headroom(for size: CGFloat) -> CGFloat {
        size * HopCanvas.figureHeightRatio * HopMotion.jumpHeightRatio
    }

    /// How far to either side a drifting hop reaches, in points.
    public static func sideroom(for size: CGFloat) -> CGFloat {
        size * HopCanvas.figureHeightRatio * HopJumpDrift.travel
    }
}

// MARK: - The four beats

/// One beat of a jump. The drawing and the movement are chosen together here,
/// which is the whole point: a pose change that does not agree with the
/// transform is what makes a mascot look like a sticker being dragged.
enum HopJumpBeat: Equatable, Sendable, CaseIterable {
    /// Feet on the ground, nothing compressed. Also the resting state.
    case grounded
    /// The crouch before take-off — the only beat that goes down.
    case crouch
    /// Off the ground, stretched, at the top of the arc.
    case airborne
    /// Coming down and hitting the floor: the impact squash.
    case landing

    /// 0…1 of the jump height.
    var elevation: CGFloat {
        switch self {
        case .grounded, .crouch, .landing: 0
        case .airborne: 1
        }
    }

    /// Vertical scale about the ground line.
    var squash: CGFloat {
        switch self {
        case .grounded: 1
        case .crouch, .landing: HopMotion.jumpSquash
        case .airborne: HopMotion.jumpStretch
        }
    }

    /// The spring that carries Hop *into* this beat.
    var spring: HopSpring {
        switch self {
        case .grounded: HopMotion.jumpSettle
        case .crouch: HopMotion.jumpCrouch
        case .airborne: HopMotion.jumpRise
        case .landing: HopMotion.jumpFall
        }
    }

    /// How long to hold this beat before the next one.
    var hold: Double {
        switch self {
        case .grounded: HopMotion.jumpSettle.duration
        case .crouch: HopMotion.jumpCrouch.duration
        // The hang at the apex is part of the rise's hold, not a beat of its
        // own: nothing changes during it, and a beat that changes nothing is a
        // state a cancellation can strand Hop in.
        case .airborne: HopMotion.jumpRise.duration + HopMotion.jumpHang
        case .landing: HopMotion.jumpFall.duration
        }
    }

    /// What Hop is drawn as during this beat, given where he is resting.
    ///
    /// `land` does double duty as the crouch and the impact — it is the squashed
    /// drawing, and a crouch is a landing played backwards.
    func pose(restingOn rest: HopPose) -> HopPose {
        switch self {
        case .grounded: rest
        case .crouch, .landing: .land
        case .airborne: .jump
        }
    }
}

// MARK: - Where the ground is

extension HopCanvas {
    /// The line Hop stands on, as a fraction of the square he is drawn in.
    ///
    /// Taken from the ground shadow's own centre in `figure()`, so the contact
    /// point the drawing implies and the point the squash anchors at are the
    /// same number.
    static var groundFraction: CGFloat {
        HopAnatomy.groundLine * referenceScale / side
    }

    /// Where squash, stretch and lean anchor.
    ///
    /// A character that squashes about its centre bobs; one that squashes about
    /// its feet flattens onto the floor, which is the only one of the two that
    /// reads as weight.
    static var groundAnchor: UnitPoint {
        UnitPoint(x: 0.5, y: groundFraction)
    }

    /// Hop's own height — crown to ground — as a fraction of the square he is
    /// drawn in. `HopMotion.jumpHeightRatio` is a fraction of *this*, not of the
    /// frame, so a jump is the same size relative to Hop at every scale.
    static var figureHeightRatio: CGFloat {
        (HopAnatomy.groundLine - HopAnatomy.crownTop) * referenceScale / side
    }
}
