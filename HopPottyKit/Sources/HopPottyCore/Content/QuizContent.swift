import Foundation

// MARK: - Identifiers

public struct QuizQuestionID: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: StringLiteralType) { self.rawValue = value }
    public var description: String { rawValue }
}

/// Unique within its question, not globally: `wipe` means the wiping picture in
/// whichever question offers it.
public struct QuizOptionID: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: StringLiteralType) { self.rawValue = value }
    public var description: String { rawValue }
}

/// What a question is teaching. Used to build a themed round and to check, in a
/// test, that no part of the curriculum has quietly lost its questions.
public enum QuizTopic: String, CaseIterable, Sendable, Identifiable {
    case afterPotty
    case bodySignals
    case tellingAGrownUp
    case whatBelongsInTheToilet
    case handWashing
    case wiping
    case flushing

    public var id: String { rawValue }
}

// MARK: - Option

/// One answer a child can tap.
///
/// The answer itself is a picture. A three-year-old cannot read "front to back",
/// so the illustration carries the whole meaning and the label exists for
/// VoiceOver and for the caregiver sitting alongside.
public struct QuizOption: Identifiable, Hashable, Sendable {
    public let id: QuizOptionID
    public let illustration: HopIllustrationKey
    /// Spoken by VoiceOver. Written as a thing, not as a sentence, because it is
    /// read out immediately after the question.
    public let label: HopCopyEntry

    public init(id: QuizOptionID, illustration: HopIllustrationKey, label: HopCopyEntry) {
        self.id = id
        self.illustration = illustration
        self.label = label
    }
}

// MARK: - Outcome

/// What happens when a child taps an answer.
///
/// Two cases, and neither of them ends anything. There is no `.wrong`, no
/// `.gameOver` and nowhere to put a score, because the type is the design: a
/// child who taps the picture that is not the one being taught hears the same
/// warm invitation every time and the question stays open underneath. Nothing is
/// counted, so nothing can be lost.
public enum QuizAnswerOutcome: Hashable, Sendable {
    /// The child found the answer the question teaches. Celebrate, then move on
    /// whenever the child wants to.
    case affirm(HopVoiceLine)
    /// Any other pick. Hop invites another try; the options stay tappable.
    case redirect(HopVoiceLine)

    public var voice: HopVoiceLine {
        switch self {
        case .affirm(let line), .redirect(let line): line
        }
    }

    /// Whether this outcome advances the round. Redirects never do — the child
    /// decides when to move on.
    public var completesQuestion: Bool {
        if case .affirm = self { return true }
        return false
    }
}

// MARK: - Question

/// One audio-first question.
public struct QuizQuestion: Identifiable, Hashable, Sendable {
    public let id: QuizQuestionID
    public let topic: QuizTopic
    /// Hop asks this aloud. Its caption is the written form of the question.
    public let prompt: HopVoiceLine
    /// Three or more pictures.
    public let options: [QuizOption]
    /// Exactly one. Stored as an id rather than a flag on each option so a
    /// question with two correct answers is unrepresentable.
    public let correctOptionID: QuizOptionID

    public init(
        id: QuizQuestionID,
        topic: QuizTopic,
        prompt: HopVoiceLine,
        options: [QuizOption],
        correctOptionID: QuizOptionID
    ) {
        self.id = id
        self.topic = topic
        self.prompt = prompt
        self.options = options
        self.correctOptionID = correctOptionID
    }

    /// The written form of the question, for readers and for the caregiver.
    public var writtenPrompt: String { prompt.caption }

    public var correctOption: QuizOption? {
        options.first { $0.id == correctOptionID }
    }

    public func outcome(for optionID: QuizOptionID) -> QuizAnswerOutcome {
        optionID == correctOptionID
            ? .affirm(HopVoice.shared.quizAffirm)
            : .redirect(HopVoice.shared.quizRedirect)
    }

