import Foundation
import Testing
import HopPottyCore

@Suite("Potty Pause lifecycle")
struct PottyPauseLifecycleTests {

    @Test("A full pause runs ready → monitoring → warning → triggered → shielded → routine → completing → restoring → cooldown → monitoring")
    func fullLifecycle() {
        var driver = PauseDriver(state: .ready)

        let armed = driver.send(.monitoringRegistered)
        #expect(driver.state == .monitoring)
        #expect(armed.effects.contains(.scheduleWarningNotification(leadTime: 120)))

        driver.send(.warningThresholdReached)
        #expect(driver.state == .warningApproaching)

        let triggered = driver.send(.pauseThresholdReached)
        #expect(driver.state == .pauseTriggered)
        #expect(triggered.effects.contains(.applyShield))
        #expect(triggered.effects.contains(.cancelWarningNotification))
        // The ceiling timer is armed before the shield goes up, so no shield can
        // exist without something already scheduled to take it down.
        let timerIndex = triggered.effects.firstIndex(of: .startPauseTimer(expiresAt: PauseFixture.now.addingTimeInterval(180)))
        let shieldIndex = triggered.effects.firstIndex(of: .applyShield)
        #expect(timerIndex != nil)
        #expect(shieldIndex != nil)
        #expect(timerIndex! < shieldIndex!)
        #expect(driver.context.activeSession?.expiresAt == PauseFixture.now.addingTimeInterval(180))

        driver.send(.shieldApplied)
        #expect(driver.state == .shieldActive)
        #expect(driver.state.isShieldConfirmedUp)

        let answered = driver.send(.childAcknowledged)
        #expect(driver.state == .routineActive)
        #expect(answered.effects.contains(.awardParticipation(.answeredPottyPause)))

        let completed = driver.send(.routineCompleted)
        #expect(driver.state == .completing)
        // Access comes back the instant the routine ends; the celebration plays
        // over unshielded apps.
        #expect(completed.effects.first == .clearShield)
        #expect(completed.effects.contains(.awardParticipation(.completedRoutine)))
        #expect(completed.effects.contains(.logPauseOutcome(.completedRoutine)))

        driver.send(.completionAcknowledged)
        #expect(driver.state == .restoring)

        let cooled = driver.send(.shieldCleared)
        #expect(driver.state == .cooldown)
        #expect(cooled.effects.contains(.beginCooldown(until: PauseFixture.now.addingTimeInterval(300))))
        #expect(cooled.effects.contains(.clearPersistedSession))
        #expect(driver.context.activeSession == nil)

        driver.send(.cooldownElapsed)
        #expect(driver.state == .monitoring)

        #expect(driver.awards == [.answeredPottyPause, .completedRoutine])
        #expect(driver.outcomes == [.completedRoutine])
        #expect(driver.didClearShield)
    }

    @Test("A pause the child never answers still ends, on the timer alone")
    func timerOnlyLifecycle() {
        var driver = PauseDriver(state: .monitoring)
        driver.send(.pauseThresholdReached)
        driver.send(.shieldApplied)
        #expect(driver.state == .shieldActive)

        driver.advance(180)
        let expired = driver.send(.pauseTimerExpired)
        #expect(driver.state == .restoring)
        #expect(expired.effects.first == .clearShield)
        #expect(expired.effects.contains(.logPauseOutcome(.timerExpired)))

        driver.send(.shieldCleared)
        #expect(driver.state == .cooldown)
        // Nothing was awarded and nothing was taken away. The child simply did
        // not answer the door.
        #expect(driver.awards.isEmpty)
    }

    @Test("The ceiling timer ends the pause even mid-routine")
    func timerBeatsRoutine() {
        var driver = PauseDriver(state: .routineActive, context: PauseFixture.context(
            activeSession: PauseFixture.session(state: .routineActive)
        ))
        let expired = driver.send(.pauseTimerExpired)
        #expect(driver.state == .restoring)
        #expect(expired.effects.first == .clearShield)
    }

    @Test("Gentle mode runs the whole routine and never raises a shield")
    func gentleModeNeverShields() {
        var driver = PauseDriver(state: .monitoring, context: PauseFixture.context(mode: .gentle))
        driver.send(.warningThresholdReached)
        driver.send(.pauseThresholdReached)
        #expect(driver.state == .routineActive)
        driver.send(.routineCompleted)
        driver.send(.completionAcknowledged)
        driver.send(.shieldCleared)
        #expect(driver.state == .cooldown)
        #expect(!driver.didApplyShield)
        #expect(driver.awards.contains(.completedRoutine))
    }

    @Test("A child who goes before the pause fires skips the shield entirely")
    func earlyStartSkipsTheShield() {
        var driver = PauseDriver(state: .warningApproaching)
        let early = driver.send(.childAcknowledged)
        #expect(driver.state == .routineActive)
        #expect(early.effects.contains(.awardParticipation(.answeredPottyPause)))
        #expect(!driver.didApplyShield)
        driver.send(.routineCompleted)
        #expect(driver.state == .completing)
    }

