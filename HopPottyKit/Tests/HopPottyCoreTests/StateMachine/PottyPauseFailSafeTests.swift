import Foundation
import Testing
import HopPottyCore

/// The invariants that make this component safe to put over a child's apps.
/// If one of these fails, the correct response is to stop shipping, not to
/// adjust the test.
@Suite("Potty Pause fail-safe invariants")
struct PottyPauseFailSafeTests {

    // MARK: - The emergency exit

    @Test(
        "parentRestoredAccess is accepted from every state and always ends shield-clear",
        arguments: PottyPauseState.exhaustiveCases
    )
    func parentRestoredAccessAlwaysClears(state: PottyPauseState) {
        for context in PauseFixture.allContexts {
            let outcome = PottyPauseMachine.reduce(
                state: state, event: .parentRestoredAccess, context: context
            )
            #expect(outcome.isAccepted, "\(state) refused the emergency exit")
            #expect(outcome.effects.first == .clearShield, "\(state) did not clear first")
            #expect(!outcome.state.mayHaveShieldUp, "\(state) → \(outcome.state) may still be shielded")
            #expect(!outcome.state.isShieldConfirmedUp)
            #expect(!outcome.raisesShield)
        }
    }

    @Test("A caregiver ending a pause logs an override, not a judgement on the child")
    func parentOverrideIsRecordedNeutrally() {
        for state in PottyPauseState.exhaustiveCases where state.isPauseInFlight {
            let outcome = PottyPauseMachine.reduce(
                state: state, event: .parentRestoredAccess, context: PauseFixture.context()
            )
            #expect(outcome.state == .cooldown)
            #expect(outcome.effects.contains(.logPauseOutcome(.parentOverride)))
            #expect(outcome.effects.contains(.notifyParent(.accessRestoredByParent)))
        }
    }

    @Test("Restoring access mid-approach skips the pause rather than queueing it")
    func parentOverrideDuringApproach() {
        for state in [PottyPauseState.monitoring, .warningApproaching] {
            let outcome = PottyPauseMachine.reduce(
                state: state, event: .parentRestoredAccess, context: PauseFixture.context()
            )
            #expect(outcome.state == .cooldown)
            #expect(outcome.effects.contains(.cancelWarningNotification))
        }
    }

    // MARK: - No shield can be stranded

    /// Every state reachable from `shieldActive` by any sequence of events.
    static func statesReachableFromShieldActive() -> Set<PottyPauseState> {
        let context = PauseFixture.context()
        var seen: Set<PottyPauseState> = [.shieldActive]
        var frontier: [PottyPauseState] = [.shieldActive]
        while let state = frontier.popLast() {
            for event in PottyPauseEvent.allCases {
                let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
                guard outcome.isAccepted, !seen.contains(outcome.state) else { continue }
                seen.insert(outcome.state)
                frontier.append(outcome.state)
            }
        }
        return seen
    }

    @Test("No state reachable from a live shield is a trap")
    func everyShieldedStateHasAnExit() {
        let context = PauseFixture.context()
        for state in Self.statesReachableFromShieldActive() where state.mayHaveShieldUp {
            let exits = PottyPauseEvent.allCases.filter { event in
                let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
                return outcome.isAccepted && !outcome.state.mayHaveShieldUp && outcome.clearsShield
            }
            #expect(!exits.isEmpty, "\(state) has no event that ends with the shield down")
        }
    }

