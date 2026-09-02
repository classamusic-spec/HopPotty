import SwiftUI
import HopPottyCore

/// The guided routine, end to end: the pause, five steps and a celebration.
///
/// ## One screen at a time, and nothing around it
///
/// Navigation is one level deep on purpose. There is no stack, no tab bar and no
/// back button — a two-year-old holding a tablet in a bathroom gets one screen
/// at a time, one thing to do, and a grown-up always in the same corner. The
/// whole run is short by construction:
/// `PottyRoutineContent.estimatedDuration` fits inside the default pause with
/// room to spare.
///
/// This view used to draw a chrome row above every step: a help button, a
/// five-dot step indicator and a close button. All three are gone, and the
/// reasons are different for each:
///
///  * **the dots** were half of a checklist — the other half was the named strip
///    along the bottom of each step — and a guided routine is one focused step
///    at a time. A child shown four more steps is being shown a queue;
///  * **the close button** was an adult's affordance wearing a child's clothes.
///    An `xmark` means nothing to a pre-reader, and the real way out of a
///    bathroom is a grown-up. `HopHubView.askForAGrownUp()` already closes the
///    routine and raises the parent gate, so the hand *is* the exit, and it is
///    an exit into adult hands rather than a shrug back to a menu;
///  * **the help button** stayed, and it is now the only chrome on the screen.
///
/// ## Where the wash step went
///
/// The wash step no longer has an illustration-and-Next screen. It opens
/// ``BubbleWashScreen`` directly — the child arrives in the close-up of Hop's
/// hands, rubs them clean, and the routine moves on by itself when they are.
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
    /// Called when the child asks for a grown-up. Never a dead end, and now the
    /// routine's only way out that is not finishing it.
    let onAskForHelp: () -> Void
    /// Reports where in the routine the child is, whenever that changes.
    ///
    /// Two numbers, and deliberately only two: a **zero-based** index — the
    /// basis `PottyPauseAttributes.ContentState.stepIndex` uses — and how many
    /// steps there are. Never the step's title. The one consumer is the Live
    /// Activity on the lock screen, which is the most public surface HopPotty
    /// has, and `Docs/Widgets.md` §2 is why "2 of 5" is allowed there and "Wash
    /// your hands" is not.
    let onStepChange: (_ stepIndex: Int, _ stepCount: Int) -> Void

    @State private var model: PottyRoutineModel

    init(
        settings: AppSettings = AppSettings(),
        onFinish: @escaping (PottyRoutineResult) -> Void,
        onOpenPond: @escaping () -> Void = {},
        onAskForHelp: @escaping () -> Void = {},
        onStepChange: @escaping (Int, Int) -> Void = { _, _ in }
    ) {
        self.onFinish = onFinish
        self.onOpenPond = onOpenPond
        self.onAskForHelp = onAskForHelp
        self.onStepChange = onStepChange
        _model = State(initialValue: PottyRoutineModel(settings: settings))
    }

    var body: some View {
        // `PottyRoutineModel.Stage` is Equatable but not Hashable, so the stage
        // cannot go through `HopPageSwitch` — the transition and the spring are
        // wired by hand instead, and they are the same two the switch would have
        // paired.
        stage
            .hopScreenChange(.childPage, value: model.stage)
            .hopBackground(.secondary)
            .routineTicker(isRunning: model.showsTimerRing) { model.tick($0) }
            // The opening step, reported once. A routine that is opened and
            // never advanced still has a position, and a lock screen that says
            // "1 of 5" because nothing told it otherwise is only right by luck.
            .onAppear { reportStep() }
            .onChange(of: model.stage) { _, stage in
                if stage == .finished { onFinish(model.result) }
                reportStep()
            }
    }

    /// `currentStepNumber` is 1-based, for the VoiceOver label and the Live
    /// Activity; the activity's index is 0-based. Converted in exactly one place.
    ///
    /// Through the celebration and after it the model clamps to the last step
    /// rather than running past the end, so this never reports a sixth step of
    /// five on the way out. A routine with no steps at all — not representable
    /// in content, but a caller can hand one in — reports nothing rather than
    /// "step −1 of 0".
    private func reportStep() {
        guard model.stepCount > 0 else { return }
        onStepChange(model.currentStepNumber - 1, model.stepCount)
    }

    // MARK: - Stage

    @ViewBuilder
    private var stage: some View {
        switch model.stage {
        case .arriving:
            RoutinePauseView(onGo: { model.advance() }, onAskForHelp: onAskForHelp)
                .hopScreenTransition(.childPage)

        case .step:
            if let step = model.currentStep {
                Group {
                    if model.isWashing {
                        // The wash step *is* Bubble Wash. It brings its own line
                        // and its own way to a grown-up, and it finishes itself.
                        BubbleWashScreen(
                            onFinish: { model.advance() },
                            onAskForHelp: onAskForHelp,
                            title: step.instruction.localized
                        )
                    } else {
                        stepStage(step)
                            .overlay(alignment: .topTrailing) { grownUpButton }
                    }
                }
                .id(stageIdentity(step))
                .hopScreenTransition(.childPage)
            }

        case .celebration:
            RoutineCelebrationView(
                outcome: model.outcome,
                starsEarned: starsEarned,
                unlocked: newlyUnlocked,
                onSeeThePond: onOpenPond,
                onFinish: { model.finishCelebration() }
            )
            .hopScreenTransition(.celebration)

        case .finished:
            // The caller has been told; hold the ground colour for the one frame
            // before it dismisses us rather than flashing an empty screen.
            Color.clear
        }
    }

    /// The identity a screen change is keyed on.
    ///
    /// The try step is two screens — sitting, then the question — so its two
    /// beats have to be two identities or the answers would appear under the
    /// child without the page ever changing.
    private func stageIdentity(_ step: PottyRoutineStep) -> String {
        step.id.rawValue + (step.id == .tryIt ? "-\(model.tryBeat)" : "")
    }

    /// The only chrome on a routine step, in the same corner every time.
    ///
    /// Framed to `hitTarget.childMinimum` rather than drawn at it — a 72pt
    /// filled disc in the corner of an illustrated screen reads as a button
    /// demanding attention, and the target is what has to be 72, not the ink.
    private var grownUpButton: some View {
        HopIconButton(
            systemImage: "hand.raised.fill",
            accessibilityLabel: HopCopy.routine.helpButton.localized,
            tint: theme.color.textSecondary,
            minimumTarget: theme.hitTarget.child,
            action: onAskForHelp
        )
        .hopPageMargins()
        .padding(.top, theme.spacing.xs)
    }

    @ViewBuilder
    private func stepStage(_ step: PottyRoutineStep) -> some View {
        RoutineStepStage(
            step: step,
            timerFraction: model.showsTimerRing ? model.timerFraction : nil,
            // The child has just said what happened, so Hop celebrates it —
            // here, on the step they land on, rather than four steps later. All
            // three answers get the same hop; only the direction differs.
            hop: model.isAcknowledgingOutcome
                ? RoutineOutcomeChoices.acknowledgementHop(for: model.outcome)
                : nil,
            // Every step after the first was arrived at by the child finishing
            // the one before, so Hop notices it — the small warm beat, not a
            // celebration, and never on the step the routine opens on.
            notices: !model.isAcknowledgingOutcome && model.currentStepNumber > 1
        ) {
            VStack(spacing: theme.spacing.l) {
                if model.isAwaitingOutcome {
                    RoutineOutcomeChoices { model.recordOutcome($0) }
                } else {
                    HopPrimaryButton(
                        primaryTitle(for: step),
                        icon: primaryIcon(for: step),
                        size: .childPrimary
                    ) {
                        model.advance()
                    }
                }

                if step.isSkippable, !model.isAwaitingOutcome {
                    // Secondary and parent-sized: skipping is a real, blameless
                    // option, but it is not one of the answers, so it must not
                    // compete with the three that are.
                    HopSecondaryButton(HopCopy.routine.skipButton.localized, icon: "forward.fill") {
                        model.skip()
                    }
                }
            }
        }
    }

    /// The word on the big button.
    ///
    /// "Next" everywhere except the last step, which leaves the steps behind and
    /// says so. Plain verbs, one or two words — a pre-reader learns the button
    /// by its shape and its place, and the word is for whoever is reading it to
    /// them.
    private func primaryTitle(for step: PottyRoutineStep) -> String {
        step.id == .highFive
            ? HopCopy.routine.leaveButton.localized
            : HopCopy.routine.nextButton.localized
    }

    private func primaryIcon(for step: PottyRoutineStep) -> String {
        step.id == .highFive ? "checkmark" : "arrow.right"
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

#Preview("Routine · from the Potty Pause") {
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
