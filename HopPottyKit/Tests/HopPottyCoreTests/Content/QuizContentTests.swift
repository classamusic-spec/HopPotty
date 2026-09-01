import Foundation
import Testing
@testable import HopPottyCore

/// Hop's questions.
///
/// The rules a quiz for a three-year-old has to obey are structural, not
/// stylistic: exactly one answer can be the one being taught, every other pick
/// gets the same warm invitation, and nothing anywhere counts, times or ends the
/// round against the child.
@Suite("Quiz content")
struct QuizContentTests {

    @Test("There are enough questions to make a round worth opening")
    func enoughQuestions() {
        #expect(QuizContent.allQuestions.count >= 12)
        #expect(QuizContent.questionsPerRound >= 2)
        #expect(QuizContent.questionsPerRound <= 5, "a round longer than this outlasts the attention it is asking for")
    }

    @Test("Every question has exactly one correct answer and at least three options")
    func questionShape() {
        for question in QuizContent.allQuestions {
            #expect(question.options.count >= 3, "\(question.id) offers \(question.options.count) options")
            let matching = question.options.filter { $0.id == question.correctOptionID }
            #expect(matching.count == 1, "\(question.id) has \(matching.count) options matching its correct id")
            #expect(question.correctOption != nil, "\(question.id) names a correct option that is not on the board")
            let ids = question.options.map(\.id)
            #expect(Set(ids).count == ids.count, "\(question.id) has duplicate option ids")
        }
    }

    @Test("Question ids are unique")
    func questionIDsAreUnique() {
        let ids = QuizContent.allQuestions.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every part of the curriculum has questions")
    func everyTopicIsCovered() {
        for topic in QuizTopic.allCases {
            #expect(!QuizContent.questions(topic: topic).isEmpty, "no questions for \(topic.rawValue)")
        }
    }

    /// The whole point. A pick that is not the taught answer produces a
    /// redirection, and the redirection is the same warm line every time — there
    /// is no sterner second version and no third strike.
    @Test("A pick that is not the taught answer gets gentle redirection")
    func wrongPicksRedirectGently() {
        for question in QuizContent.allQuestions {
            for option in question.options {
                let outcome = question.outcome(for: option.id)
                if option.id == question.correctOptionID {
                    #expect(outcome.completesQuestion, "\(question.id): the taught answer did not affirm")
                    #expect(outcome.voice.text == "Yes! That's it.")
                } else {
                    #expect(!outcome.completesQuestion, "\(question.id)/\(option.id) ended the question")
                    #expect(
                        outcome.voice.text == "Almost! Let's try another.",
                        "\(question.id)/\(option.id) said \"\(outcome.voice.text)\""
                    )
                }
            }
        }
    }

    /// An id that is not on the board — a stale tap, a restored session —
    /// redirects rather than trapping the child or crashing.
    @Test("An unknown answer redirects instead of failing")
    func unknownAnswersRedirect() {
        let question = QuizContent.afterPottyFirst
        let outcome = question.outcome(for: "somethingElse")
        #expect(!outcome.completesQuestion)
        #expect(outcome.voice.text == "Almost! Let's try another.")
    }

    /// There is no losing state to assert the absence of — the outcome type has
    /// only these two cases, and this switch is what would stop compiling if a
    /// third were added. Exhaustiveness is the test.
    @Test("The outcome type admits no losing state")
    func outcomeTypeHasNoLosingCase() {
        for question in QuizContent.allQuestions {
            for option in question.options {
                switch question.outcome(for: option.id) {
                case .affirm(let line):
                    #expect(!line.caption.isEmpty)
                case .redirect(let line):
                    #expect(!line.caption.isEmpty)
                }
            }
        }
    }

    /// If the answer were always in the same place a child would learn the
    /// position, not the idea — and a build that forgot to shuffle would teach
    /// it without anyone noticing.
    @Test("The taught answer is not always in the same position")
    func correctAnswerMovesAround() {
        var positions: Set<Int> = []
        for question in QuizContent.allQuestions {
            if let index = question.options.firstIndex(where: { $0.id == question.correctOptionID }) {
                positions.insert(index)
            }
        }
        #expect(positions.count >= 3, "the taught answer only ever sits at \(positions.sorted())")
    }

    @Test("Shuffling keeps every option and is deterministic")
    func shuffleIsAPermutation() {
        for question in QuizContent.allQuestions {
            let shuffled = question.options(shuffledBy: 7)
            #expect(Set(shuffled.map(\.id)) == Set(question.options.map(\.id)), "\(question.id) lost an option in the shuffle")
            #expect(shuffled.map(\.id) == question.options(shuffledBy: 7).map(\.id), "\(question.id) shuffled differently for the same seed")
        }
        // Different seeds have to actually produce different boards somewhere,
        // or the shuffle is decorative.
        let orders = (0..<8).map { QuizContent.afterPottyFirst.options(shuffledBy: UInt64($0)).map(\.id.rawValue) }
        #expect(Set(orders).count > 1, "every seed produced the same order")
    }

    @Test("Every question is asked aloud and written down")
    func questionsAreAudioFirst() {
        for question in QuizContent.allQuestions {
            #expect(!question.prompt.text.isEmpty, "\(question.id) has no spoken prompt")
            #expect(!question.writtenPrompt.isEmpty, "\(question.id) has no written prompt")
            let playback = HopVoiceResolver.captionsOnly.playback(for: question.prompt)
            #expect(playback.caption == question.writtenPrompt)
        }
    }

    /// The answers are pictures. A label exists for VoiceOver, but the option is
    /// identified by an illustration key — never by its text.
    @Test("Answers are pictures with labels, not text")
    func answersAreVisual() {
        for question in QuizContent.allQuestions {
            for option in question.options {
                #expect(option.illustration.isWellFormed, "\(question.id)/\(option.id): \(option.illustration) is not a valid art key")
                #expect(option.illustration.family == "icon", "quiz answers use icon art; \(option.illustration) does not")
                #expect(!option.label.value.isEmpty, "\(question.id)/\(option.id) has no VoiceOver label")
                #expect(option.label.audience == .child)
            }
        }
    }

    @Test("Quiz copy is keyed under the quizzes surface and unique")
    func quizCopyIsWellFormed() {
        let entries = QuizContent.copyEntries
        for entry in entries {
            #expect(entry.key.hasPrefix(HopCopySurface.quizzes.keyPrefix), "\(entry.key) is not on the quizzes surface")
        }
        let keys = entries.map(\.key)
        #expect(Set(keys).count == keys.count, "duplicated quiz keys")
    }
}
