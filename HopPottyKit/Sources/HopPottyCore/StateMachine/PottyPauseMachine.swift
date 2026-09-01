import Foundation

/// The Potty Pause state machine.
///
/// One pure, total function — `reduce(state:event:context:)` — plus one entry
/// point for reconstructing safe state after the process died,
/// `recoverFromColdStart(persisted:now:context:)`.
///
/// ## The rule this exists to enforce
///
/// > Screen access is never contingent on a biological outcome.
///
/// A pause ends in exactly three ways: the child completes the routine, the
/// ceiling timer elapses, or a caregiver overrides. All three restore access.
/// There is no fourth way, no branch that inspects what the child produced, and
/// no state a shield can sit in indefinitely. `CONTRACTS.md` §4.1.
///
/// ## Fail-safe posture
///
/// Every ambiguity resolves toward the child having access:
///
/// 1. `.clearShield` is idempotent, so it is emitted whenever it *might* help,
///    including on paths that believe the shield is already down.
/// 2. Every transition that leaves a possibly-shielded state for a definitely
///    unshielded one emits `.clearShield` first in its effect list.
/// 3. Every transition into an error state emits `.clearShield`. An error state
///    is by definition one where HopPotty does not know what is true.
/// 4. `.parentRestoredAccess`, `.scheduleDisabled` and `.authorizationRevoked`
///    are accepted from all thirteen states and never refused.
/// 5. Cold start always clears, whatever it finds — see the recovery section.
public enum PottyPauseMachine {

    // MARK: - The reducer

    /// Apply one event to one state. Total: defined for every pair.
    public static func reduce(
        state: PottyPauseState,
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        // Three events outrank the state table entirely. Each one either takes
        // access away from HopPotty or gives it back to the child, and neither
        // is something a state should be able to refuse.
        if let failSafe = reduceFailSafe(state: state, event: event, context: context) {
            return failSafe
        }

        switch state {
        case .disabled:
            return reduceDisabled(event: event, context: context)
        case .authorizationRequired:
            return reduceAuthorizationRequired(event: event, context: context)
        case .ready:
            return reduceReady(event: event, context: context)
        case .monitoring:
            return reduceMonitoring(event: event, context: context)
        case .warningApproaching:
            return reduceWarningApproaching(event: event, context: context)
        case .pauseTriggered:
            return reducePauseTriggered(event: event, context: context)
        case .shieldActive:
            return reduceShieldActive(event: event, context: context)
        case .routineActive:
            return reduceRoutineActive(event: event, context: context)
        case .completing:
            return reduceCompleting(event: event, context: context)
        case .restoring:
            return reduceRestoring(event: event, context: context)
        case .cooldown:
            return reduceCooldown(event: event, context: context)
        case .errorRecoverable(let failure):
            return reduceErrorRecoverable(failure: failure, event: event, context: context)
        case .errorRequiresParent(let failure):
            return reduceErrorRequiresParent(failure: failure, event: event, context: context)
        case .errorAccessRestored(let failure):
            return reduceErrorAccessRestored(failure: failure, event: event, context: context)
        }
    }

    // MARK: - Fail-safe events, accepted from every state