    /// Options in a stable but seed-dependent order.
    ///
    /// The answer must not live in the same place every time, or a child learns
    /// the position instead of the idea. A seeded shuffle rather than
    /// `shuffled()` so a preview, a screenshot and a failing test all show the
    /// same board.
    public func options(shuffledBy seed: UInt64) -> [QuizOption] {
        var state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        var result = options
        var index = result.count - 1
        while index > 0 {
            // xorshift64: small, deterministic, and identical on every platform.
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            let target = Int(state % UInt64(index + 1))
            result.swapAt(index, target)
            index -= 1
        }
        return result
    }

    public var copyEntries: [HopCopyEntry] {
        prompt.copyEntries() + options.map(\.label)
    }
}

// MARK: - Catalog

/// Hop's questions.
///
/// Audio-first: a pre-reader hears the question and answers with a picture. The
/// format is extensible by adding a `QuizQuestion` — nothing about the runtime
/// knows how many there are or in what order they come.
public enum QuizContent {

    /// Builds a question and derives every key from its id, so a new question
    /// cannot land in the catalog with a hand-typed key that collides with an
    /// old one.
    private struct Draft {
        let slug: String
        let illustration: HopIllustrationKey
        let label: String
    }

    private static func make(
        _ id: QuizQuestionID,
        _ topic: QuizTopic,
        ask: String,
        written: String? = nil,
        options drafts: [Draft],
        correct: String
    ) -> QuizQuestion {
        let base = "quizzes.q.\(id.rawValue)"
        let options = drafts.map { draft in
            QuizOption(
                id: QuizOptionID(rawValue: draft.slug),
                illustration: draft.illustration,
                label: .child(
                    "\(base).option.\(draft.slug)",
                    draft.label,
                    comment: "VoiceOver label for one picture answer. Name the thing in the picture; the picture is the answer."
                )
            )
        }
        return QuizQuestion(
            id: id,
            topic: topic,
            prompt: HopVoiceLine(id: HopVoiceLineID(rawValue: "\(base).prompt"), text: ask, caption: written ?? ask),
            options: options,
            correctOptionID: QuizOptionID(rawValue: correct)
        )
    }

    // MARK: After using the potty

    public static let afterPottyFirst = make(
        "afterPottyFirst", .afterPotty,
        ask: "You went potty. What comes first?",
        options: [
            Draft(slug: "shoes", illustration: "icon.quiz.shoes", label: "A pair of shoes"),
            Draft(slug: "wipe", illustration: "icon.quiz.wipe", label: "Wiping with toilet paper"),
            Draft(slug: "toothbrush", illustration: "icon.quiz.toothbrush", label: "A toothbrush"),
        ],
        correct: "wipe"
    )

    public static let afterPottyFlush = make(
        "afterPottyFlush", .afterPotty,
        ask: "You finished wiping. What comes next?",
        options: [
            Draft(slug: "flush", illustration: "icon.quiz.flush", label: "Flushing the toilet"),
            Draft(slug: "snack", illustration: "icon.quiz.apple", label: "A bowl of apple slices"),
            Draft(slug: "hat", illustration: "icon.quiz.hat", label: "A sun hat"),
        ],
        correct: "flush"
    )

    public static let afterPottyWash = make(
        "afterPottyWash", .afterPotty,
        ask: "The potty is flushed. What comes next?",
        options: [
            Draft(slug: "outside", illustration: "icon.quiz.outside", label: "Running outside to play"),
            Draft(slug: "truck", illustration: "icon.quiz.toyTruck", label: "A toy truck"),
            Draft(slug: "wash", illustration: "icon.quiz.washHands", label: "Washing hands"),
        ],
        correct: "wash"
    )

    // MARK: Hand washing

    public static let washSoap = make(
        "washSoap", .handWashing,
        ask: "Your hands are wet. What comes next?",
        options: [
            Draft(slug: "soap", illustration: "icon.quiz.soap", label: "A pump of soap"),
            Draft(slug: "towel", illustration: "icon.quiz.towel", label: "A hand towel"),
            Draft(slug: "toothbrush", illustration: "icon.quiz.toothbrush", label: "A toothbrush"),
        ],
        correct: "soap"
    )

