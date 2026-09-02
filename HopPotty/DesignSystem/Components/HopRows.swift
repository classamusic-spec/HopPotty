import SwiftUI
import HopPottyDesignTokens

/// A tappable settings row: icon, title, current value, chevron.
///
/// The whole row is one accessibility element with a button trait, so VoiceOver
/// reads "Interval, every 45 minutes, button" instead of three fragments.
///
/// The value cross-fades when it changes. A settings row is the one place in a
/// caregiver's app where a number changes underneath them without them asking —
/// a schedule recalculating, a count of quiet windows going up — and a value
/// that snaps reads as a glitch rather than as news.
public struct HopSettingsRow: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    private let title: String
    private let value: String?
    private let icon: String
    private let action: () -> Void

    public init(title: String, value: String?, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.m) {
                HopRowIcon(systemImage: icon)

                Text(title)
                    .hopTextStyle(.parentBody)
                    .foregroundStyle(theme.color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: theme.spacing.s)

                if let value {
                    Text(value)
                        .hopTextStyle(.parentCallout)
                        .foregroundStyle(theme.color.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .hopValueChange(value)
                }

                HopRowChevron()
            }
            .padding(.horizontal, theme.spacing.l)
            .padding(.vertical, theme.spacing.m)
            .frame(minHeight: theme.hitTarget.parent)
            .contentShape(Rectangle())
        }
        .buttonStyle(HopRowButtonStyle())
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.radius.s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

/// The disclosure chevron, which leans in the direction it is about to take you.
///
/// Three points of travel, and only while the finger is down. It is the cheapest
/// possible way to make a row feel like it is answering, and unlike a scale it
/// does not move the rows underneath it. Off entirely under Reduce Motion, where
/// the row's highlight is doing the work instead.
struct HopRowChevron: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopIsPressed) private var isPressed

    private var lean: CGFloat {
        guard isPressed, !theme.reduceMotion else { return 0 }
        return 3
    }

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.color.textTertiary)
            .offset(x: lean)
            .hopAnimation(.parentTap, value: isPressed)
            .accessibilityHidden(true)
    }
}

/// A row carrying a switch. Tapping anywhere on the row toggles it.
public struct HopToggleRow: View {
    @Environment(\.hopTheme) private var theme

    private let title: String
    private let subtitle: String?
    private let icon: String
    @Binding private var isOn: Bool

    public init(title: String, subtitle: String?, icon: String, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._isOn = isOn
    }

    public var body: some View {
        // A system Toggle, not a bespoke switch: this control's affordance,
        // haptic and VoiceOver behaviour are ones the caregiver already knows.
        // That includes its animation — a hand-animated switch here would be a
        // switch that does not match every other switch on the device.
        Toggle(isOn: $isOn) {
            HStack(spacing: theme.spacing.m) {
                HopRowIcon(systemImage: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .hopTextStyle(.parentBody)
                        .foregroundStyle(theme.color.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .hopTextStyle(.parentCaption)
                            .foregroundStyle(theme.color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .multilineTextAlignment(.leading)
            }
        }
        .toggleStyle(.switch)
        .tint(theme.color.brandAction)
        .padding(.horizontal, theme.spacing.l)
        .padding(.vertical, theme.spacing.m)
        .frame(minHeight: theme.hitTarget.parent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
    }
}

/// The leading icon column shared by every row, so titles line up down a screen.
struct HopRowIcon: View {
    @Environment(\.hopTheme) private var theme
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.color.textOnBrand)
            .frame(width: 28, height: 28)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.xs, style: .continuous)
                    .fill(theme.color.brandAction)
            }
            .accessibilityHidden(true)
    }
}

/// Rows highlight rather than scale: a row that shrinks pulls the rows below it
/// upward, which reads as the list moving.
///
/// The highlight is an opacity change, so it is the same under Reduce Motion as
/// it is without — the row is never left with no answer to a touch. The style
/// also publishes the press downward, which is how the chevron in the label
/// knows to lean without the label having to own a gesture of its own.
struct HopRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration)
    }

    // Named `StyleBody`, not `Body`. `ButtonStyle` declares
    // `associatedtype Body: View`, and a nested type whose name matches an
    // associated type wins the inference over the `some View` that
    // `makeBody` actually returns. That made this `private` view the style's
    // associated type, which is then less accessible than the style itself:
    //
    //     error: struct 'Body' must be as accessible as its enclosing type
    //            because it matches a requirement in protocol 'ButtonStyle'
    //     error: type '...' does not conform to protocol 'ButtonStyle'
    //
    // Renaming keeps the view private, where it belongs, and lets `Body` be
    // inferred from the opaque return type as intended.
    private struct StyleBody: View {
        @Environment(\.hopTheme) private var theme
        let configuration: ButtonStyleConfiguration

        var body: some View {
            configuration.label
                .background(theme.color.textPrimary.opacity(configuration.isPressed ? 0.06 : 0))
                .animation(theme.animation(.parentTap), value: configuration.isPressed)
                .environment(\.hopIsPressed, configuration.isPressed)
        }
    }
}

