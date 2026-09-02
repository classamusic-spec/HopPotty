import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

public extension PottyPauseMode {
    var displayName: String {
        switch self {
        case .gentle: HopStrings.modeGentleTitle
        case .pause: HopStrings.modePauseTitle
        case .routine: HopStrings.modeRoutineTitle
        }
    }

    var summary: String {
        switch self {
        case .gentle: HopStrings.modeGentleDetail
        case .pause: HopStrings.modePauseDetail
        case .routine: HopStrings.modeRoutineDetail
        }
    }

    var glyph: HopGlyph {
        switch self {
        case .gentle: .timer
        case .pause: .shield
        case .routine: .check
        }
    }
}

/// Chooses how assertively HopPotty interrupts.
///
/// A list of described choices rather than a segmented control: the difference
/// between "gentle" and "pause" is that one blocks a child's apps and the other
/// does not, and that is not a decision anyone should make from a three-letter
/// segment. Each row states what the mode actually does.
///
/// ## Selection travels
///
/// The selected row's wash slides from the old choice to the new one rather
/// than blinking off and on, which is the one piece of motion that makes a
/// stack of three rows read as a single control with a position in it. The
/// checkmark still arrives on its own, because the mark — not the tint — is
/// what carries the selection (`Docs/Accessibility.md` §1.9), and it must be
/// legible the instant the animation is over. Under Reduce Motion the wash does
/// not travel at all; it simply appears where it belongs.
public struct HopModeSelector: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopButtonFeedback) private var buttonFeedback
    @Namespace private var selectionNamespace

    @Binding private var selection: PottyPauseMode

    public init(selection: Binding<PottyPauseMode>) {
        self._selection = selection
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(PottyPauseMode.allCases.enumerated()), id: \.element) { index, mode in
                if index > 0 { HopRowDivider() }
                row(mode)
            }
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
        // The one transaction the travelling wash runs inside.
        .hopAnimation(.parentTransition, value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(HopStrings.modeSelectorLabel)
    }

    private func row(_ mode: PottyPauseMode) -> some View {
        let isSelected = selection == mode
        return Button {
            // Changing the mode changes what HopPotty does to a child's device,
            // which is exactly the occasion `importantChange` names. Silent
            // unless the app root installed a handler.
            buttonFeedback.play(.importantChange)
            selection = mode
        } label: {
            HStack(alignment: .top, spacing: theme.spacing.m) {
                HopGlyphBadge(mode.glyph, tint: theme.color.brandAction, diameter: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .hopTextStyle(.parentHeadline)
                        .foregroundStyle(theme.color.textPrimary)
                    Text(mode.summary)
                        .hopTextStyle(.parentCallout)
                        .foregroundStyle(theme.color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: theme.spacing.s)

                // A mark, not just a tint: selection is never carried by colour.
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.color.brandAction)
                    .scaleEffect(isSelected ? 1 : 0.6)
                    .opacity(isSelected ? 1 : 0)
                    .padding(.top, 4)
                    .hopAnimation(.parentTap, value: isSelected)
            }
            .padding(.horizontal, theme.spacing.l)
            .padding(.vertical, theme.spacing.m)
            .frame(minHeight: theme.hitTarget.parent)
            .background { selectionWash(isSelected: isSelected) }
            .contentShape(Rectangle())
        }
        .buttonStyle(HopRowButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode.displayName)
        .accessibilityValue(mode.summary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Drawn on the selected row only, so there is exactly one of it in the
    /// namespace and SwiftUI can carry it from the old row to the new one.
    @ViewBuilder
    private func selectionWash(isSelected: Bool) -> some View {
        if isSelected {
            Rectangle()
                .fill(HopColors.wash(theme.color.brandAction, isDark: theme.isDark))
                .hopSelectionHighlight(id: "hopModeSelection", in: selectionNamespace)
        }
    }
}

#if DEBUG
private struct HopModeSelectorPreviewHost: View {
    @State private var mode: PottyPauseMode = .pause
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HopSectionHeader("How HopPotty interrupts")
            HopModeSelector(selection: $mode)
        }
        .padding()
    }
}

#Preview("Mode selector") {
    HopModeSelectorPreviewHost()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Mode selector · Reduce Motion") {
    HopModeSelectorPreviewHost()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .hopBackground()
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Mode selector · AX3") {
    ScrollView {
        HopModeSelectorPreviewHost()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Mode selector · dark") {
    HopModeSelectorPreviewHost()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .hopBackground()
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}

#Preview("Mode selector · iPad high contrast") {
    HopModeSelectorPreviewHost()
        .hopReadableWidth()
        .frame(width: 834, height: 500, alignment: .top)
        .hopBackground()
        .hopThemedRoot(appearance: .lightHighContrast)
}
#endif
