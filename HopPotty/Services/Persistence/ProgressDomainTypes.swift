import Foundation
import HopPottyCore

// MARK: - Provisional home
//
// `QuizProgress` and `GameProgress` are named in the persistence spec but do not
// yet exist in `HopPottyKit/Sources/HopPottyCore/Models/`. They are defined here
// so the store, the repositories, the export and the deletion counts are
// complete and correct today.
//
// They are written to the same rules as every other Core model — value types,
// `Codable`, `Sendable`, scoped by `childID`, no reference to any Apple UI
// framework — so moving these two declarations into `HopPottyCore/Models/` is a
// file move plus a `public` keyword, with no change to the persistence layer.
// The quizzes and games agents own the *content*; this is only the shape the
// record takes on disk.

/// One child's history with Hop's quizzes.
///
/// Deliberately not a score. A quiz in HopPotty is a conversation with a
/// four-year-old about where poop goes, not an assessment: there is no grade, no
/// percentage, no "you got 2 of 5 wrong", and nothing here can go down. The
/// fields are "how many times did you play" and "when did you last play", which
/// is all a caregiver needs and all a child should ever be measured by.
struct QuizProgress: Hashable, Codable, Sendable {
    let childID: UUID
    /// Stable quiz identifier -> how many times the child has completed it.
    var completionsByQuiz: [String: Int]
    /// Stable quiz identifier -> when it was last completed.
    var lastCompletedByQuiz: [String: Date]
    var modifiedAt: Date

    init(
        childID: UUID,
        completionsByQuiz: [String: Int] = [:],
        lastCompletedByQuiz: [String: Date] = [:],
        modifiedAt: Date = Date()
    ) {
        self.childID = childID
        self.completionsByQuiz = completionsByQuiz.mapValues { max(0, $0) }
        self.lastCompletedByQuiz = lastCompletedByQuiz
        self.modifiedAt = modifiedAt
    }

    var totalCompletions: Int { completionsByQuiz.values.reduce(0, +) }
    var distinctQuizzesPlayed: Int { completionsByQuiz.filter { $0.value > 0 }.count }

    /// Records a completion. Monotonic — there is no method that decreases a
    /// count, for the same reason `RewardLedger` has no `remove`.
    mutating func recordCompletion(quizID: String, at date: Date) {
        completionsByQuiz[quizID, default: 0] += 1
        lastCompletedByQuiz[quizID] = date
        modifiedAt = date
    }
}

/// One child's history with the mini-games.
///
/// Same shape and the same rules as `QuizProgress`: plays, not scores. A
/// high-score field would turn a two-minute hand-washing game into something a
/// child can fail at, and would give the app a number that can go down.
struct GameProgress: Hashable, Codable, Sendable {
    let childID: UUID
    /// Stable game identifier -> how many times the child has finished a round.
    var completionsByGame: [String: Int]
    var lastCompletedByGame: [String: Date]
    var modifiedAt: Date

    init(
        childID: UUID,
        completionsByGame: [String: Int] = [:],
        lastCompletedByGame: [String: Date] = [:],
        modifiedAt: Date = Date()
    ) {
        self.childID = childID
        self.completionsByGame = completionsByGame.mapValues { max(0, $0) }
        self.lastCompletedByGame = lastCompletedByGame
        self.modifiedAt = modifiedAt
    }

    var totalCompletions: Int { completionsByGame.values.reduce(0, +) }
    var distinctGamesPlayed: Int { completionsByGame.filter { $0.value > 0 }.count }

    mutating func recordCompletion(gameID: String, at date: Date) {
        completionsByGame[gameID, default: 0] += 1
        lastCompletedByGame[gameID] = date
        modifiedAt = date
    }
}
