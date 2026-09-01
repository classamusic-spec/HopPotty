import SwiftUI
import HopPottyDesignTokens

/// The parent dashboard's basic surface.
///
/// Deliberately plain: a fill, a radius, a shadow and a hairline. HopPotty's
/// depth comes from a small number of cards at different elevations, not from
/// each card decorating itself.
public struct HopCard<Content: View>: View {
    @Environment(\.hopTheme) private var theme

    private let elevation: HopElevation
    private let content: Content

    public init(elevation: HopElevation = .resting, @ViewBuilder content: () -> Content) {
        self.elevation = elevation
        self.content = content()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: elevation.suggestedRadius, style: .continuous)
    }

    public var body: some View {
        content
            .padding(theme.spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(elevation.radius == 0 ? theme.color.surface : theme.color.surfaceElevated)
            }
            .overlay {
                // In increased contrast a shadow is not a boundary; the hairline
                // is what makes the card's edge findable.
                shape.strokeBorder(
                    theme.color.divider.opacity(theme.isHighContrast ? 1 : 0.55),
                    lineWidth: theme.isHighContrast ? 1.5 : 0.75
                )
            }
            .modifier(theme.elevation(elevation))
    }
}

/// A titled group of rows, in the shape of an Apple Settings section.
///
/// The title is a real header for assistive technology, not just larger text,
/// so rotor navigation by heading works down a long settings screen.
public struct HopSection<Content: View>: View {
    @Environment(\.hopTheme) private var theme

    private let title: String?
    private let footer: String?
    private let content: Content

    public init(_ title: String?, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            if let title {
                Text(title)
                    .hopTextStyle(.parentFootnote)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.color.textSecondary)
                    .padding(.horizontal, theme.spacing.xs)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: 0) {
                content
            }
            .background {
                RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                    .fill(theme.color.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                    .strokeBorder(
                        theme.color.divider.opacity(theme.isHighContrast ? 1 : 0.6),
                        lineWidth: theme.isHighContrast ? 1.5 : 0.75
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous))

            if let footer {
                Text(footer)
                    .hopTextStyle(.parentCaption)
                    .foregroundStyle(theme.color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, theme.spacing.xs)
            }
        }
    }
}

/// A hairline between rows inside a ``HopSection``, inset to clear the leading
/// icon column the way a system list does.
public struct HopRowDivider: View {
    @Environment(\.hopTheme) private var theme
    private let leadingInset: CGFloat

    public init(leadingInset: CGFloat = 56) {
        self.leadingInset = leadingInset
    }

    public var body: some View {
        Rectangle()
            .fill(theme.color.divider)
            .frame(height: theme.isHighContrast ? 1 : 0.5)
            .padding(.leading, leadingInset)
            .accessibilityHidden(true)
    }
}

/// The contents of a presented sheet: a title bar with a close control, then
/// scrolling content.
///
/// Presentation itself stays with the caller (`.sheet`, `.presentationDetents`)
/// so this composes with whatever the feature needs.
public struct HopSheet<Content: View>: View {
    @Environment(\.hopTheme) private var theme

    private let title: String
    private let onDismiss: () -> Void
    private let content: Content

    public init(title: String, onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.onDismiss = onDismiss
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.color.divider)
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hopPageMargins()
                    .padding(.vertical, theme.spacing.xl)
                    .hopReadableWidth()
            }
        }
        .background(theme.color.backgroundPrimary)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .hopTextStyle(.parentTitle)
                .foregroundStyle(theme.color.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: theme.spacing.m)

            HopIconButton(systemImage: "xmark.circle.fill", accessibilityLabel: HopStrings.close, action: onDismiss)
                .foregroundStyle(theme.color.textTertiary)
        }
        .hopPageMargins()
        .padding(.vertical, theme.spacing.l)
    }
}

#Preview("Containers") {
    ScrollView {
        VStack(spacing: 24) {
            HopCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resting card").hopTextStyle(.parentHeadline)
                    Text("The dashboard's default surface.").hopTextStyle(.parentCallout)
                }
            }
            HopCard(elevation: .raised) {
                Text("Raised card").hopTextStyle(.parentHeadline)
            }
            HopSection("Reminders", footer: "Quiet hours always win. Nothing interrupts a nap.") {
                HopSettingsRow(title: "Interval", value: "Every 45 minutes", icon: "timer") {}
                HopRowDivider()
                HopSettingsRow(title: "Quiet hours", value: "2 windows", icon: "moon.fill") {}
            }
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Sheet · iPad width") {
    HopSheet(title: "About these patterns", onDismiss: {}) {
        VStack(alignment: .leading, spacing: 12) {
            Text("HopPotty describes what it has seen in your own log.")
                .hopTextStyle(.parentBody)
            Text("Pattern, not medical advice.")
                .hopTextStyle(.parentCaption)
        }
    }
    .frame(width: 834, height: 600)
    .hopThemedRoot()
}

#Preview("Containers · dark, AX3") {
    ScrollView {
        VStack(spacing: 24) {
            HopCard { Text("Resting card").hopTextStyle(.parentHeadline) }
            HopSection("Reminders", footer: "Quiet hours always win.") {
                HopSettingsRow(title: "Interval", value: "Every 45 minutes", icon: "timer") {}
            }
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}
