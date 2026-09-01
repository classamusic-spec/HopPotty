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
    /// The action row. The try step passes its three answers; every other step
    /// passes a single "Next".
    @ViewBuilder var actions: () -> Actions

    @State private var replayPulse = 0

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
                            caption: step.id == .tryIt ? HopCopy.routine.sitTimerCaption.value : nil
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
                HopArtwork(step.illustration, accessibilityLabel: step.illustrationLabel.value)
                    .padding(theme.spacing.xl)

                // Hop is on every step, doing the step alongside the child. He
                // is decorative here: the drawing beside him already carries the
                // meaning, and two readings of the same picture is clutter.
                HopCharacterStage(pose: pose, size: ChildStage.characterSize(for: horizontalSizeClass) * 0.72)
                    .accessibilityHidden(true)
            }
            .padding(theme.spacing.m)
        }
        .frame(height: height)
        .modifier(theme.elevation(.resting))
    }

    private var words: some View {
        VStack(spacing: theme.spacing.s) {
            Text(step.title.value)
                .hopTextStyle(.childTitle)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(step.instruction.value)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HopReplayButton(
                step.voice,
                label: HopCopy.routine.repeatButton.value,
                pulse: $replayPulse
            )
            .padding(.top, theme.spacing.xs)

            HopSpokenLine(step.voice, pulse: replayPulse)
        }
    }

    /// What Hop is doing on this step. He models the action rather than
    /// watching the child perform it.
    private var pose: HopPose {
        switch step.id {
        case .tryIt: .wait
        case .wipe: .idle
        case .flush: .wave
        case .wash: .idle
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

#Preview("Routine step · wash with ring") {
    RoutineStepStage(
        step: PottyRoutineContent.washStep,
        timerFraction: 0.55
    ) {
        HopPrimaryButton(HopCopy.routine.nextButton.value, icon: "arrow.right", size: .childPrimary) {}
    }
    .hopBackground(.secondary)
    .hopThemedRoot()
}
