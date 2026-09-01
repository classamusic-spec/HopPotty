import Foundation

/// The minimum that has to survive process death.
///
/// A shield lives in `ManagedSettings`, which is system state: it outlives the
/// app, the extension, and a reboot. HopPotty's in-memory state does not. So the
/// only thing standing between a crash and a child who cannot open anything is
/// this record — and the smaller it is, the fewer ways it can be wrong.
///
/// Everything else is derived. The schedule, the mode, the selection, the star
/// balance and the child's nickname are all re-read from their own stores on
/// launch; duplicating them here would create two sources of truth for values
/// that a caregiver can change while the app is dead.
///
/// Instants are absolute `Date`s, never wall-clock times. A pause that started
/// at 14:00 and lasts three minutes ends three minutes later even if the family
/// crosses a time zone, even if daylight saving shifts, and even if the device
/// clock is nudged — an absolute instant cannot be re-interpreted by a change of
/// zone the way a `LocalTimeOfDay` can. (Quiet windows are the opposite case and
/// are stored the opposite way, for the same reason.)
public struct PersistedPauseSession: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let childID: UUID
    /// Where the machine was when this was last written.
    public var state: PottyPauseState
    /// When the pause began.
    public let startedAt: Date
    /// The instant the shield must be down by, no matter what.
    public let expiresAt: Date

    public init(
        id: UUID = UUID(),
        childID: UUID,
        state: PottyPauseState,
        startedAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.childID = childID
        self.state = state
        self.startedAt = startedAt
        self.expiresAt = expiresAt
    }

    /// Tolerance for a device clock that ticks a little differently from the one
    /// that wrote the record. Generous on purpose: the consequence of being too
    /// generous is a redundant `clearShield`, and the consequence of being too
    /// strict is a session declared corrupt for no reason.
    public static let clockSlack: TimeInterval = 60

    public var plannedDuration: TimeInterval { expiresAt.timeIntervalSince(startedAt) }

    /// Whether the pause ceiling has passed.
    public func hasExpired(at now: Date) -> Bool { now >= expiresAt }

    /// Whether this record claims to have started after the current instant.
    ///
    /// Only possible if the clock moved backwards — a manual change, an NTP
    /// correction, or a device that lost power long enough to reset its clock.
    /// The record cannot be trusted to say when the shield should come down, so
    /// it comes down now.
    public func isFromTheFuture(at now: Date) -> Bool { now < startedAt.addingTimeInterval(-Self.clockSlack) }

    /// Structural integrity, independent of the clock.
    ///
    /// A pause that ends before it starts, one that claims to last longer than
    /// any pause HopPotty will ever schedule, or one carrying a state HopPotty
    /// never writes, is a corrupted or hand-edited record.
    public var isWellFormed: Bool {
        guard state.isPersistable else { return false }
        guard plannedDuration > 0 else { return false }
        return plannedDuration <= PottySchedule.maximumPauseDuration + Self.clockSlack
    }

    /// Whether the child this record names is the child the app is running as.
    /// A mismatch means a profile was deleted or switched while the app was dead.
    public func belongs(to childID: UUID) -> Bool { self.childID == childID }

    /// Whether the child had already engaged with the routine when this was
    /// written. Used only to decide whether an interrupted pause still earns its
    /// star — never to withhold one.
    ///
    /// `routineActive` and `completing` are only reachable through a tap the
    /// child made. `restoring` is not: the ceiling timer reaches it on its own,
    /// so it is deliberately excluded — every star HopPotty gives stands for
    /// something the child actually did.
    public var childHadEngaged: Bool {
        switch state {
        case .routineActive, .completing: true
        default: false
        }
    }

    public func advanced(to state: PottyPauseState) -> PersistedPauseSession {
        PersistedPauseSession(
            id: id, childID: childID, state: state, startedAt: startedAt, expiresAt: expiresAt
        )
    }
}
