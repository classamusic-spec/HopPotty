import Foundation
import ManagedSettings
import HopPottyCore

/// What happens when a child taps a button on the Potty Pause shield.
///
/// ## Can a shield open HopPotty? — the honest answer
///
/// **Only on iOS 26.5 and later.** Below that there is no supported mechanism,
/// and this was checked rather than assumed:
///
/// - `ShieldActionResponse` has exactly three cases before iOS 26.5: `.close`,
///   `.defer`, `.none`. None of them launches an application.
/// - `ShieldActionDelegate` inherits from `NSObject`, not `UIViewController`. It
///   has no `extensionContext`, so the usual app-extension escape hatch —
///   `extensionContext.open(url:)` — does not exist to be called.
/// - `UIApplication.shared` is unavailable in app extensions.
/// - Apple's WWDC21 introduction lists exactly two outcomes for a shield button:
///   "close the shielded application or defer action and redraw the shield
///   configuration."
/// - iOS 26.5 adds `ShieldActionResponse.openParentalControlsApp`, described as
///   "open your parental controls app that is responsible for shielding the
///   application" — which is an admission that it was not previously possible.
///
/// ### The compromise, stated plainly
///
/// Below iOS 26.5, tapping "I'm going!" does **not** bring HopPotty forward. What
/// it does instead:
///
/// 1. This extension clears the `.pottyPause` store itself. Named
///    `ManagedSettingsStore`s are shared between an app and its extensions
///    automatically, so the pause genuinely ends here — no app launch required.
/// 2. It files a `pauseEnded` report in the App Group outbox.
/// 3. It returns `.close`, so the child leaves the shielded app and lands
///    somewhere they can tap HopPotty if they want to.
/// 4. The star is awarded, and the celebration shown, **the next time HopPotty is
///    opened**, when the app drains the outbox.
///
/// The cost of that compromise is real and belongs in the product, not hidden
/// here: **the child does not see their star at the moment they earn it.** So
/// child-facing copy must never promise an immediate reward — no "tap here to get
/// your star". The ledger is append-only and idempotent (Contract §4.2), so a
/// drain that runs twice cannot double-award and a drain that never runs cannot
/// un-award. On iOS 26.5+ the response is upgraded at runtime and the child does
/// see it land immediately.
///
/// UNVERIFIED — confirm on device: where `.close` actually leaves the child (Home
/// Screen, or the previously frontmost app), and whether the shield visibly
/// disappears when the store is cleared inside this same `handle` call or whether
/// the child sees a stale shield for a moment. Both affect whether the flow feels
/// like a door opening or like an app crashing.
///
/// ## Why the secondary button does not unlock anything
///
/// "Ask a grown-up" is a button on a screen a **three-year-old is holding**. If it
/// cleared the shield, it would be an unlock button with a misleading label, and
/// the feature would be decorative within a day. It raises a flag for a caregiver
/// and returns `.defer`, which keeps the shield up and redraws it. The pause still
/// ends on its own timer regardless — Contract §4.1 — so nothing about this
/// traps a child: the worst case is that they wait out the same few minutes they
/// were always going to wait.
///
/// The caregiver's actual escape hatch is "Restore Screen Access" inside HopPotty,
/// behind the parent gate. That is deliberate: an override should require an adult
/// who can be identified as one, and this extension has no way to run a parent
/// gate.
final class HopPottyShieldActionExtension: ShieldActionDelegate {

    private var store: AppGroupStore { AppGroupStore.shared }

    // MARK: - Entry points
    //
    // Three overloads for three kinds of shielded thing. All three do the same
    // work, because a Potty Pause is a pause on the *device*, not on a particular
    // app: whichever thing the child bumped into is the thing that shows the
    // shield, and finishing the routine ends the pause on all of them.
    //
    // The tokens are received and immediately ignored. They are opaque, HopPotty
    // has no use for them here, and passing them anywhere would be the beginning
    // of a way to learn what a family uses.

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    // MARK: - The decision

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        let instant = Date()

        // Reconcile first, always. A child tapping a shield is the strongest
        // available evidence that a shield exists, and this is the last of the
        // four places that can notice one has outlived its session. If it had, the
        // reconciliation just cleared it — so the honest response is `.close`: the
        // shield is gone, and leaving the child staring at a screen that no longer
        // means anything would be worse than putting them back on the Home Screen.
        let verdict = ShieldReconciler.reconcile(
            store: store, source: .shieldAction, beating: .shieldAction, now: instant
        )

