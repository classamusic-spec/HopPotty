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
/// A `ManagedSettingsStore` shield is *system* state. It survives the app being
/// force-quit, an extension crashing, the app being deleted from memory, and a
/// device restart. HopPotty's own state survives none of those. So the failure
/// mode of this feature is not "a pause does not happen" — it is **a child whose
/// games never come back**, with no in-app way to explain it, because the process
/// that knew about the pause is gone.
///
/// Every rule below therefore resolves the same way. **When it is not certain
/// that a shield should still be up, the shield comes down.** A pause that ends
/// two minutes early is a minor product defect. A shield that outlives its
/// session is the thing that gets a parenting app deleted, and deservedly.
///
/// ## The four places this runs
///
/// 1. **Every app launch and every foreground.** The app is the only target with
///    a UI, so it is the only one that can tell a caregiver what happened.
/// 2. **Every `DeviceActivityMonitor` callback.** The extension is woken by the
///    system on its own schedule and is often the first thing to run after a
///    crash.
/// 3. **Every `ShieldConfigurationDataSource` invocation.** This is the strongest
///    guarantee in the whole design and the reason a stranded shield is
///    self-healing: iOS calls the configuration extension *whenever it needs to
///    draw the shield*, which is the exact moment a child is looking at a
///    blocked app. If the session is stale, the child's tap is not even required.
/// 4. **Every `ShieldActionDelegate` invocation.** The child has now definitely
///    tapped. Last line of defence, and the one that can respond `.close`.
///
/// After a device restart, targets 3 and 4 are what run first, because nothing
/// else is scheduled to. That is deliberate: the recovery path is anchored to the
/// shield itself rather than to any timer, so it cannot be missed by a process
/// that never woke up.
///
/// ## Why the decision is a pure function
///
/// `decide(...)` takes a snapshot and two clocks and returns a verdict. It
/// touches no frameworks, so the whole fail-safe rulebook can be exercised in
/// tests on Linux with no entitlements and no device — including the cases that
/// are almost impossible to stage on hardware, like a clock moved backwards
/// mid-pause.
public enum ShieldReconciler {

    // MARK: - Verdict

    public enum Verdict: Equatable, Sendable {
        /// A pause is genuinely in flight and has not reached its ceiling.
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

    /// Why a shield came down. Stored in the App Group so the app can explain it
    /// to a caregiver after the fact, and shown in the Potty Pause Lab.
    ///
    /// Every case except `pauseEnded` describes something the design failed to
    /// prevent. They are named for the *condition*, not for a generic "error",
    /// because "HopPotty restarted and unlocked the apps to be safe" is a
    /// sentence a caregiver can act on and "an error occurred" is not.
    public enum ClearReason: String, Equatable, Sendable, CaseIterable {
        /// The ordinary path: the ceiling elapsed, or the routine finished.
        case pauseEnded
        /// A shield exists but no session claims it.
        case noSession
        /// The record is from a schema this build does not understand.
        case unknownSchema
        /// `expiresAt` has passed.
        case expired
        /// The record is structurally impossible — ends before it starts, or
        /// claims a duration longer than HopPotty will ever schedule.
        case malformedSession
        /// `now` is before the recorded start. The clock moved backwards.
        case clockMovedBackwards
        /// System uptime is lower than it was at session start. The device
        /// rebooted, so no timer that was going to end this pause still exists.
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
    }

    // MARK: - Tolerances

    /// Clock slack, matching `PersistedPauseSession.clockSlack`. Referenced
    /// rather than redefined so the two cannot drift.
    public static var clockSlack: TimeInterval { PersistedPauseSession.clockSlack }

    /// How far system uptime may appear to go backwards before we call it a
    /// reboot. Uptime is monotonic within a boot, so any regression at all is a
    /// new boot; the tolerance only absorbs floating-point noise and the small
    /// discrepancy between two processes sampling it at slightly different times.
    public static let uptimeSlack: TimeInterval = 5

