import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

/// Nothing to show yet.
///
/// Empty is a normal state, not a problem: a family on day one has no entries,
/// and the screen should look like a beginning rather than a failure.
public struct HopEmptyState: View {
    @Environment(\.hopTheme) private var theme

    private let glyph: HopGlyph
    private let title: String
    private let message: String
    private let action: (String, () -> Void)?

    public init(glyph: HopGlyph, title: String, message: String, action: (String, () -> Void)?) {
        self.glyph = glyph
        self.title = title
        self.message = message
        self.action = action
    }

    public var body: some View {
        VStack(spacing: theme.spacing.l) {
            HopGlyphBadge(glyph, tint: theme.color.neutral, diameter: 72)

            VStack(spacing: theme.spacing.s) {
                Text(title)
                    .hopTextStyle(.parentTitle)
                    .foregroundStyle(theme.color.textPrimary)
                Text(message)
                    .hopTextStyle(.parentBody)
                    .foregroundStyle(theme.color.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            if let action {
                HopSecondaryButton(action.0, action: action.1)
                    .frame(maxWidth: 320)
            }
        }
        .padding(theme.spacing.xxxl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// Something went wrong with Screen Time.
///
/// Two things are always true here and both are said: what HopPotty could not
/// do, and whether the child's apps are affected. The recovery button only
/// appears when there is genuinely something for a caregiver to change —
/// offering "Review settings" for a failure HopPotty retries by itself sends
/// someone on an errand for nothing.
public struct HopErrorState: View {
    @Environment(\.hopTheme) private var theme

    private let failure: ScreenTimeFailure
    private let onReviewSettings: () -> Void
    private let onDismiss: () -> Void

    public init(
        failure: ScreenTimeFailure,
        onReviewSettings: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.failure = failure
        self.onReviewSettings = onReviewSettings
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HopCard {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                HStack(alignment: .top, spacing: theme.spacing.m) {
                    HopGlyphBadge(.shield, tint: theme.color.warning, diameter: 40)

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text(failure.title)
                            .hopTextStyle(.parentHeadline)
                            .foregroundStyle(theme.color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(failure.recoveryMessage)
                            .hopTextStyle(.parentBody)
                            .foregroundStyle(theme.color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: theme.spacing.m) { buttons }
                    VStack(spacing: theme.spacing.m) { buttons }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(failure.title)
    }

    @ViewBuilder
    private var buttons: some View {
        if failure.needsCaregiverAction {
            HopSecondaryButton(HopStrings.dismiss, action: onDismiss)
            HopPrimaryButton(HopStrings.reviewSettings, icon: "gearshape.fill", action: onReviewSettings)
        } else {
            HopPrimaryButton(HopStrings.dismiss, action: onDismiss)
        }
    }
}

/// Work in progress.
///
/// The message is not decoration: a spinner with no words leaves a VoiceOver
/// user with nothing at all, so the label is what the element announces.
public struct HopLoadingState: View {
    @Environment(\.hopTheme) private var theme

    private let message: String?

    public init(message: String?) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: theme.spacing.l) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.color.brandAction)

            if let message {
                Text(message)
                    .hopTextStyle(.parentCallout)
                    .foregroundStyle(theme.color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(theme.spacing.xxxl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message ?? HopStrings.loading)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// A capability that is not unlocked.
///
/// Describes what unlocking *adds*. Never what the family is missing, never a
/// countdown, never a discount that expires — the paywall is a shop, not a
/// pressure tactic. Reaching the purchase itself passes the parent gate.
public struct HopLockedState: View {
    @Environment(\.hopTheme) private var theme

    private let feature: PaywallFeature
    private let onUnlock: () -> Void

    public init(feature: PaywallFeature, onUnlock: @escaping () -> Void) {
        self.feature = feature
        self.onUnlock = onUnlock
    }

    public var body: some View {
        HopCard {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                HStack(spacing: theme.spacing.s) {
                    HopPill(HopStrings.lockedBadge, tint: theme.color.celebration, glyph: .star)
                    Spacer(minLength: 0)
                }

                HStack(alignment: .top, spacing: theme.spacing.m) {
                    HopGlyphBadge(feature.glyph, tint: theme.color.brandAction, diameter: 44)

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        Text(feature.title)
                            .hopTextStyle(.parentHeadline)
                            .foregroundStyle(theme.color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(feature.summary)
                            .hopTextStyle(.parentBody)
                            .foregroundStyle(theme.color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HopPrimaryButton(HopStrings.unlock, icon: "lock.open.fill", action: onUnlock)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(HopStrings.lockedBadge). \(feature.title)")
    }
}

#Preview("States") {
    ScrollView {
        VStack(spacing: 24) {
            HopEmptyState(
                glyph: .tried,
                title: HopStrings.timelineEmptyTitle,
                message: HopStrings.timelineEmptyMessage,
                action: ("Add an entry", {})
            )
            HopErrorState(failure: .authorizationRevoked, onReviewSettings: {}, onDismiss: {})
            HopErrorState(failure: .shieldApplyFailed, onReviewSettings: {}, onDismiss: {})
            HopLoadingState(message: "Checking Screen Time…")
            HopLockedState(feature: .detailedInsights, onUnlock: {})
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot()
}

#Preview("States · AX3") {
    ScrollView {
        VStack(spacing: 24) {
            HopEmptyState(
                glyph: .pond,
                title: "Sam's pond is waiting",
                message: "Every star Hop earns adds something new to the pond.",
                action: ("See what's next", {})
            )
            HopErrorState(failure: .shieldClearFailed, onReviewSettings: {}, onDismiss: {})
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("States · dark") {
    ScrollView {
        VStack(spacing: 24) {
            HopErrorState(failure: .noSelection, onReviewSettings: {}, onDismiss: {})
            HopLockedState(feature: .additionalChildren, onUnlock: {})
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}

#Preview("States · iPad high contrast") {
    ScrollView {
        VStack(spacing: 24) {
            HopEmptyState(glyph: .timer, title: "No pauses yet today", message: "HopPotty is watching quietly.", action: nil)
            HopLockedState(feature: .fullPondCollection, onUnlock: {})
        }
        .hopPageMargins()
        .hopReadableWidth()
    }
    .frame(width: 834, height: 700)
    .hopBackground()
    .hopThemedRoot(appearance: .lightHighContrast)
}
