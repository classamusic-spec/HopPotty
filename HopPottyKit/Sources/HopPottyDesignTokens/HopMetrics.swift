import Foundation

/// The 4-point spacing scale. Every margin, gap and inset in HopPotty is one of
/// these steps; ad-hoc values are what make a layout feel arbitrary.
public enum HopSpacing {
    public static let xxs: Double = 2
    public static let xs: Double = 4
    public static let s: Double = 8
    public static let m: Double = 12
    public static let l: Double = 16
    public static let xl: Double = 20
    public static let xxl: Double = 24
    public static let xxxl: Double = 32
    public static let huge: Double = 40
    public static let giant: Double = 56

    /// Standard horizontal page margin for a compact width class.
    public static let pageCompact: Double = 20
    /// Standard horizontal page margin for a regular width class (iPad).
    public static let pageRegular: Double = 32
}

/// Corner radii. HopPotty leans soft, but not uniformly — hierarchy comes partly
/// from cards being rounder than the controls inside them.
public enum HopRadius {
    public static let xs: Double = 6
    public static let s: Double = 10
    public static let m: Double = 14
    public static let l: Double = 20
    public static let xl: Double = 26
    public static let xxl: Double = 34
    /// Full-bleed child surfaces and the shield illustration frame.
    public static let hero: Double = 44
    /// Used with `Capsule()` semantics for pills and child buttons.
    public static let pill: Double = 999
}

/// Minimum hit targets. Child controls are deliberately far above the 44pt HIG
/// floor: a three-year-old's aim is not an adult's.
public enum HopHitTarget {
    public static let parentMinimum: Double = 44
    public static let childMinimum: Double = 72
    public static let childPrimary: Double = 96
}

/// Elevation steps, expressed as shadow geometry. The colour comes from
/// ``HopSemanticPalette/shadow`` so dark mode does not glow.
public struct HopElevation: Sendable, Hashable {
    public let radius: Double
    public let yOffset: Double
    public let opacityScale: Double

    public init(radius: Double, yOffset: Double, opacityScale: Double) {
        self.radius = radius
        self.yOffset = yOffset
        self.opacityScale = opacityScale
    }

    /// No shadow. Used for flat rows inside an already-elevated card.
    public static let flat = HopElevation(radius: 0, yOffset: 0, opacityScale: 0)
    /// Resting cards on the parent dashboard.
    public static let resting = HopElevation(radius: 14, yOffset: 4, opacityScale: 1.0)
    /// The hero timer card and other primary focal surfaces.
    public static let raised = HopElevation(radius: 24, yOffset: 8, opacityScale: 1.15)
    /// Sheets, popovers and the celebration overlay.
    public static let floating = HopElevation(radius: 40, yOffset: 16, opacityScale: 1.3)
}
