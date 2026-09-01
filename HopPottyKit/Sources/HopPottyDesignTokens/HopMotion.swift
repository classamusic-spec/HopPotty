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
