import Foundation
import Observation
import HopPottyCore

/// What a completed run of the routine produced.
///
/// The model reports; it does not award. Stars are written by the caller
/// through `RewardService`, which owns idempotency — a routine that finishes
/// twice because the app was relaunched mid-celebration must not pay twice, and
/// the only place that can be guaranteed is the ledger.
struct PottyRoutineResult: Equatable, Sendable {
    /// What the child said happened. `nil` only if they left before the try step
    /// resolved — which is allowed, and is not a failure.
    var outcome: PottyEventKind?
    /// Reward reasons earned by the steps actually completed, in order.
    var earnedReasons: [RewardReason]
    /// Steps the child chose to skip. Recorded so a caregiver can see the shape
    /// of a visit, never to withhold anything.
    var skippedSteps: [PottyRoutineStepID]

    /// Whether the visit produced pee or poop. Drives which celebration line
    /// Hop says — and nothing else. It does not change the stars.
    var producedOutput: Bool { outcome?.producedOutput == true }
}

/// The guided routine's flow.
///
/// Five steps and a celebration. The model holds the position, the outcome and
/// the elapsed sit time; every screen reads it and calls exactly one of the
/// handful of methods below. There is no state here a child can get stuck in:
/// `leave()` is legal from every step, and reaching the end is not a
/// precondition for anything.
@MainActor
@Observable
final class PottyRoutineModel {

    enum Stage: Equatable {
        case step(PottyRoutineStepID)
        case celebration
        case finished
    }

    private(set) var stage: Stage = .step(.tryIt)
    /// What the child tapped at the try step. Set once; the three answers are
    /// peers, so nothing here ranks them.
    private(set) var outcome: PottyEventKind?
    private(set) var earnedReasons: [RewardReason] = []
    private(set) var skippedSteps: [PottyRoutineStepID] = []
    /// Seconds spent on the current timed step, 0 when the step has no duration.
    private(set) var elapsedOnStep: TimeInterval = 0
    /// True on the step the child lands on immediately after answering, so that
    /// screen can have Hop physically celebrate the answer they just gave.
    ///
    /// A flag, deliberately not a state. The routine does **not** wait for it:
    /// `recordOutcome` advances exactly as it always did, so there is no new
    /// place a child can be held while an animation plays, and nothing to be
    /// stuck in if one never finishes (`Docs/ChildSafety.md` §8). It clears the
    /// moment they move on, whichever way they move.
    private(set) var isAcknowledgingOutcome = false

    private let settings: AppSettings
    private let steps: [PottyRoutineStep]

    init(settings: AppSettings = AppSettings(), steps: [PottyRoutineStep] = PottyRoutineContent.steps) {
        self.settings = settings
        // A routine with no steps is not representable in content, but a caller
        // could hand one in; starting at the celebration is the graceful answer.
        self.steps = steps
        self.stage = steps.first.map { .step($0.id) } ?? .celebration
    }

    // MARK: - Reading the current position

    var currentStep: PottyRoutineStep? {
        guard case .step(let id) = stage else { return nil }
        return steps.first { $0.id == id }
    }

    var stepCount: Int { steps.count }

    /// 1-based index of the current step, for the indicator and its VoiceOver
    /// label. Clamped rather than optional so the indicator can stay on screen
    /// through the celebration without flickering to zero.
    var currentStepNumber: Int {
        guard case .step(let id) = stage, let index = steps.firstIndex(where: { $0.id == id }) else {
            return steps.count
        }
        return index + 1
    }

    /// Whether the current step wants the calm filling ring.
    ///
    /// The try step's ring is a caregiver preference and off by default — a
    /// visible clock makes some children tense, and nothing about the routine
    /// needs one. The wash step's ring is not a preference: twenty seconds of
    /// scrubbing is the whole point of the step, and the ring is how a
    /// pre-reader knows how much is left.
    var showsTimerRing: Bool {
        guard let step = currentStep, step.duration != nil else { return false }
        return step.id == .tryIt ? settings.routineSitTimerEnabled : true
    }

    /// Length of the current step's ring. The try step follows the caregiver's
    /// chosen length; every other timed step follows its content.
    var timerDuration: TimeInterval? {
        guard let step = currentStep, let authored = step.duration else { return nil }
        return step.id == .tryIt ? settings.routineSitTimerDuration : authored
    }

    /// 0...1 fill. The ring *fills up*; it never drains. A shape that empties
    /// reads as time running out, which is the feeling this product exists to
    /// remove from a bathroom.
    var timerFraction: Double {
        guard let duration = timerDuration, duration > 0 else { return 0 }
        return min(1, max(0, elapsedOnStep / duration))
    }

    /// Whether the try step is waiting on the child's answer. True the whole
    /// time they are on it: the answer is available immediately and the ring,
    /// when shown, never gates it.
    var isAwaitingOutcome: Bool { currentStep?.id == .tryIt }

    // MARK: - Moving through it

    /// Records what the child said happened and moves on.
    ///
    /// All three answers take this same path with the same reward, because the
    /// star is for going and trying (`RewardService.reason(for:)` maps `tried`,
    /// `pee` and `poop` to one reason). A branch here that paid more for output
    /// would be the contract violation the whole product is built to avoid.
    /// All three answers take this same path with the same reward *and the same
    /// celebration*: `RoutineOutcomeChoices.acknowledgementHop(for:)` and
    /// `celebrationHop(for:)` build every one of them from one constant, and the
    /// kind chooses only which way Hop leans.
    func recordOutcome(_ kind: PottyEventKind) {
        guard isAwaitingOutcome, outcome == nil else { return }
        outcome = kind
        advance()
        // Set *after* the move, because `moveOn` clears it: the flag belongs to
        // the step the child has just arrived on, and is gone as soon as they
        // leave it.
        isAcknowledgingOutcome = true
    }

    /// Marks the current step done and moves to the next one.
    func advance() {
        guard case .step(let id) = stage, let index = steps.firstIndex(where: { $0.id == id }) else { return }
        if let reason = steps[index].rewardReason, !earnedReasons.contains(reason) {
            earnedReasons.append(reason)
        }
        moveOn(from: index)
    }

    /// Skips the current step. Only offered where the content allows it, and it
    /// still counts as being here: a skipped step is a choice, not a lapse.
    func skip() {
        guard case .step(let id) = stage,
              let index = steps.firstIndex(where: { $0.id == id }),
              steps[index].isSkippable
        else { return }
        skippedSteps.append(id)
        moveOn(from: index)
    }

    private func moveOn(from index: Int) {
        elapsedOnStep = 0
        isAcknowledgingOutcome = false
        let next = index + 1
        stage = next < steps.count ? .step(steps[next].id) : .celebration
    }

    /// Leaves the routine from wherever the child is.
    ///
    /// Legal from every step and from the celebration. Leaving early never
    /// withholds screen time and never removes what was already earned; the
    /// steps completed so far keep their stars.
    func leave() {
        stage = .finished
    }

    func finishCelebration() {
        stage = .finished
    }

    // MARK: - Time

    /// Advances the timed step's ring. Driven by the view's ticker so the model
    /// owns no timer of its own and is trivially previewable at any position.
    func tick(_ interval: TimeInterval) {
        guard timerDuration != nil else { return }
        elapsedOnStep += interval
    }

    // MARK: - Result

    var result: PottyRoutineResult {
        PottyRoutineResult(outcome: outcome, earnedReasons: earnedReasons, skippedSteps: skippedSteps)
    }
}
