import Foundation

/// The one thing the app *lifecycle* needs from the Screen Time layer.
///
/// ## Why this is not `ScreenTimeProviding`
///
/// `ScreenTimeProviding` is a wide protocol — authorization, the picker,
/// selection, shields, monitoring — and there is more than one of it: the
/// services layer declares one in Apple-framework terms, the feature layer
/// declares another in Core terms for the parent screens. Both are reasonable
/// for their callers. Neither is what a launch hook needs.
///
/// A launch hook needs exactly one function, and depending on more than that
/// would tie the entry point to whichever of those protocols wins an argument it
/// has no stake in. So the app layer declares the narrow port it actually uses
/// and lets the real service satisfy it retroactively, below. This is the
/// interface-segregation case in its most literal form: one caller, one method,
/// no opinion about anything else.
///
/// `@MainActor` because Apple requires `authorizationStatus` to be read on the
/// main queue, and every implementation reaches it.
@MainActor
protocol ScreenTimeReconciling: AnyObject {

    /// Decide whether a shield is standing that nothing is going to take down,
    /// and take it down if so.
    ///
    /// Total, pure in its decision, and idempotent in its effect: clearing is
    /// `store.clearAllSettings()`, which is a no-op on an already-clear store.
    /// Call it whenever it might help.
    ///
    /// - Parameter now: supplied by the caller's clock, never read from `Date()`
    ///   inside the implementation, so a test can sit exactly on an expiry.
    func reconcile(now: Date) -> ShieldReconciler.Verdict
}

// The real service already has this method — it is part of the services layer's
// own `ScreenTimeProviding`. Declaring the conformance here rather than there
// keeps the dependency pointing the right way: the app layer names what it
// needs, and does not edit the layer that provides it.
extension ScreenTimeService: ScreenTimeReconciling {}

#if HOPPOTTY_DEBUG_TOOLS

/// The reconciler a fake build gets.
///
/// Compiled only when `HOPPOTTY_DEBUG_TOOLS` is defined, which Release does not
/// define — so this type is absent from a shipping binary rather than merely
/// unreachable in one.
///
/// It reports `.clearShield(.noSession)`, which is the literal truth of a build
/// with no App Group and no `ManagedSettings` store: there is no session, and
/// nothing is shielded. It deliberately does not pretend a pause is in flight;
/// a fake that reports `.leaveShieldUp` would let a simulator run "verify"
/// behaviour that only a device can verify.
@MainActor
final class InMemoryScreenTimeReconciler: ScreenTimeReconciling {
    private(set) var reconcileCount = 0

    func reconcile(now: Date) -> ShieldReconciler.Verdict {
        reconcileCount += 1
        return .clearShield(.noSession)
    }
}

#endif
