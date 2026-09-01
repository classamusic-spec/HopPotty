import SwiftUI
import HopPottyDesignTokens

/// A tappable settings row: icon, title, current value, chevron.
///
/// The whole row is one accessibility element with a button trait, so VoiceOver
/// reads "Interval, every 45 minutes, button" instead of three fragments.
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
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.color.textTertiary)
                    .accessibilityHidden(true)
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
struct HopRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Body(configuration: configuration)
    }

    private struct Body: View {
        @Environment(\.hopTheme) private var theme
        let configuration: ButtonStyleConfiguration

        var body: some View {
            configuration.label
                .background(theme.color.textPrimary.opacity(configuration.isPressed ? 0.06 : 0))
                .animation(theme.animation(.parentTap), value: configuration.isPressed)
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
