import Foundation

/// Font weights, mirrored from the platform's weight axis so the scale can be
/// declared without importing SwiftUI.
public enum HopFontWeight: String, Sendable, CaseIterable {
    case regular, medium, semibold, bold, heavy
}

/// The typographic family a style belongs to.
///
/// HopPotty ships no third-party fonts. The display face is the system rounded
/// design, which gives the Fredoka-like warmth the brand wants while inheriting
/// every optical size, language and Dynamic Type behaviour Apple maintains.
/// See `Docs/DesignSystem.md` for the licensing rationale.
public enum HopFontFamily: String, Sendable {
    /// System font, rounded design. Child surfaces and brand moments.
    case rounded
    /// System font, default design. Parent surfaces and dense data.
    case standard
}

/// A named text style. Every piece of user-visible text in HopPotty uses one.
public struct HopTextStyle: Sendable, Hashable {
    public let name: String
    public let family: HopFontFamily
    /// Point size at the default Dynamic Type setting.
    public let size: Double
    public let weight: HopFontWeight
    /// Line height as a multiple of the point size.
    public let lineHeightMultiple: Double
    /// Tracking in points at the base size.
    public let tracking: Double
    /// Whether the style scales with Dynamic Type. Only the largest child display
    /// text opts out, and only because it is already far above body size and
    /// would otherwise break the illustrated layouts it sits inside.
    public let scalesWithDynamicType: Bool

    public init(
        name: String,
        family: HopFontFamily,
        size: Double,
        weight: HopFontWeight,
        lineHeightMultiple: Double = 1.2,
        tracking: Double = 0,
        scalesWithDynamicType: Bool = true
    ) {
        self.name = name
        self.family = family
        self.size = size
        self.weight = weight
        self.lineHeightMultiple = lineHeightMultiple
        self.tracking = tracking
        self.scalesWithDynamicType = scalesWithDynamicType
    }
}

/// The complete HopPotty type scale.
public enum HopTypography {
    // Child + brand surfaces — rounded, warm, generous.
    public static let hero = HopTextStyle(name: "hero", family: .rounded, size: 44, weight: .heavy, lineHeightMultiple: 1.08, tracking: -0.8)
    public static let childTitle = HopTextStyle(name: "childTitle", family: .rounded, size: 34, weight: .bold, lineHeightMultiple: 1.14, tracking: -0.4)
    public static let childInstruction = HopTextStyle(name: "childInstruction", family: .rounded, size: 24, weight: .semibold, lineHeightMultiple: 1.28)
    public static let celebration = HopTextStyle(name: "celebration", family: .rounded, size: 38, weight: .heavy, lineHeightMultiple: 1.10, tracking: -0.6)
    public static let buttonLarge = HopTextStyle(name: "buttonLarge", family: .rounded, size: 22, weight: .bold, lineHeightMultiple: 1.15)

    // Parent surfaces — standard design, Apple-utility density.
    public static let parentLargeTitle = HopTextStyle(name: "parentLargeTitle", family: .rounded, size: 32, weight: .bold, lineHeightMultiple: 1.14, tracking: -0.5)
    public static let parentTitle = HopTextStyle(name: "parentTitle", family: .rounded, size: 22, weight: .semibold, lineHeightMultiple: 1.20, tracking: -0.2)
    public static let parentHeadline = HopTextStyle(name: "parentHeadline", family: .standard, size: 17, weight: .semibold, lineHeightMultiple: 1.29)
    public static let parentBody = HopTextStyle(name: "parentBody", family: .standard, size: 17, weight: .regular, lineHeightMultiple: 1.35)
    public static let parentCallout = HopTextStyle(name: "parentCallout", family: .standard, size: 15, weight: .regular, lineHeightMultiple: 1.33)
    public static let parentCaption = HopTextStyle(name: "parentCaption", family: .standard, size: 13, weight: .regular, lineHeightMultiple: 1.31)
    public static let parentFootnote = HopTextStyle(name: "parentFootnote", family: .standard, size: 12, weight: .medium, lineHeightMultiple: 1.33, tracking: 0.2)

    // Numerics. Monospaced digits are applied at the SwiftUI layer so countdowns
    // do not jitter as they tick.
    public static let metric = HopTextStyle(name: "metric", family: .rounded, size: 28, weight: .bold, lineHeightMultiple: 1.10, tracking: -0.3)
    public static let timer = HopTextStyle(name: "timer", family: .rounded, size: 56, weight: .bold, lineHeightMultiple: 1.0, tracking: -1.4)
    public static let timerHero = HopTextStyle(name: "timerHero", family: .rounded, size: 72, weight: .heavy, lineHeightMultiple: 1.0, tracking: -2.0, scalesWithDynamicType: false)

    public static let all: [HopTextStyle] = [
        hero, childTitle, childInstruction, celebration, buttonLarge,
        parentLargeTitle, parentTitle, parentHeadline, parentBody, parentCallout,
        parentCaption, parentFootnote, metric, timer, timerHero,
    ]
}
