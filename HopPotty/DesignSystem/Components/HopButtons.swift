import SwiftUI
import HopPottyDesignTokens

/// The primary call to action. One per screen.
///
/// At `.child` and `.childPrimary` the label is a capsule far above the HIG
/// floor, drawn with a glyph so a pre-reader can tell two buttons apart before
/// anyone reads them the words.
public struct HopPrimaryButton: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopButtonFeedback) private var buttonFeedback
    @FocusState private var isFocused: Bool

    private let title: String
    private let icon: String?
    private let size: HopButtonSize
    private let feedback: HopButtonFeedback?
    private let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        size: HopButtonSize = .parent,
        feedback: HopButtonFeedback? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.feedback = feedback
        self.action = action
    }

    public var body: some View {
        Button {
            // Silent unless a host installed a handler, and silent unless this
            // particular control asked for one. There is no app-wide "buzz on
            // every tap" path through here by construction.
            if let feedback { buttonFeedback.play(feedback) }
            action()
        } label: {
            HopButtonLabel(title: title, icon: icon, size: size)
        }
        .buttonStyle(
            HopButtonStyle(
                size: size,
                appearance: .filled(fill: theme.color.brandAction, foreground: theme.color.textOnBrand)
            )
        )
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: size.cornerRadius)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

/// The secondary action beside a primary one. Always parent-sized: a child
/// surface that needs two equal choices uses two `.child` primaries instead, so
/// neither is visually demoted.
public struct HopSecondaryButton: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopButtonFeedback) private var buttonFeedback
    @FocusState private var isFocused: Bool

    private let title: String
    private let icon: String?
    private let feedback: HopButtonFeedback?
    private let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        feedback: HopButtonFeedback? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.feedback = feedback
        self.action = action
    }

    public var body: some View {
        Button {
            if let feedback { buttonFeedback.play(feedback) }
            action()
        } label: {
            HopButtonLabel(title: title, icon: icon, size: .parent)
        }
        .buttonStyle(HopButtonStyle(size: .parent, appearance: .tonal(tint: theme.color.brandAction)))
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: HopButtonSize.parent.cornerRadius)
        .accessibilityLabel(title)
    }
}

/// An icon-only control.
///
/// `accessibilityLabel` is a required parameter, not an optional courtesy: an
/// unlabelled icon button is unusable with VoiceOver, and making it impossible
/// to construct one is cheaper than catching it in review.
public struct HopIconButton: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopButtonFeedback) private var buttonFeedback
    @FocusState private var isFocused: Bool

    private let systemImage: String
    private let label: String
    private let tint: Color?
    private let minimumTarget: CGFloat
    private let feedback: HopButtonFeedback?
    private let action: () -> Void

    public init(
        systemImage: String,
        accessibilityLabel: String,
        feedback: HopButtonFeedback? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = accessibilityLabel
        self.tint = nil
        self.minimumTarget = CGFloat(HopHitTarget.parentMinimum)
        self.feedback = feedback
        self.action = action
    }

    /// Child-surface variant: a bigger target and an explicit tint.
    public init(
        systemImage: String,
        accessibilityLabel: String,
        tint: Color,
        minimumTarget: CGFloat,
        feedback: HopButtonFeedback? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = accessibilityLabel
        self.tint = tint
        self.minimumTarget = minimumTarget
        self.feedback = feedback
        self.action = action
    }

    public var body: some View {
        Button {
            if let feedback { buttonFeedback.play(feedback) }
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: minimumTarget * 0.4, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(HopBareButtonStyle(minimumTarget: minimumTarget, tint: tint ?? theme.color.brandAction))
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: minimumTarget / 2)
        .accessibilityLabel(label)
    }
}

