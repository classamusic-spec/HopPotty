import SwiftUI
import HopPottyCore

/// One step of the routine, drawn as a full-screen illustrated place.
///
/// The picture is the content. A child who cannot read a word gets the meaning
/// from the drawing, Hop's pose and the spoken line; the title and instruction
/// are there for the caregiver leaning over the shoulder and for anyone using
/// VoiceOver. Nothing is small, and there is only ever one thing to do.
struct RoutineStepStage<Actions: View>: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let step: PottyRoutineStep
    let timerFraction: Double?
    /// A hop for Hop to play on arriving at this step.
    ///
    /// Used for one thing: the instant a child answers "How did it go?", the
    /// screen moves on and Hop celebrates the answer they just gave — on the
    /// step they land on, so the acknowledgement costs the routine no time and
    /// cannot hold anyone anywhere. All three answers get the same hop
    /// (`RoutineOutcomeChoices.acknowledgementHop(for:)`).
    var hop: HopJump? = nil
    /// Whether the child arrived here by finishing the step before.
    ///
    /// Drives one short beat — Hop's eyes squeeze up and he lifts an inch —
    /// before he says the line. It is *noticing*, not celebrating: the
    /// celebration belongs to the end of the run, and a step that cheered would
    /// leave it nowhere to go.
    var notices: Bool = false
    /// The action row. The try step passes its three answers; every other step
    /// passes a single "Next".
    @ViewBuilder var actions: () -> Actions

    @State private var replayPulse = 0
    /// Which beat Hop is on. One value, changed by one task, so the acts cannot
    /// end up fighting over him.
    @State private var beat: StepBeat = .arriving

    var body: some View {
        GeometryReader { proxy in
            let stageHeight = ChildStage.height(for: horizontalSizeClass, in: proxy.size.height)

            ScrollView {
                VStack(spacing: theme.spacing.xxl) {
                    illustration(height: stageHeight)
                    words
                    if let timerFraction {
                        RoutineTimerRing(
                            fraction: timerFraction,
                            diameter: stageHeight * 0.62,
                            caption: step.id == .tryIt ? HopCopy.routine.sitTimerCaption.localized : nil
                        )
                    }
                    actions()
                }
                .frame(maxWidth: ChildStage.contentWidth)
                .frame(maxWidth: .infinity)
                .hopPageMargins()
                .padding(.vertical, theme.spacing.xl)
            }
            // A child screen scrolls only when the text is enormous; the bar is
            // noise on an illustrated stage the rest of the time.
            .scrollIndicators(.hidden)
        }
        // One task owns the whole beat, and it is keyed on the replay count so
        // asking to hear the line again makes Hop say it again. The step itself
        // cannot change under this view — the caller gives each step its own
        // identity — so the first run is the arrival.
        .task(id: replayPulse) {
            if notices, replayPulse == 0 {
                beat = .noticing
                try? await Task.sleep(
                    for: .seconds(HopAct.delighted(pose).duration(reduceMotion: theme.reduceMotion))
                )
                guard !Task.isCancelled else { return }
            }
            beat = .speaking
            try? await Task.sleep(for: .seconds(step.voice.spokenDuration))
            guard !Task.isCancelled else { return }
            beat = .resting
        }
    }

    // MARK: - What Hop is doing

    /// The beats one step of the routine has, in the order they happen.
    private enum StepBeat {
        /// Before anything has run — and, when the child has just finished the
        /// step before, the moment Hop notices it.
        case arriving
        case noticing
        case speaking
        case resting
    }

    /// Hop's act on this step.
    ///
    /// The acknowledgement hop wins outright: the child has just answered "How
    /// did it go?", and nothing may interrupt or shorten the answer to that.
    /// Below it the beat runs — notice, speak, rest — and every one of them
    /// rests on the step's own contextual pose, so Hop is doing the step
    /// alongside the child rather than standing in a neutral drawing.
    private var act: HopAct {
        if let hop { return HopAct(pose: pose, beat: .hop(hop)) }
        switch beat {
        case .noticing: return .delighted(pose)
        case .speaking: return .speaking(pose: pose)
        case .arriving, .resting: return .holding(pose)
        }
    }

    // MARK: - Parts

    private func illustration(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous)
                .fill(theme.color.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous)
                        .strokeBorder(theme.color.divider.opacity(theme.isHighContrast ? 1 : 0.5), lineWidth: theme.isHighContrast ? 1.5 : 0.75)
                }

            HStack(spacing: theme.spacing.l) {
                HopArtwork(step.illustration, accessibilityLabel: step.illustrationLabel.localized)
                    .padding(theme.spacing.xl)

                // Hop is on every step, doing the step alongside the child. He
                // is decorative here: the drawing beside him already carries the
                // meaning, and two readings of the same picture is clutter.
                //
                // The headroom is reserved on every step, not only the hopping
                // one, so answering the try step does not shove the card's
                // contents around on the way out.
                HopCharacterStage(act: act, size: characterSide, gaze: gaze)
                    .frame(
                        height: characterSide + HopJump.headroom(for: characterSide),
                        alignment: .bottom
                    )
                    .accessibilityHidden(true)
            }
            .padding(theme.spacing.m)
        }
        .frame(height: height)
        .modifier(theme.elevation(.resting))
    }

    private var words: some View {
        VStack(spacing: theme.spacing.s) {
            Text(step.title.localized)
                .hopTextStyle(.childTitle)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(step.instruction.localized)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HopReplayButton(
                step.voice,
                label: HopCopy.routine.repeatButton.localized,
                pulse: $replayPulse
            )
            .padding(.top, theme.spacing.xs)

            HopSpokenLine(step.voice, pulse: replayPulse)
        }
    }

    private var characterSide: CGFloat {
        ChildStage.characterSize(for: horizontalSizeClass) * 0.72
    }

    /// Where Hop is looking on this step.
    ///
    /// He is drawn to the *right* of the illustration, so looking left is
    /// looking at the picture; looking down is looking at his own hands, or at
    /// the buttons under him. Eyes that point at the thing being talked about
    /// cost nothing and are most of what makes a drawing read as watching
    /// rather than as printed.
    private var gaze: HopGaze {
        switch step.id {
        case .tryIt: .down
        case .wipe: .down
        case .flush: .left
        case .wash: .down
        case .highFive: .forward
        }
    }

    /// What Hop is doing on this step. He models the action rather than
    /// watching the child perform it.
    private var pose: HopPose {
        switch step.id {
        case .tryIt: .wait
        case .wipe: .idle
        case .flush: .wave
        case .wash: .scrub
        case .highFive: .cheer
        }
    }
}