    public static let washDry = make(
        "washDry", .handWashing,
        ask: "Your hands are all rinsed. What comes next?",
        options: [
            Draft(slug: "paper", illustration: "icon.quiz.toiletPaper", label: "A roll of toilet paper"),
            Draft(slug: "towel", illustration: "icon.quiz.towel", label: "Drying with a towel"),
            Draft(slug: "soap", illustration: "icon.quiz.soap", label: "A pump of soap"),
        ],
        correct: "towel"
    )

    public static let washHowLong = make(
        "washHowLong", .handWashing,
        ask: "How long do we scrub our hands?",
        options: [
            Draft(slug: "splash", illustration: "icon.quiz.quickSplash", label: "A quick splash"),
            Draft(slug: "song", illustration: "icon.quiz.singing", label: "Scrubbing while Hop sings a song"),
            Draft(slug: "oneFinger", illustration: "icon.quiz.oneFinger", label: "One finger under the tap"),
        ],
        correct: "song"
    )

    // MARK: Body signals

    public static let signalSqueeze = make(
        "signalSqueeze", .bodySignals,
        ask: "Hop feels a squeeze in his tummy. Where does he go?",
        written: "Hop feels a squeeze. Where does he go?",
        options: [
            Draft(slug: "potty", illustration: "icon.quiz.potty", label: "The potty"),
            Draft(slug: "bed", illustration: "icon.quiz.bed", label: "A cosy bed"),
            Draft(slug: "kitchen", illustration: "icon.quiz.kitchen", label: "The kitchen table"),
        ],
        correct: "potty"
    )

    public static let signalWiggle = make(
        "signalWiggle", .bodySignals,
        ask: "Your body does a little wiggle dance. What is it asking for?",
        written: "Your body does a wiggle dance. What is it asking for?",
        options: [
            Draft(slug: "apple", illustration: "icon.quiz.apple", label: "An apple"),
            Draft(slug: "nap", illustration: "icon.quiz.bed", label: "A nap"),
            Draft(slug: "potty", illustration: "icon.quiz.potty", label: "The potty"),
        ],
        correct: "potty"
    )

    public static let signalDuringPlay = make(
        "signalDuringPlay", .bodySignals,
        ask: "You feel it while you are playing. What do you do?",
        options: [
            Draft(slug: "goPotty", illustration: "icon.quiz.potty", label: "Going to the potty"),
            Draft(slug: "keepPlaying", illustration: "icon.quiz.keepPlaying", label: "Playing with blocks"),
            Draft(slug: "shoes", illustration: "icon.quiz.shoes", label: "A pair of shoes"),
        ],
        correct: "goPotty"
    )

    // MARK: Telling a grown-up

    public static let tellWho = make(
        "tellWho", .tellingAGrownUp,
        ask: "You feel like you have to go. Who do you tell?",
        options: [
            Draft(slug: "teddy", illustration: "icon.quiz.teddy", label: "A teddy bear"),
            Draft(slug: "grownUp", illustration: "icon.quiz.grownUp", label: "A grown-up"),
            Draft(slug: "television", illustration: "icon.quiz.television", label: "A television"),
        ],
        correct: "grownUp"
    )

    public static let tellAtThePark = make(
        "tellAtThePark", .tellingAGrownUp,
        ask: "You are at the park and you feel it. What do you do?",
        options: [
            Draft(slug: "slide", illustration: "icon.quiz.slide", label: "Going down the slide"),
            Draft(slug: "snack", illustration: "icon.quiz.apple", label: "Eating a snack"),
            Draft(slug: "grownUp", illustration: "icon.quiz.grownUp", label: "Telling a grown-up"),
        ],
        correct: "grownUp"
    )

    public static let tellNeedHelp = make(
        "tellNeedHelp", .tellingAGrownUp,
        ask: "You need help in the bathroom. What do you do?",
        options: [
            Draft(slug: "callGrownUp", illustration: "icon.quiz.grownUp", label: "Calling for a grown-up"),
            Draft(slug: "soapPlay", illustration: "icon.quiz.soap", label: "Playing with the soap"),
            Draft(slug: "mirror", illustration: "icon.quiz.mirror", label: "Looking in the mirror"),
        ],
        correct: "callGrownUp"
    )

