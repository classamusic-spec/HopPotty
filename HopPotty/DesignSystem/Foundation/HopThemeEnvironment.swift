import SwiftUI
import HopPottyDesignTokens

private struct HopThemeKey: EnvironmentKey {
    // A view rendered outside a themed root still draws correctly rather than
    // crashing or rendering black-on-black; it just will not follow dark mode.
    static let defaultValue = HopTheme.fallback
}

public extension EnvironmentValues {
    /// The resolved design system. Install it once with ``View/hopThemedRoot(appearance:)``.
    var hopTheme: HopTheme {
        get { self[HopThemeKey.self] }
        set { self[HopThemeKey.self] = newValue }
    }
}

/// Resolves the appearance from the OS and publishes a ``HopTheme``.
///
/// This is the *only* view in HopPotty that reads `colorScheme`,
/// `colorSchemeContrast` or `accessibilityReduceMotion`. Everything downstream
/// asks the theme. Install it at the app root and at the root of every preview.
public struct HopThemedRoot<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Forces an appearance regardless of the OS. Previews and the design lab
    /// use it to show increased contrast, which SwiftUI does not let a preview
    /// set through the environment.
    private let appearanceOverride: HopAppearance?
    /// Forces Reduce Motion on, so a preview or a snapshot test can exercise the
    /// degraded path without changing a device setting.
    private let reduceMotionOverride: Bool?
    private let content: Content

    public init(
        appearance appearanceOverride: HopAppearance? = nil,
        reduceMotion reduceMotionOverride: Bool? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.appearanceOverride = appearanceOverride
        self.reduceMotionOverride = reduceMotionOverride
        self.content = content()
    }

    private var theme: HopTheme {
        let appearance = appearanceOverride
            ?? HopTheme.appearance(colorScheme: colorScheme, contrast: contrast)
        return HopTheme(appearance: appearance, reduceMotion: reduceMotionOverride ?? reduceMotion)
    }

    public var body: some View {
        content
            .environment(\.hopTheme, theme)
            // Forcing the colour scheme when an appearance is overridden keeps
            // system-drawn chrome (selection, keyboard, native controls) in step
            // with the palette we just swapped underneath it.
            .preferredColorScheme(
                appearanceOverride.map { (appearance: HopAppearance) -> ColorScheme in
                    appearance.isDark ? .dark : .light
                }
            )
            .tint(theme.color.brandAction)
    }
}

public extension View {
    /// Installs the design system. Call once, as high as possible.
    func hopThemedRoot(
        appearance: HopAppearance? = nil,
        reduceMotion: Bool? = nil
    ) -> some View {
        HopThemedRoot(appearance: appearance, reduceMotion: reduceMotion) { self }
    }

    /// Paints the app's ground colour behind the content.
    func hopBackground(_ ground: HopGround = .primary) -> some View {
        modifier(HopBackgroundModifier(ground: ground))
    }
}

/// Which ground a surface sits on.
public enum HopGround: Equatable, Sendable {
    case primary
    case secondary
    case sunken
}

public struct HopBackgroundModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    let ground: HopGround

    private var color: Color {
        switch ground {
        case .primary: theme.color.backgroundPrimary
        case .secondary: theme.color.backgroundSecondary
        case .sunken: theme.color.surfaceSunken
        }
    }

    public func body(content: Content) -> some View {
        content.background(color.ignoresSafeArea())
    }
}
