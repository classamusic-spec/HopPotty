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
///
/// ## Three things, then a disclosure
///
/// This screen used to make its case in three paragraphs of `parentCallout`,
/// one of which opened "Apple hands over a sealed token for each app you pick".
/// Every word of it was true and none of it is what a caregiver needs in the
/// four seconds before a system dialog. §9 names exactly what has to be
/// front-loaded and nothing else:
///
/// > You choose the apps. HopPotty can't see inside them. You can turn this off
/// > anytime.
///
/// So the three promises are three short lines, and the framework vocabulary,
/// what persists, what the next screen is and what happens if the answer is no
/// all moved behind **How this works** — a `DisclosureGroup` a caregiver opens
/// if they want it. Trust is not built by saying more at the moment of the ask;
/// it is built by making the short version true and the long version reachable.
struct WhyScreenTimeScreen: View {
    @Environment(\.hopTheme) private var theme
    let model: OnboardingModel

    @State private var isDetailExpanded = false

    private var promises: [(HopGlyph, String)] {
        [
            (.check, HopCopy.onboarding.screenTimePromiseApps.localized),
            (.shield, HopCopy.onboarding.screenTimePromisePrivate.localized),
            (.pause, HopCopy.onboarding.screenTimePromiseReversible.localized),
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
            VStack(alignment: .leading, spacing: theme.spacing.xl) {
                // No card per line. Three cards holding one sentence each is
                // three containers doing the work one list does (§35).
                ForEach(Array(promises.enumerated()), id: \.offset) { _, promise in
                    HStack(alignment: .top, spacing: theme.spacing.m) {
                        HopGlyphView(promise.0, size: 20)
                            .foregroundStyle(theme.color.brandAction)
                            .frame(width: 24)
                        Text(verbatim: promise.1)
                            .font(theme.font(.parentBody))
                            .foregroundStyle(theme.color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }

                howThisWorks
            }
        }
    }

    /// Everything the three lines left out, one tap away and closed by default.
    private var howThisWorks: some View {
        DisclosureGroup(isExpanded: $isDetailExpanded) {
            Text(hop: HopCopy.onboarding.screenTimeHowBody)
                .font(theme.font(.parentCallout))
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, theme.spacing.s)
        } label: {
            Text(hop: HopCopy.onboarding.screenTimeHowTitle)
                .font(theme.font(.parentBody))
                .foregroundStyle(theme.color.textPrimary)
        }
        .tint(theme.color.brandAction)
        .padding(theme.spacing.l)
        .frame(minHeight: theme.hitTarget.parent)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                .fill(theme.color.surface)
        )
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
            skipTitle: skipTitle,
            isWorking: model.isWorking,
            canGoBack: model.canGoBack,
            onPrimary: primaryAction,
            onSkip: skipAction,
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

    /// Offered only after a denial, and worded as continuing rather than
    /// giving up: gentle mode is a real way to use HopPotty, not a consolation.
    private var skipTitle: String? {
        status == .denied ? HopCopy.common.notNow.localized : nil
    }

    private var skipAction: (() -> Void)? {
        guard status == .denied else { return nil }
        return { model.advance() }
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
