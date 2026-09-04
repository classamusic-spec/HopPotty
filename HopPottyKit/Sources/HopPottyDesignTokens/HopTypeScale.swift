import Foundation

/// Font weights, mirrored from the platform's weight axis so the scale can be
/// declared without importing SwiftUI.
public enum HopFontWeight: String, Sendable, CaseIterable {
    case regular, medium, semibold, bold, heavy
}

/// The typographic family a style belongs to.
///
/// HopPotty ships **Fredoka** for display and child surfaces and **Nunito** for
/// parent surfaces, both under the SIL Open Font License. The app previously
/// used the system font's rounded design as a stand-in for Fredoka, which was a
/// defensible trade until it met the design renders: those are set in the real
/// faces, so every screen in the app was a different typeface from its own
/// specification. See `HopPotty/Resources/Fonts/README.md` and
/// `Docs/DesignSystem.md`.
public enum HopFontFamily: String, Sendable {
    /// Fredoka. Child surfaces and brand moments.
    case rounded
    /// Nunito. Parent surfaces and dense data.
    case standard

    /// The bundled face for a weight, by PostScript name.
    ///
    /// Static instances, one per weight — see the fonts' README for why the
    /// variable files cannot be bundled directly. A weight with no shipped face
    /// resolves to the nearest heavier one rather than silently rendering at the
    /// variable default, which is the lightest instance in both families.
    public func postScriptName(for weight: HopFontWeight) -> String {
        switch self {
        case .rounded:
            // Fredoka's axis stops at 700, so `heavy` clamps to Bold — exactly
            // what the render harness gets from a `font-weight: 300 700` face.
            switch weight {
            case .regular, .medium, .semibold: return "Fredoka-SemiBold"
            case .bold, .heavy: return "Fredoka-Bold"
            }
        case .standard:
            switch weight {
            case .regular: return "Nunito-Regular"
            case .medium: return "Nunito-Medium"
            case .semibold: return "Nunito-SemiBold"
            case .bold: return "Nunito-Bold"
            case .heavy: return "Nunito-ExtraBold"
            }
        }
    }

    /// Every face the app must bundle for this family to render.
    public var bundledFaces: [String] {
        HopFontWeight.allCases.map { postScriptName(for: $0) }.reduced()
    }
}

private extension Array where Element == String {
    /// Distinct, order-preserving — several weights share one face.
    func reduced() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
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
    //
    // `parentLargeTitle` was `.rounded`, which contradicted the line above it:
    // a rounded bold 32pt heading is the single loudest signal that a screen
    // belongs to a children's app, and it sat on top of Home, Progress and
    // every Settings screen. Parent surfaces are SF Pro. Only parent surfaces
    // use this style — the rounded `parentTitle` below is shared with child
    // screens and is deliberately left alone.
    public static let parentLargeTitle = HopTextStyle(name: "parentLargeTitle", family: .standard, size: 32, weight: .bold, lineHeightMultiple: 1.14, tracking: -0.5)
    public static let parentTitle = HopTextStyle(name: "parentTitle", family: .rounded, size: 22, weight: .semibold, lineHeightMultiple: 1.20, tracking: -0.2)
    public static let parentHeadline = HopTextStyle(name: "parentHeadline", family: .standard, size: 17, weight: .semibold, lineHeightMultiple: 1.29)
    public static let parentBody = HopTextStyle(name: "parentBody", family: .standard, size: 17, weight: .regular, lineHeightMultiple: 1.35)
    public static let parentCallout = HopTextStyle(name: "parentCallout", family: .standard, size: 15, weight: .regular, lineHeightMultiple: 1.33)
    public static let parentCaption = HopTextStyle(name: "parentCaption", family: .standard, size: 13, weight: .regular, lineHeightMultiple: 1.31)
    public static let parentFootnote = HopTextStyle(name: "parentFootnote", family: .standard, size: 12, weight: .medium, lineHeightMultiple: 1.33, tracking: 0.2)
    /// A figure in a compact totals row — the day's counts on Home, the week's
    /// on Progress. Additive: `metric` below is the *rounded* number style and
    /// stays that way because the child's star badge shares it, while a row of
    /// four numbers on a caregiver's dashboard is parent chrome and is set in
    /// the system font like the rest of it. Smaller than `parentLargeTitle`,
    /// which is a heading and would shout at four across.
    public static let parentMetric = HopTextStyle(name: "parentMetric", family: .standard, size: 24, weight: .bold, lineHeightMultiple: 1.15, tracking: -0.4)

    // Numerics. Monospaced digits are applied at the SwiftUI layer so countdowns
    // do not jitter as they tick.
    public static let metric = HopTextStyle(name: "metric", family: .rounded, size: 28, weight: .bold, lineHeightMultiple: 1.10, tracking: -0.3)
    // The two countdowns a caregiver reads — the dashboard hero and the Live
    // Activity — are parent surfaces, so they are SF Pro too. `metric` stays
    // rounded: it is shared with the child's star badge, where the warmth is
    // the point.
    public static let timer = HopTextStyle(name: "timer", family: .standard, size: 56, weight: .bold, lineHeightMultiple: 1.0, tracking: -1.4)
    public static let timerHero = HopTextStyle(name: "timerHero", family: .standard, size: 72, weight: .heavy, lineHeightMultiple: 1.0, tracking: -2.0, scalesWithDynamicType: false)

    public static let all: [HopTextStyle] = [
        hero, childTitle, childInstruction, celebration, buttonLarge,
        parentLargeTitle, parentTitle, parentHeadline, parentBody, parentCallout,
        parentCaption, parentFootnote, parentMetric, metric, timer, timerHero,
    ]
}