    @Test("Every step out of the shielded region clears the shield on the way")
    func noBoundaryIsCrossedWithoutClearing() {
        for context in PauseFixture.allContexts {
            for state in Self.statesReachableFromShieldActive() {
                for event in PottyPauseEvent.allCases {
                    let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
                    guard outcome.isAccepted, state.mayHaveShieldUp, !outcome.state.mayHaveShieldUp else { continue }
                    #expect(
                        outcome.clearsShield,
                        "\(state) + \(event) → \(outcome.state) left the shielded region without clearing"
                    )
                }
            }
        }
    }

    @Test("A shielded pause ends on the timer alone, with no help from anyone")
    func timerAloneEndsThePause() {
        // The child does nothing, the caregiver does nothing, and the only
        // inputs are the ones the system produces by itself.
        var driver = PauseDriver(state: .shieldActive, context: PauseFixture.context(
            activeSession: PauseFixture.session(state: .shieldActive)
        ))
        var steps = 0
        while driver.state.mayHaveShieldUp && steps < 10 {
            driver.advance(60)
            driver.send(.pauseTimerExpired)
            driver.send(.shieldCleared)
            steps += 1
        }
        #expect(driver.state == .cooldown)
        #expect(steps <= 2)
        #expect(driver.didClearShield)
    }

    @Test("Every way a pause can end restores access")
    func everyPauseEndingRestoresAccess() {
        let endings: [PottyPauseEvent] = [.routineCompleted, .pauseTimerExpired, .parentRestoredAccess]
        for ending in endings {
            var driver = PauseDriver(state: .shieldActive, context: PauseFixture.context(
                activeSession: PauseFixture.session(state: .shieldActive)
            ))
            let outcome = driver.send(ending)
            #expect(outcome.isAccepted, "\(ending) did not end the pause")
            #expect(outcome.effects.first == .clearShield)
            #expect(!driver.state.isShieldConfirmedUp)
        }
    }

    @Test("Nothing but those three endings, plus losing permission, closes a pause")
    func onlySanctionedEventsEndAPause() {
        // CONTRACTS.md §4.1. A pause ends on its timer, on completion, or on
        // caregiver override. `scheduleDisabled` is a caregiver override by
        // another name; `authorizationRevoked` is the system taking the ability
        // away from us. Nothing else may log an ending.
        let sanctioned: Set<PottyPauseEvent> = [
            .routineCompleted, .pauseTimerExpired, .parentRestoredAccess,
            .scheduleDisabled, .authorizationRevoked,
        ]
        for context in PauseFixture.allContexts {
            for state in PottyPauseState.exhaustiveCases where state.isPauseInFlight {
                for event in PottyPauseEvent.allCases {
                    let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
                    let logsAnEnding = outcome.effects.contains { effect in
                        if case .logPauseOutcome(let reason) = effect {
                            return reason != .couldNotStart
                        }
                        return false
                    }
                    guard logsAnEnding else { continue }
                    #expect(sanctioned.contains(event), "\(state) + \(event) ended a pause")
                    #expect(outcome.clearsShield, "\(state) + \(event) ended a pause without clearing")
                }
            }
        }
    }

    // MARK: - Nothing depends on a biological outcome

    @Test("No event or outcome in the vocabulary describes what the child produced")
    func vocabularyCarriesNoBiologicalOutcome() {
        // The strongest form of CONTRACTS.md §4.1 is that the machine has no way
        // to *say* what happened in the bathroom, so no branch can read it.
        // Only outcome words: `…Failed` cases describe a Screen Time API call,
        // not a child.
        let forbidden = ["pee", "poop", "wet", "dry", "accident", "urine", "stool", "bladder", "bowel"]
        for event in PottyPauseEvent.allCases {
            for word in forbidden {
                #expect(!event.rawValue.lowercased().contains(word), "\(event) mentions \(word)")
            }
        }
        for outcome in PauseOutcome.allCases {
            for word in forbidden {
                #expect(!outcome.rawValue.lowercased().contains(word), "\(outcome) mentions \(word)")
            }
        }
    }

    @Test("The routine can be completed without the child having produced anything")
    func completionNeedsNoOutcome() {
        // `routineCompleted` carries no payload, so "the child went and tried"
        // and "the child went and produced something" are the same event, and
        // the shield comes down identically for both.
        var driver = PauseDriver(state: .routineActive, context: PauseFixture.context(
            activeSession: PauseFixture.session(state: .routineActive)
        ))
        let completed = driver.send(.routineCompleted)
        #expect(completed.effects.first == .clearShield)
        #expect(driver.awards == [.completedRoutine])
    }

    // MARK: - Idempotence

    @Test("Clearing repeatedly is safe and stays accepted")
    func clearingIsIdempotent() {
        var driver = PauseDriver(state: .restoring, context: PauseFixture.context(
            activeSession: PauseFixture.session(state: .restoring)
        ))
        for _ in 0..<5 {
            let outcome = driver.send(.retryRequested)
            #expect(outcome.isAccepted)
            #expect(outcome.effects == [.clearShield])
            #expect(driver.state == .restoring)
        }
        driver.send(.shieldCleared)
        #expect(driver.state == .cooldown)
        // A stray confirmation after the fact changes nothing.
        let stray = driver.send(.shieldCleared)
        #expect(stray.isAccepted)
        #expect(driver.state == .cooldown)
    }

    @Test("A shield is only ever raised from one place, behind three gates")
    func shieldIsRaisedFromOnePlaceOnly() {
        var raisingPairs: [(PottyPauseState, PottyPauseEvent)] = []
        for context in PauseFixture.allContexts {
            for state in PottyPauseState.exhaustiveCases {
                for event in PottyPauseEvent.allCases {
                    let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
                    if outcome.raisesShield { raisingPairs.append((state, event)) }
                }
            }
        }
        let states = Set(raisingPairs.map(\.0))
        let events = Set(raisingPairs.map(\.1))
        #expect(states == [.monitoring, .warningApproaching])
        #expect(events == [.pauseThresholdReached])
    }

    @Test("Losing authorization mid-pause always reaches a cleared, caregiver-visible state")
    func authorizationLossIsAlwaysSurfaced() {
        for context in PauseFixture.allContexts {
            for state in PottyPauseState.exhaustiveCases where state.mayHaveShieldUp {
                let outcome = PottyPauseMachine.reduce(
                    state: state, event: .authorizationRevoked, context: context
                )
                #expect(outcome.state == .errorRequiresParent(.authorizationRevoked))
                #expect(outcome.effects.first == .clearShield)
                #expect(outcome.effects.contains(.notifyParent(.screenTimeFailure(.authorizationRevoked))))
            }
        }
    }

    @Test("A persisted session exists only while a pause could be in flight")
    func persistenceTracksTheShield() {
        for context in PauseFixture.allContexts {
            for state in PottyPauseState.exhaustiveCases {
                for event in PottyPauseEvent.allCases {
                    let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
                    for effect in outcome.effects {
                        guard case .persistSession(let session) = effect else { continue }
                        // Anything written to disk must be something recovery can
                        // recognise, or the next launch will call it corrupt.
                        #expect(session.state.isPersistable, "\(state) + \(event) persisted \(session.state)")
                        #expect(session.isWellFormed)
                        #expect(session.state == outcome.state)
                        #expect(session.belongs(to: context.childID))
                    }
                }
            }
        }
    }

    @Test("A persisted expiry never exceeds the product ceiling, whatever the schedule says")
    func persistedExpiryIsClamped() {
        var context = PauseFixture.context()
        // A corrupted or migrated schedule asking for an hour-long shield.
        context.schedule.pauseDuration = 3600
        let outcome = PottyPauseMachine.reduce(
            state: .monitoring, event: .pauseThresholdReached, context: context
        )
        let persisted = outcome.effects.compactMap { effect -> PersistedPauseSession? in
            if case .persistSession(let session) = effect { session } else { nil }
        }.first
        #expect(persisted?.plannedDuration == PottySchedule.maximumPauseDuration)
        #expect(persisted?.isWellFormed == true)
    }
}
