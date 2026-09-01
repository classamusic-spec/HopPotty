import SwiftUI
import HopPottyDesignTokens

/// How large a control has to be before a finger can reliably hit it.
///
/// `child` and `childPrimary` are far above the 44pt HIG floor on purpose: a
/// three-year-old aims with a whole hand, often while holding the device with
/// the other one.
public enum HopButtonSize: String, CaseIterable, Sendable {
    case parent
    case child
    case childPrimary

    /// Minimum height, from ``HopHitTarget``.
    public var minimumHeight: CGFloat {
        switch self {
        case .parent: CGFloat(HopHitTarget.parentMinimum)
        case .child: CGFloat(HopHitTarget.childMinimum)
        case .childPrimary: CGFloat(HopHitTarget.childPrimary)
        }
    }

    var textStyle: HopTextStyle {
        switch self {
        case .parent: HopTypography.parentHeadline
        case .child, .childPrimary: HopTypography.buttonLarge
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .parent: CGFloat(HopSpacing.xxl)
        case .child: CGFloat(HopSpacing.xxxl)
        case .childPrimary: CGFloat(HopSpacing.huge)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        // Child controls are capsules: a capsule has no corner to miss, and it
        // reads as "press me" to someone who cannot read "press me".
        case .parent: CGFloat(HopRadius.m)
        case .child, .childPrimary: CGFloat(HopRadius.pill)
        }
    }

    var glyphSize: CGFloat {
        switch self {
        case .parent: 17
        case .child: 26
        case .childPrimary: 32
        }
    }

    var motion: HopAnimationToken {
        self == .parent ? .parentTap : .childTap
    }

    /// How far the control sinks when pressed. Child controls squash more —
    /// the feedback has to be visible from a metre away at arm's length.
    var pressedScale: CGFloat {
        self == .parent ? 0.975 : 0.945
    }

    var elevation: HopElevation {
        switch self {
        case .parent: .resting
        case .child, .childPrimary: .raised
        }
    }

    /// Whether the control stretches to the width it is given. Parent buttons
    /// fill their row like a form control; child buttons hug their label so the
    /// capsule stays a recognisable object rather than a bar.
    var fillsWidth: Bool { self == .parent }
}

/// How a HopPotty control is painted.
enum HopButtonAppearance {
    /// Solid fill, text on brand. One per screen.
    case filled(fill: Color, foreground: Color)
    /// Tinted wash, brand text. The parent dashboard's workhorse.
    case tonal(tint: Color)
}

/// The one button style. Press feedback, elevation, hit target and Reduce
/// Motion all live here, so no individual button re-implements them.
struct HopButtonStyle: ButtonStyle {
    let size: HopButtonSize
    let appearance: HopButtonAppearance

    func makeBody(configuration: Configuration) -> some View {
        // ButtonStyle is not a View, so @Environment inside it never updates.
        // The body has to be a real View for the theme to track appearance and
        // Reduce Motion changes.
        Body(configuration: configuration, size: size, appearance: appearance)
    }

    private struct Body: View {
        @Environment(\.hopTheme) private var theme
        @Environment(\.isEnabled) private var isEnabled

        let configuration: Configuration
        let size: HopButtonSize
        let appearance: HopButtonAppearance

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
        }

        private var foreground: Color {
            switch appearance {
            case .filled(_, let foreground): foreground
            case .tonal(let tint): tint
            }
        }

        var body: some View {
            configuration.label
                .hopTextStyle(size.textStyle)
                .foregroundStyle(foreground)
                .padding(.horizontal, size.horizontalPadding)
                .frame(minHeight: size.minimumHeight)
                .frame(maxWidth: size.fillsWidth ? .infinity : nil)
                .background { background }
                .modifier(theme.elevation(elevation))
                .scaleEffect(configuration.isPressed ? size.pressedScale : 1)
                .opacity(isEnabled ? 1 : 0.4)
                .animation(theme.animation(size.motion), value: configuration.isPressed)
                .contentShape(shape)
        }

        private var elevation: HopElevation {
            switch appearance {
            // Tonal controls are flat by definition; a pressed control drops to
            // the ground so the press reads as a press and not as a colour change.
            case .tonal: .flat
            case .filled: configuration.isPressed ? .flat : size.elevation
            }
        }

        @ViewBuilder
        private var background: some View {
            switch appearance {
            case .filled(let fill, _):
                shape
                    .fill(fill)
                    .overlay {
                        // Drawn, not opacity-based, so a disabled control and a
                        // pressed control never look alike.
                        shape
                            .fill(theme.isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.10))
                            .opacity(configuration.isPressed ? 1 : 0)
                    }
            case .tonal(let tint):
                shape
                    .fill(HopColors.wash(tint, isDark: theme.isDark))
                    .overlay {
                        shape.strokeBorder(
                            tint.opacity(theme.isHighContrast ? 0.85 : 0),
                            lineWidth: 1.5
                        )
                    }
                    .overlay {
                        shape
                            .fill(tint.opacity(0.12))
                            .opacity(configuration.isPressed ? 1 : 0)
                    }
            }
        }
    }
}

/// A borderless control that still guarantees its hit target.
struct HopBareButtonStyle: ButtonStyle {
    let minimumTarget: CGFloat
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        Body(configuration: configuration, minimumTarget: minimumTarget, tint: tint)
    }

    private struct Body: View {
        @Environment(\.hopTheme) private var theme
        @Environment(\.isEnabled) private var isEnabled

        let configuration: Configuration
        let minimumTarget: CGFloat
        let tint: Color

        var body: some View {
            configuration.label
                .foregroundStyle(tint)
                .frame(minWidth: minimumTarget, minHeight: minimumTarget)
                .contentShape(Rectangle())
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .opacity(configuration.isPressed ? 0.7 : (isEnabled ? 1 : 0.4))
                .animation(theme.animation(.parentTap), value: configuration.isPressed)
        }
    }
}
