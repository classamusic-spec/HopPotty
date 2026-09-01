import Foundation
import Testing
@testable import HopPottyCore

/// The guided routine.
///
/// Two things can go wrong here and both are quiet. The routine can grow —
/// somebody adds a step, then another — until it no longer fits inside the pause
/// that promised the child their game back. And a spoken line can lose its
/// caption, which takes the routine away from every child who cannot hear it.
@Suite("Potty routine content")
struct RoutineContentTests {

    @Test("The routine is the five canonical steps, in order")
    func stepsAreCanonical() {
        #expect(PottyRoutineContent.steps.map(\.id) == [.tryIt, .wipe, .flush, .wash, .highFive])
    }

    @Test("Every step id resolves to a step")
    func stepLookupIsTotal() {
        for id in PottyRoutineStepID.allCases {
            #expect(PottyRoutineContent.step(id).id == id, "step(\(id.rawValue)) returned the wrong step")
        }
    }

    /// `Docs/CONTRACTS.md` §6: every spoken line has a written caption.
    @Test("Every routine step has a caption for its spoken line")
    func everyStepHasACaption() {
        for step in PottyRoutineContent.steps {
            let caption = step.voice.caption.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(!caption.isEmpty, "\(step.id.rawValue) has a spoken line with no caption")
            #expect(!step.voice.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(step.id.rawValue) has an empty spoken line")
        }
    }

    /// The caption is what a child sees when there is no audio, which is every
    /// child today. It has to say the same thing the recording would.
    @Test("Every step degrades to a caption that carries the whole instruction")
    func stepsDegradeToCaptions() {
        for step in PottyRoutineContent.steps {
            let playback = HopVoiceResolver.captionsOnly.playback(for: step.voice)
            #expect(playback.caption == step.voice.caption)
            #expect(!playback.isAudible, "\(step.id.rawValue) claims audio that does not exist yet")
            if case .captionOnly(_, let reason) = playback {
                #expect(reason == .assetNotYetRecorded)
            }
        }
    }

    /// The routine sits between a child and the game they were promised back.
    /// It has to finish well inside the pause, or the shield lifts mid-routine.
    @Test("A full run fits inside the default pause")
    func routineFitsInsideThePause() {
        let defaultPause = PottySchedule(childID: UUID()).pauseDuration
        let estimate: TimeInterval = PottyRoutineContent.estimatedDuration
        #expect(estimate <= defaultPause, "the routine estimates \(estimate)s inside a \(defaultPause)s pause")
        #expect(estimate <= PottySchedule.maximumPauseDuration)
        // And it is not so short that the estimate is obviously wrong.
        #expect(estimate > 60.0)
    }

    @Test("Only the hygiene steps are unskippable")
    func skippabilityIsDeliberate() {
        #expect(PottyRoutineContent.requiredSteps.map(\.id) == [.wash, .highFive])
        // The flush is skippable on purpose: the noise frightens plenty of
        // two-year-olds, and trapping a scared child at the flush is how a
        // family stops using the routine.
        #expect(PottyRoutineContent.flushStep.isSkippable)
        #expect(PottyRoutineContent.tryStep.isSkippable)
    }

    @Test("Timing matches the settings the app exposes")
    func timingMatchesSettings() {
        let sitDuration: TimeInterval? = PottyRoutineContent.tryStep.duration
        let settingsDefault: TimeInterval = AppSettings().routineSitTimerDuration
        #expect(sitDuration == settingsDefault, "the sit step and the sit-timer setting disagree")

        let washDuration: TimeInterval? = PottyRoutineContent.washStep.duration
        #expect(washDuration == TimeInterval(20), "the wash step should be the twenty-second scrub")

        // The steps with no duration advance on a tap and show no clock at all.
        #expect(PottyRoutineContent.wipeStep.duration == nil)
        #expect(PottyRoutineContent.flushStep.duration == nil)
        #expect(PottyRoutineContent.highFiveStep.duration == nil)
    }

    /// Stars come from actions a child chose to take. The routine's rewards must
    /// map onto that, never onto a result.
    @Test("Step rewards are for actions, not outcomes")
    func rewardsAreForActions() {
        #expect(PottyRoutineContent.tryStep.rewardReason == .triedThePotty)
        #expect(PottyRoutineContent.washStep.rewardReason == .washedHands)
        #expect(PottyRoutineContent.highFiveStep.rewardReason == .completedRoutine)
        for step in PottyRoutineContent.steps {
            if let reason = step.rewardReason {
                #expect(reason.defaultQuantity > 0, "\(step.id.rawValue) awards nothing")
            }
        }
    }

    @Test("Every step contributes keyed, unique copy under the routine surface")
    func stepCopyIsWellFormed() {
        let entries = PottyRoutineContent.copyEntries
        #expect(!entries.isEmpty)
        for entry in entries {
            #expect(entry.key.hasPrefix(HopCopySurface.routine.keyPrefix), "\(entry.key) is not on the routine surface")
            #expect(entry.audience == .child, "\(entry.key) is spoken to the child and should be child copy")
        }
        let keys = entries.map(\.key)
        #expect(Set(keys).count == keys.count, "duplicated routine keys")
    }

    @Test("Every step has its own illustration and a label for it")
    func illustrationsAreDistinctAndLabelled() {
        let keys = PottyRoutineContent.illustrations
        #expect(Set(keys).count == keys.count, "two steps share an illustration")
        for step in PottyRoutineContent.steps {
            #expect(step.illustration.isWellFormed, "\(step.id.rawValue) has a malformed illustration key")
            #expect(!step.illustrationLabel.value.isEmpty, "\(step.id.rawValue) illustration has no VoiceOver label")
        }
    }
}
