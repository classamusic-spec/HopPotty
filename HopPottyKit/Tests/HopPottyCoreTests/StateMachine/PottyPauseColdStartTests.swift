import Foundation
import Testing
import HopPottyCore

/// A `ManagedSettings` shield outlives the process that applied it. These tests
/// are the ones that stop a crash from turning into a child holding a device
/// that will not open anything.
@Suite("Potty Pause cold-start recovery")
struct PottyPauseColdStartTests {

    /// Every state HopPotty ever writes to disk.
    static var persistableStates: [PottyPauseState] {
        PottyPauseState.exhaustiveCases.filter(\.isPersistable)
    }

    @Test("Recovery from every persistable state clears the shield first")
    func recoveryFromEveryPersistableState() {
        for state in Self.persistableStates {
            let session = PauseFixture.session(state: state)
            let recovery = PottyPauseMachine.recoverFromColdStart(
                persisted: session,
                now: PauseFixture.now.addingTimeInterval(30),
                context: PauseFixture.context()
            )
            #expect(recovery.effects.first == .clearShield, "\(state) did not clear first")
            #expect(recovery.effects.contains(.cancelPauseTimer))
            #expect(recovery.effects.contains(.clearPersistedSession))
            #expect(!recovery.state.mayHaveShieldUp, "\(state) recovered into \(recovery.state)")
            #expect(recovery.state == .ready)
        }
    }

    @Test("A crash mid-pause ends the pause rather than re-raising the shield")
    func interruptedMidPause() {
        let session = PauseFixture.session(state: .shieldActive)
        let recovery = PottyPauseMachine.recoverFromColdStart(
            persisted: session,
            now: PauseFixture.now.addingTimeInterval(10),
            context: PauseFixture.context()
        )
        #expect(recovery.verdict == .interruptedMidPause)
        #expect(recovery.clearsShield)
        #expect(recovery.effects.contains(.logPauseOutcome(.interruptedByProcessDeath)))
        #expect(recovery.effects.contains(.notifyParent(.accessRestoredAfterInterruption)))
        // Ten seconds into a three-minute pause is exactly the case where
        // "restore the shield, there is time left" is tempting and wrong.
        #expect(!recovery.effects.contains(.applyShield))
    }

    @Test("A crash after the child engaged still earns the star")
    func interruptedAfterEngagement() {
        for state in [PottyPauseState.routineActive, .completing] {
            let recovery = PottyPauseMachine.recoverFromColdStart(
                persisted: PauseFixture.session(state: state),
                now: PauseFixture.now.addingTimeInterval(20),
                context: PauseFixture.context()
            )
            #expect(recovery.verdict == .interruptedAfterEngagement)
            #expect(recovery.effects.contains(.awardParticipation(.answeredPottyPause)))
        }
    }

    @Test("A crash before the child engaged awards nothing and removes nothing")
    func interruptedBeforeEngagement() {
        // `restoring` is included on purpose: the ceiling timer reaches it with
        // no child action at all, so it earns nothing.
        for state in [PottyPauseState.pauseTriggered, .shieldActive, .restoring] {
            let recovery = PottyPauseMachine.recoverFromColdStart(
                persisted: PauseFixture.session(state: state),
                now: PauseFixture.now.addingTimeInterval(20),
                context: PauseFixture.context()
            )
            #expect(recovery.verdict == .interruptedMidPause)
            #expect(!recovery.effects.contains(.awardParticipation(.answeredPottyPause)))
        }
    }

    @Test("Nothing persisted still clears")
    func noSessionStillClears() {
        let recovery = PottyPauseMachine.recoverFromColdStart(
            persisted: nil, now: PauseFixture.now, context: PauseFixture.context()
        )
        #expect(recovery.verdict == .noSessionFound)
        // The absence of a record is not evidence of the absence of a shield: the
        // write may simply never have landed.
        #expect(recovery.effects.first == .clearShield)
        #expect(recovery.state == .ready)
    }

    @Test("An expired shield is always cleared")
    func expiredSessionIsCleared() {
        let recovery = PottyPauseMachine.recoverFromColdStart(
            persisted: PauseFixture.session(state: .shieldActive, duration: 180),
            now: PauseFixture.now.addingTimeInterval(4 * 3600),
            context: PauseFixture.context()
        )
        #expect(recovery.verdict == .sessionExpired)
        #expect(recovery.effects.first == .clearShield)
        #expect(!recovery.state.mayHaveShieldUp)
    }

