import Foundation

/// Every situation a Potty Pause can be in, for one child, on one device.
///
/// The whole point of naming these is that HopPotty can put a shield over a
/// child's apps. A shield is a thing that *takes something away*, so the set of
/// states is deliberately explicit and closed: there is no "in between" a
/// scattering of booleans could describe but nobody could enumerate. If a
/// situation is not in this list, HopPotty is not in it.
///
/// `Codable` because a subset of these values must survive process death — see
/// `PersistedPauseSession`.
public enum PottyPauseState: Hashable, Codable, Sendable {
    /// Potty Pause is switched off for this child, or the caregiver suspended it
    /// indefinitely. Nothing is monitored and nothing is ever shielded.
    case disabled

    /// Shielding is configured but Family Controls authorization is missing,
    /// denied or revoked. HopPotty cannot shield and does not pretend it can.
    case authorizationRequired

    /// Configured and permitted, but not yet armed. Monitoring registration has
    /// been asked for and not yet confirmed.
    case ready

    /// Armed. `DeviceActivity` (or the clock) is counting toward the next pause.
    case monitoring

    /// The warning threshold has passed; a pause is imminent. Still no shield.
    case warningApproaching

    /// The trigger fired and the shield has been asked for, but the shield has
    /// not been confirmed. Treated as *possibly shielded*, because a partially
    /// applied `ManagedSettings` store is indistinguishable from a fully applied
    /// one from the outside.
    case pauseTriggered

    /// The shield is confirmed up and the child is looking at the Potty Pause
    /// screen. A timer is running that will end this whatever the child does.
    case shieldActive

    /// The child engaged with the routine. Still shielded in `pause`/`routine`
    /// mode; never shielded in `gentle` mode.
    case routineActive

    /// The pause is finishing: the outcome is being recorded and the star is
    /// being awarded. Access is already being restored — the celebration does
    /// not hold the shield open.
    case completing

    /// Access restoration is in flight and unconfirmed.
    case restoring

    /// Access is restored and the schedule is deliberately quiet, so the child
    /// is not re-interrupted the moment they get back to what they were doing.
    case cooldown

    /// Something failed that HopPotty can retry by itself.
    case errorRecoverable(ScreenTimeFailure)

    /// Something failed that a caregiver has to resolve — a revoked permission,
    /// an empty selection, a shield we could not lift.
    case errorRequiresParent(ScreenTimeFailure)
}

public extension PottyPauseState {
    /// A tag with one value per case, used to make the hand-written
    /// `exhaustiveCases` list self-checking. The switch below has no `default`,
    /// so adding a state breaks the build here first.
    enum Kind: String, CaseIterable, Hashable, Sendable {
        case disabled, authorizationRequired, ready, monitoring, warningApproaching
        case pauseTriggered, shieldActive, routineActive, completing, restoring
        case cooldown, errorRecoverable, errorRequiresParent
    }

    var kind: Kind {
        switch self {
        case .disabled: .disabled
        case .authorizationRequired: .authorizationRequired
        case .ready: .ready
        case .monitoring: .monitoring
        case .warningApproaching: .warningApproaching
        case .pauseTriggered: .pauseTriggered
        case .shieldActive: .shieldActive
        case .routineActive: .routineActive
        case .completing: .completing
        case .restoring: .restoring
        case .cooldown: .cooldown
        case .errorRecoverable: .errorRecoverable
        case .errorRequiresParent: .errorRequiresParent
        }
    }

    /// Every distinct state value, including one per `ScreenTimeFailure` for the
    /// two error cases. The totality tests iterate this against every event.
    static var exhaustiveCases: [PottyPauseState] {
        var all: [PottyPauseState] = [
            .disabled, .authorizationRequired, .ready, .monitoring, .warningApproaching,
            .pauseTriggered, .shieldActive, .routineActive, .completing, .restoring, .cooldown,
        ]
        all += ScreenTimeFailure.allCases.map(PottyPauseState.errorRecoverable)
        all += ScreenTimeFailure.allCases.map(PottyPauseState.errorRequiresParent)
        return all
    }

    var failure: ScreenTimeFailure? {
        switch self {
        case .errorRecoverable(let failure), .errorRequiresParent(let failure): failure
        default: nil
        }
    }

    var isError: Bool { failure != nil }

    /// Whether a shield is *known* to be up. Used for child-facing UI, never for
    /// safety decisions — safety uses `mayHaveShieldUp`.
    var isShieldConfirmedUp: Bool {
        switch self {
        case .shieldActive, .routineActive: true
        default: false
        }
    }

    /// Whether a shield *might* be up.
    ///
    /// This is the conservative reading and it is the one every fail-safe rule
    /// keys off. `pauseTriggered` counts because the apply may have half
    /// succeeded; `completing` and `restoring` count because a clear is in
    /// flight and unconfirmed; error states count unless the failure provably
    /// happened before any shield could exist.
    var mayHaveShieldUp: Bool {
        switch self {
        case .pauseTriggered, .shieldActive, .routineActive, .completing, .restoring:
            true
        case .disabled, .authorizationRequired, .ready, .monitoring, .warningApproaching, .cooldown:
            false
        case .errorRecoverable(let failure), .errorRequiresParent(let failure):
            failure.couldLeaveShieldUp
        }
    }

    /// The window between the trigger firing and access being confirmed back.
    var isPauseInFlight: Bool {
        switch self {
        case .pauseTriggered, .shieldActive, .routineActive, .completing, .restoring: true
        default: false
        }
    }

    var isArmed: Bool {
        switch self {
        case .monitoring, .warningApproaching: true
        default: false
        }
    }

    /// Whether this state is one HopPotty ever writes to disk.
    ///
    /// Only states where a process death could strand a shield are persisted.
    /// Everything else is re-derived on launch, which means a persisted session
    /// carrying any other state is corrupt by definition — a cheap integrity
    /// check that costs no extra bytes.
    var isPersistable: Bool { isPauseInFlight || (isError && mayHaveShieldUp) }
}

public extension ScreenTimeFailure {
    /// Whether this failure could have left a shield standing.
    ///
    /// The line is drawn at *when the failure can happen*. Configuration,
    /// authorization-request and monitoring-registration failures all occur
    /// strictly before a shield could exist, so they provably cannot have left
    /// one up. Everything that can happen at or after apply time is ambiguous —
    /// including `unknown`, and including `authorizationConflict`, whose whole
    /// meaning is "another app may now be in charge of the settings store" —
    /// and ambiguity always resolves toward "assume the child's apps are
    /// blocked, and clear them".
    ///
    /// The switch is deliberately written without a `default`, so a new failure
    /// case cannot be added without someone deciding which side of this line it
    /// falls on.
    var couldLeaveShieldUp: Bool {
        switch self {
        case .noSelection, .scheduleInvalid, .monitoringRegistrationFailed, .monitoringLimitReached,
             .invalidAccountType, .networkError, .authenticationMethodUnavailable:
            false
        case .authorizationRevoked, .shieldApplyFailed, .shieldClearFailed, .extensionUnavailable,
             .authorizationConflict, .unknown:
            true
        }
    }
}
