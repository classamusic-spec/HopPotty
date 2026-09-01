import Foundation

/// The result of applying one event to one state.
///
/// Every `(state, event)` pair produces one of these — there is no `nil`, no
/// `throws` and no silent no-op. An event the current state has no meaning for
/// comes back *rejected*, carrying the state and event that did not fit, so the
/// app layer can log it and the tests can assert on it. A silent no-op is the
/// same thing with the evidence thrown away.
public struct TransitionOutcome: Hashable, Sendable {
    /// The state after the transition. For a rejection this is the state that
    /// was passed in, unchanged.
    public let state: PottyPauseState
    /// Side effects, in the order they must be performed.
    public let effects: [PottyPauseEffect]
    /// Set only when the event did not apply.
    public let rejection: TransitionRejection?

    public init(state: PottyPauseState, effects: [PottyPauseEffect], rejection: TransitionRejection? = nil) {
        self.state = state
        self.effects = effects
        self.rejection = rejection
    }

    public var isAccepted: Bool { rejection == nil }
    public var isRejected: Bool { rejection != nil }

    public var clearsShield: Bool { effects.contains(.clearShield) }
    public var raisesShield: Bool { effects.contains(.applyShield) }

    /// Accept a transition. Effects are stored as given; callers put
    /// `.clearShield` first whenever it is present.
    public static func accept(_ state: PottyPauseState, _ effects: [PottyPauseEffect] = []) -> TransitionOutcome {
        TransitionOutcome(state: state, effects: effects, rejection: nil)
    }

    /// Refuse a transition, leaving the state exactly as it was and performing
    /// nothing. Refusing is safe here because no state can strand a shield on
    /// its own: every shield-bearing state has a running ceiling timer, and
    /// `parentRestoredAccess` is never refused.
    public static func refuse(
        state: PottyPauseState,
        event: PottyPauseEvent,
        reason: RejectionReason = .eventNotValidInState
    ) -> TransitionOutcome {
        TransitionOutcome(
            state: state,
            effects: [],
            rejection: TransitionRejection(state: state, event: event, reason: reason)
        )
    }
}

/// Why an event did not apply.
public struct TransitionRejection: Hashable, Sendable {
    public let state: PottyPauseState
    public let event: PottyPauseEvent
    public let reason: RejectionReason

    public init(state: PottyPauseState, event: PottyPauseEvent, reason: RejectionReason) {
        self.state = state
        self.event = event
        self.reason = reason
    }
}

public enum RejectionReason: String, CaseIterable, Hashable, Sendable {
    /// The event has no meaning in this state.
    case eventNotValidInState
    /// A pause was requested during the quiet period that follows one.
    case cooldownNotElapsed
    /// Retrying cannot help; a caregiver has to change something first.
    case requiresParentAction
}