    private static func reduceFailSafe(
        state: PottyPauseState,
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome? {
        switch event {
        case .parentRestoredAccess:
            return parentRestoredAccess(from: state, context: context)
        case .scheduleDisabled:
            return scheduleDisabled(from: state, context: context)
        case .authorizationRevoked:
            return authorizationRevoked(from: state, context: context)
        default:
            return nil
        }
    }

    /// The emergency exit, from anywhere.
    ///
    /// A caregiver pressing "give the apps back" must not have to be right about
    /// what HopPotty currently thinks. Every branch clears, and every branch
    /// lands somewhere `mayHaveShieldUp` is false.
    private static func parentRestoredAccess(
        from state: PottyPauseState,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        if let failure = state.failure {
            // Clearing the shield does not fix a revoked permission or an empty
            // selection, so the failure stays on screen for the caregiver — but
            // the child gets their apps back regardless, and the state stops
            // claiming a shield might still be standing.
            return .accept(.errorAccessRestored(failure), [
                .clearShield,
                .cancelPauseTimer,
                .dismissPauseScreen,
                .clearPersistedSession,
                .notifyParent(.accessRestoredByParent),
            ])
        }

        if state.isPauseInFlight {
            return .accept(.cooldown, [
                .clearShield,
                .cancelPauseTimer,
                .dismissPauseScreen,
                .logPauseOutcome(.parentOverride),
                .clearPersistedSession,
                .beginCooldown(until: context.cooldownEnd),
                .notifyParent(.accessRestoredByParent),
            ])
        }

        if state.isArmed {
            // Mid-approach, "restore access" means "not this time" — so the
            // countdown is dropped and the quiet period starts.
            return .accept(.cooldown, [
                .clearShield,
                .cancelWarningNotification,
                .clearPersistedSession,
                .beginCooldown(until: context.cooldownEnd),
            ])
        }

        // Nothing was shielded. Sweep anyway: the cost is one no-op call, and
        // the alternative is trusting that our idea of "nothing" is correct.
        return .accept(state, [.clearShield, .clearPersistedSession])
    }

    /// The caregiver switched Potty Pause off. Nothing survives that.
    private static func scheduleDisabled(
        from state: PottyPauseState,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        var effects: [PottyPauseEffect] = [
            .clearShield,
            .cancelPauseTimer,
            .cancelWarningNotification,
            .cancelMonitoring,
            .dismissPauseScreen,
        ]
        if state.isPauseInFlight {
            effects.append(.logPauseOutcome(.parentOverride))
        }
        effects.append(.clearPersistedSession)
        return .accept(.disabled, effects)
    }

    /// Authorization went away. If it went away mid-pause the shield may still
    /// be standing and we may no longer have the permission needed to lift it —
    /// which is precisely the situation a caregiver has to be told about.
    private static func authorizationRevoked(
        from state: PottyPauseState,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        if state.mayHaveShieldUp {
            return .accept(.errorRequiresParent(.authorizationRevoked), [
                .clearShield,
                .cancelPauseTimer,
                .dismissPauseScreen,
                .logPauseOutcome(.authorizationLost),
                .persistSession(context.session(advancedTo: .errorRequiresParent(.authorizationRevoked))),
                .notifyParent(.screenTimeFailure(.authorizationRevoked)),
            ])
        }
        if state == .disabled {
            return .accept(.disabled, [.clearShield])
        }
        return .accept(.authorizationRequired, [
            .clearShield,
            .cancelWarningNotification,
            .cancelMonitoring,
            .clearPersistedSession,
            .notifyParent(.screenTimeFailure(.authorizationRevoked)),
        ])
    }

    // MARK: - Idle states

    private static func reduceDisabled(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .scheduleEnabled:
            return enterLiveState(context: context)
        default:
            return .refuse(state: .disabled, event: event)
        }
    }