/// A section header with an optional trailing action, in the shape Apple Health
/// uses above a group of cards.
public struct HopSectionHeader: View {
    @Environment(\.hopTheme) private var theme

    private let title: String
    private let action: (title: String, handler: () -> Void)?

    public init(_ title: String, action: (title: String, handler: () -> Void)? = nil) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .hopTextStyle(.parentTitle)
                .foregroundStyle(theme.color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: theme.spacing.m)

            if let action {
                Button(action.title, action: action.handler)
                    .hopTextStyle(.parentCallout)
                    .buttonStyle(HopBareButtonStyle(minimumTarget: theme.hitTarget.parent, tint: theme.color.brandAction))
            }
        }
    }
}

/// A small status token. Carries a glyph whenever it carries a meaning, so the
/// tint is never the only signal.
///
/// The label cross-fades when it changes, because a pill is very often the thing
/// a live dashboard rewrites — "Next pause in 12 minutes" becoming "11" — and it
/// is small enough that a snap is the only thing the eye catches.
public struct HopPill: View {
    @Environment(\.hopTheme) private var theme

    private let text: String
    private let tint: Color
    private let glyph: HopGlyph?

    public init(_ text: String, tint: Color, glyph: HopGlyph? = nil) {
        self.text = text
        self.tint = tint
        self.glyph = glyph
    }

    public var body: some View {
        HStack(spacing: theme.spacing.xs) {
            if let glyph {
                HopGlyphView(glyph, size: 12)
            }
            Text(text)
                .hopTextStyle(.parentFootnote)
                .lineLimit(1)
                .hopValueChange(text)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, theme.spacing.xs)
        .background {
            Capsule().fill(HopColors.wash(tint, isDark: theme.isDark))
        }
        .overlay {
            Capsule().strokeBorder(tint.opacity(theme.isHighContrast ? 0.8 : 0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Preview host, so the previews below can own mutable state without relying on
/// the `@Previewable` macro.
private struct HopRowsPreviewHost: View {
    @Environment(\.hopTheme) private var theme
    @State private var warnings = true
    @State private var summary = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HopSectionHeader("Today", action: (title: "See all", handler: {}))
                HopSection("Reminders") {
                    HopSettingsRow(title: "Interval", value: "Every 45 minutes", icon: "timer") {}
                    HopRowDivider()
                    HopToggleRow(
                        title: "Warning before a pause",
                        subtitle: "A gentle nudge two minutes ahead.",
                        icon: "bell.fill",
                        isOn: $warnings
                    )
                    HopRowDivider()
                    HopToggleRow(title: "Daily summary", subtitle: nil, icon: "chart.bar.fill", isOn: $summary)
                }
                HStack {
                    HopPill("Tried", tint: theme.color.eventTried, glyph: .tried)
                    HopPill("Quiet hours", tint: theme.color.brandSecondary, glyph: .quietHours)
                    HopPill("Plus", tint: theme.color.celebration)
                }
            }
            .padding()
        }
    }
}

#Preview("Rows") {
    HopRowsPreviewHost()
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Rows · AX3, long values") {
    ScrollView {
        HopSection("Reminders") {
            HopSettingsRow(title: "Time between Potty Pauses", value: "Every 45 minutes of screen time", icon: "timer") {}
            HopRowDivider()
            HopSettingsRow(title: "Quiet hours", value: "Nap 12:30–14:30, bedtime 19:00–07:00", icon: "moon.fill") {}
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Rows · high contrast dark") {
    ScrollView {
        HopSection("Reminders") {
            HopSettingsRow(title: "Interval", value: "Every 45 minutes", icon: "timer") {}
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot(appearance: .darkHighContrast)
}

#if DEBUG
/// Rows under a finger, and rows whose value is rewritten underneath them —
/// the two things a settings screen actually does.
private struct HopRowMotionGallery: View {
    @Environment(\.hopTheme) private var theme
    @State private var minutes = 45

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            Text(theme.reduceMotion
                 ? "Reduce Motion: the row still highlights, the chevron does not lean, the value cross-fades."
                 : "Press and hold a row: it highlights and the chevron leans three points.")
                .hopTextStyle(.parentCaption)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HopSection("Reminders") {
                HopSettingsRow(title: "Interval", value: "Every \(minutes) minutes", icon: "timer") {}
                HopRowDivider()
                HopSettingsRow(title: "Quiet hours", value: "2 windows", icon: "moon.fill") {}
            }

            HStack(spacing: theme.spacing.m) {
                HopPill("Every \(minutes) min", tint: theme.color.brandSecondary, glyph: .timer)
                Spacer(minLength: 0)
            }

            HopSecondaryButton("Change the interval", icon: "slider.horizontal.3") {
                minutes = minutes == 45 ? 60 : 45
            }
        }
        .padding()
    }
}

#Preview("Rows · motion") {
    ScrollView { HopRowMotionGallery() }
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Rows · motion, Reduce Motion") {
    ScrollView { HopRowMotionGallery() }
        .hopBackground()
        .hopThemedRoot(reduceMotion: true)
}
#endif
