import SwiftUI
import HopPottyDesignTokens

/// Applies an elevation step as shadow geometry.
///
/// Two shadows, not one. The wide soft shadow gives the card its height; the
/// tight contact shadow directly under it is what stops a raised surface from
/// looking like it is floating unattached. Both are drawn from
/// ``HopSemanticPalette/shadow``, so dark mode deepens instead of glowing.
public struct HopElevationModifier: ViewModifier {
    private let level: HopElevation
    private let shadow: HopColorValue

    public init(level: HopElevation, shadow: HopColorValue) {
        self.level = level
        self.shadow = shadow
    }

    private var primary: Color {
        Color(shadow.opacity(min(1, shadow.alpha * level.opacityScale)))
    }

    private var contact: Color {
        Color(shadow.opacity(min(1, shadow.alpha * level.opacityScale * 0.55)))
    }

    public func body(content: Content) -> some View {
        if level.radius == 0 {
            content
        } else {
            content
                .shadow(color: primary, radius: CGFloat(level.radius), x: 0, y: CGFloat(level.yOffset))
                .shadow(color: contact, radius: CGFloat(level.radius) * 0.18, x: 0, y: CGFloat(level.yOffset) * 0.22)
        }
    }
}

public extension View {
    /// Raises a surface by a named elevation step, using the current theme's
    /// shadow colour.
    func hopElevation(_ level: HopElevation) -> some View {
        modifier(HopElevationEnvironmentModifier(level: level))
    }
}

/// Reads the theme so `hopElevation(_:)` can be called without one in hand.
public struct HopElevationEnvironmentModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    let level: HopElevation

    public func body(content: Content) -> some View {
        content.modifier(theme.elevation(level))
    }
}

public extension HopElevation {
    /// The corner radius a surface at this elevation normally uses. Higher
    /// surfaces are rounder, which is most of what separates a row from a card
    /// from a sheet before you read a single word.
    var suggestedRadius: CGFloat {
        switch radius {
        case 0: CGFloat(HopRadius.m)
        case ..<20: CGFloat(HopRadius.l)
        case ..<30: CGFloat(HopRadius.xl)
        default: CGFloat(HopRadius.xxl)
        }
    }
}
