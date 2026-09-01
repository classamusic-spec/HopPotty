import Foundation
import HopPottyCore
#if canImport(ManagedSettings)
import ManagedSettings
#endif

// MARK: - Target membership
//
// SHARED BY ALL FOUR TARGETS. See the note at the top of `ScreenTimeIdentifiers.swift`.

/// The fail-safe.
///
/// ## The problem this exists to solve
///
/// A `ManagedSettingsStore` shield is *system* state. Apple documents neither its
/// lifetime across a restart nor across app termination
/// (`Docs/ScreenTimeArchitecture.md` §5), which is precisely why it must be
/// assumed to outlive everything: the app being force-quit, an extension
/// crashing, the app being evicted from memory, a reboot. HopPotty's own state
/// survives none of those.
///
/// So the failure mode of this feature is not "a pause does not happen". It is
/// **a child whose games never come back**, with no in-app way to explain it,
/// because every process that knew about the pause is gone.
///
/// Every rule below therefore resolves the same way. **When it is not certain
/// that a shield should still be up, the shield comes down.** A pause that ends
/// two minutes early is a minor product defect and is explicitly permitted —
/// Contract §4.1 says a pause ends on its timer, on completion, or on caregiver
/// override, and nothing in the product may ever *extend* one. A shield that
/// outlives its session is the thing that gets a parenting app deleted, and
/// deservedly.
///
/// ## The four places this runs
///
/// 1. **Every app launch and every foreground.** The app is the only target with
///    a UI, so it is the only one that can tell a caregiver what happened.
/// 2. **Every `DeviceActivityMonitor` callback.** Woken by the system on its own
///    schedule; often the first thing to run after a crash.
/// 3. **Every `ShieldConfigurationDataSource` invocation.** The strongest
///    guarantee in the design, and the reason a stranded shield is self-healing:
///    iOS calls the configuration extension *whenever it needs to draw the
///    shield*, which is the exact moment a child is looking at a blocked app. No
///    tap is required.
/// 4. **Every `ShieldActionDelegate` invocation.** The child has now definitely
///    tapped. Last line of defence, and the only one that can respond `.close`.
///
/// After a device restart, 3 and 4 are what run first, because nothing else is
/// scheduled to. That is deliberate: recovery is anchored to the shield itself
/// rather than to any timer, so it cannot be missed by a process that never woke.
///
/// ## Why the decision is a pure function
///
/// ``decide(_:)`` takes a snapshot and returns a verdict. It touches no
/// frameworks, so the entire fail-safe rulebook is exercisable in tests on Linux
/// with no entitlements and no device — including cases that are close to
/// impossible to stage on hardware, like a clock moved backwards mid-pause.
public enum ShieldReconciler {

    // MARK: - Verdict

    public enum Verdict: Equatable, Sendable {
        /// A pause is genuinely in flight and has not reached any ceiling.
        case leaveShieldUp
        /// Clear now. Always safe; always idempotent.
        case clearShield(ClearReason)

        public var clears: Bool {
            if case .clearShield = self { return true }
            return false
        }

        public var reason: ClearReason? {
            if case .clearShield(let reason) = self { return reason }
            return nil
        }
    }

    /// Why a shield came down.
    ///
    /// Named for the *condition*, never for a generic "error", because "HopPotty
    /// restarted and unlocked the apps to be safe" is a sentence a caregiver can
    /// act on and "an error occurred" is not. Each maps to one `ParentNotice` or
    /// `PauseOutcome` in the app layer.
    public enum ClearReason: String, Equatable, Sendable, CaseIterable {
        /// The ordinary path: the intended duration elapsed.
        case pauseEnded
        /// The 15-minute backstop interval ended. Every other end-path missed.
        case backstopElapsed
        /// The child finished the routine on the shield itself.
        case childCompleted
        /// A shield exists but no session claims it.
        case noSession
        /// `plannedEndAt` has passed.
        case expired
        /// The record is structurally impossible.
        case malformedSession
        /// `now` is before the recorded start. The clock moved backwards.
        case clockMovedBackwards
        /// System uptime is lower than at session start: the device rebooted, so
        /// no timer that was going to end this pause still exists.
        case deviceRestarted
        /// Nothing has checked in for longer than any pause can last.
        case staleState
        /// Family Controls authorization is gone.
        case authorizationLost
        /// A caregiver asked for their child's apps back.
        case parentRestoredAccess
        /// The caregiver switched Potty Pause off entirely.
        case scheduleDisabled
        /// The Potty Pause Lab, or a developer.
        case manual
        /// The shared container was unreadable, so nothing can be trusted.
        case sharedStateUnavailable

        /// How this ending is recorded on the child's timeline.
        ///
        /// None of these is a success or a failure, and none is about whether the
        /// child produced anything — Contract §4.1 and §4.3.
        public var pauseOutcome: PauseOutcome {
            switch self {
            case .childCompleted: .completedRoutine
            case .pauseEnded, .backstopElapsed, .expired: .timerExpired
            case .parentRestoredAccess, .scheduleDisabled, .manual: .parentOverride
            case .authorizationLost: .authorizationLost
            case .noSession, .malformedSession, .clockMovedBackwards,
                 .deviceRestarted, .staleState, .sharedStateUnavailable:
                .interruptedByProcessDeath
            }
        }