    @Test("A shield exactly on its expiry instant is cleared")
    func expiryBoundaryIsClosed() {
        let session = PauseFixture.session(state: .shieldActive, duration: 180)
        let recovery = PottyPauseMachine.recoverFromColdStart(
            persisted: session, now: session.expiresAt, context: PauseFixture.context()
        )
        #expect(recovery.verdict == .sessionExpired)
        #expect(session.hasExpired(at: session.expiresAt))
    }

    @Test("A session from the future — the clock moved backwards — is cleared")
    func clockMovedBackwards() {
        let session = PauseFixture.session(state: .routineActive, duration: 180)
        let recovery = PottyPauseMachine.recoverFromColdStart(
            persisted: session,
            now: PauseFixture.now.addingTimeInterval(-3600),
            context: PauseFixture.context()
        )
        // Its expiry is still an hour away by the device's reckoning, and it is
        // cleared anyway: a record that cannot be trusted about *when* must not
        // be trusted about *whether*.
        #expect(recovery.verdict == .clockMovedBackwards)
        #expect(!session.hasExpired(at: PauseFixture.now.addingTimeInterval(-3600)))
        #expect(recovery.effects.first == .clearShield)
        #expect(!recovery.state.mayHaveShieldUp)
    }

    @Test("Small clock jitter is not mistaken for a corrupted record")
    func smallClockJitterIsTolerated() {
        let session = PauseFixture.session(state: .shieldActive, duration: 180)
        let recovery = PottyPauseMachine.recoverFromColdStart(
            persisted: session,
            now: PauseFixture.now.addingTimeInterval(-5),
            context: PauseFixture.context()
        )
        #expect(recovery.verdict == .interruptedMidPause)
        #expect(recovery.clearsShield)
    }

    @Test("Corrupted records are cleared, whatever shape the corruption takes")
    func corruptedSessionsAreCleared() {
        let corrupted: [PersistedPauseSession] = [
            // Ends before it starts.
            PauseFixture.session(state: .shieldActive, duration: -60),
            // Zero-length.
            PauseFixture.session(state: .shieldActive, duration: 0),
            // Longer than any pause HopPotty will ever schedule.
            PauseFixture.session(state: .shieldActive, duration: 6 * 3600),
            // A state that is never written to disk.
            PauseFixture.session(state: .monitoring),
            PauseFixture.session(state: .cooldown),
            PauseFixture.session(state: .errorRequiresParent(.noSelection)),
            // Another child's record, left by a profile switch or deletion.
            PauseFixture.session(state: .shieldActive, childID: UUID()),
        ]
        for session in corrupted {
            let recovery = PottyPauseMachine.recoverFromColdStart(
                persisted: session,
                now: PauseFixture.now.addingTimeInterval(10),
                context: PauseFixture.context()
            )
            #expect(recovery.verdict == .sessionMalformed, "\(session.state) \(session.plannedDuration)")
            #expect(recovery.effects.first == .clearShield)
            #expect(!recovery.state.mayHaveShieldUp)
        }
    }

    @Test("Every combination of session and clock clears the shield")
    func everyRecoveryClears() {
        let offsets: [TimeInterval] = [-86_400, -3600, -61, -5, 0, 1, 179, 180, 181, 3600, 86_400]
        var sessions: [PersistedPauseSession?] = [nil]
        for state in PottyPauseState.exhaustiveCases {
            sessions.append(PauseFixture.session(state: state))
        }
        sessions.append(PauseFixture.session(state: .shieldActive, duration: -1))
        sessions.append(PauseFixture.session(state: .shieldActive, childID: UUID()))

        for session in sessions {
            for offset in offsets {
                for context in [PottyPauseContext?.none] + PauseFixture.allContexts.map({ Optional($0) }) {
                    let recovery = PottyPauseMachine.recoverFromColdStart(
                        persisted: session,
                        now: PauseFixture.now.addingTimeInterval(offset),
                        context: context
                    )
                    #expect(recovery.effects.first == .clearShield)
                    #expect(!recovery.state.mayHaveShieldUp)
                    #expect(!recovery.effects.contains(.applyShield))
                    #expect(recovery.effects.contains(.clearPersistedSession))
                }
            }
        }
    }

    @Test("Recovery lands where the live configuration says it should")
    func recoveryRestingState() {
        let cases: [(PottyPauseContext?, PottyPauseState)] = [
            (nil, .disabled),
            (PauseFixture.context(), .ready),
            (PauseFixture.context(isEnabled: false), .disabled),
            (PauseFixture.context(authorization: .denied), .authorizationRequired),
            (PauseFixture.context(authorization: .restricted), .authorizationRequired),
            (PauseFixture.context(hasSelection: false), .errorRequiresParent(.noSelection)),
            (PauseFixture.context(mode: .gentle, hasSelection: false), .errorRequiresParent(.noSelection)),
            // A clock-driven gentle schedule needs neither permission nor a
            // selection, so it comes back armed.
            (PauseFixture.context(mode: .gentle, triggerBasis: .clockTime, hasSelection: false), .ready),
        ]
        for (context, expected) in cases {
            let recovery = PottyPauseMachine.recoverFromColdStart(
                persisted: PauseFixture.session(state: .shieldActive),
                now: PauseFixture.now.addingTimeInterval(10),
                context: context
            )
            #expect(recovery.state == expected)
        }
    }

