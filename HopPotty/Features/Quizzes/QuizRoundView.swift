import SwiftUI
import HopPottyCore

/// Hop's questions, audio-first.
///
/// The screen is a spoken prompt with a replay button and three large pictures.
/// A child who cannot read a word can play the whole thing: they hear the
/// question, they tap a picture, Hop answers. Captions sit under the prompt for
/// the caregiver, for a family with the sound off, and for a deaf child —
/// contract §6, and today the *only* delivery, because no voice bundle has
/// shipped yet.
///
/// A pick that is not the one being taught is never called wrong. It gets
/// `HopVoice.shared.quizRedirect` — "Almost! Let's try another." — once, warmly,
/// with the board untouched underneath. There is no score, no timer, no streak
/// and no way to finish this screen having done badly at it.
struct QuizRoundView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Called when the child leaves, however they leave — the last question, or
    /// the close control on the first one. The caller records the completion and
    /// awards through `RewardService`; leaving early is not a lesser ending and
    /// earns the same star.
    let onFinish: (QuizRoundResult) -> Void

    @State private var model: QuizRoundModel
    @State private var promptPulse = 0

    init(model: QuizRoundModel = QuizRoundModel(), onFinish: @escaping (QuizRoundResult) -> Void) {
        self.onFinish = onFinish
        _model = State(initialValue: model)
    }

    private func leave() { onFinish(model.result) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.isFinished {
                finished
            } else if let question = model.currentQuestion {
                round(question)
            }
        }
        .hopBackground(.secondary)
        .hopAnimation(.childArrive, value: model.index)
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
            HopCharacterStage(pose: .idle, size: ChildStage.characterSize(for: horizontalSizeClass) * 0.7)
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
    }

    @ViewBuilder
    private func options(_ question: QuizQuestion) -> some View {
        let cards = ForEach(model.options) { option in
            QuizOptionCard(
                option: option,
                isAffirmed: model.hasAnswered && option.id == question.correctOptionID
            ) {
                model.answer(option.id)
            }
        }

        Group {
            // Three pictures side by side stop being pictures at accessibility
            // text sizes, so they stack. Nothing else about them changes.
            if dynamicTypeSize >= .accessibility2 {
                VStack(spacing: theme.spacing.m) { cards }
            } else {
                HStack(spacing: theme.spacing.m) { cards }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(HopCopy.a11y.quizOptionHint.localized)
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
        VStack(spacing: theme.spacing.xl) {
            HopCharacterStage(pose: .cheer, size: ChildStage.characterSize(for: horizontalSizeClass))
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
