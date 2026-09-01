import Foundation

/// What recovery concluded about a persisted session. Reported so the app can
/// log it and the tests can assert on the reasoning, not just the result.
public enum ColdStartVerdict: String, CaseIterable, Hashable, Sendable {
    /// Nothing was persisted. Either no pause was in flight, or the write never
    /// landed. Both are handled the same way: clear anyway.
    case noSessionFound
    /// The record is structurally impossible — ends before it starts, lasts
    /// longer than any pause HopPotty schedules, carries a state that is never
    /// written, or belongs to a different child.
    case sessionMalformed
    /// The record starts in the future. The clock moved backwards.
    case clockMovedBackwards
    /// The pause ceiling has already passed.
    case sessionExpired
    /// A pause was genuinely in flight when the process died.
    case interruptedMidPause
    /// As above, and the child had already engaged with the routine.
    case interruptedAfterEngagement
}

/// The result of a cold start.
public struct ColdStartRecovery: Hashable, Sendable {
    public let state: PottyPauseState
    public let effects: [PottyPauseEffect]
    public let verdict: ColdStartVerdict

    public init(state: PottyPauseState, effects: [PottyPauseEffect], verdict: ColdStartVerdict) {
        self.state = state
        self.effects = effects
        self.verdict = verdict
    }

    /// The same result shaped like any other transition, for an app layer that
    /// wants one execution path.
    public var outcome: TransitionOutcome { .accept(state, effects) }

    public var clearsShield: Bool { effects.contains(.clearShield) }
}

public extension PottyPauseMachine {

    /// Reconstruct safe state after the app was killed, crashed, the device
    /// restarted, or a Screen Time extension died.
    ///
    /// ## Why this always clears
    ///
    /// A `ManagedSettings` shield is system state. It survives the process that
    /// applied it, and it survives a reboot. HopPotty's in-memory state does
    /// not. So on every launch there is exactly one honest statement available:
    /// *a shield may be up and there is no longer anything scheduled to take it
    /// down.* Even the ceiling timer is gone — timers die with the process.
    ///
    /// Every branch below therefore emits `.clearShield` first, including the
    /// branch where nothing at all was persisted. Clearing is idempotent
    /// (`store.clearAllSettings()` on an already-clear store), so the cost of a
    /// needless clear is one no-op call at launch. The cost of a missed one is a
    /// child holding a device that will not open anything, with no timer left to
    /// fix it and no way for them to explain the problem.
    ///
    /// The mirror-image decision — "the pause was only 40 seconds in, put the
    /// shield back" — is never taken. A pause interrupted by a crash is over.
    /// Re-shielding after a crash would mean a bug in HopPotty could keep a
    /// child's apps locked across relaunches, which is the one failure mode this
    /// component exists to make impossible.
    ///
    /// ## Order of checks
    ///
    /// Integrity before the clock, and the clock in both directions, because a
    /// record that cannot be trusted about *when* must not be trusted about
    /// *whether*:
    ///
    /// 1. nothing persisted → clear
    /// 2. malformed or another child's record → clear
    /// 3. `startedAt` in the future (clock moved backwards) → clear
    /// 4. `expiresAt` already passed → clear
    /// 5. genuinely mid-pause → clear, and award the star if the child had
    ///    already engaged
    ///
    /// Note what is *not* consulted: the time zone, the calendar, and any wall
    /// clock. `startedAt`/`expiresAt` are absolute instants, so a family flying
    /// to another zone or a daylight-saving change cannot move an expiry. A
    /// travelling family gets the same answer as a stationary one.
    ///
    /// - Parameters:
    ///   - persisted: the session read from disk, if any.
    ///   - now: the current instant.
    ///   - context: the live configuration, when the caller has one. The app
    ///     always passes it and gets a re-armed state back. A Screen Time
    ///     extension has no access to the schedule store, passes `nil`, and gets
    ///     `.disabled` — nothing shielded, nothing armed — which the app then
    ///     re-arms with `.scheduleEnabled` once it can read the schedule. That
    ///     is the safe direction to be wrong in: a schedule that needs one
    ///     explicit re-arm, rather than a shield that needs one.
    static func recoverFromColdStart(
        persisted: PersistedPauseSession?,
        now: Date,
        context: PottyPauseContext? = nil
    ) -> ColdStartRecovery {
        let (restingState, restingEffects) = restingState(context)

        // Performed in this order: clear first, tidy up after. If the process
        // dies again part-way through, it dies with the shield already down and
        // the session still on disk, so the next launch simply repeats this.
        // Awards are idempotent by `RewardTransaction.idempotencyKey`, so a
        // repeated recovery cannot double-award, and nothing here can subtract.
        var effects: [PottyPauseEffect] = [
            .clearShield,
            .cancelPauseTimer,
            .cancelWarningNotification,
            .dismissPauseScreen,
        ]

        guard let persisted else {
            effects.append(.clearPersistedSession)
            return ColdStartRecovery(
                state: restingState,
                effects: effects + restingEffects,
                verdict: .noSessionFound
            )
        }

        let verdict: ColdStartVerdict
        if !persisted.isWellFormed || !(context.map { persisted.belongs(to: $0.childID) } ?? true) {
            verdict = .sessionMalformed
        } else if persisted.isFromTheFuture(at: now) {
            verdict = .clockMovedBackwards
        } else if persisted.hasExpired(at: now) {
            verdict = .sessionExpired
        } else if persisted.childHadEngaged {
            verdict = .interruptedAfterEngagement
        } else {
            verdict = .interruptedMidPause
        }

        if verdict == .interruptedAfterEngagement {
            // The child went and did the thing; the crash is HopPotty's problem,
            // not theirs. Stars are never withheld for a technical failure.
            effects.append(.awardParticipation(.answeredPottyPause))
        }
        if verdict != .sessionMalformed {
            effects.append(.logPauseOutcome(.interruptedByProcessDeath))
        }
        if persisted.state.mayHaveShieldUp {
            // The caregiver is told, because from the child's side the apps
            // silently came back and someone should know why.
            effects.append(.notifyParent(.accessRestoredAfterInterruption))
        }
        effects.append(.clearPersistedSession)

        return ColdStartRecovery(
            state: restingState,
            effects: effects + restingEffects,
            verdict: verdict
        )
    }

    /// Where a recovered launch lands once the shield is down.
    ///
    /// Never a shield-bearing state, never `cooldown` (there is no trustworthy
    /// record of when a cooldown would end), and never `monitoring` — the
    /// monitoring registration died with the process, so the app must register
    /// again and be told it worked before HopPotty claims to be armed.
    private static func restingState(
        _ context: PottyPauseContext?
    ) -> (PottyPauseState, [PottyPauseEffect]) {
        guard let context else { return (.disabled, []) }
        guard context.isScheduleLive else { return (.disabled, [.cancelMonitoring]) }
        if context.requiresAuthorization && !context.isAuthorized {
            return (.authorizationRequired, [.requestAuthorization])
        }
        if !context.selectionSatisfied {
            return (.errorRequiresParent(.noSelection), [.notifyParent(.screenTimeFailure(.noSelection))])
        }
        return (.ready, [.registerMonitoring])
    }
}