    private static func reduceAuthorizationRequired(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .authorizationGranted:
            guard context.selectionSatisfied else {
                return .accept(.errorRequiresParent(.noSelection), [
                    .clearShield, .notifyParent(.screenTimeFailure(.noSelection)),
                ])
            }
            return .accept(.ready, [.registerMonitoring])
        case .authorizationDenied:
            // Staying put is the honest answer: HopPotty genuinely cannot shield
            // and will not pretend the schedule is running.
            return .accept(.authorizationRequired, [.clearShield, .notifyParent(.authorizationNeeded)])
        case .scheduleEnabled, .retryRequested, .parentAcknowledgedError:
            return .accept(.authorizationRequired, [.requestAuthorization])
        case .shieldCleared:
            return .accept(.authorizationRequired, [])
        default:
            return .refuse(state: .authorizationRequired, event: event)
        }
    }

    private static func reduceReady(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .monitoringRegistered:
            return .accept(.monitoring, warningEffects(context))
        case .monitoringRegistrationFailed:
            return enterError(
                .errorRecoverable(.monitoringRegistrationFailed),
                context: context,
                persistSession: false
            )
        case .scheduleEnabled, .retryRequested:
            return .accept(.ready, [.registerMonitoring])
        case .shieldCleared:
            return .accept(.ready, [])
        default:
            return .refuse(state: .ready, event: event)
        }
    }

    // MARK: - Armed states

    private static func reduceMonitoring(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .warningThresholdReached:
            return .accept(.warningApproaching, [.presentWarning])
        case .pauseThresholdReached:
            return beginPause(context: context)
        case .monitoringRegistered:
            // Re-registration after a schedule edit. Nothing to do.
            return .accept(.monitoring, [])
        case .monitoringRegistrationFailed:
            return enterError(
                .errorRecoverable(.monitoringRegistrationFailed),
                context: context,
                persistSession: false
            )
        case .shieldCleared:
            // A stray confirmation from a previous pause. It can only ever mean
            // the child has more access, so it is never treated as a problem.
            return .accept(.monitoring, [])
        default:
            return .refuse(state: .monitoring, event: event)
        }
    }

    private static func reduceWarningApproaching(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .pauseThresholdReached:
            return beginPause(context: context)
        case .warningThresholdReached:
            return .accept(.warningApproaching, [])
        case .childAcknowledged:
            // The child chose to go before being interrupted. There is nothing
            // to shield in that case — going early is rewarded with the routine,
            // not with a lock.
            let session = context.startingSession(state: .routineActive)
            return .accept(.routineActive, [
                .cancelWarningNotification,
                .persistSession(session),
                .startPauseTimer(expiresAt: session.expiresAt),
                .presentPauseScreen,
                .awardParticipation(.answeredPottyPause),
            ])
        case .monitoringRegistrationFailed:
            return enterError(
                .errorRecoverable(.monitoringRegistrationFailed),
                context: context,
                persistSession: false
            )
        case .shieldCleared:
            return .accept(.warningApproaching, [])
        default:
            return .refuse(state: .warningApproaching, event: event)
        }
    }

    /// The one place a shield is ever raised.
    ///
    /// Three gates in order — authorization, selection, mode — and each failure
    /// clears rather than proceeds.
    private static func beginPause(context: PottyPauseContext) -> TransitionOutcome {
        if context.requiresAuthorization && !context.isAuthorized {
            return .accept(.authorizationRequired, [
                .clearShield,
                .cancelWarningNotification,
                .cancelMonitoring,
                .requestAuthorization,
                .notifyParent(.authorizationNeeded),
            ])
        }

        if !context.selectionSatisfied {
            return .accept(.errorRequiresParent(.noSelection), [
                .clearShield,
                .cancelWarningNotification,
                .logPauseOutcome(.couldNotStart),
                .notifyParent(.screenTimeFailure(.noSelection)),
            ])
        }

        guard context.shieldsApps else {
            // Gentle mode: a reminder, never a shield. It still runs the full
            // routine lifecycle so the timeline and the star ledger see the same
            // shape of session whichever mode a family uses.
            let session = context.startingSession(state: .routineActive)
            return .accept(.routineActive, [
                .cancelWarningNotification,
                .persistSession(session),
                .startPauseTimer(expiresAt: session.expiresAt),
                .presentPauseScreen,
            ])
        }

        let session = context.startingSession(state: .pauseTriggered)
        return .accept(.pauseTriggered, [
            .cancelWarningNotification,
            .persistSession(session),
            // The ceiling timer is armed *before* the shield goes up, so there
            // is no window in which a shield exists with nothing scheduled to
            // take it down.
            .startPauseTimer(expiresAt: session.expiresAt),
            .applyShield,
        ])
    }

    // MARK: - Paused states

    private static func reducePauseTriggered(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .shieldApplied:
            return .accept(.shieldActive, [
                .presentPauseScreen,
                .persistSession(context.session(advancedTo: .shieldActive)),
            ])
        case .shieldApplyFailed:
            // A failed apply may still have set *some* settings, so this clears
            // before it reports.
            return enterError(.errorRecoverable(.shieldApplyFailed), context: context, persistSession: true)
        case .pauseTimerExpired:
            return beginRestore(reason: .timerExpired, context: context)
        case .routineCompleted:
            return completeRoutine(context: context)
        default:
            return .refuse(state: .pauseTriggered, event: event)
        }
    }

    private static func reduceShieldActive(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .childAcknowledged:
            // Answering the door is the reward-worthy act. What happens in the
            // bathroom is not HopPotty's business and never affects the shield.
            return .accept(.routineActive, [
                .persistSession(context.session(advancedTo: .routineActive)),
                .awardParticipation(.answeredPottyPause),
            ])
        case .routineCompleted:
            return completeRoutine(context: context)
        case .pauseTimerExpired:
            return beginRestore(reason: .timerExpired, context: context)
        case .shieldApplied:
            return .accept(.shieldActive, [])
        case .shieldApplyFailed:
            return enterError(.errorRecoverable(.shieldApplyFailed), context: context, persistSession: true)
        default:
            return .refuse(state: .shieldActive, event: event)
        }
    }

    private static func reduceRoutineActive(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .routineCompleted:
            return completeRoutine(context: context)
        case .pauseTimerExpired:
            // The ceiling elapses mid-routine. Access comes back anyway; the
            // child can finish in the bathroom without an app holding them to it.
            return beginRestore(reason: .timerExpired, context: context)
        case .childAcknowledged:
            return .accept(.routineActive, [])
        case .shieldApplied:
            return .accept(.routineActive, [])
        case .shieldApplyFailed:
            return enterError(.errorRecoverable(.shieldApplyFailed), context: context, persistSession: true)
        default:
            return .refuse(state: .routineActive, event: event)
        }
    }

    /// The routine finished. Access is restored *immediately* — the celebration
    /// runs on top of unshielded apps, because holding a shield open for an
    /// animation is holding it open for no reason.
    private static func completeRoutine(context: PottyPauseContext) -> TransitionOutcome {
        .accept(.completing, [
            .clearShield,
            .cancelPauseTimer,
            .dismissPauseScreen,
            .awardParticipation(.completedRoutine),
            .logPauseOutcome(.completedRoutine),
            .persistSession(context.session(advancedTo: .completing)),
        ])
    }

    private static func beginRestore(
        reason: PauseOutcome,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        .accept(.restoring, [
            .clearShield,
            .cancelPauseTimer,
            .dismissPauseScreen,
            .logPauseOutcome(reason),
            .persistSession(context.session(advancedTo: .restoring)),
        ])
    }

    private static func reduceCompleting(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .completionAcknowledged, .pauseTimerExpired:
            return .accept(.restoring, [
                .clearShield,
                .cancelPauseTimer,
                .persistSession(context.session(advancedTo: .restoring)),
            ])
        case .shieldCleared:
            return enterCooldown(context: context)
        case .shieldClearFailed:
            return enterError(.errorRecoverable(.shieldClearFailed), context: context, persistSession: true)
        case .routineCompleted:
            return .accept(.completing, [])
        default:
            return .refuse(state: .completing, event: event)
        }
    }

    private static func reduceRestoring(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .shieldCleared:
            return enterCooldown(context: context)
        case .shieldClearFailed:
            // The most dangerous failure in the product: apps may still be
            // blocked and the lift did not work. Retry, and tell the caregiver
            // now rather than after the second attempt.
            return enterError(.errorRecoverable(.shieldClearFailed), context: context, persistSession: true)
        case .pauseTimerExpired, .retryRequested, .completionAcknowledged:
            return .accept(.restoring, [.clearShield])
        case .routineCompleted, .childAcknowledged:
            return .accept(.restoring, [.clearShield])
        default:
            return .refuse(state: .restoring, event: event)
        }
    }

    private static func enterCooldown(context: PottyPauseContext) -> TransitionOutcome {
        // `.clearShield` is redundant on this path — the executor just told us
        // the store is clear — and it is emitted anyway. See `PottyPauseEffect`.
        .accept(.cooldown, [
            .clearShield,
            .dismissPauseScreen,
            .clearPersistedSession,
            .beginCooldown(until: context.cooldownEnd),
        ])
    }

    private static func reduceCooldown(
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        switch event {
        case .cooldownElapsed:
            // Monitoring registration outlives a pause, so the schedule is armed
            // again the moment the quiet period ends.
            return .accept(.monitoring, warningEffects(context))
        case .pauseThresholdReached, .warningThresholdReached:
            return .refuse(state: .cooldown, event: event, reason: .cooldownNotElapsed)
        case .shieldCleared:
            return .accept(.cooldown, [])
        case .monitoringRegistrationFailed:
            return enterError(
                .errorRecoverable(.monitoringRegistrationFailed),
                context: context,
                persistSession: false
            )
        default:
            return .refuse(state: .cooldown, event: event)
        }
    }

    // MARK: - Error states

    /// Entering an error always clears. An error is a state in which HopPotty
    /// does not know what is true, and not knowing is resolved in the child's
    /// favour.
    private static func enterError(
        _ state: PottyPauseState,
        context: PottyPauseContext,
        persistSession: Bool
    ) -> TransitionOutcome {
        var effects: [PottyPauseEffect] = [.clearShield, .cancelPauseTimer, .dismissPauseScreen]
        if persistSession {
            effects.append(.persistSession(context.session(advancedTo: state)))
        } else {
            effects.append(.clearPersistedSession)
        }
        if let failure = state.failure {
            effects.append(.notifyParent(.screenTimeFailure(failure)))
        }
        return .accept(state, effects)
    }

    private static func reduceErrorRecoverable(
        failure: ScreenTimeFailure,
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        let state = PottyPauseState.errorRecoverable(failure)
        switch event {
        case .retryRequested:
            if failure == .shieldClearFailed {
                // Retrying a failed lift means lifting again, not re-arming.
                return .accept(.restoring, [
                    .clearShield,
                    .persistSession(context.session(advancedTo: .restoring)),
                ])
            }
            return .accept(.ready, [.clearShield, .clearPersistedSession, .registerMonitoring])
        case .shieldCleared:
            return .accept(.ready, [.clearShield, .clearPersistedSession, .registerMonitoring])
        case .shieldClearFailed:
            // Second failure. Stop retrying silently and hand it to a caregiver,
            // who can lift the shield from Settings if it comes to that.
            return .accept(.errorRequiresParent(.shieldClearFailed), [
                .clearShield,
                .persistSession(context.session(advancedTo: .errorRequiresParent(.shieldClearFailed))),
                .notifyParent(.screenTimeFailure(.shieldClearFailed)),
            ])
        case .shieldApplyFailed:
            return .accept(.errorRecoverable(.shieldApplyFailed), [
                .clearShield, .notifyParent(.screenTimeFailure(.shieldApplyFailed)),
            ])
        case .monitoringRegistered:
            return .accept(.monitoring, [.clearShield, .clearPersistedSession] + warningEffects(context))
        case .monitoringRegistrationFailed:
            return .accept(.errorRecoverable(.monitoringRegistrationFailed), [
                .clearShield, .notifyParent(.screenTimeFailure(.monitoringRegistrationFailed)),
            ])
        case .parentAcknowledgedError, .authorizationGranted, .scheduleEnabled:
            return resumeAfterError(context: context)
        case .authorizationDenied:
            return .accept(.authorizationRequired, [
                .clearShield, .cancelMonitoring, .clearPersistedSession, .notifyParent(.authorizationNeeded),
            ])
        default:
            return .refuse(state: state, event: event)
        }
    }

    private static func reduceErrorRequiresParent(
        failure: ScreenTimeFailure,
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        let state = PottyPauseState.errorRequiresParent(failure)
        switch event {
        case .parentAcknowledgedError, .authorizationGranted, .scheduleEnabled:
            return resumeAfterError(context: context)
        case .retryRequested:
            guard failure == .shieldClearFailed || failure == .shieldApplyFailed else {
                // Retrying will not conjure a permission or an app selection.
                return .refuse(state: state, event: event, reason: .requiresParentAction)
            }
            return .accept(.restoring, [
                .clearShield,
                .persistSession(context.session(advancedTo: .restoring)),
            ])
        case .shieldCleared:
            return .accept(.ready, [.clearShield, .clearPersistedSession, .registerMonitoring])
        case .shieldClearFailed:
            return .accept(state, [.clearShield, .notifyParent(.screenTimeFailure(.shieldClearFailed))])
        case .authorizationDenied:
            return .accept(.authorizationRequired, [
                .clearShield, .cancelMonitoring, .clearPersistedSession, .notifyParent(.authorizationNeeded),
            ])
        default:
            return .refuse(state: state, event: event)
        }
    }

    /// The failure is unresolved but the apps are back. Nothing here may raise a
    /// shield: this state exists precisely because a caregiver asked for the
    /// opposite, so the only ways out are fixing the cause or switching off.
    private static func reduceErrorAccessRestored(
        failure: ScreenTimeFailure,
        event: PottyPauseEvent,
        context: PottyPauseContext
    ) -> TransitionOutcome {
        let state = PottyPauseState.errorAccessRestored(failure)
        switch event {
        case .parentAcknowledgedError, .authorizationGranted, .scheduleEnabled:
            return resumeAfterError(context: context)
        case .retryRequested:
            guard failure.isSelfRecoverable else {
                return .refuse(state: state, event: event, reason: .requiresParentAction)
            }
            return resumeAfterError(context: context)
        case .authorizationDenied:
            return .accept(.authorizationRequired, [
                .clearShield, .cancelMonitoring, .clearPersistedSession, .notifyParent(.authorizationNeeded),
            ])
        case .shieldCleared:
            // Confirmation of what this state already assumed. The clear is
            // re-issued anyway so that "entering an error state always clears"
            // holds without exception — an invariant with a carve-out is one
            // nobody can rely on.
            return .accept(state, [.clearShield, .clearPersistedSession])
        case .shieldClearFailed:
            // The clear did not take after all, so the shield is back in
            // question and the state must say so.
            return .accept(.errorRequiresParent(.shieldClearFailed), [
                .clearShield, .notifyParent(.screenTimeFailure(.shieldClearFailed)),
            ])
        default:
            return .refuse(state: state, event: event)
        }
    }

    /// Leaving an error state re-runs the same gates as enabling the schedule,
    /// so a caregiver who fixed nothing lands back on the error that describes
    /// what is still wrong rather than on a `ready` state that is a lie.
    private static func resumeAfterError(context: PottyPauseContext) -> TransitionOutcome {
        enterLiveState(context: context)
    }

    // MARK: - Shared builders

    /// The gate every "start running" path goes through: schedule on,
    /// authorization present, something selected.
    ///
    /// It always sweeps the shield first. Enabling a schedule and recovering
    /// from an error are the two moments when HopPotty's idea of the world is
    /// least likely to match `ManagedSettings`, so both begin by making the one
    /// statement that is always safe to make.
    private static func enterLiveState(context: PottyPauseContext) -> TransitionOutcome {
        var prefix: [PottyPauseEffect] = [.clearShield]

        guard context.isScheduleLive else {
            prefix.append(.cancelMonitoring)
            prefix.append(.clearPersistedSession)
            return .accept(.disabled, prefix)
        }
        if context.requiresAuthorization && !context.isAuthorized {
            prefix.append(.requestAuthorization)
            return .accept(.authorizationRequired, prefix)
        }
        if !context.selectionSatisfied {
            prefix.append(.notifyParent(.screenTimeFailure(.noSelection)))
            return .accept(.errorRequiresParent(.noSelection), prefix)
        }
        prefix.append(.clearPersistedSession)
        prefix.append(.registerMonitoring)
        return .accept(.ready, prefix)
    }

    private static func warningEffects(_ context: PottyPauseContext) -> [PottyPauseEffect] {
        let lead = context.warningLeadTime
        guard lead > 0 else { return [] }
        return [.scheduleWarningNotification(leadTime: lead)]
    }
}
