import Foundation

public enum MiniGameID: String, CaseIterable, Sendable, Identifiable, Codable {
    case bubbleWash
    case pottyPath
    case bathroomMatch
    case flySnack
    case mudOff
    case bodySignal
    case flushWave
    case pottyOrder

    public var id: String { rawValue }
}

/// How a round of a mini-game ends.
///
/// Every case ends well. There is no `.timeUp` and no `.failed`, because a game
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
    /// The round finishes by walking the child into the guided routine.
    ///
    /// Fly Snack is the one game whose ending *is* the lesson: Hop eats, Hop's
    /// tummy fills, and the story only makes sense if what happens next is going
    /// to the potty. So the round hands off to the first routine step rather
    /// than returning to the game list. Still an ending the game reaches on its
    /// own, and still nothing a child can get wrong.
    case handOffToRoutine

    /// Whether the round can finish without the child asking it to.
    public var endsAutomatically: Bool {
        switch self {
        case .whenTaskComplete, .handOffToRoutine: true
        case .whenChildIsDone: false
        }
    }

    /// The routine step this ending drops the child on, where it has one.
    ///
    /// Derived from the routine rather than stored beside the game: if the
    /// routine is ever reordered, the handoff follows it instead of pointing at
    /// a step that is no longer first.
    public var handOffStep: PottyRoutineStepID? {
        switch self {
        case .handOffToRoutine: PottyRoutineContent.steps.first?.id
        case .whenTaskComplete, .whenChildIsDone: nil
        }
    }
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
    /// The line on the opening card, which says what to do with a finger.
    /// `nil` on the three original games, whose `childDescription` already is
    /// that line.
    public let intro: HopCopyEntry?
    /// The line on the closing card. `nil` where the game uses the shared
    /// "Great playing!" (`HopCopy.games.finished`).
    public let done: HopCopyEntry?
    /// How long a round usually lasts. Held between 30 and 90 seconds: below
    /// that a game is not worth loading, above it the game becomes the reason to
    /// go to the bathroom rather than a small thank-you afterwards.
    public let targetDuration: TimeInterval
    public let completion: MiniGameCompletion
    public let illustration: HopIllustrationKey
    /// The small drawings the board moves around: flies, mud patches, cards.
    /// Declared here so the art check and the key tests see them; a sprite the
    /// content layer never names is a drawing nobody notices has gone missing.
    public let sprites: [HopIllustrationKey]
    /// Everything Hop says during a round, in the order a child hears it.
    public let voiceLines: [HopVoiceLine]
    public let rewardReason: RewardReason

    public init(
        id: MiniGameID,
        title: HopCopyEntry,
        childDescription: HopCopyEntry,
        learningGoal: HopCopyEntry,
        intro: HopCopyEntry? = nil,
        done: HopCopyEntry? = nil,
        targetDuration: TimeInterval,
        completion: MiniGameCompletion,
        illustration: HopIllustrationKey,
        sprites: [HopIllustrationKey] = [],
        voiceLines: [HopVoiceLine] = [],
        rewardReason: RewardReason = .completedGame
    ) {
        self.id = id
        self.title = title
        self.childDescription = childDescription
        self.learningGoal = learningGoal
        self.intro = intro
        self.done = done
        self.targetDuration = targetDuration
        self.completion = completion
        self.illustration = illustration
        self.sprites = sprites
        self.voiceLines = voiceLines
        self.rewardReason = rewardReason
    }

    public var endsAutomatically: Bool { completion.endsAutomatically }

    /// Every drawing this game needs: the scene it plays on and the pieces on it.
    public var illustrations: [HopIllustrationKey] { [illustration] + sprites }

    public var copyEntries: [HopCopyEntry] {
        [title, childDescription, learningGoal]
            + [intro, done].compactMap { $0 }
            + voiceLines.flatMap { $0.copyEntries() }
    }
}

