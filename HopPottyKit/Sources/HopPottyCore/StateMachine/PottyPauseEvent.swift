import Foundation

/// Everything that can happen to a Potty Pause.
///
/// No case carries a payload. Anything a transition needs to know — the current
/// instant, the schedule, the authorization status, the in-flight session —
/// arrives in `PottyPauseContext`, which keeps the event set `CaseIterable` and
/// therefore keeps the "every state × every event" totality test honest. An
/// event with an associated `Date` would quietly make that test impossible to
/// write, and the test is the reason the component is trustworthy.
public enum PottyPauseEvent: String, CaseIterable, Hashable, Sendable {
    // MARK: Configuration

    /// The caregiver switched Potty Pause on for this child.
    case scheduleEnabled
    /// The caregiver switched Potty Pause off, or suspended it indefinitely.
    /// Accepted from every state, and always ends with access restored.
    case scheduleDisabled

    // MARK: Authorization

    case authorizationGranted
    case authorizationDenied
    /// Family Controls authorization went away underneath a running schedule —
    /// a parent revoked it in Settings, or the child's device left the family.
    /// Accepted from every state.
    case authorizationRevoked

    // MARK: Monitoring

    case monitoringRegistered
    case monitoringRegistrationFailed

    // MARK: Approach and trigger

    /// The warning threshold passed: a pause is about to start.
    case warningThresholdReached
    /// The pause threshold passed: the pause starts now.
    case pauseThresholdReached

    // MARK: Shield handshake

    /// The `ManagedSettings` store reports the shield is up.
    case shieldApplied
    case shieldApplyFailed
    /// The `ManagedSettings` store reports the shield is down. Safe to accept
    /// generously: it can only ever mean the child has *more* access.
    case shieldCleared
    case shieldClearFailed

    // MARK: The child

    /// The child answered the door — tapped through the Potty Pause screen.
    case childAcknowledged
    /// The child finished the routine.
    case routineCompleted

    // MARK: Timers

    /// The pause ceiling elapsed. This ends the pause no matter what the child
    /// did or did not do, which is the rule the whole product rests on.
    case pauseTimerExpired
    /// The celebration finished; nothing is left to show.
    case completionAcknowledged
    /// The post-pause quiet period elapsed.
    case cooldownElapsed

    // MARK: Caregiver and recovery

    /// The emergency exit. Accepted from every single state, and always ends in
    /// a shield-cleared state. A caregiver must never have to reason about what
    /// HopPotty thinks is happening in order to give their child their apps back.
    case parentRestoredAccess
    /// The caregiver read the error and asked to continue.
    case parentAcknowledgedError
    /// Retry a self-recoverable failure.
    case retryRequested
}
