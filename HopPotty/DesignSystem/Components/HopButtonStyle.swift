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

    /// How this control behaves under a finger.
    ///
    /// The parent/child split from `HopMotion` in one value: a caregiver's
    /// button sinks 3% and comes back on a nearly flat spring, a child's sinks
    /// 6% and comes back with the bounce. Same code, two personalities.
    var pressFeel: HopPressFeel {
        self == .parent ? .parent : .child
    }

    var motion: HopAnimationToken {
        self == .parent ? .parentTap : .childTap
    }

    /// How far the control sinks when pressed. Kept as a named value because it
    /// is the number a designer asks about; it comes from ``pressFeel`` so
    /// there is still only one place it is decided.
    var pressedScale: CGFloat { pressFeel.surfaceScale }

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
///
/// ## What a press does
///
/// Four things, in this order, and the order is the point:
///
/// 1. the **surface sinks** on ``HopAnimationToken/press`` — no bounce, because
///    a finger going down is not springy;
/// 2. the **shadow softens** toward the ground by the same transaction, so the
///    button reads as pressed *into* the page rather than as merely smaller;
/// 3. a **pressed wash** is drawn over the fill — this is the part that still
///    happens under Reduce Motion, so the control is never silent;
/// 4. on release the surface comes back on the audience's own spring, and the
///    **label settles a beat behind it**, which is the difference between a
///    control that scales and a control with a front face.
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

        let configuration: ButtonStyleConfiguration
        let size: HopButtonSize
        let appearance: HopButtonAppearance

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
        }

        private var isPressed: Bool { configuration.isPressed }
        private var feel: HopPressFeel { size.pressFeel }

        /// Spelled out rather than `size.fillsWidth ? .infinity : nil`, which
        /// asks the compiler to find `.infinity` through an Optional.
        private var maximumWidth: CGFloat? {
            size.fillsWidth ? CGFloat.infinity : nil
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
                // The label's own transaction, so it can lag the surface on the
                // way back up without lagging it on the way down.
                .scaleEffect(feel.labelScale(isPressed: isPressed, reduceMotion: theme.reduceMotion))
                .animation(
                    feel.labelAnimation(isPressed: isPressed, reduceMotion: theme.reduceMotion),
                    value: isPressed
                )
                .padding(.horizontal, size.horizontalPadding)
                .frame(minHeight: size.minimumHeight)
                .frame(maxWidth: maximumWidth)
                .background { background }
                .modifier(theme.elevation(pressedElevation))
                .scaleEffect(feel.scale(isPressed: isPressed, reduceMotion: theme.reduceMotion))
                .opacity(isEnabled ? 1 : 0.4)
                .animation(feel.animation(isPressed: isPressed, reduceMotion: theme.reduceMotion), value: isPressed)
                .contentShape(shape)
                .environment(\.hopIsPressed, isPressed)
        }

        /// The elevation the control rests at, independent of the press.
        private var restingElevation: HopElevation {
            switch appearance {
            // Tonal controls are flat by definition.
            case .tonal: .flat
            case .filled: size.elevation
            }
        }

        /// The elevation it is drawing right now.
        ///
        /// Softened rather than swapped for `.flat`: a shadow that is scaled
        /// down can be animated, and a shadow that is removed cannot — it cuts.
        private var pressedElevation: HopElevation {
            feel.elevation(restingElevation, isPressed: isPressed, reduceMotion: theme.reduceMotion)
        }

        @ViewBuilder
        private var background: some View {
            switch appearance {
            case .filled(let fill, _):
                shape
                    .fill(fill)
                    .overlay {
                        // Drawn, not opacity-based, so a disabled control and a
                        // pressed control never look alike. This is also the
                        // whole of the press feedback under Reduce Motion.
                        shape
                            .fill(theme.isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.10))
                            .opacity(isPressed ? 1 : 0)
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
                            .opacity(isPressed ? 1 : 0)
                    }
            }
        }
    }
}

/// A borderless control that still guarantees its hit target.
struct HopBareButtonStyle: ButtonStyle {
    let minimumTarget: CGFloat
    let tint: Color
    /// Additive, with a default, so every existing call site is untouched.
    var feel: HopPressFeel = .bare

    func makeBody(configuration: Configuration) -> some View {
        Body(configuration: configuration, minimumTarget: minimumTarget, tint: tint, feel: feel)
    }

    private struct Body: View {
        @Environment(\.hopTheme) private var theme
        @Environment(\.isEnabled) private var isEnabled

        let configuration: ButtonStyleConfiguration
        let minimumTarget: CGFloat
        let tint: Color
        let feel: HopPressFeel

        var body: some View {
            configuration.label
                .foregroundStyle(tint)
                .frame(minWidth: minimumTarget, minHeight: minimumTarget)
                .contentShape(Rectangle())
                .scaleEffect(feel.scale(isPressed: configuration.isPressed, reduceMotion: theme.reduceMotion))
                // The dim is not conditional on Reduce Motion: it is the only
                // feedback a borderless control has left when nothing may move.
                .opacity(configuration.isPressed ? 0.7 : (isEnabled ? 1 : 0.4))
                .animation(
                    feel.animation(isPressed: configuration.isPressed, reduceMotion: theme.reduceMotion),
                    value: configuration.isPressed
                )
                .environment(\.hopIsPressed, configuration.isPressed)
        }
    }
}

/// A whole surface pressed as one object — a tappable card, a tile.
///
/// Deliberately thin. It publishes the press into the environment and leaves the
/// drawing to the surface, because the surface already knows its own corner
/// radius, fill and elevation, and a style that guessed at them would have to be
/// told all three. See ``HopCard`` for the other half.
struct HopSurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Corners included: a card whose corner is dead to touch is a card
            // a person taps twice.
            .contentShape(Rectangle())
            .environment(\.hopIsPressed, configuration.isPressed)
    }
}

// MARK: - Feedback

/// What a control confirmed, in the design system's own words.
///
/// Not a haptic pattern and not a `HopHapticEvent`: the design system does not
/// know what a device can do, and `HopHapticEvent` is a deliberately closed list
/// owned by `Services/Haptics` (five occasions, "and no more" — a buzz on every
/// tap teaches a child nothing and gets the whole setting switched off). This
/// enum is the seam between the two. Nothing plays unless a host installs a
/// handler, so a preview, a snapshot and a test are all silent.
public enum HopButtonFeedback: String, CaseIterable, Sendable {
    /// Something was written down or completed.
    case confirmation
    /// One option was chosen from several.
    case selection
    /// Something that changes what the app *does* to a child's device.
    case importantChange
}

/// Plays a control's feedback. Installed by the app root; no-op by default.
public struct HopButtonFeedbackHandler: Sendable {
    /// Un-isolated for the same reason ``HopVoicePlayback`` is: the design
    /// system only needs to say "this happened", and the service decides which
    /// actor answers.
    public let play: @Sendable (HopButtonFeedback) -> Void

    public init(play: @escaping @Sendable (HopButtonFeedback) -> Void) {
        self.play = play
    }

    public static let disabled = HopButtonFeedbackHandler { _ in }
}

private struct HopButtonFeedbackKey: EnvironmentKey {
    static let defaultValue = HopButtonFeedbackHandler.disabled
}

public extension EnvironmentValues {
    /// How a control confirms itself beyond the screen. Install once at the app
    /// root and map to the haptics service there.
    var hopButtonFeedback: HopButtonFeedbackHandler {
        get { self[HopButtonFeedbackKey.self] }
        set { self[HopButtonFeedbackKey.self] = newValue }
    }
}
