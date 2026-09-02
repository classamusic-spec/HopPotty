import SwiftUI
import HopPottyDesignTokens

// Hop's jump.
//
// A jump is five beats — crouch, rise, hang, fall, impact — and then a settle,
// not one curve, and not a picture sliding up and back. What sells it is that
// the *drawing* changes with the movement (`HopPose.jump` in the air,
// `HopPose.land` on the way down and on impact) and that the squash and stretch
// are anchored at Hop's feet, so he flattens **onto the ground** rather than
// about his own middle.
//
// ## Why the beats are not evenly spaced
//
// The beat lengths come out of `HopMotion` as 0.14, 0.26, 0.06, 0.14, 0.08, and
// then a 0.46 settle, and the shape of that list is the whole read:
//
// * the **crouch** is the shortest thing that is not the hang — anticipation has
//   to be quick or it becomes hesitation;
// * the **rise** is the longest airborne beat, and it decelerates into the apex
//   because a spring from rest does;
// * the **hang** is a beat of its own rather than dead time on the end of the
//   rise. It is where the body relaxes out of its take-off stretch and where the
//   arms, which have been trailing the rise, catch up. A hang in which nothing
//   changes is not weight, it is a pause;
// * the **fall** is deliberately cut short — it holds for 65% of `jumpFall` and
//   the impact takes the remainder. A spring that has only run 65% of its
//   duration is still moving fast, so handing the last of the descent to a much
//   shorter spring makes Hop *accelerate* into the floor instead of easing onto
//   it, which is what a decelerating spring left to finish would do;
// * the **impact** is where the compression happens, and only there. A body that
//   squashes all the way down is a body squashing against nothing;
// * the **settle** is the longest beat by a factor of three, and it carries the
//   overshoot: past 1.0 into a small stretch and back, which is a real rebound.
//
// ## What follows a beat late
//
// The body moving as one piece is the difference between "moved" and
// "animated". ``HopSecondary`` carries the parts that arrive after the rest of
// him: hands that have not dropped yet when the body crouches, hands that have
// not come up yet when it rises, and hands that swing down *past* the pose on
// contact. The belly does the same, one step behind the squash.
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

    /// Leaving the ground, hanging, and coming back down: everything between the
    /// crouch and the floor.
    static let airborneBeat = HopMotion.jumpRise.duration
        + HopMotion.jumpHang
        + HopMotion.jumpFall.duration

    /// The first hop of a burst: its own crouch, then the air.
    static let openingBeat = HopMotion.jumpCrouch.duration + airborneBeat

    /// Every hop after the first. It has **no crouch of its own** — the previous
    /// hop's impact is already the squashed, feet-planted drawing a crouch is,
    /// and re-entering it would leave a quarter of a second in which nothing on
    /// screen changes. That silence is exactly what makes repeated hops read as
    /// a queue; removing it is what makes them read as a bounce.
    static let repeatBeat = HopMotion.jumpRepeatGap + airborneBeat

    /// Wall-clock length of a burst of `hops`.
    ///
    /// Hops inside a burst do not settle between them — they land and launch
    /// again out of the same compression — so a double hop reads as one happy
    /// burst rather than as a queue. Only the last one settles.
    public static func duration(hops: Int) -> Double {
        let count = Double(max(1, hops))
        return openingBeat
            + (count - 1) * repeatBeat
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

// MARK: - The beats

/// One beat of a jump. The drawing, the movement and the parts of the body that
/// lag behind it are chosen together here, which is the whole point: a pose
/// change that does not agree with the transform is what makes a mascot look
/// like a sticker being dragged.
///
/// Every beat is a *complete* description of Hop at one instant, so an act that
/// is cancelled part-way through one is never stranded: the frame it produced is
/// valid on its own and the next act simply replaces it.
enum HopJumpBeat: Equatable, Sendable, CaseIterable {
    /// Feet on the ground, nothing compressed. Also the resting state.
    case grounded
    /// The crouch before take-off — the only beat that goes down.
    case crouch
    /// Leaving the ground, stretched along the direction of travel.
    case rise
    /// The apex. The body relaxes out of the take-off stretch and the arms,
    /// which have been trailing the rise, catch up with it.
    case hang
    /// Coming down. Still stretched: a body squashes when it *hits* something.
    case fall
    /// Contact. The compression, and the arms swinging down past it.
    case impact

    /// How much of ``HopMotion/jumpFall`` belongs to the contact rather than to
    /// the descent.
    ///
    /// The two together are exactly `jumpFall`, so splitting them cannot change
    /// how long a hop takes. What it changes is the shape: the descent hands off
    /// while its spring is still moving quickly, and the short contact spring
    /// finishes the drop — Hop accelerates into the floor instead of easing onto
    /// it, and the squash happens *at* the floor rather than all the way down.
    static let contactShare: Double = 0.35

    /// 0…1 of the jump height.
    var elevation: CGFloat {
        switch self {
        case .grounded, .crouch, .fall, .impact: 0
        case .rise, .hang: 1
        }
    }

    /// How much of the drift this beat carries, as a multiple of
    /// ``HopJumpDrift/apexTravel``.
    ///
    /// The crouch goes the *other* way. A body that is about to move right
    /// shifts its weight left first, and without that counter-move a sideways
    /// hop reads as the drawing being slid rather than as Hop pushing off.
    /// The landing keeps a little of the travel and gives it back over the
    /// settle, which is a weight shift rather than a snap home.
    var driftFactor: CGFloat {
        switch self {
        case .grounded: 0
        case .crouch: -0.18
        case .rise, .hang: 1
        case .fall: 0.45
        case .impact: 0.28
        }
    }

    /// Vertical scale about the ground line.
    var squash: CGFloat {
        switch self {
        case .grounded: 1
        case .crouch, .impact: HopMotion.jumpSquash
        case .rise, .fall: HopMotion.jumpStretch
        // At the top of the arc a body is neither accelerating nor falling, so
        // it is closer to its resting shape than at any other airborne instant.
        case .hang: 1 + (HopMotion.jumpStretch - 1) * 0.35
        }
    }

    /// What arrives a beat after the rest of him.
    var secondary: HopSecondary {
        switch self {
        case .grounded:
            HopSecondary.settled
        // The body drops; the hands have not.
        case .crouch:
            HopSecondary(hands: CGSize(width: 0, height: -9), belly: 0.06)
        // The body leaves; the hands are still on their way up.
        case .rise:
            HopSecondary(hands: CGSize(width: 0, height: 11), belly: -0.05)
        // They arrive, and carry a little past the pose, which is what an arm
        // thrown upward does at the top of the throw.
        case .hang:
            HopSecondary(hands: CGSize(width: 0, height: -3), belly: 0)
        // The body falls out from under them.
        case .fall:
            HopSecondary(hands: CGSize(width: 0, height: -12), belly: -0.04)
        // The body stops. The hands do not, and the soft middle spreads.
        case .impact:
            HopSecondary(hands: CGSize(width: 0, height: 7), belly: 0.10)
        }
    }

    /// The spring that carries Hop *into* this beat.
    var spring: HopSpring {
        switch self {
        case .grounded: HopMotion.jumpSettle
        case .crouch: HopMotion.jumpCrouch
        case .rise: HopMotion.jumpRise
        // Short enough to finish inside its own hold: the apex is a small,
        // complete settle, not a movement the fall interrupts.
        case .hang: HopSpring(duration: HopMotion.jumpHang, bounce: 0)
        case .fall: HopMotion.jumpFall
        case .impact: HopSpring(duration: HopMotion.jumpFall.duration * HopJumpBeat.contactShare, bounce: 0)
        }
    }

    /// How long to hold this beat before the next one.
    var hold: Double {
        switch self {
        case .grounded: HopMotion.jumpSettle.duration
        case .crouch: HopMotion.jumpCrouch.duration
        case .rise: HopMotion.jumpRise.duration
        case .hang: HopMotion.jumpHang
        case .fall: HopMotion.jumpFall.duration * (1 - HopJumpBeat.contactShare)
        case .impact: HopMotion.jumpFall.duration * HopJumpBeat.contactShare
        }
    }

    /// What Hop is drawn as during this beat, given where he is resting.
    ///
    /// `land` does double duty as the crouch and the impact — it is the squashed
    /// drawing, and a crouch is a landing played backwards. The descent uses it
    /// too, because the legs reaching for the floor are the descent.
    func pose(restingOn rest: HopPose) -> HopPose {
        switch self {
        case .grounded: rest
        case .crouch, .fall, .impact: .land
        case .rise, .hang: .jump
        }
    }

    /// The beats of one hop, in order, for a hop that has to crouch first.
    static let opening: [HopJumpBeat] = [.crouch, .rise, .hang, .fall, .impact]

    /// The beats of a hop that launches straight out of the previous one's
    /// impact.
    static let repeated: [HopJumpBeat] = [.rise, .hang, .fall, .impact]
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
