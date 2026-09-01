import Foundation

/// The steps of the guided routine, in order.
///
/// `tryIt` is spelled out because `try` is a keyword; the raw value stays `try`
/// so keys read `routine.step.try.title`.
public enum PottyRoutineStepID: String, CaseIterable, Sendable, Identifiable, Codable {
    case tryIt = "try"
    case wipe
    case flush
    case wash
    case highFive

    public var id: String { rawValue }
}

/// One step of the guided routine.
public struct PottyRoutineStep: Identifiable, Hashable, Sendable {
    public let id: PottyRoutineStepID
    /// One or two words, large, on its own line.
    public let title: HopCopyEntry
    /// The single thing to do, as a sentence.
    public let instruction: HopCopyEntry
    /// What Hop says, with its written caption.
    public let voice: HopVoiceLine
    public let illustration: HopIllustrationKey
    /// VoiceOver label for the illustration. Illustrations carry the meaning on
    /// these screens, so they are never decorative.
    public let illustrationLabel: HopCopyEntry
    /// Suggested time on this step, where one applies. `nil` means the step
    /// advances when the child taps, with no clock at all.
    public let duration: TimeInterval?
    /// Whether a "Skip this" control appears.
    ///
    /// This governs the control, not the exit: a child can leave the routine at
    /// any point from any step, and leaving never withholds screen access.
    public let isSkippable: Bool
    /// The star this step can earn, when it earns one.
    public let rewardReason: RewardReason?

    public init(
        id: PottyRoutineStepID,
        title: HopCopyEntry,
        instruction: HopCopyEntry,
        voice: HopVoiceLine,
        illustration: HopIllustrationKey,
        illustrationLabel: HopCopyEntry,
        duration: TimeInterval?,
        isSkippable: Bool,
        rewardReason: RewardReason? = nil
    ) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.voice = voice
        self.illustration = illustration
        self.illustrationLabel = illustrationLabel
        self.duration = duration
        self.isSkippable = isSkippable
        self.rewardReason = rewardReason
    }

    /// Every string this step puts on screen or in the air.
    public var copyEntries: [HopCopyEntry] {
        [title, instruction, illustrationLabel] + voice.copyEntries()
    }
}

/// The guided routine.
///
/// Five steps, and no more. Every step added is another thing standing between a
/// child and the game they were promised back, and a routine a family finds long
/// is a routine a family switches off. The steps that are not hygiene-critical
/// are skippable, and the whole run fits inside the default 180-second pause
/// (`PottySchedule.pauseDuration`) with room to spare.
public enum PottyRoutineContent {

    public static let tryStep = PottyRoutineStep(
        id: .tryIt,
        title: .child("routine.step.try.title", "Try", comment: "Step name. A verb: give it a try. Not a noun."),
        instruction: .child("routine.step.try.instruction", "Sit down and give it a try."),
        voice: HopVoiceLine(
            id: "routine.step.try.voice",
            text: "Let's give it a try. Take your time.",
            caption: "Let's give it a try. Take your time."
        ),
        illustration: "scene.routine.try",
        illustrationLabel: .child("routine.step.try.illustration", "Hop sitting on the potty"),
        // Matches AppSettings.routineSitTimerDuration. Only ever shown as a
        // circle filling up, and only when a caregiver switched it on.
        duration: 90,
        isSkippable: true,
        rewardReason: .triedThePotty
    )

    public static let wipeStep = PottyRoutineStep(
        id: .wipe,
        title: .child("routine.step.wipe.title", "Wipe"),
        instruction: .child("routine.step.wipe.instruction", "Wipe from front to back."),
        voice: HopVoiceLine(
            id: "routine.step.wipe.voice",
            text: "Wipe from front to back. A grown-up can help.",
            caption: "Wipe from front to back. A grown-up can help."
        ),
        illustration: "scene.routine.wipe",
        illustrationLabel: .child("routine.step.wipe.illustration", "Toilet paper, front to back"),
        duration: nil,
        // Skippable because plenty of visits produce nothing to wipe, and because
        // in many families a grown-up does this part.
        isSkippable: true
    )

    public static let flushStep = PottyRoutineStep(
        id: .flush,
        title: .child("routine.step.flush.title", "Flush"),
        instruction: .child("routine.step.flush.instruction", "Flush it away."),
        voice: HopVoiceLine(
            id: "routine.step.flush.voice",
            text: "Flush it away. Bye-bye!",
            caption: "Flush it away. Bye-bye!"
        ),
        illustration: "scene.routine.flush",
        illustrationLabel: .child("routine.step.flush.illustration", "A hand on the flush handle"),
        duration: nil,
        // Skippable on purpose: the noise frightens a real share of two- and
        // three-year-olds, and a routine that traps a scared child at the flush
        // is a routine they refuse tomorrow.
        isSkippable: true
    )

    public static let washStep = PottyRoutineStep(
        id: .wash,
        title: .child("routine.step.wash.title", "Wash"),
        instruction: .child("routine.step.wash.instruction", "Soap, scrub, rinse."),
        voice: HopVoiceLine(
            id: "routine.step.wash.voice",
            text: "Soap, scrub, rinse. Keep scrubbing while we sing!",
            caption: "Soap, scrub, rinse. Keep scrubbing while we sing!"
        ),
        illustration: "scene.routine.wash",
        illustrationLabel: .child("routine.step.wash.illustration", "Bubbly hands under the tap"),
        // The one timed hygiene step: twenty seconds of scrubbing, shown as
        // bubbles filling rather than as a countdown.
        duration: 20,
        isSkippable: false,
        rewardReason: .washedHands
    )

    public static let highFiveStep = PottyRoutineStep(
        id: .highFive,
        title: .child("routine.step.highFive.title", "High five"),
        instruction: .child("routine.step.highFive.instruction", "High five with Hop!"),
        voice: HopVoiceLine(
            id: "routine.step.highFive.voice",
            text: "Flush, wash, high five!",
            caption: "Flush, wash, high five!"
        ),
        illustration: "scene.routine.highFive",
        illustrationLabel: .child("routine.step.highFive.illustration", "Hop with his hand up for a high five"),
        duration: nil,
        isSkippable: false,
        rewardReason: .completedRoutine
    )

    /// The routine, in order.
    public static let steps: [PottyRoutineStep] = [tryStep, wipeStep, flushStep, washStep, highFiveStep]

    public static func step(_ id: PottyRoutineStepID) -> PottyRoutineStep {
        // Total function: every case in the enum has a step, and the test proves it.
        steps.first { $0.id == id } ?? tryStep
    }

    /// Time a step with no duration is assumed to take: long enough to read the
    /// instruction, hear Hop and tap. Used only to estimate the whole routine.
    public static let untimedStepAllowance: TimeInterval = 10

    /// Rough length of a full run with the sit timer on.
    ///
    /// The number that matters: it has to fit comfortably inside the default
    /// pause, or a child would be handed back their game mid-routine.
    public static var estimatedDuration: TimeInterval {
        steps.reduce(0) { total, step in total + (step.duration ?? untimedStepAllowance) }
    }

    /// The steps that cannot be skipped. Washing, and the high five that ends the
    /// run on a good note.
    public static var requiredSteps: [PottyRoutineStep] { steps.filter { !$0.isSkippable } }

    public static var voiceLines: [HopVoiceLine] { steps.map(\.voice) }

    public static var copyEntries: [HopCopyEntry] { steps.flatMap(\.copyEntries) }

    public static var illustrations: [HopIllustrationKey] { steps.map(\.illustration) }
}
