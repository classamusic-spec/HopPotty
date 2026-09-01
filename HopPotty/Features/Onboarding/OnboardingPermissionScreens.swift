import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import HopPottyCore

// Screens 6–8: the permission conversation.
//
// The order is the point. HopPotty explains what Screen Time is for and what it
// will and will not see *before* iOS shows its prompt, because a system alert
// that arrives with no context is the one a caregiver declines. Apple's own
// guidance says the same thing, and `Docs/ScreenTimeArchitecture.md` §3 records
// that a declined request is not retryable in the way a caregiver expects.

/// 6. Why Screen Time — shown before the system prompt, never after.
struct WhyScreenTimeScreen: View {
    @Environment(\.hopTheme) private var theme
    let model: OnboardingModel

    private var promises: [(HopGlyph, String)] {
        [
            (.shield, HopCopy.onboarding.screenTimeBody.localized),
            (.pause, HopCopy.timerSettings.durationFooter.localized),
            (.check, HopCopy.onboarding.privacyBody.localized),
        ]
    }

    var body: some View {
        OnboardingScaffold(
            title: HopCopy.onboarding.screenTimeTitle.localized,
            message: nil,
            primaryTitle: HopCopy.common.next.localized,
            canGoBack: model.canGoBack,
            onPrimary: model.advance,
            onBack: model.goBack
        ) {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                ForEach(Array(promises.enumerated()), id: \.offset) { _, promise in
                    HStack(alignment: .top, spacing: theme.spacing.m) {
                        HopGlyphView(promise.0, size: 24)
                            .foregroundStyle(theme.color.brandPrimary)
                            .frame(width: 32)
                        Text(verbatim: promise.1)
                            .font(theme.font(.parentCallout))
                            .foregroundStyle(theme.color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// 7. Authorization, with every answer designed.
///
/// Four outcomes, four screens' worth of copy in one view:
///
/// - **approved** — say so, then move on.
/// - **denied** — the caregiver said no. HopPotty moves to gentle mode, says
///   exactly what that means, and offers the Settings app rather than nagging.
/// - **restricted** — this device cannot do it at all. No retry button is shown,
///   because there is nothing a retry could change.
/// - **error** — a real `ScreenTimeFailure`, rendered through the same mapping
///   every other screen uses, so "another parental controls app is already
///   installed" reads the same here as it does on the dashboard.
struct AuthorizationScreen: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.openURL) private var openURL
    let model: OnboardingModel

    private var status: ScreenTimeAuthorizationStatus { model.draft.authorizationStatus }

    var body: some View {
        OnboardingScaffold(
            title: title,
            message: message,
            primaryTitle: primaryTitle,
            isWorking: model.isWorking,
            canGoBack: model.canGoBack,
            onPrimary: primaryAction,
            onSkip: status.isRetryable && status == .denied ? { model.advance() } : nil,
            onBack: model.goBack
        ) {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                switch status {
                case .approved:
                    statusBanner(glyph: .check, tint: theme.color.success, text: HopFeatureStrings.authorizationApprovedBody)
                case .denied:
                    statusBanner(glyph: .pause, tint: theme.color.warning, text: HopFeatureStrings.authorizationGentleFallbackBody)
                    systemSettingsLink
                case .restricted:
                    statusBanner(glyph: .shield, tint: theme.color.neutral, text: HopCopy.errors.screenTimeRestrictedBody.localized)
                case .notDetermined:
                    Text(hop: HopCopy.onboarding.screenTimeBody)
                        .font(theme.font(.parentCallout))
                        .foregroundStyle(theme.color.textSecondary)
                }
            }
        }
    }

    private var title: String {
        switch status {
        case .approved: HopFeatureStrings.authorizationApprovedTitle
        case .denied: HopFeatureStrings.authorizationGentleFallbackTitle
        case .restricted: HopCopy.errors.screenTimeRestrictedTitle.localized
        case .notDetermined: HopCopy.onboarding.screenTimeTitle.localized
        }
    }

    private var message: String? {
        status == .notDetermined ? HopCopy.onboarding.screenTimeBody.localized : nil
    }

    private var primaryTitle: String {
        switch status {
        case .notDetermined: HopCopy.onboarding.screenTimeGrant.localized
        case .approved, .restricted: HopCopy.common.next.localized
        // Asking again is offered, once, and is never the only way forward:
        // the skip control beside it continues in gentle mode.
        case .denied: HopFeatureStrings.authorizationRetry
        }
    }

    private func primaryAction() {
        switch status {
        case .notDetermined, .denied:
            Task { await model.requestScreenTimeAuthorization() }
        case .approved, .restricted:
            model.advance()
        }
    }

    private func statusBanner(glyph: HopGlyph, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.m) {
            HopGlyphView(glyph, size: 24, isDecorative: false)
                .foregroundStyle(tint)
            Text(verbatim: text)
                .font(theme.font(.parentCallout))
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.m, style: .continuous)
                .fill(theme.color.surfaceSunken)
        )
    }

    @ViewBuilder
    private var systemSettingsLink: some View {
        if let url = ParentSystemSettings.url {
            HopSecondaryButton(HopCopy.common.openSettings.localized) { openURL(url) }
        }
    }
}

/// 8. Choose Apps.
///
/// The picker is Apple's. HopPotty renders the *count* of what was chosen and
/// nothing else — `ScreenTimeConfiguration` stores counts precisely because the
/// app is not entitled to the identities behind them.
struct ChooseAppsScreen: View {
    @Environment(\.hopTheme) private var theme
    let model: OnboardingModel

    var body: some View {
        OnboardingScaffold(
            title: HopCopy.onboarding.appsTitle.localized,
            message: HopCopy.onboarding.appsBody.localized,
            primaryTitle: HopCopy.common.next.localized,
            primaryEnabled: model.draft.hasAppSelection,
            canGoBack: model.canGoBack,
            onPrimary: model.advance,
            onBack: model.goBack
        ) {
            AppSelectionSection(
                childID: model.draft.childProfile.id,
                onChange: { configuration in
                    model.recordAppSelection(hasSelection: configuration.hasSelection)
                }
            )
        }
    }
}

#if DEBUG
#Preview("Why Screen Time") {
    WhyScreenTimeScreen(model: .preview(step: .whyScreenTime))
        .hopThemedRoot()
}

#Preview("Authorization, not determined") {
    AuthorizationScreen(model: .preview(step: .authorization))
        .hopThemedRoot()
}

#Preview("Authorization, denied") {
    AuthorizationScreen(model: .preview(step: .authorization, authorization: .denied))
        .hopThemedRoot()
}

#Preview("Authorization, restricted, dark") {
    AuthorizationScreen(model: .preview(step: .authorization, authorization: .restricted))
        .preferredColorScheme(.dark)
        .hopThemedRoot()
}
#endif