        /// Whether a caregiver should be told, unprompted, that the apps came
        /// back. The ordinary endings are not news; the recovery endings are,
        /// because from the child's side the apps silently reappeared and
        /// somebody should know why.
        public var warrantsParentNotice: Bool {
            switch self {
            case .pauseEnded, .backstopElapsed, .childCompleted, .parentRestoredAccess,
                 .scheduleDisabled, .manual, .expired:
                false
            case .noSession, .malformedSession, .clockMovedBackwards, .deviceRestarted,
                 .staleState, .sharedStateUnavailable, .authorizationLost:
                true
            }
        }
    }

    // MARK: - Tolerances

    /// Clock slack, referenced from `PersistedPauseSession` rather than
    /// redefined, so the app's persisted-session rules and the App Group's
    /// cross-process rules cannot drift apart.
    public static var clockSlack: TimeInterval { PersistedPauseSession.clockSlack }

    /// How far system uptime may appear to regress before we call it a reboot.
    /// Uptime is monotonic within a boot, so any regression at all is a new boot;
    /// this tolerance only absorbs the discrepancy between two processes sampling
    /// it at slightly different moments.
    public static let uptimeSlack: TimeInterval = 5

    /// If no target — not the app, not any extension — has checked in for this
    /// long, the record is abandoned. Comfortably longer than any pause, so a
    /// legitimate pause with every process asleep is never cut short by it.
    public static var staleHeartbeatWindow: TimeInterval {
        PottySchedule.maximumPauseDuration * 3
    }

    // MARK: - The decision
    //
    // Ordered most-certain to least. Every guard is written so that the *absence*
    // of information triggers it: a missing record, a missing container, or an
    // unparseable state all fall through to a clear rather than past it.

    public static func decide(_ snapshot: AppGroupSnapshot) -> Verdict {
        let now = snapshot.observedAt

        // The container is unreachable, so this process cannot know what any
        // other process believes. It can still clear a shield, and clearing is
        // the only action that is safe under total ignorance.
        guard snapshot.isSharedContainerAvailable else {
            return .clearShield(.sharedStateUnavailable)
        }

        // No record, or one written by a schema this build does not understand
        // (`loadPause()` returns `nil` for both). Any shield found here is
        // stranded — this is the branch that recovers from the app being killed
        // between "pause ended" and "shield cleared".
        guard let pause = snapshot.pause else {
            return .clearShield(.noSession)
        }

        guard pause.state.mayHaveShieldUp else {
            return .clearShield(.noSession)
        }

        // Structural checks, independent of the clock. A pause that ends before
        // it begins, or one longer than the product's own ceiling, was not
        // written by this code.
        let plannedDuration = pause.plannedEndAt.timeIntervalSince(pause.startedAt)
        guard plannedDuration > 0,
              plannedDuration <= PottySchedule.maximumPauseDuration + clockSlack,
              pause.backstopEndAt >= pause.plannedEndAt
        else {
            return .clearShield(.malformedSession)
        }

        // The device rebooted. Every timer, every in-memory countdown and the app
        // process itself are gone; the shield is the only survivor. It does not
        // matter that `plannedEndAt` may still be in the future — nothing is left
        // that would act on it.
        //
        // UNVERIFIED — confirm on device: that `ProcessInfo.systemUptime` is
        // measured from boot and does not include, or does consistently include,
        // time asleep in a way that breaks this comparison. Being wrong here ends
        // a pause early; it can never end one late.
        if snapshot.observedUptime + uptimeSlack < pause.startedUptime {
            return .clearShield(.deviceRestarted)
        }

        // The clock moved backwards — a manual change, an NTP correction, or a
        // device that lost power long enough to reset. `plannedEndAt` can no
        // longer be compared to anything meaningfully.
        if now < pause.startedAt.addingTimeInterval(-clockSlack) {
            return .clearShield(.clockMovedBackwards)
        }

        // The backstop, checked before the intended end so its reason wins in the
        // log. Reaching this means paths (A), (B) and (D) all missed.
        if now >= pause.backstopEndAt {
            return .clearShield(.backstopElapsed)
        }

        // The intended end.
        if now >= pause.plannedEndAt {
            return .clearShield(.expired)
        }

        // Nothing has run in longer than three maximum pauses. Whatever wrote
        // this record is not coming back.
        if let latest = snapshot.heartbeats.values.compactMap({ $0 }).max(),
           now.timeIntervalSince(latest) > staleHeartbeatWindow {
            return .clearShield(.staleState)
        }

        // A live pause, inside both ceilings, on a device that has not restarted,
        // with a clock that has not moved. The only path that leaves a child's
        // apps shielded.
        return .leaveShieldUp
    }

    // MARK: - Performing the clear

    #if canImport(ManagedSettings)

