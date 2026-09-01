import Foundation

/// Everything a transition is allowed to read.
///
/// The reducer is a pure function of `(state, event, context)`. Putting the
/// clock in here rather than calling `Date()` inside the reducer is what lets a
/// test move time backwards, jump a day, or sit exactly on an expiry boundary.
public struct PottyPauseContext: Hashable, Sendable {
    /// The instant this transition is being evaluated at.
    public var now: Date
    public var childID: UUID
    /// The identifier to stamp on a session that *starts* in this transition.
    /// Supplied by the caller so the reducer stays deterministic.
    public var sessionID: UUID
    public var schedule: PottySchedule
    public var authorizationStatus: ScreenTimeAuthorizationStatus
    /// Whether the caregiver has picked anything to shield. A count-free bool —
    /// Core is not entitled to know what was selected.
    public var hasSelection: Bool
    /// The pause currently in flight, if there is one.
    public var activeSession: PersistedPauseSession?

    public init(
        now: Date,
        childID: UUID,
        sessionID: UUID = UUID(),
        schedule: PottySchedule,
        authorizationStatus: ScreenTimeAuthorizationStatus = .approved,
        hasSelection: Bool = true,
        activeSession: PersistedPauseSession? = nil
    ) {
        self.now = now
        self.childID = childID
        self.sessionID = sessionID
        self.schedule = schedule
        self.authorizationStatus = authorizationStatus
        self.hasSelection = hasSelection
        self.activeSession = activeSession
    }
}

public extension PottyPauseContext {
    /// Whether this configuration shields anything at all. `gentle` never does.
    var shieldsApps: Bool { schedule.mode.shieldsApps }

    var requiresAuthorization: Bool { schedule.mode.requiresScreenTimeAuthorization }

    var isAuthorized: Bool { authorizationStatus.canShield }

    /// A selection is needed to shield anything, and also to count screen
    /// activity — a usage trigger with nothing selected can never fire.
    var requiresSelection: Bool { shieldsApps || schedule.triggerBasis.requiresAppSelection }

    var selectionSatisfied: Bool { !requiresSelection || hasSelection }

    /// Whether the caregiver has Potty Pause switched on at all.
    var isScheduleLive: Bool { schedule.isEnabled && schedule.suspension != .indefinite }

    /// The pause ceiling, clamped to the product's bounds.
    ///
    /// Clamped here rather than trusted from the schedule because this value
    /// becomes the persisted `expiresAt`: a corrupted or migrated schedule must
    /// not be able to write a shield that lasts an hour.
    var pauseDuration: TimeInterval {
        min(max(schedule.pauseDuration, PottySchedule.minimumPauseDuration), PottySchedule.maximumPauseDuration)
    }

    var pauseExpiry: Date { now.addingTimeInterval(pauseDuration) }

    var cooldownEnd: Date { now.addingTimeInterval(max(0, schedule.cooldown)) }

    var warningLeadTime: TimeInterval { schedule.effectiveWarningOffset }

    /// A brand new session for a pause starting now.
    func startingSession(state: PottyPauseState) -> PersistedPauseSession {
        PersistedPauseSession(
            id: sessionID,
            childID: childID,
            state: state,
            startedAt: now,
            expiresAt: pauseExpiry
        )
    }

    /// The in-flight session moved to a new state, or a fresh one anchored at
    /// `now` if the caller has somehow lost it. Never returns `nil`: a pause
    /// without a record is exactly the situation that strands a shield.
    func session(advancedTo state: PottyPauseState) -> PersistedPauseSession {
        activeSession?.advanced(to: state) ?? startingSession(state: state)
    }
}
