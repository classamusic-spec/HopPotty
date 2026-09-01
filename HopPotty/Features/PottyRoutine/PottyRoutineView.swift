import SwiftUI
import HopPottyCore

/// The guided routine, end to end: five steps and a celebration.
///
/// Navigation is one level deep on purpose. There is no stack, no tab bar and
/// no back button — a two-year-old holding a tablet in a bathroom gets one
/// screen at a time, one thing to do, and a way out that is always in the same
/// corner. The whole run is short by construction:
/// `PottyRoutineContent.estimatedDuration` fits inside the default pause with
/// room to spare.
struct PottyRoutineView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.childContext) private var context

    /// Called once, with everything the run produced. The caller writes the
    /// `PottyEvent` and awards through `RewardService`, which owns idempotency;
    /// this view never touches a ledger.
    let onFinish: (PottyRoutineResult) -> Void
    /// Opens Hop's Pond. Separate from `onFinish` so the caller can decide
    /// whether the pond replaces the routine or sits on top of it.
    let onOpenPond: () -> Void
    /// Called when the child asks for a grown-up. Never a dead end.
    let onAskForHelp: () -> Void

    @State private var model: PottyRoutineModel

    init(
        settings: AppSettings = AppSettings(),
        onFinish: @escaping (PottyRoutineResult) -> Void,
        onOpenPond: @escaping () -> Void = {},
        onAskForHelp: @escaping () -> Void = {}
    ) {
        self.onFinish = onFinish
        self.onOpenPond = onOpenPond
        self.onAskForHelp = onAskForHelp
        _model = State(initialValue: PottyRoutineModel(settings: settings))
    }

    var body: some View {
        VStack(spacing: 0) {
            chrome
            stage
        }
        .hopBackground(.secondary)
        .routineTicker(isRunning: model.showsTimerRing) { model.tick($0) }
        .onChange(of: model.stage) { _, stage in
            if stage == .finished { onFinish(model.result) }
        }
    }

    // MARK: - Chrome

    /// The step indicator and the two escapes, in the same place on every step.
    private var chrome: some View {
        HStack(spacing: theme.spacing.m) {
            HopIconButton(
                systemImage: "hand.raised.fill",
                accessibilityLabel: HopCopy.routine.helpButton.value,
                action: onAskForHelp
            )

            Spacer(minLength: theme.spacing.s)

            HopStepIndicator(total: model.stepCount, current: model.currentStepNumber)
                .accessibilityLabel(
                    HopCopy.a11y.progressDots.filled([
                        1: .count(model.currentStepNumber),
                        2: .count(model.stepCount),
                    ])
                )

            Spacer(minLength: theme.spacing.s)

            HopIconButton(
                systemImage: "xmark",
                accessibilityLabel: HopCopy.routine.leaveButton.value,
                action: { model.leave() }
            )
        }
        .hopPageMargins()
        .padding(.vertical, theme.spacing.m)
    }

    // MARK: - Stage

    @ViewBuilder
    private var stage: some View {
        switch model.stage {
        case .step:
            if let step = model.currentStep {
                stepStage(step)
                    .id(step.id)
                    .hopTransition(.childArrive)
            }
        case .celebration:
            RoutineCelebrationView(
                outcome: model.outcome,
                starsEarned: starsEarned,
                totalStars: context.totalStars + starsEarned,
                unlocked: newlyUnlocked,
                onSeeThePond: onOpenPond,
                onFinish: { model.finishCelebration() }
            )
            .hopTransition(.childCelebrate)
        case .finished:
            // The caller has been told; hold the ground colour for the one frame
            // before it dismisses us rather than flashing an empty screen.
            Color.clear
        }
    }

    @ViewBuilder
    private func stepStage(_ step: PottyRoutineStep) -> some View {
        RoutineStepStage(
            step: step,
            timerFraction: model.showsTimerRing ? model.timerFraction : nil
        ) {
            VStack(spacing: theme.spacing.l) {
                if model.isAwaitingOutcome {
                    RoutineOutcomeChoices { model.recordOutcome($0) }
                } else {
                    HopPrimaryButton(
                        HopCopy.routine.nextButton.value,
                        icon: "arrow.right",
                        size: .childPrimary
                    ) {
                        model.advance()
                    }
                }

                if step.isSkippable {
                    // Secondary and parent-sized: skipping is a real, blameless
                    // option, but it is not one of the answers, so it must not
                    // compete with the three that are.
                    HopSecondaryButton(HopCopy.routine.skipButton.value, icon: "forward.fill") {
                        model.skip()
                    }
                }
            }
        }
    }

    // MARK: - Derived reward preview

    /// Stars this run would earn. Derived from the reasons the steps declare, so
    /// this screen and the ledger agree about the shape of the award.
    ///
    /// The *authoritative* write happens in the caller through `RewardService`,
    /// which collapses duplicates. If a retried award turns out to be a
    /// duplicate the pond simply does not change — which is why nothing here
    /// subtracts, and why the celebration never promises more than a star.
    private var starsEarned: Int {
        model.result.earnedReasons.reduce(0) { $0 + $1.defaultQuantity }
    }

    private var newlyUnlocked: PondItem? {
        PondProgressService()
            .newlyUnlocked(from: context.totalStars, to: context.totalStars + starsEarned)
            .last
    }
}

#Preview("Routine · default, from the top") {
    PottyRoutineView(onFinish: { _ in })
        .childContext(ChildContext(child: ChildProfile(nickname: "Maya"), totalStars: 7))
        .hopThemedRoot()
}

#Preview("Routine · sit timer on") {
    PottyRoutineView(
        settings: AppSettings(routineSitTimerEnabled: true, routineSitTimerDuration: 90),
        onFinish: { _ in }
    )
    .childContext(ChildContext(totalStars: 2))
    .hopThemedRoot()
}

#Preview("Routine · Reduce Motion") {
    PottyRoutineView(onFinish: { _ in })
        .childContext(ChildContext(totalStars: 2))
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Routine · AX3") {
    PottyRoutineView(onFinish: { _ in })
        .environment(\.dynamicTypeSize, .accessibility3)
        .childContext(ChildContext(totalStars: 2))
        .hopThemedRoot()
}

#Preview("Routine · iPad") {
    PottyRoutineView(onFinish: { _ in })
        .frame(width: 1024, height: 768)
        .childContext(ChildContext(child: ChildProfile(nickname: "Sam"), totalStars: 40))
        .hopThemedRoot()
}
