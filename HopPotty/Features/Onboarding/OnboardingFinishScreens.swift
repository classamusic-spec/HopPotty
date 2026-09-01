import SwiftUI
import HopPottyCore

// Screens 9–12: quiet hours, notifications, the test pause, and the summary.

/// 9. Quiet Hours. Skippable, and pre-seeded with the two windows nearly every
/// family with a small child has.
struct QuietHoursScreen: View {
    @Environment(\.hopTheme) private var theme
    let model: OnboardingModel

    @State private var windows: [QuietWindow] = []

    var body: some View {
        OnboardingScaffold(
            title: HopCopy.timerSettings.quietTitle.localized,
            message: HopCopy.timerSettings.quietFooter.localized,
            primaryTitle: HopCopy.common.next.localized,
            skipTitle: HopCopy.onboarding.nameSkip.localized,
            canGoBack: model.canGoBack,
            onPrimary: {
                model.setQuietWindows(windows.filter(\.isEnabled))
                model.advance()
            },
            onSkip: {
                model.setQuietWindows([])
                model.advance()
            },
            onBack: model.goBack
        ) {
            VStack(spacing: theme.spacing.s) {
                ForEach($windows) { $window in
                    QuietWindowToggleRow(window: $window)
                }
            }
            .onAppear {
                guard windows.isEmpty else { return }
                windows = model.draft.quietWindows.isEmpty
                    ? QuietWindow.onboardingSuggestions
                    : model.draft.quietWindows
            }
        }
    }
}

/// A suggested quiet window with a switch and its own time pickers.
struct QuietWindowToggleRow: View {
    @Environment(\.hopTheme) private var theme
    @Binding var window: QuietWindow

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Toggle(isOn: $window.isEnabled) {
                Label(window.label.parentTitle, systemImage: window.label.systemImage)
                    .font(theme.font(.parentHeadline))
            }
            if window.isEnabled {
                HStack {
                    LocalTimePicker(time: $window.start)
                    Text(verbatim: "–").foregroundStyle(theme.color.textTertiary)
                    LocalTimePicker(time: $window.end)
                }
                .font(theme.font(.parentCallout))
            }
        }
        .padding(theme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                .fill(theme.color.surface)
        )
    }
}

/// 10. Notifications.
struct NotificationsScreen: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.openURL) private var openURL
    let model: OnboardingModel

    var body: some View {
        OnboardingScaffold(
            title: HopFeatureStrings.notificationsTitle,
            message: HopFeatureStrings.notificationsBody,
            primaryTitle: primaryTitle,
            isWorking: model.isWorking,
            skipTitle: HopCopy.common.notNow.localized,
            canGoBack: model.canGoBack,
            onPrimary: primaryAction,
            onSkip: model.advance,
            onBack: model.goBack
        ) {
            if model.draft.notificationPermission == .denied {
                VStack(alignment: .leading, spacing: theme.spacing.s) {
                    Text(hop: HopCopy.errors.notificationsDeniedBody)
                        .font(theme.font(.parentCallout))
                        .foregroundStyle(theme.color.textSecondary)
                    if let url = ParentSystemSettings.url {
                        HopSecondaryButton(HopCopy.common.openSettings.localized) { openURL(url) }
                    }
                }
            }
        }
    }

    private var primaryTitle: String {
        switch model.draft.notificationPermission {
        case .authorized, .provisional: HopCopy.common.next.localized
        case .notDetermined, .denied: HopFeatureStrings.notificationsAllow
        }
    }

    private func primaryAction() {
        switch model.draft.notificationPermission {
        case .authorized, .provisional:
            model.advance()
        case .notDetermined:
            Task { await model.requestNotifications() }
        case .denied:
            // iOS only ever asks once. Advancing is the honest move; the
            // Settings link above is the only thing that can change the answer.
            model.advance()
        }
    }
}

/// 11. Test Potty Pause.
///
/// Offered only when it can actually work — `OnboardingState.canOfferTestPause`
/// routes past this screen otherwise, because showing a caregiver a failure
/// they caused by skipping the app picker teaches them the feature is broken.
struct TestPauseScreen: View {
    @Environment(\.hopTheme) private var theme
    let model: OnboardingModel