        let sessionID = store.loadPause()?.sessionID

        switch action {
        case .primaryButtonPressed:
            store.appendReport(
                ExtensionReport(
                    source: .shieldAction,
                    kind: .shieldPrimaryButtonTapped,
                    at: instant,
                    sessionID: sessionID
                )
            )
            return endPause(sessionID: sessionID, at: instant)

        case .secondaryButtonPressed:
            store.appendReport(
                ExtensionReport(
                    source: .shieldAction,
                    kind: .shieldSecondaryButtonTapped,
                    at: instant,
                    sessionID: sessionID
                )
            )
            // A flag, not an unlock. The app surfaces it behind the parent gate on
            // next launch. If the reconciliation above already cleared the shield,
            // there is nothing left to defer to, so close instead of asking the
            // system to redraw a shield that is gone.
            store.setGrownUpRequested(at: instant)
            return verdict.clears ? .close : .defer

        @unknown default:
            // iOS 26.4 added three secondary-submenu actions. HopPotty does not
            // configure a submenu, so it should never receive one — but an unknown
            // action must not silently do nothing, because "nothing" leaves a
            // child tapping a button that does not respond.
            //
            // `.defer` redraws the shield, which at least looks like a response.
            // The pause still ends on its timer.
            store.appendReport(
                ExtensionReport(
                    source: .shieldAction,
                    kind: .failure,
                    at: instant,
                    sessionID: sessionID,
                    failureCode: ScreenTimeFailure.unknown.rawValue
                )
            )
            return .defer
        }
    }

    /// End the pause from here, because nothing else can end it fast enough to
    /// feel like an answer to a tap.
    private func endPause(sessionID: String?, at instant: Date) -> ShieldActionResponse {
        // Clear unconditionally and without consulting the record. The child has
        // said they are going; the pause is over. Contract §4.1: a pause ends on
        // its timer, on completion, or on caregiver override — this is completion,
        // and no code path anywhere may keep a shield up pending an outcome.
        ShieldReconciler.forceClear(reason: .childCompleted, store: store, source: .shieldAction)

        // The cooldown starts here rather than on the app's next launch, so a
        // child who finishes at 10:02 is not re-interrupted at 10:03 by a monitor
        // extension that has no idea the pause already ended.
        //
        // The gate may be unreadable — the app may never have written one. In that
        // case no cooldown is recorded, and the monitor's own cooldown check
        // treats "no record" as "elapsed". The consequence is at worst one
        // early second pause, which is a nuisance rather than a lockout.
        if let gate = store.loadGate(), gate.cooldownSeconds > 0 {
            store.setCooldown(until: instant.addingTimeInterval(gate.cooldownSeconds))
        }

        store.appendReport(
            ExtensionReport(
                source: .shieldAction,
                kind: .pauseEnded,
                at: instant,
                sessionID: sessionID,
                outcomeCode: PauseOutcome.completedRoutine.rawValue,
                clearReasonCode: ShieldReconciler.ClearReason.childCompleted.rawValue
            )
        )

        // iOS 26.5+ can bring HopPotty forward so the star lands while the child
        // is still looking. Runtime-gated, never required: everything above has
        // already happened, and this only changes where the child ends up.
        //
        // UNVERIFIED — confirm on device: that `.openParentalControlsApp` exists
        // under this spelling and does open the containing app rather than a
        // system settings pane. If the case name is wrong, delete this block —
        // `.close` below is the shipping behaviour and the one every other part
        // of the design assumes.
        //
        // The `#if compiler` gate is not belt and braces, it is required.
        // `#available` is a RUNTIME check: the case still has to exist in the
        // SDK being compiled against, and `.openParentalControlsApp` is not in
        // the iOS 18 SDK that Xcode 16 ships. Without the gate this file does
        // not compile there at all. Swift 6.2 is the compiler that arrives with
        // the iOS 26 SDK, which is the first one that could have the case.
        #if compiler(>=6.2)
        if #available(iOS 26.5, *) {
            return .openParentalControlsApp
        }
        #endif
        return .close
    }
}