/// The mini-games.
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

    // MARK: Fly Snack

    /// The game that teaches the whole chain: eat, feel it, go.
    ///
    /// A fly the child does not catch drifts off and comes round again, so there
    /// is nothing to miss and nothing to count. The tummy meter fills only on
    /// catches, which is why it can be shown as six friendly segments rather
    /// than a bar that could look like it is running out.
    public static let flySnack = MiniGame(
        id: .flySnack,
        title: .child("games.flySnack.title", "Fly Snack"),
        childDescription: .child("games.flySnack.description", "Tap a fly and watch Hop's tongue go!"),
        learningGoal: .parent(
            "games.flySnack.goal",
            "Shows the whole chain in one minute: eating and drinking give the body a signal, and the signal means it is time to go."
        ),
        intro: .child("games.flySnack.intro", "Hop is on his lily pad. Tap the flies for a snack!"),
        // Neutral and warm on purpose. The tummy is a messenger here, never a
        // comment on how much a child has eaten.
        done: .child("games.flySnack.done", "Hop's tummy says: potty time!"),
        targetDuration: 45,
        completion: .handOffToRoutine,
        illustration: "scene.games.flySnack",
        sprites: [
            "icon.games.fly.blue",
            "icon.games.fly.green",
            "icon.games.fly.gold",
            "icon.games.tummyMeter",
        ],
        voiceLines: [
            HopVoiceLine(id: "games.flySnack.spoken.intro", text: "Hop is hungry! Tap a fly."),
            HopVoiceLine(id: "games.flySnack.spoken.catch", text: "Yum! Hop's tummy is filling up."),
            HopVoiceLine(id: "games.flySnack.spoken.tummyFull", text: "Hop's tummy says: potty time!"),
            HopVoiceLine(id: "games.flySnack.spoken.handOff", text: "Let's hop to the potty together."),
        ]
    )

    // MARK: Mud Off

    public static let mudOff = MiniGame(
        id: .mudOff,
        title: .child("games.mudOff.title", "Mud Off"),
        childDescription: .child("games.mudOff.description", "Swipe the mud off Hop's hands."),
        learningGoal: .parent(
            "games.mudOff.goal",
            "Joins up seeing something on your hands with washing it off, so hand washing has a reason your child can see."
        ),
        intro: .child("games.mudOff.intro", "Hop played by the pond! Swipe each patch away."),
        done: .child("games.mudOff.done", "Sparkly clean hands!"),
        targetDuration: 45,
        completion: .whenTaskComplete,
        illustration: "scene.games.mudOff",
        sprites: [
            "icon.games.mud.brown",
            "icon.games.mud.green",
            "icon.games.mud.paint",
            "icon.games.sparkle",
        ],
        voiceLines: [
            HopVoiceLine(id: "games.mudOff.spoken.intro", text: "Hop's hands are muddy. Swipe it away!"),
            HopVoiceLine(id: "games.mudOff.spoken.patchGone", text: "One patch gone!"),
            HopVoiceLine(id: "games.mudOff.spoken.tap", text: "Now tap the tap for bubbles."),
            HopVoiceLine(id: "games.mudOff.spoken.done", text: "Sparkly clean hands!"),
        ]
    )

    // MARK: Listen to Your Body

    /// Tapping Hop when no bubble is showing gets a giggle, which is the point:
    /// a child exploring the screen finds warmth, so there is nothing here to
    /// get right and nothing to get otherwise.
    public static let bodySignal = MiniGame(
        id: .bodySignal,
        title: .child("games.bodySignal.title", "Listen to Your Body"),
        childDescription: .child("games.bodySignal.description", "Tap the bubble when it pops up."),
        learningGoal: .parent(
            "games.bodySignal.goal",
            "Practises catching the body's signal in the middle of playing, which is exactly when it is easiest to miss."
        ),
        intro: .child("games.bodySignal.intro", "Hop is bouncing his ball. Watch for his bubble!"),
        done: .child("games.bodySignal.done", "You listened to Hop's body!"),
        // Three signals with play between them.
        targetDuration: 60,
        completion: .whenTaskComplete,
        illustration: "scene.games.bodySignal",
        sprites: [
            "icon.games.ball",
            "icon.games.thoughtBubble",
        ],
        voiceLines: [
            HopVoiceLine(id: "games.bodySignal.spoken.intro", text: "Hop is playing. Tap his bubble when you see it."),
            HopVoiceLine(id: "games.bodySignal.spoken.signal", text: "I need the potty!"),
            HopVoiceLine(id: "games.bodySignal.spoken.giggle", text: "Hee hee! That tickles."),
            HopVoiceLine(id: "games.bodySignal.spoken.done", text: "You noticed every time!"),
        ]
    )

    // MARK: Flush and Wave

    /// For the child who finds the flush loud.
    ///
    /// The whole game is one cause and one effect, repeated as often as a child
    /// likes, with the sound under their own finger. This is also why the
    /// routine's Flush step is skippable: familiarity is built here, in play,
    /// and not required in the bathroom.
    public static let flushWave = MiniGame(
        id: .flushWave,
        title: .child("games.flushWave.title", "Flush and Wave"),
        childDescription: .child("games.flushWave.description", "Tap the flusher and wave bye-bye!"),
        learningGoal: .parent(
            "games.flushWave.goal",
            "Makes the flush familiar for a child who finds it loud, with the sound under their own finger and nowhere they have to be."
        ),
        intro: .child("games.flushWave.intro", "Tap the handle and watch the water swirl!"),
        done: .child("games.flushWave.done", "Bye-bye, water! Time to wash."),
        // The shortest game in the catalog: one cause, one effect, a wave.
        targetDuration: 30,
        completion: .whenTaskComplete,
        illustration: "scene.games.flushWave",
        sprites: [
            "icon.games.flusher",
            "icon.games.swirl",
        ],
        voiceLines: [
            HopVoiceLine(id: "games.flushWave.spoken.intro", text: "Give the flusher a tap!"),
            HopVoiceLine(id: "games.flushWave.spoken.flush", text: "Whoosh! Around it goes."),
            HopVoiceLine(id: "games.flushWave.spoken.wave", text: "Wave bye-bye!"),
            HopVoiceLine(id: "games.flushWave.spoken.wash", text: "Now we wash our hands."),
        ]
    )

    // MARK: Potty Order

    /// A card in a slot it does not belong in bounces back with the same warm
    /// invitation the quizzes use. Nothing is counted and the board stays open,
    /// so a child can rearrange the whole path as many times as they like.
    public static let pottyOrder = MiniGame(
        id: .pottyOrder,
        title: .child("games.pottyOrder.title", "Potty Order"),
        childDescription: .child("games.pottyOrder.description", "Put the cards on the path in order."),
        learningGoal: .parent(
            "games.pottyOrder.goal",
            "Rehearses the order of the routine away from the bathroom, where there is all the time in the world to think about it."
        ),
        intro: .child("games.pottyOrder.intro", "Four cards, one path. Which one comes first?"),
        done: .child("games.pottyOrder.done", "That's the order! Pants, sit, wipe, wash."),
        targetDuration: 60,
        completion: .whenTaskComplete,
        illustration: "scene.games.pottyOrder",
        sprites: [
            "icon.games.card.pantsDown",
            "icon.games.card.sit",
            "icon.games.card.wipe",
            "icon.games.card.wash",
        ],
        voiceLines: [
            HopVoiceLine(id: "games.pottyOrder.spoken.intro", text: "Let's put the cards in order. Which one comes first?"),
            // The same sentence the quizzes use for a pick that is not the one
            // being taught. One warm invitation, every time, however many tries.
            HopVoiceLine(id: "games.pottyOrder.spoken.retry", text: "Almost! Try another spot."),
            HopVoiceLine(id: "games.pottyOrder.spoken.placed", text: "That one fits!"),
            HopVoiceLine(id: "games.pottyOrder.spoken.done", text: "That's the order! Great job."),
        ]
    )

    public static let all: [MiniGame] = [
        bubbleWash, pottyPath, bathroomMatch,
        flySnack, mudOff, bodySignal, flushWave, pottyOrder,
    ]

    public static func game(_ id: MiniGameID) -> MiniGame {
        // Total: every case in the enum has an entry, and the test proves it.
        all.first { $0.id == id } ?? bubbleWash
    }

    /// The bounds every game is held to.
    public static let targetDurationRange: ClosedRange<TimeInterval> = 30...90

    public static var copyEntries: [HopCopyEntry] { all.flatMap(\.copyEntries) }

    public static var voiceLines: [HopVoiceLine] { all.flatMap(\.voiceLines) }

    public static var illustrations: [HopIllustrationKey] { all.flatMap(\.illustrations) }
}
