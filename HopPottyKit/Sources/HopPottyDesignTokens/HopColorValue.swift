import Foundation

/// A platform-independent sRGB colour value.
///
/// The design system's colour truth lives here rather than in an asset catalog so
/// that contrast ratios can be asserted in tests on any toolchain. The SwiftUI
/// layer converts these into `Color` at the boundary; nothing else should ever
/// hold a raw hex string.
public struct HopColorValue: Hashable, Sendable {
    /// Red channel, 0...1 in sRGB space.
    public let red: Double
    /// Green channel, 0...1 in sRGB space.
    public let green: Double
    /// Blue channel, 0...1 in sRGB space.
    public let blue: Double
    /// Opacity, 0...1.
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red.clampedToUnitRange
        self.green = green.clampedToUnitRange
        self.blue = blue.clampedToUnitRange
        self.alpha = alpha.clampedToUnitRange
    }

    /// Creates a colour from a 6-digit RGB hex value such as `0x63C88A`.
    ///
    /// A numeric literal is used rather than a string so that a malformed colour
    /// is a compile-time error instead of a silent runtime fallback.
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// The uppercase `#RRGGBB` representation, used by documentation and the art pipeline.
    public var hexString: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Returns the same colour at a different opacity.
    public func opacity(_ value: Double) -> HopColorValue {
        HopColorValue(red: red, green: green, blue: blue, alpha: value)
    }

    // MARK: - Contrast

    /// Relative luminance per WCAG 2.1, used to verify text legibility.
    public var relativeLuminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// The WCAG 2.1 contrast ratio between two opaque colours, from 1 to 21.
    ///
    /// Both colours are treated as opaque; composite translucent colours against
    /// their backdrop with ``composited(over:)`` before measuring.
    public func contrastRatio(against other: HopColorValue) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Flattens a translucent colour onto an opaque backdrop using source-over compositing.
    public func composited(over backdrop: HopColorValue) -> HopColorValue {
        guard alpha < 1 else { return self }
        return HopColorValue(
            red: red * alpha + backdrop.red * (1 - alpha),
            green: green * alpha + backdrop.green * (1 - alpha),
            blue: blue * alpha + backdrop.blue * (1 - alpha),
            alpha: 1
        )
    }
}

private extension Double {
    var clampedToUnitRange: Double { Swift.min(1, Swift.max(0, self)) }
}
