import SwiftUI
import HopPottyCore

/// Hop's questions, audio-first.
///
/// ## One question, three giant pictures
///
/// The screen is a spoken prompt with a replay button and three pictures, and
/// the pictures get the room: they are square tiles that fill the width between
/// them, never a row of thumbnails with captions. A child who cannot read a word
/// can play the whole thing — they hear the question, they tap a picture, Hop
/// answers. Captions sit under the prompt for the caregiver, for a family with
/// the sound off, and for a deaf child (contract §6), and today they are the
/// *only* delivery, because no voice bundle has shipped yet.
///
/// Nothing on this screen is a description of an answer. There is no text under
/// a tile, no "tap the right one", no hint text and no explanation — §32's "no
/// long descriptions" is not a length rule, it is a rule about what a picture is
/// for.
///
/// ## A pick that is not the one being taught
///
/// It is never called wrong. Hop turns thoughtful, the picture the child touched
/// gives one gentle bounce, and he says `HopVoice.shared.quizRedirect` —
/// "Almost! Let's try another." — once, warmly, with the board untouched
/// underneath. There is no score, no percentage, no timer, no streak, no count
/// of tries and no way to finish this screen having done badly at it.
struct QuizRoundView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.hopButtonFeedback) private var buttonFeedback

    /// Called when the child leaves, however they leave — the last question, or
    /// the close control on the first one. The caller records the completion and
    /// awards through `RewardService`; leaving early is not a lesser ending and
    /// earns the same star.
    let onFinish: (QuizRoundResult) -> Void

    @State private var model: QuizRoundModel
    @State private var promptPulse = 0
    /// True while Hop is delivering the prompt, so his mouth moves with it.
    @State private var isAsking = false
    /// The picture that was touched and turned out not to be the one being
    /// taught. It bounces once and is forgotten — nothing counts it, and it is
    /// deliberately not stored on the model, which has no room for such a thing.
    @State private var nudging: QuizOptionID?

    init(model: QuizRoundModel = QuizRoundModel(), onFinish: @escaping (QuizRoundResult) -> Void) {
        self.onFinish = onFinish
        _model = State(initialValue: model)
    }

    private func leave() { onFinish(model.result) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.isFinished {
                // No transition of its own: Hop hopping into the ending *is*
                // its arrival, and a page slide underneath him would be two
                // animations saying the same thing.
                finished
            } else if let question = model.currentQuestion {
                round(question)
                    .id(page)
                    .hopScreenTransition(.childPage)
            }
        }
        .hopBackground(.secondary)
        .hopScreenChange(.childPage, value: page)
        // A new question is a clean board: nothing carries over, least of all a
        // memory of what was touched on the last one.
        .onChange(of: page) { _, _ in nudging = nil }
    }

    /// Which page of the round is on screen: a question by its index, or the
    /// ending. `model.index` alone cannot say — it stops moving on the last
    /// question and `isFinished` is what changes instead.
    private var page: Int {
        model.isFinished ? model.questions.count : model.index
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: theme.spacing.m) {
            Text(HopCopy.quizzes.title.localized)
                .hopTextStyle(.parentTitle)
                .foregroundStyle(theme.color.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: theme.spacing.s)

            HopStepIndicator(total: model.questions.count, current: model.questionNumber)
                .accessibilityLabel(
                    HopCopy.a11y.progressDots.localized(filling: [
                        1: .count(model.questionNumber),
                        2: .count(model.questions.count),
                    ])
                )

            HopIconButton(
                systemImage: "xmark",
                accessibilityLabel: HopCopy.quizzes.doneButton.localized,
                action: leave
            )
        }
        .hopPageMargins()
        .padding(.vertical, theme.spacing.m)
    }

    // MARK: - A question

    private func round(_ question: QuizQuestion) -> some View {
        ScrollView {
            VStack(spacing: theme.spacing.xxl) {
                prompt(question)
                options(question)
                feedback
                if model.hasAnswered { advance }
            }
            .frame(maxWidth: ChildStage.contentWidth)
            .frame(maxWidth: .infinity)
            .hopPageMargins()
            .padding(.vertical, theme.spacing.xl)
        }
        .scrollIndicators(.hidden)
    }

    private func prompt(_ question: QuizQuestion) -> some View {
        VStack(spacing: theme.spacing.m) {
            HopCharacterStage(
                act: promptAct,
                size: ChildStage.characterSize(for: horizontalSizeClass) * 0.7,
                // The three pictures are below him, and they are what the child
                // is being asked to touch.
                gaze: .down
            )
            .accessibilityHidden(true)

            HopSpokenLine(question.prompt, style: .childTitle, pulse: promptPulse)

            HopReplayButton(
                question.prompt,
                label: HopCopy.quizzes.replayPrompt.localized,
                pulse: $promptPulse
            )
        }
        // The prompt is the heading of the screen for rotor navigation, and it
        // is what VoiceOver should land on when a new question arrives.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: question.prompt.localizedCaption))
        // Hop asks the question when it arrives, and asks it again when the
        // child taps the replay button. Nothing repeats it on its own.
        .task(id: [page, promptPulse]) {
            isAsking = true
            try? await Task.sleep(for: .seconds(question.prompt.spokenDuration))
            guard !Task.isCancelled else { return }
            isAsking = false
        }
    }

    /// What Hop is doing over the question.
    ///
    /// Three states, and none of them is disapproval. Finding the answer gets
    /// the small warm beat — *he noticed you*. A pick that is not the one being
    /// taught gets him **speaking**, because he has a warm sentence to say and a
    /// mascot who says a line without moving his mouth reads as a recording.
    /// Otherwise he is asking, or standing there.
    private var promptAct: HopAct {
        if model.hasAnswered { return .delighted() }
        if nudging != nil { return .speaking() }
        return isAsking ? .speaking() : .idle
    }

    @ViewBuilder
    private func options(_ question: QuizQuestion) -> some View {
        let cards = ForEach(model.options) { option in
            QuizOptionCard(
                option: option,
                isAffirmed: model.hasAnswered && option.id == question.correctOptionID,
                isNudging: nudging == option.id
            ) {
                pick(option, in: question)
            }
        }

        Group {
            // Three pictures side by side stop being pictures at accessibility
            // text sizes, so they stack — and stacked they get the full width,
            // which makes them larger rather than smaller. Nothing else about
            // them changes.
            if dynamicTypeSize >= .accessibility2 {
                VStack(spacing: theme.spacing.m) { cards }
            } else {
                HStack(spacing: theme.spacing.m) { cards }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(HopCopy.a11y.quizOptionHint.localized)
    }

    /// A picture was touched.
    ///
    /// Two outcomes, and the difference between them is one haptic and one
    /// bounce. Nothing is recorded about the second: `QuizRoundModel` has no
    /// `attempts` property, on purpose, and this view has no counter either —
    /// `nudging` holds one id for four tenths of a second and then forgets it.
    private func pick(_ option: QuizOption, in question: QuizQuestion) {
        let isTheOne = option.id == question.correctOptionID
        model.answer(option.id)

        guard !isTheOne else {
            // The soft confirmation §32 asks for, through the design system's
            // seam so the caregiver's haptics switch still governs it.
            buttonFeedback.play(.confirmation)
            nudging = nil
            return
        }

        nudging = option.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            if nudging == option.id { nudging = nil }
        }
    }

    /// Hop's answer to the pick. One line, either way.
    @ViewBuilder
    private var feedback: some View {
        if let outcome = model.lastOutcome {
            HopSpokenLine(outcome.voice, style: .childInstruction)
                .padding(theme.spacing.l)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                        .fill(HopColors.wash(
                            outcome.completesQuestion ? theme.color.success : theme.color.brandAction,
                            isDark: theme.isDark
                        ))
                }
                .hopTransition(.childArrive)
                .id(outcome.voice.id.rawValue)
        }
    }

    private var advance: some View {
        HopPrimaryButton(
            HopCopy.quizzes.nextButton.localized,
            icon: "arrow.right",
            size: .childPrimary
        ) {
            model.next()
        }
    }

    // MARK: - The end of a round

    private var finished: some View {
        let side = ChildStage.characterSize(for: horizontalSizeClass)
        return VStack(spacing: theme.spacing.xl) {
            // Hop hops into the ending rather than fading up in it. The frame
            // reserves the arc he travels through — the height he reaches and
            // the width he leans across — so the arrival never pushes the
            // sentence under him around or clips his head.
            HopCharacterStage(act: .entering(from: .left, restingOn: .cheer), size: side)
                .frame(
                    width: side + HopJump.sideroom(for: side) * 2,
                    height: side + HopJump.headroom(for: side),
                    alignment: .bottom
                )
                .accessibilityHidden(true)

            Text(HopCopy.quizzes.finishedTitle.localized)
                .hopTextStyle(.celebration)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            HopSpokenLine(HopVoice.shared.quizFinished)

            Text(HopCopy.quizzes.finishedBody.localized)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textSecondary)
                .multilineTextAlignment(.center)

            HopPrimaryButton(HopCopy.quizzes.doneButton.localized, icon: "checkmark", size: .childPrimary, action: leave)
            HopPrimaryButton(HopCopy.quizzes.startButton.localized, icon: "arrow.clockwise", size: .child) {
                model.restart()
            }
        }
        .frame(maxWidth: ChildStage.contentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hopPageMargins()
    }
}

#Preview("Quiz · first question") {
    QuizRoundView(onFinish: { _ in })
        .hopThemedRoot()
}

#Preview("Quiz · after a redirect") {
    QuizRoundView(model: {
        let model = QuizRoundModel(seed: 7)
        // A pick that is not the one being taught: the board stays exactly as
        // it was and Hop says the one warm line.
        model.answer("aPictureThatIsNotTheAnswer")
        return model
    }(), onFinish: { _ in })
    .hopThemedRoot()
}

#Preview("Quiz · answered, ready to move on") {
    QuizRoundView(model: {
        let model = QuizRoundModel(seed: 7)
        if let correct = model.currentQuestion?.correctOptionID { model.answer(correct) }
        return model
    }(), onFinish: { _ in })
    .hopThemedRoot()
}

#Preview("Quiz · Reduce Motion") {
    QuizRoundView(onFinish: { _ in })
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Quiz · AX3") {
    QuizRoundView(onFinish: { _ in })
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopThemedRoot()
}

#Preview("Quiz · iPad") {
    QuizRoundView(onFinish: { _ in })
        .frame(width: 1024, height: 768)
        .hopThemedRoot()
}