    @Test("A warning-free schedule goes straight from monitoring to the pause")
    func noWarningConfigured() {
        var context = PauseFixture.context()
        context.schedule.warningOffset = 0
        var driver = PauseDriver(state: .ready, context: context)
        let armed = driver.send(.monitoringRegistered)
        #expect(driver.state == .monitoring)
        #expect(!armed.effects.contains(where: { if case .scheduleWarningNotification = $0 { true } else { false } }))
        driver.send(.pauseThresholdReached)
        #expect(driver.state == .pauseTriggered)
    }

    @Test("Enabling the schedule runs every gate")
    func enablingRunsTheGates() {
        let cases: [(ScreenTimeAuthorizationStatus, Bool, PottyPauseState)] = [
            (.approved, true, .ready),
            (.denied, true, .authorizationRequired),
            (.notDetermined, true, .authorizationRequired),
            (.restricted, true, .authorizationRequired),
            (.approved, false, .errorRequiresParent(.noSelection)),
        ]
        for (auth, selection, expected) in cases {
            let context = PauseFixture.context(authorization: auth, hasSelection: selection)
            let outcome = PottyPauseMachine.reduce(state: .disabled, event: .scheduleEnabled, context: context)
            #expect(outcome.isAccepted)
            #expect(outcome.state == expected)
            #expect(outcome.effects.first == .clearShield)
        }
    }

    @Test("Cooldown refuses a new pause, and says why")
    func cooldownRefusesRetrigger() {
        let outcome = PottyPauseMachine.reduce(
            state: .cooldown, event: .pauseThresholdReached, context: PauseFixture.context()
        )
        #expect(outcome.isRejected)
        #expect(outcome.state == .cooldown)
        #expect(outcome.rejection?.reason == .cooldownNotElapsed)
    }

    @Test("A failed shield apply clears whatever landed and offers a retry")
    func shieldApplyFailure() {
        var driver = PauseDriver(state: .pauseTriggered, context: PauseFixture.context(
            activeSession: PauseFixture.session(state: .pauseTriggered)
        ))
        let failed = driver.send(.shieldApplyFailed)
        #expect(driver.state == .errorRecoverable(.shieldApplyFailed))
        #expect(failed.effects.first == .clearShield)
        #expect(failed.effects.contains(.notifyParent(.screenTimeFailure(.shieldApplyFailed))))

        driver.send(.retryRequested)
        #expect(driver.state == .ready)
    }

    @Test("A failed shield clear retries, then escalates to the caregiver")
    func shieldClearFailureEscalates() {
        var driver = PauseDriver(state: .restoring, context: PauseFixture.context(
            activeSession: PauseFixture.session(state: .restoring)
        ))
        driver.send(.shieldClearFailed)
        #expect(driver.state == .errorRecoverable(.shieldClearFailed))

        // Retrying a failed lift means lifting again, not re-arming.
        let retry = driver.send(.retryRequested)
        #expect(driver.state == .restoring)
        #expect(retry.effects.first == .clearShield)

        driver.send(.shieldClearFailed)
        driver.send(.shieldClearFailed)
        #expect(driver.state == .errorRequiresParent(.shieldClearFailed))
        // Even the escalated state keeps trying to lift on every event it takes.
        #expect(driver.performed.filter { $0 == .clearShield }.count >= 4)
    }

    @Test("Authorization revoked mid-pause clears the shield and tells the caregiver")
    func authorizationRevokedMidPause() {
        for state in [PottyPauseState.pauseTriggered, .shieldActive, .routineActive, .completing, .restoring] {
            var driver = PauseDriver(state: state, context: PauseFixture.context(
                activeSession: PauseFixture.session(state: state)
            ))
            let revoked = driver.send(.authorizationRevoked)
            #expect(driver.state == .errorRequiresParent(.authorizationRevoked))
            #expect(revoked.effects.first == .clearShield)
            #expect(revoked.effects.contains(.notifyParent(.screenTimeFailure(.authorizationRevoked))))
            #expect(revoked.effects.contains(.logPauseOutcome(.authorizationLost)))
            #expect(!driver.state.isShieldConfirmedUp)
        }
    }

    @Test("Authorization revoked outside a pause just disarms")
    func authorizationRevokedWhileIdle() {
        for state in [PottyPauseState.ready, .monitoring, .warningApproaching, .cooldown] {
            let outcome = PottyPauseMachine.reduce(
                state: state, event: .authorizationRevoked, context: PauseFixture.context()
            )
            #expect(outcome.state == .authorizationRequired)
            #expect(outcome.effects.first == .clearShield)
        }
    }

    @Test("Switching the schedule off ends everything, from any state")
    func scheduleDisabledFromEveryState() {
        for state in PottyPauseState.exhaustiveCases {
            let outcome = PottyPauseMachine.reduce(
                state: state, event: .scheduleDisabled, context: PauseFixture.context()
            )
            #expect(outcome.isAccepted)
            #expect(outcome.state == .disabled)
            #expect(outcome.effects.first == .clearShield)
            #expect(outcome.effects.contains(.cancelMonitoring))
            #expect(outcome.effects.contains(.clearPersistedSession))
        }
    }
}