    var body: some View {
        OnboardingScaffold(
            title: HopFeatureStrings.testPauseTitle,
            message: HopFeatureStrings.testPauseBody,
            primaryTitle: model.draft.didTestPauseSucceed == true
                ? HopCopy.common.next.localized
                : HopFeatureStrings.testPauseRun,
            isWorking: model.isWorking,
            skipTitle: HopFeatureStrings.testPauseSkip,
            canGoBack: model.canGoBack,
            onPrimary: {
                if model.draft.didTestPauseSucceed == true {
                    model.advance()
                } else {
                    Task { await model.runTestPause() }
                }
            },
            onSkip: model.advance,
            onBack: model.goBack
        ) {
            if model.draft.didTestPauseSucceed == true {
                HStack(spacing: theme.spacing.s) {
                    HopGlyphView(.check, size: 22, isDecorative: false)
                        .foregroundStyle(theme.color.success)
                    Text(verbatim: HopFeatureStrings.testPauseSucceeded)
                        .font(theme.font(.parentCallout))
                        .foregroundStyle(theme.color.textSecondary)
                }
            }
        }
    }
}

/// 12. Ready.
///
/// States what is actually armed, including the case where the caregiver
/// declined Screen Time — "reminders are on, apps are not paused" is a fact
/// they need, not a nag to go back and fix something.
struct ReadyScreen: View {
    @Environment(\.hopTheme) private var theme
    let model: OnboardingModel

    var body: some View {
        OnboardingScaffold(
            title: HopCopy.onboarding.doneTitle.localized,
            message: HopCopy.onboarding.doneBody.localized,
            primaryTitle: HopCopy.onboarding.doneButton.localized,
            isWorking: model.isWorking,
            canGoBack: model.canGoBack,
            onPrimary: { Task { await model.finish() } },
            onBack: model.goBack
        ) {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                HopCharacterStage(pose: .cheer, size: 160)
                    .frame(maxWidth: .infinity)

                SummaryRow(
                    glyph: .timer,
                    title: HopCopy.timerSettings.modeLabel.localized,
                    value: model.draft.mode.parentTitle
                )
                SummaryRow(
                    glyph: .pause,
                    title: HopCopy.timerSettings.intervalLabel.localized,
                    value: ParentFormat.minutes(model.draft.interval.minutes)
                )
                if !model.draft.quietWindows.isEmpty {
                    SummaryRow(
                        glyph: .quietHours,
                        title: HopCopy.timerSettings.quietTitle.localized,
                        value: ParentFormat.count(model.draft.quietWindows.count)
                    )
                }
                if model.draft.fellBackToGentle {
                    Text(verbatim: HopFeatureStrings.readyGentleNote)
                        .font(theme.font(.parentFootnote))
                        .foregroundStyle(theme.color.textSecondary)
                }
            }
        }
    }
}

private struct SummaryRow: View {
    @Environment(\.hopTheme) private var theme
    let glyph: HopGlyph
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: theme.spacing.m) {
            HopGlyphView(glyph, size: 20)
                .foregroundStyle(theme.color.brandPrimary)
            Text(verbatim: title)
                .foregroundStyle(theme.color.textSecondary)
            Spacer()
            Text(verbatim: value)
                .foregroundStyle(theme.color.textPrimary)
        }
        .font(theme.font(.parentBody))
        .accessibilityElement(children: .combine)
    }
}

extension QuietWindow {
    /// The two windows nearly every family with a small child wants, offered
    /// switched on so the common case is one tap.
    static var onboardingSuggestions: [QuietWindow] {
        [
            QuietWindow(
                start: LocalTimeOfDay(hour: 12, minute: 30),
                end: LocalTimeOfDay(hour: 14, minute: 30),
                label: .nap
            ),
            QuietWindow(
                start: LocalTimeOfDay(hour: 19, minute: 30),
                end: LocalTimeOfDay(hour: 7, minute: 0),
                label: .bedtime
            ),
        ]
    }
}

#if DEBUG
#Preview("Quiet hours") { QuietHoursScreen(model: .preview(step: .quietHours)).hopThemedRoot() }
#Preview("Notifications") { NotificationsScreen(model: .preview(step: .notifications)).hopThemedRoot() }
#Preview("Test pause") { TestPauseScreen(model: .preview(step: .testPause)).hopThemedRoot() }
#Preview("Ready, gentle fallback") {
    ReadyScreen(model: .preview(step: .ready, authorization: .denied)).hopThemedRoot()
}
#Preview("Ready, AX3 dark") {
    ReadyScreen(model: .preview(step: .ready))
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
        .hopThemedRoot()
}
#endif
