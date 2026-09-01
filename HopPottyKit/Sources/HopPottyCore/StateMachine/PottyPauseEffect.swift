import Foundation

/// A single side effect the app layer must perform after a transition.
///
/// The reducer performs no I/O. It returns a list of these instead, which is
/// what makes the shield logic testable on Linux with no entitlements, and what
/// reduces the iOS layer to a `for effect in outcome.effects { perform(effect) }`
/// loop with no decisions of its own.
///
/// **Effects are ordered and must be performed in order.** Every bundle that
/// contains `.clearShield` puts it first, so a crash part-way through a bundle
/// still leaves the child's apps usable.
public enum PottyPauseEffect: Hashable, Sendable {
    /// Ask for Family Controls authorization.
    case requestAuthorization

    /// Start `DeviceActivity` monitoring for this schedule.
    case registerMonitoring
    /// Stop monitoring entirely.
    case cancelMonitoring

    /// Arrange the "potty time soon" nudge, `leadTime` seconds ahead of the pause.
    case scheduleWarningNotification(leadTime: TimeInterval)
    case cancelWarningNotification
    /// Show the in-app approach cue.
    case presentWarning

    /// Apply the `ManagedSettings` shield to the caregiver's selection.
    ///
    /// Only ever emitted when authorization is present and the mode shields.
    case applyShield

    /// Remove every setting from the `ManagedSettings` store.
    ///
    /// **Idempotent by construction**: it is `store.clearAllSettings()`, which
    /// is a no-op on an already-clear store. It is therefore safe — and
    /// deliberately common — for this to be emitted more than once for the same
    /// pause, from more than one path, including paths that "know" the shield is
    /// already down. Emitting it twice costs nothing; not emitting it once costs
    /// a child their apps until someone notices.
    case clearShield

    /// Arm the ceiling timer that ends the pause regardless of outcome.
    case startPauseTimer(expiresAt: Date)
    case cancelPauseTimer

    case presentPauseScreen
    case dismissPauseScreen

    /// Write the session to disk, so a process death is recoverable.
    case persistSession(PersistedPauseSession)
    /// Remove the persisted session. Only correct once access is confirmed back.
    case clearPersistedSession

    /// Append to the Hop Star ledger. Always additive — see `RewardTransaction`.
    case awardParticipation(RewardReason)
    /// Record how the pause ended, for the timeline and the insights engine.
    case logPauseOutcome(PauseOutcome)

    /// Begin the post-pause quiet period.
    case beginCooldown(until: Date)

    /// Tell the caregiver something they need to know.
    case notifyParent(ParentNotice)
}

public extension PottyPauseEffect {
    var isShieldClearing: Bool { self == .clearShield }
    var isShieldRaising: Bool { self == .applyShield }
}

/// How a pause ended. Descriptive only — none of these is a success or a
/// failure, and none of them is about whether the child produced anything.
public enum PauseOutcome: String, CaseIterable, Hashable, Sendable {
    /// The child finished the routine.
    case completedRoutine
    /// The ceiling timer elapsed. A completely ordinary way for a pause to end.
    case timerExpired
    /// A caregiver restored access or switched the schedule off.
    case parentOverride
    /// Authorization disappeared mid-pause.
    case authorizationLost
    /// The app, extension or device died mid-pause and recovery ended it.
    case interruptedByProcessDeath
    /// The pause could not start at all.
    case couldNotStart
}

/// Something the caregiver is told. Each maps to one sentence of `HopCopy`;
/// none of them is ever shown to the child.
public enum ParentNotice: Hashable, Sendable {
    case screenTimeFailure(ScreenTimeFailure)
    case authorizationNeeded
    case accessRestoredByParent
    /// "HopPotty restarted and unlocked the apps to be safe."
    case accessRestoredAfterInterruption
}