/// A destructive action. Parent surfaces only, and every caller is expected to
/// have already passed the parent gate — see ``View/hopParentGated(isPresented:onPass:)``.
public struct HopDestructiveButton: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopButtonFeedback) private var buttonFeedback
    @FocusState private var isFocused: Bool

    private let title: String
    private let feedback: HopButtonFeedback?
    private let action: () -> Void

    public init(_ title: String, feedback: HopButtonFeedback? = nil, action: @escaping () -> Void) {
        self.title = title
        self.feedback = feedback
        self.action = action
    }

    /// Deliberately not the brand's peach accent: destructive controls use the
    /// platform's red so they carry the meaning a person already learned
    /// everywhere else on their phone.
    private var destructive: Color {
        theme.isDark ? Color(red: 1.0, green: 0.41, blue: 0.38) : Color(red: 0.76, green: 0.13, blue: 0.13)
    }

    public var body: some View {
        Button {
            if let feedback { buttonFeedback.play(feedback) }
            action()
        } label: {
            HopButtonLabel(title: title, icon: nil, size: .parent)
        }
        .buttonStyle(HopButtonStyle(size: .parent, appearance: .tonal(tint: destructive)))
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: HopButtonSize.parent.cornerRadius)
        .accessibilityLabel(title)
        // VoiceOver announces the consequence before the person commits, which
        // the visual red does on a parent surface but the label alone does not.
        .accessibilityHint(HopStrings.destructiveHint)
    }
}

/// Shared label layout: optional leading symbol, then the title.
///
/// The glyph presses a little further than the words. On a child's capsule the
/// symbol is 26–32pt and is the part a pre-reader is aiming at, so giving it a
/// touch more travel makes the button read as a thing with a face on it rather
/// than a rectangle that got smaller. Parent buttons skip it: at 17pt it would
/// be noise.
struct HopButtonLabel: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopIsPressed) private var isPressed

    let title: String
    let icon: String?
    let size: HopButtonSize

    private var glyphScale: CGFloat {
        guard isPressed, size != .parent, !theme.reduceMotion else { return 1 }
        return 0.94
    }

    var body: some View {
        HStack(spacing: size == .parent ? CGFloat(HopSpacing.s) : CGFloat(HopSpacing.m)) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: size.glyphSize, weight: .semibold))
                    .scaleEffect(glyphScale)
                    .hopAnimation(size.pressFeel.pressToken, value: isPressed)
                    // Decorative: the title beside it already carries the meaning.
                    .accessibilityHidden(true)
            }
            Text(title)
                // Child labels are short by design, but a localised string can
                // still run long; wrapping is always allowed, truncation is not.
                .lineLimit(size == .parent ? 2 : 3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, CGFloat(HopSpacing.s))
    }
}