    /// The absolute ceiling on any pause, regardless of what the record claims.
    ///
    /// This is the backstop against a corrupted `expiresAt`. If a record somehow
    /// says a pause expires in the year 2050, this catches it 10 minutes in.
    public static var absoluteCeiling: TimeInterval {
        PottySchedule.maximumPauseDuration + clockSlack
    }

    /// If no target — not the app, not any extension — has checked in for this
    /// long, the record is abandoned. Comfortably longer than any pause, so a
    /// legitimate pause with every process asleep is never cut short by it.
    public static var staleHeartbeatWindow: TimeInterval {
        PottySchedule.maximumPauseDuration * 3
    }

    // MARK: - The decision
    //
    // Ordered most-certain to least. Each guard is written so that the *absence*
    // of information triggers it: a `nil` start, a `nil` expiry, or an
    // unparseable state all fall through to a clear rather than past it.

    public static func decide(_ snapshot: AppGroupSnapshot) -> Verdict {
        let now = snapshot.observedAt

        // The shared container is unreachable, so this process cannot know what
        // any other process believes. It can still clear a shield, and clearing
        // is the only action that is safe under total ignorance.
        guard snapshot.isSharedStoreAvailable else {
            return .clearShield(.sharedStateUnavailable)
        }

        // A record written by a schema we do not understand is not a record.
        guard snapshot.schemaVersion == AppGroupStore.currentSchemaVersion else {
            // Version 0 with no session at all is simply a fresh install, which
            // is `noSession`, not a migration problem. Distinguished only so the
            // Lab and the QA log read sensibly.
            return .clearShield(snapshot.sessionID == nil ? .noSession : .unknownSchema)
        }

        // No pause is supposed to exist. Any shield found here is stranded —
        // this is the branch that recovers from the app being killed between
        // "pause ended" and "shield cleared".
        guard snapshot.pauseState.mayHaveShieldUp else {
            return .clearShield(.noSession)
        }

        // A state that claims a shield but carries no session identity is a
        // half-written record.
        guard snapshot.sessionID != nil else {
            return .clearShield(.noSession)
        }

        guard let startedAt = snapshot.startedAt, let expiresAt = snapshot.expiresAt else {
            return .clearShield(.malformedSession)
        }

        // Structural checks, independent of the clock. A pause that ends before
        // it begins, or one longer than the product's own ceiling, was not
        // written by this code.
        let plannedDuration = expiresAt.timeIntervalSince(startedAt)
        guard plannedDuration > 0, plannedDuration <= PottySchedule.maximumPauseDuration + clockSlack else {
            return .clearShield(.malformedSession)
        }

        // The device rebooted. Every timer, every in-memory countdown and the
        // app process itself are gone; the shield is the only survivor. It does
        // not matter that `expiresAt` may still be in the future — nothing is
        // left that would act on it.
        //
        // UNVERIFIED — confirm on device: that `ProcessInfo.systemUptime` is
        // measured from boot and is not advanced by time spent asleep in a way
        // that breaks this comparison. The consequence of being wrong here is a
        // pause that ends early, never one that ends late.
        if let startedUptime = snapshot.startedUptime,
           snapshot.observedUptime + uptimeSlack < startedUptime {
            return .clearShield(.deviceRestarted)
        }

        // The clock moved backwards — a manual change, an NTP correction, or a
        // device that lost power long enough to reset. `expiresAt` can no longer
        // be compared to anything meaningfully.
        if now < startedAt.addingTimeInterval(-clockSlack) {
            return .clearShield(.clockMovedBackwards)
        }

        // The ordinary ceiling.
        if now >= expiresAt {
            return .clearShield(.expired)
        }

        // Backstop against an `expiresAt` that passed the structural check but is
        // still wrong: measure elapsed time from the start instead.
        if now.timeIntervalSince(startedAt) > absoluteCeiling {
            return .clearShield(.expired)
        }

        // Nothing has run in longer than three maximum pauses. Whatever wrote
        // this record is not coming back.
        if let latest = snapshot.heartbeats.values.compactMap({ $0 }).max(),
           now.timeIntervalSince(latest) > staleHeartbeatWindow {
            return .clearShield(.staleState)
        }

        // A live pause, inside its ceiling, on a device that has not restarted,
        // with a clock that has not moved. This is the only path that leaves a
        // child's apps shielded.
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
    /// times, in any state, including states that "know" the shield is already
    /// down. It is called redundantly on purpose throughout this layer: calling
    /// it twice costs a system write, and failing to call it once costs a child
    /// their apps until an adult notices.
    ///
    /// ## Why it clears two stores
    ///
    /// The named store is the only one HopPotty writes. The unnamed default store
    /// is cleared too, because a bug — a missing `named:` argument, a bad merge,
    /// an older build — could have written a shield there, and the resulting
    /// shield would be invisible to a service that only knows about the named
    /// store. `ManagedSettingsStore` is scoped to the containing app, so clearing
    /// HopPotty's default store cannot affect any other app.
    ///
    /// UNVERIFIED — confirm on device: that `clearAllSettings()` on a named store
    /// removes the shield promptly, and that a shield removed while the shielded
    /// app is frontmost causes that app to become usable without a relaunch.
    /// UNVERIFIED — confirm on device: whether a store write from within the
    /// ShieldConfiguration extension is honoured. It is attempted there because
    /// it is the earliest possible recovery point; the ShieldAction extension and
    /// the app both repeat it, so the design does not depend on the answer.
    public static func clearAllShields() {
        ManagedSettingsStore(named: .pottyPause).clearAllSettings()
        ManagedSettingsStore().clearAllSettings()
    }

    /// Evaluate and act, in one call, from any target.
    ///
    /// This is what every extension entry point and every app launch calls. It
    /// takes its own snapshot, decides, clears if it must, records why, and
    /// returns the verdict so the caller can log or display it.
    ///
    /// The write order matters and is not negotiable: **clear the shield first,
    /// end the session second.** The session record is the only evidence that a
    /// shield might exist; erasing it before the shield is gone would hide the
    /// problem from every process that runs afterwards.
    @discardableResult
    public static func reconcile(
        store: AppGroupStore = .shared,
        beating target: AppGroupStore.HeartbeatTarget? = nil,
        now: Date = Date(),
        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Verdict {
        if let target { store.beat(target, at: now) }

        let verdict = decide(store.snapshot(now: now, uptime: uptime))

        guard case .clearShield(let reason) = verdict else { return verdict }

        clearAllShields()
        store.recordClear(reason: reason.rawValue, at: now)
        store.endSession()
        return verdict
    }

    /// The emergency exit, callable from anywhere with no preconditions.
    ///
    /// Unlike `reconcile`, this asks no questions: it does not read the snapshot,
    /// does not check authorization, does not consult a state machine, and cannot
    /// decline. A caregiver must never have to reason about what HopPotty thinks
    /// is happening in order to give their child their apps back.
    public static func forceClear(
        reason: ClearReason,
        store: AppGroupStore = .shared,
        now: Date = Date()
    ) {
        clearAllShields()
        store.recordClear(reason: reason.rawValue, at: now)
        store.endSession()
    }

    #if DEBUG
    /// The compiler cannot check a string literal against a constant, so this
    /// does, once, in DEBUG, at the first reconciliation. A mismatch here means
    /// the app and its extensions are shielding through two different stores —
    /// the single worst misconfiguration this layer has.
    public static func assertStoreNamesAgree() {
        assert(
            ManagedSettingsStore.Name.pottyPause == ManagedSettingsStore.Name(rawValue: ScreenTimeIdentifiers.managedSettingsStoreName),
            "ManagedSettingsStore.Name.pottyPause must equal ScreenTimeIdentifiers.managedSettingsStoreName"
        )
    }
    #endif

    #endif
}