    /// Remove every setting HopPotty has ever written.
    ///
    /// ## Why this cannot fail from the caller's point of view
    ///
    /// `clearAllSettings()` on an already-clear store is a no-op, so this is
    /// idempotent by construction and safe to call from anywhere, any number of
    /// times, in any state — including states that "know" the shield is already
    /// down. It is called redundantly on purpose throughout this layer: calling it
    /// twice costs one system write, and failing to call it once costs a child
    /// their apps until an adult notices.
    ///
    /// ## Why it clears two stores
    ///
    /// The named store is the only one HopPotty writes; `Docs/ScreenTimeArchitecture.md`
    /// §5 records the default store as deliberately empty. The default store is
    /// cleared anyway, because a bug — a missing `named:` argument, a bad merge,
    /// an older build still installed over the top — could have written a shield
    /// there, and such a shield would be invisible to a service that only knows
    /// about the named store. `ManagedSettingsStore` is scoped to the containing
    /// app, so clearing HopPotty's default store cannot affect any other app.
    ///
    /// UNVERIFIED — confirm on device: that `clearAllSettings()` removes the
    /// shield promptly, and that a shield removed while the shielded app is
    /// frontmost makes that app usable without a relaunch. Apple is explicit that
    /// "the system doesn't guarantee that the settings you specify govern the
    /// device's behavior" — our writes are inputs to an effective-settings
    /// calculation, not commands.
    ///
    /// UNVERIFIED — confirm on device: whether a store write from *inside the
    /// ShieldConfiguration extension* is honoured. It is attempted there because
    /// that is the earliest possible recovery point; the ShieldAction extension,
    /// the monitor and the app all repeat it, so the design does not depend on
    /// the answer.
    public static func clearAllShields() {
        ManagedSettingsStore(named: .pottyPause).clearAllSettings()
        ManagedSettingsStore().clearAllSettings()
    }

    /// Evaluate and act, in one call, from any target.
    ///
    /// The write order is not negotiable: **clear the shield first, remove the
    /// record second.** The record is the only evidence that a shield might
    /// exist; erasing it first would hide the problem from every process that
    /// runs afterwards. A crash between the two leaves the shield down and the
    /// record present, so the next run simply repeats a no-op clear — the safe
    /// direction to be interrupted in.
    @discardableResult
    public static func reconcile(
        store: AppGroupStore = .shared,
        source: ExtensionReport.Source,
        beating target: AppGroupStore.HeartbeatTarget? = nil,
        now: Date = Date(),
        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Verdict {
        #if DEBUG
        assertStoreNamesAgree()
        #endif

        if let target { store.beat(target, at: now, uptime: uptime) }

        let snapshot = store.snapshot(now: now, uptime: uptime)
        let verdict = decide(snapshot)

        guard case .clearShield(let reason) = verdict else { return verdict }

        clearAllShields()

        // Only report an ending for a pause that existed. A no-op clear on an
        // empty container is the common case — it happens on every cold launch —
        // and filing a report for each one would fill the outbox with nothing.
        if let pause = snapshot.pause, pause.state.mayHaveShieldUp {
            store.appendReport(
                ExtensionReport(
                    source: source,
                    kind: .pauseEnded,
                    at: now,
                    sessionID: pause.sessionID,
                    outcomeCode: reason.pauseOutcome.rawValue,
                    clearReasonCode: reason.rawValue
                )
            )
        }

        store.clearPause()
        return verdict
    }

    /// The emergency exit, callable from anywhere with no preconditions.
    ///
    /// Unlike `reconcile`, this asks no questions: it does not read the snapshot,
    /// does not check authorization, does not consult a state machine, and cannot
    /// decline. A caregiver must never have to reason about what HopPotty thinks
    /// is happening in order to give their child their apps back.
    ///
    /// It is deliberately not `throws` and returns nothing to check. There is no
    /// useful failure to report: if the underlying write did not take, the next
    /// reconciliation — on the next foreground, the next shield draw, the next
    /// tap — repeats it, and the caller has no better recovery available than
    /// trying again, which is what already happens.
    public static func forceClear(
        reason: ClearReason,
        store: AppGroupStore = .shared,
        source: ExtensionReport.Source = .app,
        now: Date = Date()
    ) {
        clearAllShields()
        let sessionID = store.loadPause()?.sessionID
        store.appendReport(
            ExtensionReport(
                source: source,
                kind: .shieldCleared,
                at: now,
                sessionID: sessionID,
                outcomeCode: reason.pauseOutcome.rawValue,
                clearReasonCode: reason.rawValue
            )
        )
        store.clearPause()
    }

    #if DEBUG
    /// The compiler cannot check a string literal against a constant, so this
    /// does, in DEBUG, at every reconciliation. A mismatch means the app and its
    /// extensions are shielding through two different stores — the single worst
    /// misconfiguration this layer has, and one that is otherwise invisible until
    /// a child is holding a device that will not unlock.
    public static func assertStoreNamesAgree() {
        assert(
            ManagedSettingsStore.Name.pottyPause.rawValue == ScreenTimeIdentifiers.managedSettingsStoreName,
            "ManagedSettingsStore.Name.pottyPause must equal ScreenTimeIdentifiers.managedSettingsStoreName"
        )
    }
    #endif

    #endif
}
