import Foundation
import HopPottyCore
import HopPottyFixtures

/// Shared fixtures and a miniature executor for the Potty Pause tests.
///
/// The driver below is deliberately the smallest possible version of the real
/// app layer: it applies the returned state, performs the two effects that
/// change what the reducer can see next (persist / clear the session), and
/// records everything else. If a test can be written against this, the iOS
/// executor has no decisions left to get wrong.
enum PauseFixture {
    static let now = HopFixtures.referenceDate
    static let childID = HopFixtures.samChildID
    static let sessionID = UUID(uuidString: "5E551000-0000-4000-8000-000000000001")!

    static func schedule(
        mode: PottyPauseMode = .routine,
        triggerBasis: PottyTriggerBasis = .screenActivity,
        warningOffset: TimeInterval = 120,
        pauseDuration: TimeInterval = 180,
        cooldown: TimeInterval = 300,
        isEnabled: Bool = true,
        suspension: ScheduleSuspension = .none
    ) -> PottySchedule {
        PottySchedule(
            childID: childID,
            mode: mode,
            triggerBasis: triggerBasis,
            interval: .minutes45,
            warningOffset: warningOffset,
            pauseDuration: pauseDuration,
            cooldown: cooldown,
            isEnabled: isEnabled,
            suspension: suspension,
            createdAt: now,
            modifiedAt: now
        )
    }

    static func context(
        now: Date = PauseFixture.now,
        mode: PottyPauseMode = .routine,
        triggerBasis: PottyTriggerBasis = .screenActivity,
        authorization: ScreenTimeAuthorizationStatus = .approved,
        hasSelection: Bool = true,
        isEnabled: Bool = true,
        activeSession: PersistedPauseSession? = nil
    ) -> PottyPauseContext {
        PottyPauseContext(
            now: now,
            childID: childID,
            sessionID: sessionID,
            schedule: schedule(mode: mode, triggerBasis: triggerBasis, isEnabled: isEnabled),
            authorizationStatus: authorization,
            hasSelection: hasSelection,
            activeSession: activeSession
        )
    }

    /// A spread of configurations wide enough that no invariant can pass by
    /// accident on one lucky setup: every mode, both authorization outcomes,
    /// with and without a selection, enabled and disabled.
    static var allContexts: [PottyPauseContext] {
        [
            context(),
            context(mode: .pause),
            context(mode: .gentle),
            context(authorization: .denied),
            context(authorization: .notDetermined),
            context(authorization: .restricted),
            context(hasSelection: false),
            context(mode: .gentle, hasSelection: false),
            context(mode: .gentle, triggerBasis: .clockTime, hasSelection: false),
            context(isEnabled: false),
            context(mode: .pause, authorization: .denied, hasSelection: false),
        ]
    }

    static func session(
        state: PottyPauseState,
        startedAt: Date = PauseFixture.now,
        duration: TimeInterval = 180,
        childID: UUID = PauseFixture.childID
    ) -> PersistedPauseSession {
        PersistedPauseSession(
            id: sessionID,
            childID: childID,
            state: state,
            startedAt: startedAt,
            expiresAt: startedAt.addingTimeInterval(duration)
        )
    }
}

/// Applies outcomes the way the iOS layer will: take the new state, honour the
/// two persistence effects, record the rest.
struct PauseDriver {
    private(set) var state: PottyPauseState
    private(set) var context: PottyPauseContext
    private(set) var performed: [PottyPauseEffect] = []
    private(set) var rejections: [TransitionRejection] = []

    init(state: PottyPauseState, context: PottyPauseContext = PauseFixture.context()) {
        self.state = state
        self.context = context
    }

    @discardableResult
    mutating func send(_ event: PottyPauseEvent) -> TransitionOutcome {
        let outcome = PottyPauseMachine.reduce(state: state, event: event, context: context)
        if let rejection = outcome.rejection {
            rejections.append(rejection)
        } else {
            state = outcome.state
        }
        for effect in outcome.effects {
            switch effect {
            case .persistSession(let session): context.activeSession = session
            case .clearPersistedSession: context.activeSession = nil
            default: break
            }
        }
        performed += outcome.effects
        return outcome
    }

    mutating func advance(_ seconds: TimeInterval) {
        context.now = context.now.addingTimeInterval(seconds)
    }

    var didClearShield: Bool { performed.contains(.clearShield) }
    var didApplyShield: Bool { performed.contains(.applyShield) }

    var awards: [RewardReason] {
        performed.compactMap { if case .awardParticipation(let reason) = $0 { reason } else { nil } }
    }

    var outcomes: [PauseOutcome] {
        performed.compactMap { if case .logPauseOutcome(let outcome) = $0 { outcome } else { nil } }
    }
}
