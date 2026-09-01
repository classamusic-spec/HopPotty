import SwiftUI
import HopPottyDesignTokens

/// The resolved design system for one appearance.
///
/// A view reads exactly one thing from the environment — `\.hopTheme` — and
/// gets colour, type, spacing, radius, elevation and motion from it. That is
/// what makes light, dark, increased-contrast and Reduce Motion free at every
/// call site: there is no `if colorScheme == .dark` anywhere in HopPotty
/// outside this file's resolver, and no Reduce Motion check outside
/// ``HopTheme/animation(_:)``.
public struct HopTheme: Equatable, Sendable {
    /// Which of the four appearances this theme resolves.
    public let appearance: HopAppearance
    /// Whether the system has asked for reduced motion. Read it through
    /// ``animation(_:)`` rather than branching on it; the ambient modifiers in
    /// `Motion/` are the only other legitimate readers.
    public let reduceMotion: Bool

    public let color: HopColors
    public let spacing = HopSpacingScale()
    public let radius = HopRadiusScale()
    public let hitTarget = HopHitTargetScale()

    public init(appearance: HopAppearance, reduceMotion: Bool = false) {
        self.appearance = appearance
        self.reduceMotion = reduceMotion
        self.color = HopColors(HopSemanticPalette.resolved(for: appearance))
    }

    /// Whether the theme sits on a dark ground. Used for washes and for
    /// choosing between an additive and a subtractive highlight, never for
    /// picking a colour — the palette already did that.
    public var isDark: Bool { appearance.isDark }
    public var isHighContrast: Bool { appearance.isHighContrast }

    // MARK: - Type

    public func font(_ style: HopTextStyle) -> Font { style.font }

    // MARK: - Elevation

    /// A shadow modifier for the given step, coloured from the palette so dark
    /// mode gets a deeper shadow instead of a glow.
    public func elevation(_ level: HopElevation) -> HopElevationModifier {
        HopElevationModifier(level: level, shadow: color.values.shadow)
    }

    // MARK: - Motion

    /// The animation for a motion token, already degraded if Reduce Motion is
    /// on. **This is the only place in HopPotty that substitutes for a spring.**
    public func animation(_ token: HopAnimationToken) -> Animation {
        token.animation(reduceMotion: reduceMotion)
    }

    /// A transition matching a motion token. Collapses to a cross-fade under
    /// Reduce Motion, for the same reason.
    public func transition(_ token: HopAnimationToken) -> AnyTransition {
        token.transition(reduceMotion: reduceMotion)
    }

    /// Wall-clock length of a token's animation, for sequencing work that has to
    /// wait for it (a celebration handing control back, a haptic landing on the
    /// beat). Already reduced when Reduce Motion is on.
    public func duration(_ token: HopAnimationToken) -> Double {
        token.duration(reduceMotion: reduceMotion)
    }

    // MARK: - Resolution

    /// Resolves the appearance from the two environment values Apple exposes.
    public static func appearance(
        colorScheme: ColorScheme,
        contrast: ColorSchemeContrast
    ) -> HopAppearance {
        switch (colorScheme, contrast) {
        case (.dark, .increased): .darkHighContrast
        case (.dark, _): .dark
        case (_, .increased): .lightHighContrast
        default: .light
        }
    }

    /// The theme used before a root has installed one. Light, motion on — the
    /// same thing a fresh iPhone shows.
    public static let fallback = HopTheme(appearance: .light)
}

/// The 4-point spacing scale, as `CGFloat` for SwiftUI.
public struct HopSpacingScale: Equatable, Sendable {
    public init() {}
    public var xxs: CGFloat { CGFloat(HopSpacing.xxs) }
    public var xs: CGFloat { CGFloat(HopSpacing.xs) }
    public var s: CGFloat { CGFloat(HopSpacing.s) }
    public var m: CGFloat { CGFloat(HopSpacing.m) }
    public var l: CGFloat { CGFloat(HopSpacing.l) }
    public var xl: CGFloat { CGFloat(HopSpacing.xl) }
    public var xxl: CGFloat { CGFloat(HopSpacing.xxl) }
    public var xxxl: CGFloat { CGFloat(HopSpacing.xxxl) }
    public var huge: CGFloat { CGFloat(HopSpacing.huge) }
    public var giant: CGFloat { CGFloat(HopSpacing.giant) }
    public var pageCompact: CGFloat { CGFloat(HopSpacing.pageCompact) }
    public var pageRegular: CGFloat { CGFloat(HopSpacing.pageRegular) }
}

/// Corner radii, as `CGFloat` for SwiftUI.
public struct HopRadiusScale: Equatable, Sendable {
    public init() {}
    public var xs: CGFloat { CGFloat(HopRadius.xs) }
    public var s: CGFloat { CGFloat(HopRadius.s) }
    public var m: CGFloat { CGFloat(HopRadius.m) }
    public var l: CGFloat { CGFloat(HopRadius.l) }
    public var xl: CGFloat { CGFloat(HopRadius.xl) }
    public var xxl: CGFloat { CGFloat(HopRadius.xxl) }
    public var hero: CGFloat { CGFloat(HopRadius.hero) }
}

/// Minimum hit targets, as `CGFloat` for SwiftUI.
public struct HopHitTargetScale: Equatable, Sendable {
    public init() {}
    public var parent: CGFloat { CGFloat(HopHitTarget.parentMinimum) }
    public var child: CGFloat { CGFloat(HopHitTarget.childMinimum) }
    public var childPrimary: CGFloat { CGFloat(HopHitTarget.childPrimary) }
}
