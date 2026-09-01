import SwiftUI
import HopPottyDesignTokens

/// The primary call to action. One per screen.
///
/// At `.child` and `.childPrimary` the label is a capsule far above the HIG
/// floor, drawn with a glyph so a pre-reader can tell two buttons apart before
/// anyone reads them the words.
public struct HopPrimaryButton: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    private let title: String
    private let icon: String?
    private let size: HopButtonSize
    private let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        size: HopButtonSize = .parent,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
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
    @FocusState private var isFocused: Bool

    private let title: String
    private let icon: String?
    private let action: () -> Void

    public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
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
    @FocusState private var isFocused: Bool

    private let systemImage: String
    private let label: String
    private let tint: Color?
    private let minimumTarget: CGFloat
    private let action: () -> Void

    public init(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = accessibilityLabel
        self.tint = nil
        self.minimumTarget = CGFloat(HopHitTarget.parentMinimum)
        self.action = action
    }

    /// Child-surface variant: a bigger target and an explicit tint.
    public init(
        systemImage: String,
        accessibilityLabel: String,
        tint: Color,
        minimumTarget: CGFloat,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = accessibilityLabel
        self.tint = tint
        self.minimumTarget = minimumTarget
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
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
    @FocusState private var isFocused: Bool

    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    /// Deliberately not the brand's peach accent: destructive controls use the
    /// platform's red so they carry the meaning a person already learned
    /// everywhere else on their phone.
    private var destructive: Color {
        theme.isDark ? Color(red: 1.0, green: 0.41, blue: 0.38) : Color(red: 0.76, green: 0.13, blue: 0.13)
    }

    public var body: some View {
        Button(action: action) {
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
struct HopButtonLabel: View {
    let title: String
    let icon: String?
    let size: HopButtonSize

    var body: some View {
        HStack(spacing: size == .parent ? CGFloat(HopSpacing.s) : CGFloat(HopSpacing.m)) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: size.glyphSize, weight: .semibold))
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
