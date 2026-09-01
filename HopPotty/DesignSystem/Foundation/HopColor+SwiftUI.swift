import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

// The only place a `HopColorValue` becomes a SwiftUI `Color`. Keeping the
// conversion in one file is what lets the contrast tests in HopPottyKit stay
// the single source of truth: nothing downstream can invent a hue.

public extension Color {
    /// Bridges a token colour into SwiftUI.
    ///
    /// Constructed in the explicit sRGB space rather than the default
    /// (`.sRGBLinear` is what SwiftUI uses for some initialisers) so the value
    /// rendered on screen is the value the contrast tests measured.
    init(_ value: HopColorValue) {
        self.init(
            .sRGB,
            red: value.red,
            green: value.green,
            blue: value.blue,
            opacity: value.alpha
        )
    }
}

/// The semantic palette, pre-bridged to SwiftUI `Color`.
///
/// Views read `theme.color.textPrimary`; they never see a `HopColorValue` and
/// never see a hex literal.
public struct HopColors: Equatable, Sendable {
    /// The underlying token values, for the rare case a component needs the raw
    /// channels (gradients built from a single hue, contrast assertions in a
    /// debug overlay).
    public let values: HopSemanticPalette

    public init(_ values: HopSemanticPalette) {
        self.values = values
    }

    // Grounds
    public var backgroundPrimary: Color { Color(values.backgroundPrimary) }
    public var backgroundSecondary: Color { Color(values.backgroundSecondary) }
    public var surface: Color { Color(values.surface) }
    public var surfaceElevated: Color { Color(values.surfaceElevated) }
    public var surfaceSunken: Color { Color(values.surfaceSunken) }

    // Text
    public var textPrimary: Color { Color(values.textPrimary) }
    public var textSecondary: Color { Color(values.textSecondary) }
    public var textTertiary: Color { Color(values.textTertiary) }
    public var textOnBrand: Color { Color(values.textOnBrand) }

    // Brand
    public var brandPrimary: Color { Color(values.brandPrimary) }
    public var brandSecondary: Color { Color(values.brandSecondary) }
    public var brandAction: Color { Color(values.brandAction) }

    // Status
    public var success: Color { Color(values.success) }
    public var warning: Color { Color(values.warning) }
    public var neutral: Color { Color(values.neutral) }
    public var celebration: Color { Color(values.celebration) }

    // Potty events
    public var eventTried: Color { Color(values.eventTried) }
    public var eventPee: Color { Color(values.eventPee) }
    public var eventPoop: Color { Color(values.eventPoop) }
    public var eventAccident: Color { Color(values.eventAccident) }

    // Structure
    public var divider: Color { Color(values.divider) }
    public var focusRing: Color { Color(values.focusRing) }
    public var shadow: Color { Color(values.shadow) }
    public var scrim: Color { Color(values.scrim) }

    /// The accent a potty event kind is drawn in. Always paired with
    /// ``HopGlyph`` — colour alone never carries the meaning.
    public func accent(for kind: PottyEventKind) -> Color {
        switch kind {
        case .tried: eventTried
        case .pee: eventPee
        case .poop: eventPoop
        case .accident: eventAccident
        }
    }

    /// A very low-opacity wash of a tint, used behind glyphs and pills.
    ///
    /// Derived from the tint rather than from a separate token so a caller
    /// passing an arbitrary `Color` (the API contract allows it on
    /// ``HopMetricCard`` and ``HopPill``) still gets a consistent container.
    public static func wash(_ tint: Color, isDark: Bool) -> Color {
        tint.opacity(isDark ? 0.22 : 0.12)
    }
}