#Preview("Routine step · try") {
    RoutineStepStage(
        step: PottyRoutineContent.tryStep,
        timerFraction: nil
    ) {
        RoutineOutcomeChoices { _ in }
    }
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Routine step · Hop acknowledges the answer") {
    RoutineStepStage(
        step: PottyRoutineContent.washStep,
        timerFraction: nil,
        hop: RoutineOutcomeChoices.acknowledgementHop(for: .tried)
    ) {
        HopPrimaryButton(HopCopy.routine.nextButton.localized, icon: "arrow.right", size: .childPrimary) {}
    }
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Routine step · Reduce Motion (hop is a cross-fade)") {
    RoutineStepStage(
        step: PottyRoutineContent.washStep,
        timerFraction: nil,
        hop: RoutineOutcomeChoices.acknowledgementHop(for: .pee)
    ) {
        HopPrimaryButton(HopCopy.routine.nextButton.localized, icon: "arrow.right", size: .childPrimary) {}
    }
    .hopBackground(.secondary)
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Routine step · wash with ring") {
    RoutineStepStage(
        step: PottyRoutineContent.washStep,
        timerFraction: 0.55
    ) {
        HopPrimaryButton(HopCopy.routine.nextButton.localized, icon: "arrow.right", size: .childPrimary) {}
    }
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Routine step · AX3") {
    RoutineStepStage(
        step: PottyRoutineContent.tryStep,
        timerFraction: nil
    ) {
        RoutineOutcomeChoices { _ in }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Routine step · iPad") {
    RoutineStepStage(
        step: PottyRoutineContent.highFiveStep,
        timerFraction: nil
    ) {
        HopPrimaryButton(HopCopy.routine.nextButton.localized, icon: "arrow.right", size: .childPrimary) {}
    }
    .frame(width: 1024, height: 768)
    .hopBackground(.secondary)
    .hopThemedRoot()
}
