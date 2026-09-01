import Foundation
import Observation
import HopPottyCore

/// What a round of questions produced.
///
/// Question ids and one reward reason — enough for the caller to record a
/// `QuizProgress` completion and award through `RewardService`, and nothing
/// else. There is deliberately no count of picks, no accuracy and no timing:
/// a number that exists is a number that ends up on a screen.
struct QuizRoundResult: Equatable, Sendable {
    /// Questions the child found the answer to, in the order they came.
    let answeredQuestionIDs: [QuizQuestionID]

    /// One star for having a go, the same as every other child-facing surface.
    var rewardReason: RewardReason { .completedQuiz }
}

/// A short round of Hop's questions.
///
/// `QuizContent.questionsPerRound` is three, and three is about as long as a
/// three-year-old's willingness to be asked things. The round is audio-first:
/// Hop asks, the child answers with a picture.
///
/// ## What cannot happen here
///
/// `QuizAnswerOutcome` has two cases and neither of them ends anything, so this
/// model has nowhere to put a score, a streak or a failure:
///
/// * a pick that is not the one being taught produces `.redirect`, the same warm
///   invitation every time, and the question **stays open underneath** — the
///   options remain tappable and the child decides when to move on;
/// * nothing is counted, so nothing can be lost. There is no `attempts`
///   property, deliberately: a number that exists is a number that ends up on
///   screen.
/// * there is no timer. A question waits as long as it waits.
@MainActor
@Observable
final class QuizRoundModel {

    private(set) var questions: [QuizQuestion]
    private(set) var index = 0
    /// The most recent answer's outcome, or `nil` before the child has tried.
    /// Cleared when the round moves on.
    private(set) var lastOutcome: QuizAnswerOutcome?
    private(set) var isFinished = false
    /// Questions the child has completed this round.
    private(set) var answeredQuestionIDs: [QuizQuestionID] = []

    private let seed: UInt64

    /// Builds a round.
    ///
    /// The questions are drawn with a seeded shuffle rather than `shuffled()` so
    /// a preview, a screenshot and a failing test all show the same round — the
    /// same reason `QuizQuestion.options(shuffledBy:)` is seeded.
    init(
        seed: UInt64 = UInt64(Date().timeIntervalSince1970),
        pool: [QuizQuestion] = QuizContent.allQuestions,
        count: Int = QuizContent.questionsPerRound
    ) {
        self.seed = seed
        var shuffler = GameShuffler(seed: seed)
        self.questions = Array(shuffler.shuffled(pool).prefix(max(1, count)))
    }

    var currentQuestion: QuizQuestion? {
        index < questions.count ? questions[index] : nil
    }

    /// The answers, in an order that changes between questions so a child learns
    /// the idea rather than the position of the correct picture.
    var options: [QuizOption] {
        guard let question = currentQuestion else { return [] }
        return question.options(shuffledBy: seed &+ UInt64(index) &* 31)
    }

    /// Whether the child has found the answer this question teaches. Drives
    /// which control is offered next, and nothing else.
    var hasAnswered: Bool { lastOutcome?.completesQuestion == true }

    /// 1-based position, for the step indicator.
    var questionNumber: Int { min(index + 1, questions.count) }

    // MARK: - Answering

    /// Records a pick.
    ///
    /// A redirect leaves everything exactly as it was except the line Hop says.
    /// The options are not disabled, not reordered and not marked — a child who
    /// taps the same picture three times hears the same warm sentence three
    /// times, which is the whole of the design.
    func answer(_ optionID: QuizOptionID) {
        guard let question = currentQuestion, !hasAnswered else { return }
        let outcome = question.outcome(for: optionID)
        lastOutcome = outcome
        if outcome.completesQuestion, !answeredQuestionIDs.contains(question.id) {
            answeredQuestionIDs.append(question.id)
        }
    }

    /// Moves to the next question, or ends the round.
    func next() {
        lastOutcome = nil
        if index + 1 < questions.count {
            index += 1
        } else {
            isFinished = true
        }
    }

    /// Ends the round wherever it is. Always legal, never commented on.
    func finish() {
        isFinished = true
    }

    /// Offers the same round again, from the top.
    func restart() {
        index = 0
        lastOutcome = nil
        isFinished = false
        answeredQuestionIDs = []
    }

    var result: QuizRoundResult {
        QuizRoundResult(answeredQuestionIDs: answeredQuestionIDs)
    }
}
