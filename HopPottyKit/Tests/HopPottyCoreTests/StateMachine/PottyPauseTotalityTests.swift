import Foundation
import Testing
import HopPottyCore

/// The reducer is only trustworthy if it is *total*: every one of the
/// 13 states × 21 events (27 × 21 = 567 distinct pairs once the two error cases
/// are expanded over every `ScreenTimeFailure`) has a defined answer, in every
/// configuration. These tests are the proof, and they are what stops a future
/// event from being added with a hole behind it.
@Suite("Potty Pause reducer totality")
struct PottyPauseTotalityTests {

    @Test("The state list covers every case of the enum")
    func exhaustiveCasesIsExhaustive() {
        let kinds = Set(PottyPauseState.exhaustiveCases.map(\.kind))
        #expect(kinds == Set(PottyPauseState.Kind.allCases))
        #expect(PottyPauseState.exhaustiveCases.count == 11 + 2 * ScreenTimeFailure.allCases.count)
        #expect(Set(PottyPauseState.exhaustiveCases).count == PottyPauseState.exhaustiveCases.count)
    }

    @Test(
        "Every (state, event) pair has a defined outcome in every configuration",
        arguments: PottyPauseState.exhaustiveCases, PottyPauseEvent.allCases
    )
    func everyPairIsDefined(state: PottyPauseState, event: PottyPauseEvent) {
        for context in PauseFixture.allContexts {
            let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)

            if let rejection = outcome.rejection {
                // A rejection is a *defined* answer: it names the pair that did
                // not fit and changes nothing.
                #expect(outcome.state == state)
                #expect(outcome.effects.isEmpty)
                #expect(rejection.state == state)
                #expect(rejection.event == event)
            } else {
                // An accepted outcome must land on a state the machine knows.
                #expect(PottyPauseState.exhaustiveCases.contains(outcome.state))
            }
        }
    }

    @Test(
        "Leaving a possibly-shielded state for an unshielded one always clears first",
        arguments: PottyPauseState.exhaustiveCases, PottyPauseEvent.allCases
    )
    func leavingTheShieldAlwaysClears(state: PottyPauseState, event: PottyPauseEvent) {
        for context in PauseFixture.allContexts {
            let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
            guard outcome.isAccepted, state.mayHaveShieldUp, !outcome.state.mayHaveShieldUp else { continue }
            #expect(
                outcome.effects.first == .clearShield,
                "\(state) + \(event) → \(outcome.state) must clear the shield first"
            )
        }
    }

    @Test(
        "Any outcome that clears puts the clear first, and never clears and applies at once",
        arguments: PottyPauseState.exhaustiveCases, PottyPauseEvent.allCases
    )
    func clearIsAlwaysFirst(state: PottyPauseState, event: PottyPauseEvent) {
        for context in PauseFixture.allContexts {
            let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
            if outcome.clearsShield {
                // The executor performs effects in order, so a crash part-way
                // through a bundle still leaves the child's apps usable.
                #expect(outcome.effects.first == .clearShield, "\(state) + \(event)")
                #expect(!outcome.raisesShield, "\(state) + \(event) both raises and clears")
            }
        }
    }

    @Test(
        "Entering an error state always clears",
        arguments: PottyPauseState.exhaustiveCases, PottyPauseEvent.allCases
    )
    func errorStatesAlwaysClear(state: PottyPauseState, event: PottyPauseEvent) {
        for context in PauseFixture.allContexts {
            let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
            guard outcome.isAccepted, outcome.state.isError else { continue }
            // An error state is one where HopPotty does not know what is true,
            // and not knowing resolves in the child's favour.
            #expect(outcome.clearsShield, "\(state) + \(event) → \(outcome.state) must clear")
        }
    }

    @Test(
        "A shield is only ever raised when it is permitted and configured",
        arguments: PottyPauseState.exhaustiveCases, PottyPauseEvent.allCases
    )
    func shieldOnlyRaisedWhenPermitted(state: PottyPauseState, event: PottyPauseEvent) {
        for context in PauseFixture.allContexts {
            let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
            guard outcome.raisesShield else { continue }
            #expect(outcome.isAccepted)
            #expect(context.isAuthorized, "\(state) + \(event) raised a shield without authorization")
            #expect(context.shieldsApps, "\(state) + \(event) raised a shield in \(context.schedule.mode)")
            #expect(context.hasSelection)
            #expect(outcome.state == .pauseTriggered)
            #expect(outcome.effects.contains(where: { if case .startPauseTimer = $0 { true } else { false } }))
        }
    }

    @Test(
        "Nothing is ever taken away and no reward depends on an outcome",
        arguments: PottyPauseState.exhaustiveCases, PottyPauseEvent.allCases
    )
    func rewardsAreOnlyForActions(state: PottyPauseState, event: PottyPauseEvent) {
        // CONTRACTS.md §4.1 and §4.2: only *actions the child chose to take* are
        // rewarded, and there is no effect that removes anything.
        let permitted: Set<RewardReason> = [.answeredPottyPause, .completedRoutine]
        for context in PauseFixture.allContexts {
            let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
            for effect in outcome.effects {
                if case .awardParticipation(let reason) = effect {
                    #expect(permitted.contains(reason), "\(state) + \(event) awarded \(reason)")
                }
            }
        }
    }

    @Test("Illegal transitions are refused and change nothing")
    func illegalTransitionsAreRefused() {
        let illegal: [(PottyPauseState, PottyPauseEvent)] = [
            (.disabled, .pauseThresholdReached),
            (.disabled, .shieldApplied),
            (.disabled, .childAcknowledged),
            (.authorizationRequired, .pauseThresholdReached),
            (.ready, .pauseThresholdReached),
            (.ready, .warningThresholdReached),
            (.ready, .childAcknowledged),
            (.monitoring, .shieldApplied),
            (.monitoring, .routineCompleted),
            (.monitoring, .cooldownElapsed),
            (.warningApproaching, .shieldApplied),
            (.pauseTriggered, .pauseThresholdReached),
            (.pauseTriggered, .childAcknowledged),
            (.pauseTriggered, .cooldownElapsed),
            (.shieldActive, .pauseThresholdReached),
            (.shieldActive, .warningThresholdReached),
            (.shieldActive, .cooldownElapsed),
            (.shieldActive, .retryRequested),
            (.routineActive, .pauseThresholdReached),
            (.completing, .pauseThresholdReached),
            (.restoring, .pauseThresholdReached),
            (.cooldown, .shieldApplied),
            (.cooldown, .routineCompleted),
            (.errorRequiresParent(.noSelection), .retryRequested),
        ]
        for (state, event) in illegal {
            let outcome = PottyPauseMachine.reduce(state: state, event: event, context: PauseFixture.context())
            #expect(outcome.isRejected, "\(state) + \(event) should be refused")
            #expect(outcome.state == state, "\(state) + \(event) changed state while refusing")
            #expect(outcome.effects.isEmpty, "\(state) + \(event) performed work while refusing")
        }
    }

    @Test("Refusing a pause during cooldown and refusing a pointless retry are told apart")
    func rejectionReasonsAreSpecific() {
        let cooldown = PottyPauseMachine.reduce(
            state: .cooldown, event: .pauseThresholdReached, context: PauseFixture.context()
        )
        #expect(cooldown.rejection?.reason == .cooldownNotElapsed)

        let retry = PottyPauseMachine.reduce(
            state: .errorRequiresParent(.noSelection), event: .retryRequested, context: PauseFixture.context()
        )
        #expect(retry.rejection?.reason == .requiresParentAction)

        let nonsense = PottyPauseMachine.reduce(
            state: .ready, event: .childAcknowledged, context: PauseFixture.context()
        )
        #expect(nonsense.rejection?.reason == .eventNotValidInState)
    }

    @Test("Refusals never happen for the three fail-safe events", arguments: PottyPauseState.exhaustiveCases)
    func failSafeEventsAreNeverRefused(state: PottyPauseState) {
        for event in [PottyPauseEvent.parentRestoredAccess, .scheduleDisabled, .authorizationRevoked] {
            for context in PauseFixture.allContexts {
                let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
                #expect(outcome.isAccepted, "\(state) refused \(event)")
                #expect(outcome.clearsShield, "\(state) + \(event) did not clear")
            }
        }
    }
}
