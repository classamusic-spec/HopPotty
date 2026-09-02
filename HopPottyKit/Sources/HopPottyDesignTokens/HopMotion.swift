import Foundation

/// A spring description, expressed in the duration/bounce form SwiftUI uses.
public struct HopSpring: Sendable, Hashable {
    public let duration: Double
    /// 0 is critically damped; higher values overshoot more.
    public let bounce: Double

    public init(duration: Double, bounce: Double) {
        self.duration = duration
        self.bounce = bounce
    }
}

/// HopPotty's motion vocabulary.
///
/// Parent motion is quick and nearly flat — it should feel like the OS. Child
/// motion carries more bounce because it is doing narrative work: telling a
/// pre-reader that something arrived, succeeded, or is waiting for them.
public enum HopMotion {
    // Parent
    public static let parentTap = HopSpring(duration: 0.22, bounce: 0.10)
    public static let parentTransition = HopSpring(duration: 0.34, bounce: 0.0)
    public static let parentSheet = HopSpring(duration: 0.42, bounce: 0.08)

    // Child
    public static let childTap = HopSpring(duration: 0.30, bounce: 0.34)
    public static let childArrive = HopSpring(duration: 0.55, bounce: 0.28)
    public static let childCelebrate = HopSpring(duration: 0.70, bounce: 0.42)

    // Ambient character motion
    public static let breathePeriod: Double = 3.4
    public static let blinkInterval: ClosedRange<Double> = 2.8...6.5
    public static let blinkDuration: Double = 0.14

    // MARK: - Hop's jump
    //
    // A jump is four beats, not one curve: Hop crouches, leaves the ground,
    // hangs for an instant, then lands and settles. Splitting it out means the
    // squash on take-off and the squash on landing can differ, which is the
    // difference between a character that jumps and a picture that moves up.

    /// The crouch before take-off. Short, and the only beat that goes *down*.
    public static let jumpCrouch = HopSpring(duration: 0.14, bounce: 0.0)
    /// The rise. Low bounce: the overshoot belongs to the landing, not here.
    public static let jumpRise = HopSpring(duration: 0.26, bounce: 0.12)
    /// The fall back down, a touch quicker than the rise.
    public static let jumpFall = HopSpring(duration: 0.22, bounce: 0.0)
    /// The landing settle, where the bounce lives.
    public static let jumpSettle = HopSpring(duration: 0.46, bounce: 0.46)

    /// How far Hop leaves the ground, as a fraction of his own height.
    public static let jumpHeightRatio: CGFloat = 0.34
    /// Vertical stretch at the top of the rise (1.0 is no change).
    public static let jumpStretch: CGFloat = 1.07
    /// Vertical squash at the bottom of the crouch and on landing.
    public static let jumpSquash: CGFloat = 0.90
    /// Hang time at the apex. Small, but it reads as weight.
    public static let jumpHang: Double = 0.06

    /// One full hop, crouch through settle. Used to schedule what follows.
    public static var jumpDuration: Double {
        jumpCrouch.duration + jumpRise.duration + jumpHang + jumpFall.duration + jumpSettle.duration
    }

    /// Gap between hops when Hop hops more than once. Shorter than a single
    /// jump, so repeated hops read as one happy burst rather than a queue.
    public static let jumpRepeatGap: Double = 0.10

    // MARK: - Pond ambience
    //
    // Every period here is a prime-ish number of seconds and none of them are
    // multiples of each other, so the layers never resynchronise into a single
    // visible pulse. Slow on purpose: a pond that reads as *calm* is doing the
    // job. Nothing here is a reward, so nothing here demands to be watched.

    public static let pondRipplePeriod: Double = 7.3
    public static let pondLilyBobPeriod: Double = 5.9
    public static let pondReedSwayPeriod: Double = 6.7
    public static let pondCloudDriftPeriod: Double = 41.0
    public static let pondFishPeriod: Double = 17.0
    public static let pondDragonflyPeriod: Double = 11.3
    public static let pondShimmerPeriod: Double = 9.1

    /// Ambient movement amplitudes, in points at the pond's reference size.
    public static let pondBobDistance: CGFloat = 3.5
    public static let pondSwayDegrees: Double = 2.4

    // MARK: - Surfaces and transitions

    /// A card or button pressing in under a finger.
    public static let pressScale: CGFloat = 0.97
    public static let childPressScale: CGFloat = 0.94
    public static let press = HopSpring(duration: 0.18, bounce: 0.0)
    /// The release, which carries the bounce the press did not.
    public static let release = HopSpring(duration: 0.34, bounce: 0.30)

    /// Pushing forward through a parent flow, and its reverse.
    public static let pagePush = HopSpring(duration: 0.38, bounce: 0.04)
    /// A child-facing screen change: bigger, slower, more physical.
    public static let childPage = HopSpring(duration: 0.52, bounce: 0.22)
    /// How far an outgoing page slides, as a fraction of its width.
    public static let pageParallax: CGFloat = 0.28

    /// Ceiling on any celebration sequence. The product's whole premise is a
    /// *short* interruption; a long reward animation works against it.
    public static let celebrationMaxDuration: Double = 3.5

    /// Reduce Motion replacement for any spring. A cross-fade of this length
    /// keeps state changes legible without movement.
    public static let reducedMotionFade: Double = 0.20

    /// Staggered arrival delay for list and grid items.
    public static func stagger(index: Int, step: Double = 0.045, cap: Double = 0.36) -> Double {
        min(Double(index) * step, cap)
    }
}
