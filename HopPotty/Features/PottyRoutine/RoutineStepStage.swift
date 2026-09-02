import SwiftUI
import HopPottyCore

/// One step of the routine, drawn as a full-screen place.
///
/// ## What came off this screen, and why
///
/// It used to be a rounded white card with the illustration inside it, a
/// five-dot indicator above and a five-cell named strip below. Three things were
/// wrong with that, and all three are gone:
///
///  * **the card.** A rounded rectangle floating on a background is the
///    vocabulary of an app. The drawing is the bathroom the child is standing
///    in, so it is bled edge to edge and dissolved into the page at both ends;
///    there is no frame anywhere on the screen.
///  * **the two progress indicators.** Dots at the top and a named strip at the
///    bottom were two readings of the same checklist, and a guided routine is
///    one focused step at a time. A two-year-old shown four more steps is being
///    shown a queue.
///  * **the close button.** The way out of a routine is an adult, and it is the
///    hand in the corner — see ``PottyRoutineView``.
///
/// What is left is the room, Hop doing the step alongside the child, one short
/// sentence, one big button, and — only where the content marks the step
/// skippable — the word "Skip this" underneath.
struct RoutineStepStage<Actions: View>: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let step: PottyRoutineStep
    let timerFraction: Double?
    /// A hop for Hop to play on arriving at this step.
    ///
    /// Used for one thing: the instant a child answers "All done trying?", the
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
    /// The action row. The try step's second beat passes its three answers;
    /// every other step passes a single "Next".
    @ViewBuilder var actions: () -> Actions

    @State private var replayPulse = 0
    /// Which beat Hop is on. One value, changed by one task, so the acts cannot
    /// end up fighting over him.
    @State private var beat: StepBeat = .arriving

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: theme.spacing.l) {
                    Spacer(minLength: theme.spacing.m)
                    character(in: proxy.size)
                    words
                    Spacer(minLength: theme.spacing.l)
                    actions()
                }
                .frame(maxWidth: ChildStage.contentWidth)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                .hopPageMargins()
                .padding(.bottom, theme.spacing.l)
            }
            // A child screen scrolls only when the text is enormous; the bar is
            // noise on an illustrated stage the rest of the time.
            .scrollIndicators(.hidden)
            .background {
                RoutineStepGround(
                    illustration: step.illustration,
                    label: step.illustrationLabel.localized,
                    showsIllustration: timerFraction == nil
                )
            }
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
    /// The acknowledgement hop wins outright: the child has just answered "All
    /// done trying?", and nothing may interrupt or shorten the answer to that.
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

    /// Hop, staged large, with the calm ring behind him where there is one.
    ///
    /// The ring is behind rather than beside because it belongs *to* the sitting
    /// — a circle slowly filling around a frog who is waiting reads as time
    /// passing with him, and the same circle in its own box beside him reads as
    /// a gauge being watched.
    private func character(in size: CGSize) -> some View {
        let side = characterSide(in: size)
        return ZStack {
            if let timerFraction {
                RoutineTimerRing(fraction: timerFraction, diameter: side * 1.34, caption: nil)
            }

            HopCharacterStage(act: act, size: side, gaze: gaze)
                .frame(height: side + HopJump.headroom(for: side), alignment: .bottom)
                // Hop is doing the step; the drawing behind him and the words
                // under him already say which step, and three readings of one
                // sentence is what VoiceOver users have to sit through.
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
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

    /// Hop is the subject of the screen now that the card has gone, so he is
    /// drawn at the full stage size rather than at the 0.72 that made room for
    /// an illustration beside him.
    private func characterSide(in size: CGSize) -> CGFloat {
        min(ChildStage.characterSize(for: horizontalSizeClass), size.height * 0.34)
    }

    /// Where Hop is looking on this step.
    ///
    /// Eyes that point at the thing being talked about cost nothing and are most
    /// of what makes a drawing read as watching rather than as printed. He is
    /// centred on the screen now, so the targets are the room behind him and the
    /// button under him rather than a picture at his side.
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

/// The room a step happens in.
///
/// The step's own drawing at full width — the scenes are 4:3, so a full-width
/// band is the whole picture with nothing cropped — masked away at the top and
/// the bottom so it dissolves into the page instead of ending on an edge. That
/// mask is the entire difference between a place and a card.
///
/// `showsIllustration` is false on the one step that has a calm ring: a filling
/// circle and a picture of a potty competing for the middle of the screen is two
/// subjects, and the ring wins on the step whose whole content is waiting.
private struct RoutineStepGround: View {
    @Environment(\.hopTheme) private var theme

    let illustration: HopIllustrationKey
    let label: String
    let showsIllustration: Bool

    /// The drawing goes on top of the room only when there is a drawing. The
    /// asset catalog is still empty (`BUILD_STATUS.md`), so on today's build
    /// every step is the room alone — which is a bathroom, and is correct, where
    /// `HopArtwork`'s placeholder would be a soft lilac blob behind the words.
    private var hasDrawing: Bool {
        showsIllustration && HopArtwork.hasAsset(for: illustration)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .top) {
                ChildRoom(floorFraction: 0.66, glow: !hasDrawing)

                if hasDrawing {
                    HopArtwork(illustration, accessibilityLabel: label)
                        .frame(width: size.width, height: size.width * 0.75)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.17),
                                    .init(color: .black, location: 0.83),
                                    .init(color: .clear, location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .offset(y: size.height * 0.2)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

#Preview("Routine step · try, with the calm ring") {
    RoutineStepStage(
        step: PottyRoutineContent.tryStep,
        timerFraction: 0.36
    ) {
        HopPrimaryButton(HopCopy.routine.nextButton.localized, icon: "arrow.right", size: .childPrimary) {}
    }
    .hopThemedRoot()
}

#Preview("Routine step · the question") {
    RoutineStepStage(
        step: PottyRoutineContent.tryStep,
        timerFraction: nil
    ) {
        RoutineOutcomeChoices { _ in }
    }
    .hopThemedRoot()
}

#Preview("Routine step · Hop acknowledges the answer") {
    RoutineStepStage(
        step: PottyRoutineContent.wipeStep,
        timerFraction: nil,
        hop: RoutineOutcomeChoices.acknowledgementHop(for: .tried)
    ) {
        HopPrimaryButton(HopCopy.routine.nextButton.localized, icon: "arrow.right", size: .childPrimary) {}
    }
    .hopThemedRoot()
}

#Preview("Routine step · Reduce Motion (the hop is a cross-fade)") {
    RoutineStepStage(
        step: PottyRoutineContent.flushStep,
        timerFraction: nil,
        hop: RoutineOutcomeChoices.acknowledgementHop(for: .pee)
    ) {
        HopPrimaryButton(HopCopy.routine.nextButton.localized, icon: "arrow.right", size: .childPrimary) {}
    }
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Routine step · AX3") {
    RoutineStepStage(
        step: PottyRoutineContent.tryStep,
        timerFraction: nil
    ) {
        RoutineOutcomeChoices { _ in }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopThemedRoot()
}

#Preview("Routine step · iPad") {
    RoutineStepStage(
        step: PottyRoutineContent.highFiveStep,
        timerFraction: nil
    ) {
        HopPrimaryButton(HopCopy.routine.leaveButton.localized, icon: "checkmark", size: .childPrimary) {}
    }
    .frame(width: 1024, height: 768)
    .hopThemedRoot()
}
