import SwiftUI
import HopPottyDesignTokens

// Bridges the platform-agnostic type scale onto SwiftUI. Two things happen here
// that cannot happen in HopPottyKit: the font is built, and Dynamic Type is
// bounded for the handful of display styles that sit inside fixed illustrated
// layouts.

public extension HopFontWeight {
    var swiftUIWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
}

public extension HopFontFamily {
    var swiftUIDesign: Font.Design {
        switch self {
        case .rounded: .rounded
        case .standard: .default
        }
    }
}

public extension HopTextStyle {
    // Leading-dot access at call sites: `theme.font(.parentBody)`.
    static var hero: HopTextStyle { HopTypography.hero }
    static var childTitle: HopTextStyle { HopTypography.childTitle }
    static var childInstruction: HopTextStyle { HopTypography.childInstruction }
    static var celebration: HopTextStyle { HopTypography.celebration }
    static var buttonLarge: HopTextStyle { HopTypography.buttonLarge }
    static var parentLargeTitle: HopTextStyle { HopTypography.parentLargeTitle }
    static var parentTitle: HopTextStyle { HopTypography.parentTitle }
    static var parentHeadline: HopTextStyle { HopTypography.parentHeadline }
    static var parentBody: HopTextStyle { HopTypography.parentBody }
    static var parentCallout: HopTextStyle { HopTypography.parentCallout }
    static var parentCaption: HopTextStyle { HopTypography.parentCaption }
    static var parentFootnote: HopTextStyle { HopTypography.parentFootnote }
    static var parentMetric: HopTextStyle { HopTypography.parentMetric }
    static var metric: HopTextStyle { HopTypography.metric }
    static var timer: HopTextStyle { HopTypography.timer }
    static var timerHero: HopTextStyle { HopTypography.timerHero }

    /// Whether this style renders numbers that change in place.
    ///
    /// A proportional "1" is narrower than a "4", so a ticking countdown drawn
    /// in a proportional face shifts sideways every second. Monospaced digits
    /// are not a preference here; they are the reason the timer stops twitching.
    var usesMonospacedDigits: Bool {
        switch name {
        case HopTypography.parentMetric.name, HopTypography.metric.name,
             HopTypography.timer.name, HopTypography.timerHero.name:
            true
        default:
            false
        }
    }

    /// Extra leading, in points, to reach the style's line-height multiple.
    var lineSpacing: CGFloat {
        max(0, CGFloat(size * (lineHeightMultiple - 1)))
    }

    /// The largest Dynamic Type size this style is allowed to reach.
    ///
    /// Only display text is bounded, and never below `.xxxLarge` — the text
    /// still grows well past the default, it just stops before a 44pt heading
    /// at AX5 pushes Hop off the screen. Body and control text is never capped.
    var maximumDynamicTypeSize: DynamicTypeSize? {
        guard !scalesWithDynamicType else { return nil }
        return .accessibility1
    }

    /// The SwiftUI font, before any Dynamic Type bounding.
    var font: Font {
        let base = Font.system(size: CGFloat(size), weight: weight.swiftUIWeight, design: family.swiftUIDesign)
        return usesMonospacedDigits ? base.monospacedDigit() : base
    }
}

/// Applies a named text style: font, tracking, leading, and the Dynamic Type
/// bound for display styles.
public struct HopTextStyleModifier: ViewModifier {
    private let style: HopTextStyle
    private let allowsTightening: Bool

    public init(style: HopTextStyle, allowsTightening: Bool = true) {
        self.style = style
        self.allowsTightening = allowsTightening
    }

    public func body(content: Content) -> some View {
        applyBound(
            content
                .font(style.font)
                .tracking(CGFloat(style.tracking))
                .lineSpacing(style.lineSpacing)
                // Shrinking a hair before wrapping keeps a long nickname on one
                // line; it never replaces wrapping, which stays available.
                .minimumScaleFactor(allowsTightening ? 0.82 : 1.0)
        )
    }

    @ViewBuilder
    private func applyBound(_ content: some View) -> some View {
        if let maximum = style.maximumDynamicTypeSize {
            content.dynamicTypeSize(...maximum)
        } else {
            content
        }
    }
}

public extension View {
    /// The only way text is styled in HopPotty.
    func hopTextStyle(_ style: HopTextStyle, allowsTightening: Bool = true) -> some View {
        modifier(HopTextStyleModifier(style: style, allowsTightening: allowsTightening))
    }

    /// Marks text as numeric so digits stay in fixed-width cells.
    ///
    /// Redundant for `.timer` and `.metric`, which already carry it; needed when
    /// a number is set in a text style that is normally prose.
    func hopNumericText() -> some View {
        monospacedDigit()
    }
}
