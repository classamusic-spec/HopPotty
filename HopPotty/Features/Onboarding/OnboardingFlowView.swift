import SwiftUI
import HopPottyCore

/// The onboarding host.
///
/// There is **no purchase surface anywhere in this flow.** A caregiver is asked
/// to pay only after they have used the product; the paywall lives behind the
/// parent gate in Settings and behind the second-child action, and never here.
struct OnboardingFlowView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var model: OnboardingModel
    let onFinished: () -> Void

    init(environment: ParentEnvironment, onFinished: @escaping () -> Void) {
        _model = State(initialValue: OnboardingModel(environment: environment))
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(spacing: 0) {
            indicator
            // Forward through setup pushes; "Back" pops. The direction is the
            // whole point of the transition — a caregiver who taps Back and
            // watches the page slide the same way it did on the way in has been
            // told nothing.
            HopPageSwitch(model.isGoingBack ? .parentPop : .parentPush, value: model.step, alignment: .top) { _ in
                // The fill goes on the page, not on the switch: the scaffold
                // pins its footer to the bottom of whatever it is given, and a
                // switch that sized itself to its content would take that away.
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .hopBackground(.primary)
        .onChange(of: scenePhase) { _, phase in
            // Authorization can be granted or revoked in the Settings app while
            // HopPotty is in the background. The flow re-reads it on return so a
            // caregiver who fixed it outside does not have to answer twice.
            guard phase == .active else { return }
            Task { await model.refreshAuthorization() }
        }
        .onChange(of: model.isFinished) { _, finished in
            if finished { onFinished() }
        }
        .alert(
            model.failure?.presentation.title ?? "",
            isPresented: Binding(
                get: { model.failure != nil },
                set: { if !$0 { model.dismissFailure() } }
            )
        ) {
            Button(HopCopy.errors.dismissButton.localized) { model.dismissFailure() }
        } message: {
            Text(verbatim: model.failure?.presentation.message ?? "")
        }
    }

    private var indicator: some View {
        let position = model.state.indicatorPosition
        return HopStepIndicator(total: position.total, current: position.current)
            .padding(.top, theme.spacing.m)
            .padding(.bottom, theme.spacing.s)
            .accessibilityLabel(
                Text(verbatim: HopCopy.a11y.progressDots.localized(.count(position.current), .count(position.total)))
            )
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .meetHop: MeetHopScreen(model: model)
        case .theIdea: TheIdeaScreen(model: model)
        case .nickname: NicknameScreen(model: model)
        case .chooseRoutine: ChooseRoutineScreen(model: model)
        case .interval: IntervalScreen(model: model)
        case .whyScreenTime: WhyScreenTimeScreen(model: model)
        case .authorization: AuthorizationScreen(model: model)
        case .chooseApps: ChooseAppsScreen(model: model)
        case .quietHours: QuietHoursScreen(model: model)
        case .notifications: NotificationsScreen(model: model)
        case .testPause: TestPauseScreen(model: model)
        case .ready: ReadyScreen(model: model)
        }
    }
}

/// The shared frame every onboarding screen sits in.
///
/// One scaffold rather than twelve layouts: the title, the measure, the button
/// placement and the safe-area behaviour are identical on every step, and a step
/// that laid itself out differently would read as a different app.
struct OnboardingScaffold<Content: View>: View {
    @Environment(\.hopTheme) private var theme

    let title: String
    let message: String?
    var primaryTitle: String
    var primaryEnabled = true
    var skipTitle: String?
    var isWorking = false
    var canGoBack = false
    let onPrimary: () -> Void
    var onSkip: (() -> Void)?
    var onBack: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    VStack(alignment: .leading, spacing: theme.spacing.s) {
                        Text(verbatim: title)
                            .font(theme.font(.parentLargeTitle))
                            .foregroundStyle(theme.color.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        if let message {
                            Text(verbatim: message)
                                .font(theme.font(.parentBody))
                                .foregroundStyle(theme.color.textSecondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    content()
                }
                .hopPageMargins()
                .padding(.vertical, theme.spacing.l)
                .hopReadableWidth()
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
    }

    private var footer: some View {
        VStack(spacing: theme.spacing.s) {
            if isWorking {
                HopLoadingState(message: nil)
            } else {
                HopPrimaryButton(primaryTitle, action: onPrimary)
                    .disabled(!primaryEnabled)
            }
            HStack {
                if canGoBack, let onBack {
                    Button(HopCopy.common.back.localized, action: onBack)
                        .font(theme.font(.parentCallout))
                }
                Spacer()
                if let skipTitle, let onSkip {
                    Button(skipTitle, action: onSkip)
                        .font(theme.font(.parentCallout))
                }
            }
            .foregroundStyle(theme.color.textSecondary)
        }
        .hopPageMargins()
        .padding(.bottom, theme.spacing.l)
        .hopReadableWidth()
        .background(theme.color.backgroundPrimary)
    }
}