    // MARK: What belongs in the toilet

    public static let toiletPaper = make(
        "toiletPaper", .whatBelongsInTheToilet,
        ask: "Which one belongs in the toilet?",
        options: [
            Draft(slug: "truck", illustration: "icon.quiz.toyTruck", label: "A toy truck"),
            Draft(slug: "sock", illustration: "icon.quiz.sock", label: "A stripy sock"),
            Draft(slug: "paper", illustration: "icon.quiz.toiletPaper", label: "Toilet paper"),
        ],
        correct: "paper"
    )

    public static let toysBelong = make(
        "toysBelong", .whatBelongsInTheToilet,
        ask: "Where do toys belong?",
        options: [
            Draft(slug: "toyBox", illustration: "icon.quiz.toyBox", label: "The toy box"),
            Draft(slug: "toilet", illustration: "icon.quiz.toilet", label: "The toilet"),
            Draft(slug: "sink", illustration: "icon.quiz.sink", label: "The sink"),
        ],
        correct: "toyBox"
    )

    // MARK: Flushing

    public static let flushWhenFinished = make(
        "flushWhenFinished", .flushing,
        ask: "You are all finished. What do you press?",
        options: [
            Draft(slug: "lightSwitch", illustration: "icon.quiz.lightSwitch", label: "A light switch"),
            Draft(slug: "handle", illustration: "icon.quiz.flush", label: "The flush handle"),
            Draft(slug: "doorbell", illustration: "icon.quiz.doorbell", label: "A doorbell"),
        ],
        correct: "handle"
    )

    // MARK: Wiping

    public static let wipeDirection = make(
        "wipeDirection", .wiping,
        ask: "Which way do we wipe?",
        options: [
            Draft(slug: "frontToBack", illustration: "icon.quiz.frontToBack", label: "Front to back"),
            Draft(slug: "backToFront", illustration: "icon.quiz.backToFront", label: "Back to front"),
            Draft(slug: "sideToSide", illustration: "icon.quiz.sideToSide", label: "Side to side"),
        ],
        correct: "frontToBack"
    )

    public static let wipeHowMuch = make(
        "wipeHowMuch", .wiping,
        ask: "How much toilet paper do we need?",
        options: [
            Draft(slug: "pile", illustration: "icon.quiz.paperPile", label: "A giant pile of paper"),
            Draft(slug: "fewSquares", illustration: "icon.quiz.paperFewSquares", label: "A few squares"),
            Draft(slug: "tinyCorner", illustration: "icon.quiz.paperCorner", label: "One tiny corner"),
        ],
        correct: "fewSquares"
    )

    /// Every question, in a stable order.
    public static let allQuestions: [QuizQuestion] = [
        afterPottyFirst, afterPottyFlush, afterPottyWash,
        washSoap, washDry, washHowLong,
        signalSqueeze, signalWiggle, signalDuringPlay,
        tellWho, tellAtThePark, tellNeedHelp,
        toiletPaper, toysBelong,
        flushWhenFinished,
        wipeDirection, wipeHowMuch,
    ]

    public static func questions(topic: QuizTopic) -> [QuizQuestion] {
        allQuestions.filter { $0.topic == topic }
    }

    public static func question(_ id: QuizQuestionID) -> QuizQuestion? {
        allQuestions.first { $0.id == id }
    }

    /// A short round. Short on purpose: this sits between a child and their
    /// game, and three questions is about as long as a three-year-old's
    /// willingness to be asked things.
    public static let questionsPerRound = 3

    public static var voiceLines: [HopVoiceLine] { allQuestions.map(\.prompt) }

    public static var copyEntries: [HopCopyEntry] { allQuestions.flatMap(\.copyEntries) }

    public static var illustrations: [HopIllustrationKey] {
        allQuestions.flatMap { $0.options.map(\.illustration) }
    }
}
