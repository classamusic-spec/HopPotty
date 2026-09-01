import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

/// The parent dashboard's focal surface: what Potty Pause is doing right now.
///
/// One number, one sentence, at most two controls. Everything else on the
/// dashboard is subordinate to this card, which is why it is the only thing
/// drawn at `.raised`.
public struct HopTimerCard: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let state: PottyPauseDisplayState
    private let onSkip: () -> Void
    private let onStartNow: () -> Void

    public init(
        state: PottyPauseDisplayState,
        onSkip: @escaping () -> Void,
        onStartNow: @escaping () -> Void
    ) {
        self.state = state
        self.onSkip = onSkip
        self.onStartNow = onStartNow
    }

    public var body: some View {
        HopCard(elevation: .raised) {
            VStack(alignment: .leading, spacing: theme.spacing.xl) {
                header
                dial
                actions
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .hopTextStyle(.parentHeadline)
                    .foregroundStyle(theme.color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let childName = state.childName {
                    Text(childName)
                        .hopTextStyle(.parentCaption)
                        .foregroundStyle(theme.color.textSecondary)
                }
            }

            Spacer(minLength: theme.spacing.s)

            if let pill = statusPill {
                HopPill(pill.text, tint: pill.tint, glyph: pill.glyph)
            }
        }
    }

    private var headline: String {
        switch state.phase {
        case .off: HopStrings.timerPaused
        case .counting, .approaching: HopStrings.timerNextPause
        case .pausing: HopStrings.timerPauseRunning
        case .cooldown: HopStrings.timerCooldown
        case .needsAttention, .needsAttentionAccessRestored: HopStrings.timerNeedsAttention
        }
    }

    private var statusPill: (text: String, tint: Color, glyph: HopGlyph)? {
        switch state.phase {
        case .approaching:
            (HopStrings.timerApproaching, theme.color.warning, .timer)
        case .pausing:
            state.isHoldingApps
                ? (HopStrings.timerAppsPaused, theme.color.brandAction, .shield)
                : (HopStrings.timerPauseRunning, theme.color.brandAction, .pause)
        case .needsAttentionAccessRestored:
            // Says the reassuring half out loud: whatever went wrong, the child
            // is not locked out of anything.
            (HopStrings.timerAppsBack, theme.color.success, .check)
        case .needsAttention:
            (HopStrings.timerNeedsAttention, theme.color.warning, .shield)
        case .off, .counting, .cooldown:
            nil
        }
    }

    // MARK: - Dial

    private var dialTint: Color {
        switch state.phase {
        case .approaching: theme.color.warning
        case .needsAttention, .needsAttentionAccessRestored: theme.color.warning
        case .off: theme.color.neutral
        default: theme.color.brandAction
        }
    }

    @ViewBuilder
    private var dial: some View {
        if let remaining = state.remaining {
            HStack(spacing: theme.spacing.xl) {
                ZStack {
                    HopProgressRing(progress: state.progress ?? 0, lineWidth: 10, tint: dialTint)
                    HopGlyphView(state.phase.isPausing ? .pause : .timer, size: 22)
                        .foregroundStyle(dialTint)
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    Text(HopDurationFormat.glanceable(remaining))
                        .hopTextStyle(.timer, allowsTightening: false)
                        .foregroundStyle(theme.color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(HopStrings.timerRemaining)
                        .hopTextStyle(.parentCaption)
                        .foregroundStyle(theme.color.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.phase.isPausing ? HopStrings.timerRemainingLabel : HopStrings.timerUntilNextLabel)
            .accessibilityValue(HopDurationFormat.spoken(remaining))
        } else {
            Text(detail)
                .hopTextStyle(.parentBody)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var detail: String {
        switch state.phase {
        case .off: HopStrings.timerOffDetail
        case .cooldown: HopStrings.timerCooldownDetail
        case .needsAttention(let failure), .needsAttentionAccessRestored(let failure): failure.recoveryMessage
        case .counting, .approaching, .pausing: HopStrings.timerNoCountdown
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        if state.allowsManualControl {
            // Stacked at accessibility sizes: two buttons side by side at AX5
            // leaves about four characters each.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.m) {
                    HopSecondaryButton(HopStrings.skip, action: onSkip)
                    HopPrimaryButton(HopStrings.startNow, icon: "play.fill", action: onStartNow)
                }
                VStack(spacing: theme.spacing.m) {
                    HopPrimaryButton(HopStrings.startNow, icon: "play.fill", action: onStartNow)
                    HopSecondaryButton(HopStrings.skip, action: onSkip)
                }
            }
        } else if case .off = state.phase {
            HopPrimaryButton(HopStrings.startNow, icon: "play.fill", action: onStartNow)
        }
    }
}

private extension PottyPauseDisplayState.Phase {
    var isPausing: Bool {
        if case .pausing = self { return true }
        return false
    }
}

#if DEBUG
#Preview("Timer card · states") {
    ScrollView {
        VStack(spacing: 20) {
            HopTimerCard(
                state: PottyPauseDisplayState(phase: .counting, mode: .pause, remaining: 1_845, total: 2_700, childName: "Sam"),
                onSkip: {}, onStartNow: {}
            )
            HopTimerCard(
                state: PottyPauseDisplayState(phase: .approaching, mode: .routine, remaining: 118, total: 2_700, childName: "Sam"),
                onSkip: {}, onStartNow: {}
            )
            HopTimerCard(
                state: PottyPauseDisplayState(phase: .pausing, mode: .pause, remaining: 245, total: 300, childName: "Sam"),
                onSkip: {}, onStartNow: {}
            )
            HopTimerCard(
                state: PottyPauseDisplayState(phase: .off, mode: .gentle, childName: "Sam"),
                onSkip: {}, onStartNow: {}
            )
            HopTimerCard(
                state: PottyPauseDisplayState(pauseState: .errorAccessRestored(.shieldApplyFailed), mode: .pause, childName: "Sam"),
                onSkip: {}, onStartNow: {}
            )
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Timer card · AX3") {
    ScrollView {
        HopTimerCard(
            state: PottyPauseDisplayState(phase: .counting, mode: .pause, remaining: 1_845, total: 2_700, childName: "Maya"),
            onSkip: {}, onStartNow: {}
        )
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Timer card · dark") {
    HopTimerCard(
        state: PottyPauseDisplayState(phase: .pausing, mode: .routine, remaining: 245, total: 300, childName: "Sam"),
        onSkip: {}, onStartNow: {}
    )
    .padding()
    .frame(maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}

#Preview("Timer card · iPad, high contrast") {
    HopTimerCard(
        state: PottyPauseDisplayState(phase: .counting, mode: .pause, remaining: 3_845, total: 5_400, childName: "Sam"),
        onSkip: {}, onStartNow: {}
    )
    .hopPageMargins()
    .hopReadableWidth()
    .frame(width: 834, height: 400)
    .hopBackground()
    .hopThemedRoot(appearance: .lightHighContrast)
}
#endif
