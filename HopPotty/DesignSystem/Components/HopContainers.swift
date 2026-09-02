import SwiftUI
import HopPottyDesignTokens

/// The parent dashboard's basic surface.
///
/// Deliberately plain: a fill, a radius, a shadow and a hairline. HopPotty's
/// depth comes from a small number of cards at different elevations, not from
/// each card decorating itself.
///
/// ## Motion
///
/// Both of the moving parts are opt-in, and both default to off, because most
/// of the cards in this app already sit inside something that animates them and
/// a surface that animates twice is worse than one that does not animate at all.
///
/// - `arrivalIndex:` gives the card a considered arrival — it lifts 14 points
///   into place — staggered by its index when several arrive together. It runs
///   **once per card**, on first appearance. A value inside the card changing
///   later does not re-run it.
/// - `action:` makes the whole card a control. It then presses like a physical
///   thing: the surface sinks a little, its shadow softens toward the page, and
///   a wash confirms the touch even when nothing is allowed to move.
public struct HopCard<Content: View>: View {
    private let elevation: HopElevation
    private let arrivalIndex: Int?
    private let action: (() -> Void)?
    private let content: Content

    public init(
        elevation: HopElevation = .resting,
        arrivalIndex: Int? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.elevation = elevation
        self.arrivalIndex = arrivalIndex
        self.action = action
        self.content = content()
    }

    @ViewBuilder
    public var body: some View {
        if let action {
            Button(action: action) {
                HopCardSurface(elevation: elevation, isTappable: true, content: content)
            }
            // Thin by design: the style publishes the press, the surface draws
            // it. See HopSurfaceButtonStyle.
            .buttonStyle(HopSurfaceButtonStyle())
            .accessibilityAddTraits(.isButton)
            .hopArrival(index: arrivalIndex ?? 0, isEnabled: arrivalIndex != nil)
        } else {
            HopCardSurface(elevation: elevation, isTappable: false, content: content)
                .hopArrival(index: arrivalIndex ?? 0, isEnabled: arrivalIndex != nil)
        }
    }
}

/// The card's drawing, split out so it can read the press state published by
/// ``HopSurfaceButtonStyle`` when — and only when — the card owns the tap.
///
/// The `isTappable` guard matters: without it a plain card nested inside some
/// other pressed control would sink along with it, and a dashboard where
/// pressing a row squashes the card behind it looks broken rather than deep.
private struct HopCardSurface<Content: View>: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopIsPressed) private var isPressed

    let elevation: HopElevation
    let isTappable: Bool
    /// The already-built content, not a builder closure: this view is only ever
    /// constructed from ``HopCard``, which has already resolved it.
    let content: Content

    private var isHeld: Bool { isTappable && isPressed }
    private var feel: HopPressFeel { .surface }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: elevation.suggestedRadius, style: .continuous)
    }

    var body: some View {
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
            .overlay {
                // The half of the press that survives Reduce Motion.
                shape
                    .fill(theme.color.textPrimary.opacity(0.05))
                    .opacity(isHeld ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .modifier(theme.elevation(feel.elevation(elevation, isPressed: isHeld, reduceMotion: theme.reduceMotion)))
            .scaleEffect(feel.scale(isPressed: isHeld, reduceMotion: theme.reduceMotion))
            .animation(feel.animation(isPressed: isHeld, reduceMotion: theme.reduceMotion), value: isHeld)
    }
}

/// A titled group of rows, in the shape of an Apple Settings section.
///
/// The title is a real header for assistive technology, not just larger text,
/// so rotor navigation by heading works down a long settings screen.
///
/// Deliberately has no arrival animation. A caregiver's settings list is the
/// one surface in this app that should feel exactly like the OS, and the OS
/// does not stagger a settings screen in.
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
/// so this composes with whatever the feature needs. When a sheet is drawn
/// *inside* the app rather than presented by the system — an overlay in a
/// `ZStack` — give it `.hopScreenTransition(.sheet)` so it rises rather than
/// appearing.
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

            HopIconButton(
                systemImage: "xmark.circle.fill",
                accessibilityLabel: HopStrings.close,
                tint: theme.color.textTertiary,
                minimumTarget: theme.hitTarget.parent,
                action: onDismiss
            )
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

#if DEBUG
/// The two opt-in behaviours together: cards that arrive staggered, and a card
/// that is itself a control.
private struct HopCardMotionGallery: View {
    @Environment(\.hopTheme) private var theme
    @State private var generation = 0
    @State private var taps = 0

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            Text(theme.reduceMotion
                 ? "Reduce Motion: cards fade in where they belong and the press is a wash, not a squash."
                 : "Cards lift into place, staggered. The tappable card sinks and its shadow softens.")
                .hopTextStyle(.parentCaption)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HopSecondaryButton("Play the arrival again", icon: "arrow.clockwise") { generation += 1 }

            VStack(spacing: theme.spacing.m) {
                ForEach(0..<3, id: \.self) { index in
                    HopCard(arrivalIndex: index) {
                        Text("Arrives \(index + 1) of 3").hopTextStyle(.parentHeadline)
                    }
                }
            }
            .id(generation)

            HopCard(elevation: .raised, action: { taps += 1 }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Press me").hopTextStyle(.parentHeadline)
                    Text("Tapped \(taps.formatted()) times")
                        .hopTextStyle(.parentCallout)
                        .foregroundStyle(theme.color.textSecondary)
                        .hopNumericTransition()
                        .hopAnimation(.parentTransition, value: taps)
                }
            }
        }
        .padding()
    }
}

#Preview("Cards · motion") {
    ScrollView { HopCardMotionGallery() }
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Cards · motion, Reduce Motion") {
    ScrollView { HopCardMotionGallery() }
        .hopBackground()
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Cards · motion, dark") {
    ScrollView { HopCardMotionGallery() }
        .hopBackground()
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}
#endif
