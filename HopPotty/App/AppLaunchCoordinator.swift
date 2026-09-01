import Foundation
import OSLog

/// Runs the Screen Time reconciliation that every launch and every foreground
/// owes the child holding the device.
///
/// ## Why this exists at the app-lifecycle level
///
/// A `ManagedSettings` shield is *system* state. It outlives the process that
/// applied it, it outlives an app update, and Apple documents neither its
/// behaviour across a reboot nor across a force-quit
/// (`Docs/ScreenTimeArchitecture.md` §5). HopPotty's in-memory state outlives
/// none of those. So at the moment the app comes up there is exactly one honest
/// statement available:
///
/// > A shield may be up, and there is no longer anything scheduled to take it
/// > down. Even the ceiling timer is gone — timers die with the process.
///
/// Reconciliation is what turns that into a child whose apps work. It is the
/// floor under the four other end-paths (`ScreenTimeArchitecture.md` §9): the
/// shield-action tap, the monitor's warning callback, the 15-minute backstop,
/// and the caregiver override. Each of those can be missed. This one cannot,
/// because it does not depend on being woken — it runs because the app ran.
///
/// ## Why it is safe to run it twice, or ten times
///
/// The verdict is computed by `ShieldReconciler`, which is pure, and clearing is
/// `store.clearAllSettings()`, which is a no-op on an already-clear store. The
/// cost of a redundant reconcile is one no-op call. The cost of a missed one is
/// a child holding a device that will not open anything, with no timer left to
/// fix it and no way for them to explain the problem. So this runs on cold
/// start *and* on every return to the foreground, and it never asks whether it
/// is needed first.
///
/// ## What this deliberately does not do
///
/// It does not drain the extensions' outbox. Draining is destructive — the app
/// reads a `PauseOutcome` and deletes it — and what happens to that outcome
/// (a timeline event, at most one star, keyed for idempotency) is reward logic
/// that belongs to the Potty Pause feature, not to a lifecycle hook. A hook that
/// drained here would silently discard outcomes whenever the feature had not
/// been built yet.
@MainActor
final class AppLaunchCoordinator {

    /// Why reconciliation is running. Logged, so a diagnostic session can tell a
    /// launch-time clear from one that happened when the caregiver came back.
    enum Trigger: String, Sendable {
        /// The process just started. Nothing HopPotty put in memory survived.
        case coldStart
        /// The app returned to the foreground. Shields, extensions and the
        /// caregiver's Settings changes could all have moved underneath us.
        case foreground
    }

    private let screenTime: any ScreenTimeProviding
    private let clock: any HopClock

    /// Whether the cold-start pass has run. Read by the scene so a `.active`
    /// transition that arrives in the same frame as launch does not run the same
    /// work twice — harmless if it did, but noise in the log is noise in the one
    /// place a stranded shield would show up.
    private(set) var hasCompletedColdStart = false

    /// The most recent verdict, for the parent diagnostics screen and the Lab.
    private(set) var lastVerdict: ShieldReconciler.Verdict?

    init(screenTime: any ScreenTimeProviding, clock: any HopClock) {
        self.screenTime = screenTime
        self.clock = clock
    }

    /// The cold-start pass. Idempotent; safe to call from more than one place.
    @discardableResult
    func runColdStartReconciliation() -> ShieldReconciler.Verdict {
        let verdict = reconcile(.coldStart)
        hasCompletedColdStart = true
        return verdict
    }

    /// The foreground pass. Skipped only when cold start has not yet run, in
    /// which case cold start is about to do the same work with a better label.
    @discardableResult
    func runForegroundReconciliation() -> ShieldReconciler.Verdict? {
        guard hasCompletedColdStart else { return nil }
        return reconcile(.foreground)
    }

    private func reconcile(_ trigger: Trigger) -> ShieldReconciler.Verdict {
        let verdict = screenTime.reconcile(now: clock.now)
        lastVerdict = verdict

        // `reason` is a fixed enum case name, never anything a family typed, so
        // it is safe to log publicly — and a stranded shield is exactly the bug
        // that gets debugged from a sysdiagnose someone mailed in.
        HopLog.restoration.info(
            "reconcile trigger=\(trigger.rawValue, privacy: .public) cleared=\(verdict.clears, privacy: .public) reason=\(verdict.reason?.rawValue ?? "none", privacy: .public)"
        )
        return verdict
    }
}