#Preview("Buttons · default") {
    ScrollView {
        VStack(spacing: 20) {
            HopPrimaryButton("Start a Potty Pause", icon: "play.fill") {}
            HopSecondaryButton("Skip this one", icon: "forward.fill") {}
            HopDestructiveButton("Delete all of Sam's data") {}
            HStack(spacing: 16) {
                HopIconButton(systemImage: "gearshape.fill", accessibilityLabel: "Settings") {}
                HopIconButton(systemImage: "plus", accessibilityLabel: "Add an entry") {}
            }
            Divider()
            HopPrimaryButton("I tried!", icon: "checkmark", size: .child) {}
            HopPrimaryButton("Let's go", icon: "figure.walk", size: .childPrimary) {}
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Buttons · long text at AX3") {
    ScrollView {
        VStack(spacing: 20) {
            HopPrimaryButton("Start a Potty Pause for Sam right now", icon: "play.fill") {}
            HopSecondaryButton("Skip this one and wait for the next reminder") {}
            HopPrimaryButton("I gave it a really good try just now", size: .childPrimary) {}
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Buttons · dark") {
    VStack(spacing: 20) {
        HopPrimaryButton("Start a Potty Pause", icon: "play.fill") {}
        HopSecondaryButton("Skip this one") {}
        HopDestructiveButton("Delete all of Sam's data") {}
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}

#Preview("Buttons · high contrast") {
    VStack(spacing: 20) {
        HopPrimaryButton("Start a Potty Pause", icon: "play.fill") {}
        HopSecondaryButton("Skip this one") {}
        HopPrimaryButton("I tried!", size: .child) {}
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot(appearance: .lightHighContrast)
}

#if DEBUG
/// Draws a control at rest beside the same control held down.
///
/// `ButtonStyle.Configuration.isPressed` cannot be forced from a preview, so the
/// held state is drawn from the same ``HopPressFeel`` the style uses rather than
/// from a screenshot of a finger. If this specimen and the real button ever
/// disagree, the specimen is wrong — it reads the tokens, not the style.
private struct HopPressSpecimen: View {
    @Environment(\.hopTheme) private var theme

    let title: String
    let size: HopButtonSize
    let feel: HopPressFeel

    /// Spelled out with a plain string rather than a `format:` interpolation:
    /// `CGFloat` has no guaranteed `FloatingPointFormatStyle`, and a specimen
    /// label is not worth a conversion dance.
    private var scaleDescription: String {
        String(Int((feel.surfaceScale * 100).rounded())) + "%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text("\(title) · held at \(scaleDescription) of full size")
                .hopTextStyle(.parentFootnote)
                .foregroundStyle(theme.color.textSecondary)

            HStack(spacing: theme.spacing.xl) {
                specimen(isPressed: false, caption: "at rest")
                specimen(isPressed: true, caption: "held")
            }
        }
    }

    private func specimen(isPressed: Bool, caption: String) -> some View {
        VStack(spacing: theme.spacing.xs) {
            Text(title)
                .hopTextStyle(size.textStyle)
                .foregroundStyle(theme.color.textOnBrand)
                .scaleEffect(feel.labelScale(isPressed: isPressed, reduceMotion: theme.reduceMotion))
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, theme.spacing.s)
                .frame(minHeight: size.minimumHeight)
                .background {
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(theme.color.brandAction)
                        .overlay {
                            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                                .fill(theme.isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.10))
                                .opacity(isPressed ? 1 : 0)
                        }
                }
                .modifier(
                    theme.elevation(
                        feel.elevation(size.elevation, isPressed: isPressed, reduceMotion: theme.reduceMotion)
                    )
                )
                .scaleEffect(feel.scale(isPressed: isPressed, reduceMotion: theme.reduceMotion))

            Text(caption)
                .hopTextStyle(.parentCaption)
                .foregroundStyle(theme.color.textTertiary)
        }
    }
}

private struct HopPressStateGallery: View {
    @Environment(\.hopTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xxl) {
            Text(theme.reduceMotion
                 ? "Reduce Motion: the geometry is identical. Only the pressed wash confirms the touch."
                 : "Full motion: the surface sinks, the shadow softens, the label settles a beat later.")
                .hopTextStyle(.parentCallout)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HopPressSpecimen(title: "Save", size: .parent, feel: .parent)
            HopPressSpecimen(title: "I tried!", size: .child, feel: .child)

            Divider().overlay(theme.color.divider)

            Text("Live — press and hold in the canvas")
                .hopTextStyle(.parentFootnote)
                .foregroundStyle(theme.color.textSecondary)

            HopPrimaryButton("Start a Potty Pause", icon: "play.fill") {}
            HopSecondaryButton("Skip this one", icon: "forward.fill") {}
            HopPrimaryButton("I tried!", icon: "checkmark", size: .child) {}
            HopIconButton(systemImage: "gearshape.fill", accessibilityLabel: "Settings") {}
        }
        .padding()
    }
}

#Preview("Press states") {
    ScrollView { HopPressStateGallery() }
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Press states · Reduce Motion") {
    ScrollView { HopPressStateGallery() }
        .hopBackground()
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Press states · dark") {
    ScrollView { HopPressStateGallery() }
        .hopBackground()
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}
#endif