    @Test("An extension with no configuration still recovers safely")
    func recoveryWithoutContext() {
        let recovery = PottyPauseMachine.recoverFromColdStart(
            persisted: PauseFixture.session(state: .shieldActive),
            now: PauseFixture.now.addingTimeInterval(10)
        )
        // Nothing shielded and nothing armed. The app re-arms with
        // `.scheduleEnabled` once it can read the schedule, which re-runs every
        // gate — a schedule that needs one explicit re-arm is the safe direction
        // to be wrong in; a shield that needs one is not.
        #expect(recovery.state == .disabled)
        #expect(recovery.effects.first == .clearShield)
    }

    @Test("Expiry is an absolute instant, so a time-zone change cannot postpone it")
    func expiryIsZoneIndependent() throws {
        let zones = ["America/New_York", "Europe/London", "Asia/Tokyo", "Pacific/Kiritimati"]
        for identifier in zones {
            let zone = try #require(TimeZone(identifier: identifier))
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            // "The pause started at 18:00 local, wherever local is."
            let components = DateComponents(year: 2026, month: 3, day: 10, hour: 18, minute: 0)
            let startedAt = try #require(calendar.date(from: components))
            let session = PauseFixture.session(state: .shieldActive, startedAt: startedAt, duration: 180)

            let recovery = PottyPauseMachine.recoverFromColdStart(
                persisted: session,
                now: startedAt.addingTimeInterval(200),
                context: PauseFixture.context()
            )
            #expect(recovery.verdict == .sessionExpired, "\(identifier)")
            #expect(recovery.effects.first == .clearShield)
        }
    }

    @Test("A daylight-saving fall-back cannot hold a shield open for an extra hour")
    func daylightSavingFallBack() throws {
        let zone = try #require(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        // 2026-11-01: clocks go back at 02:00 local. A pause that starts at
        // 01:59 EDT and lasts three minutes ends at 01:02 EST — an instant whose
        // wall clock reads *earlier* than the one it started at.
        let startedAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 1, minute: 59))
        )
        let now = startedAt.addingTimeInterval(200)
        let startedHour = calendar.component(.hour, from: startedAt) * 60 + calendar.component(.minute, from: startedAt)
        let nowHour = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        #expect(nowHour < startedHour, "the fixture must actually cross the fall-back boundary")

        let session = PauseFixture.session(state: .shieldActive, startedAt: startedAt, duration: 180)
        let recovery = PottyPauseMachine.recoverFromColdStart(
            persisted: session, now: now, context: PauseFixture.context()
        )
        // Wall-clock reasoning would conclude the pause has 57 minutes left.
        #expect(recovery.verdict == .sessionExpired)
        #expect(recovery.effects.first == .clearShield)
    }

    @Test("Recovering twice is safe and cannot double-award")
    func recoveryIsRepeatable() {
        let session = PauseFixture.session(state: .routineActive)
        let first = PottyPauseMachine.recoverFromColdStart(
            persisted: session, now: PauseFixture.now.addingTimeInterval(10), context: PauseFixture.context()
        )
        // The second launch finds no session, because the first cleared it — and
        // even if the clear had not landed, the award carries an idempotency key.
        let second = PottyPauseMachine.recoverFromColdStart(
            persisted: nil, now: PauseFixture.now.addingTimeInterval(20), context: PauseFixture.context()
        )
        #expect(first.clearsShield)
        #expect(second.clearsShield)
        #expect(second.effects.filter { $0 == .awardParticipation(.answeredPottyPause) }.isEmpty)
        #expect(first.state == second.state)
    }

    @Test("The recovery outcome is shaped like any other transition")
    func recoveryOutcomeInterop() {
        let recovery = PottyPauseMachine.recoverFromColdStart(
            persisted: PauseFixture.session(state: .shieldActive),
            now: PauseFixture.now.addingTimeInterval(10),
            context: PauseFixture.context()
        )
        #expect(recovery.outcome.isAccepted)
        #expect(recovery.outcome.state == recovery.state)
        #expect(recovery.outcome.effects == recovery.effects)
    }
}
