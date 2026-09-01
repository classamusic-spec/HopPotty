import Foundation

public enum MiniGameID: String, CaseIterable, Sendable, Identifiable, Codable {
    case bubbleWash
    case pottyPath
    case bathroomMatch

    public var id: String { rawValue }
}

/// How a round of a mini-game ends.
///
/// Both cases end well. There is no `.timeUp` and no `.failed`, because a game
/// that can be lost turns a bathroom trip into something a child can be bad at,
/// and a countdown turns it into something to rush. Whatever a child does, the
/// round finishes with the same cheer.
public enum MiniGameCompletion: Hashable, Sendable {
    /// The board runs out of things to do — every bubble popped, the path
    /// walked to the end. The game ends itself.
    case whenTaskComplete
    /// Open-ended. The board keeps offering more and the child taps "All done"
    /// when they have had enough.
    case whenChildIsDone

    /// Whether the round can finish without the child asking it to.
    public var endsAutomatically: Bool { self == .whenTaskComplete }
}

public struct MiniGame: Identifiable, Hashable, Sendable {
    public let id: MiniGameID
    /// Shown to the child and to the caregiver; the games are named, not
    /// numbered, so a child can ask for one by name.
    public let title: HopCopyEntry
    /// One line, read to the child before they start.
    public let childDescription: HopCopyEntry
    /// What the game is actually for, in the caregiver's list. Written plainly:
    /// a caregiver deciding whether to leave games on deserves to know what each
    /// one is practising.
    public let learningGoal: HopCopyEntry
    /// How long a round usually lasts. Held between 30 and 90 seconds: below
    /// that a game is not worth loading, above it the game becomes the reason to
    /// go to the bathroom rather than a small thank-you afterwards.
    public let targetDuration: TimeInterval
    public let completion: MiniGameCompletion
    public let illustration: HopIllustrationKey
    public let rewardReason: RewardReason

    public init(
        id: MiniGameID,
        title: HopCopyEntry,
        childDescription: HopCopyEntry,
        learningGoal: HopCopyEntry,
        targetDuration: TimeInterval,
        completion: MiniGameCompletion,
        illustration: HopIllustrationKey,
        rewardReason: RewardReason = .completedGame
    ) {
        self.id = id
        self.title = title
        self.childDescription = childDescription
        self.learningGoal = learningGoal
        self.targetDuration = targetDuration
        self.completion = completion
        self.illustration = illustration
        self.rewardReason = rewardReason
    }

    public var endsAutomatically: Bool { completion.endsAutomatically }

    public var copyEntries: [HopCopyEntry] { [title, childDescription, learningGoal] }
}

/// The three mini-games.
public enum MiniGameCatalog {

    public static let bubbleWash = MiniGame(
        id: .bubbleWash,
        title: .child("games.bubbleWash.title", "Bubble Wash"),
        childDescription: .child("games.bubbleWash.description", "Pop every bubble to get your hands sparkly clean!"),
        learningGoal: .parent(
            "games.bubbleWash.goal",
            "Makes the twenty seconds of scrubbing feel like something worth finishing."
        ),
        // Twenty seconds of scrubbing plus the popping either side of it.
        targetDuration: 45,
        completion: .whenTaskComplete,
        illustration: "scene.games.bubbleWash"
    )

    public static let pottyPath = MiniGame(
        id: .pottyPath,
        title: .child("games.pottyPath.title", "Potty Path"),
        childDescription: .child("games.pottyPath.description", "Hop along the lily pads all the way to the potty!"),
        learningGoal: .parent(
            "games.pottyPath.goal",
            "Rehearses the trip to the bathroom as a small, friendly journey with an ending."
        ),
        targetDuration: 60,
        completion: .whenTaskComplete,
        illustration: "scene.games.pottyPath"
    )

    public static let bathroomMatch = MiniGame(
        id: .bathroomMatch,
        title: .child("games.bathroomMatch.title", "Bathroom Match"),
        childDescription: .child("games.bathroomMatch.description", "Find the two that go together."),
        learningGoal: .parent(
            "games.bathroomMatch.goal",
            "Gives your child words for the things in a bathroom: soap, towel, paper, flush."
        ),
        // The calm one. The board reshuffles as long as a child wants it to, so
        // it is the only game with no ending of its own.
        targetDuration: 90,
        completion: .whenChildIsDone,
        illustration: "scene.games.bathroomMatch"
    )

    public static let all: [MiniGame] = [bubbleWash, pottyPath, bathroomMatch]

    public static func game(_ id: MiniGameID) -> MiniGame {
        // Total: every case in the enum has an entry, and the test proves it.
        all.first { $0.id == id } ?? bubbleWash
    }

    /// The bounds every game is held to.
    public static let targetDurationRange: ClosedRange<TimeInterval> = 30...90

    public static var copyEntries: [HopCopyEntry] { all.flatMap(\.copyEntries) }

    public static var illustrations: [HopIllustrationKey] { all.map(\.illustration) }
}
