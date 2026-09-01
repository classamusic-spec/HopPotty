import Foundation
import HopPottyCore
#if canImport(FamilyControls)
import FamilyControls
#endif

/// Everything the app layer is allowed to ask of Screen Time.
///
/// ## Why a protocol at all
///
/// Not for testability alone. The concrete `ScreenTimeService` cannot run
/// anywhere except a provisioned physical device with a real Family Controls
/// authorization — not in a SwiftUI preview, not in the simulator (Apple
/// documents nothing either way; see `Docs/ScreenTimeArchitecture.md` §12 item 7),
/// and not in a UI test on CI. Without this seam, every screen that mentions a
/// pause would be undesignable and untestable.
///
/// ## What is deliberately absent
///
/// There is no way to ask this protocol *what* is selected. `selection` exists
/// only because `FamilyActivityPicker` needs a binding, and it is an opaque value
/// HopPotty cannot read. Everything the parent UI displays comes from
/// ``SelectionSummary``, which is three integers. Apple hands out tokens
/// specifically so that an app cannot learn what a family uses, and a protocol
/// that offered a way around that would be a design defect even if the compiler
/// allowed it.
///
/// ## Threading
///
/// `@MainActor` throughout, because Apple requires it: "Only access the
/// `authorizationStatus` property on the main queue." Making the whole surface
/// main-actor is simpler than a partial rule nobody will remember, and nothing
/// here is expensive enough to want off the main thread.
@MainActor
public protocol ScreenTimeProviding: AnyObject {

    // MARK: Authorization

    /// The last known status. Never blocks.
    var authorizationStatus: ScreenTimeAuthorizationStatus { get }

    /// A stream of status changes.
    ///
    /// Status can change without HopPotty doing anything — Apple names "a child
    /// graduating to an adult account, or a parent or guardian changing the
    /// status in Settings". A revocation mid-pause voids every token we hold and
    /// must end the pause, so this is not a nicety.
    var authorizationUpdates: AsyncStream<ScreenTimeAuthorizationStatus> { get }

    /// Re-read the system's status without prompting.
    @discardableResult
    func refreshAuthorizationStatus() -> ScreenTimeAuthorizationStatus

    /// Ask for authorization.
    ///
    /// May present system UI, and must therefore only be called from a caregiver
    /// action or from onboarding — never speculatively at launch. See
    /// ``ScreenTimeService/restoreAuthorizationIfPreviouslyGranted()`` for the
    /// launch-time path that does not prompt a first-time user.
    func requestAuthorization() async -> Result<ScreenTimeAuthorizationStatus, ScreenTimeFailure>

    /// Give authorization back.
    ///
    /// Required before a family can delete HopPotty: while authorization is held,
    /// Apple prevents the user from deleting the app. Offering no way out of that
    /// would be indefensible in a product whose entire premise is that a family
    /// stays in control.
    func revokeAuthorization() async -> Result<Void, ScreenTimeFailure>

    // MARK: Selection

    /// The caregiver's picked apps, categories and web domains.
    ///
    /// Opaque. Settable only so `FamilyActivityPicker` has something to bind to.
    /// Reading it yields tokens HopPotty cannot decode and must never try to.
    var selection: FamilyActivitySelection { get set }

    /// Counts, which is all the parent UI is entitled to know.
    var selectionSummary: SelectionSummary { get }

    /// Persist the current selection and republish it to the extensions.
    @discardableResult
    func commitSelection() -> Result<SelectionSummary, ScreenTimeFailure>

    /// Forget the selection entirely. Used when authorization is lost, because
    /// Apple voids every token issued while an app was authorized.
    func clearSelection()

    // MARK: Shield

    /// Whether HopPotty believes a shield is up.
    ///
    /// "Believes" is the honest word and the API says so. Apple: "The system
    /// doesn't guarantee that the settings you specify govern the device's
    /// behavior." This reads back HopPotty's own store, which is a record of what
    /// was asked for, not an observation of what the device is doing. No
    /// caregiver-facing copy may state that apps *are* blocked on the strength of
    /// it — Contract §5 and `Docs/ScreenTimeArchitecture.md` §11 item 12.
    var believesShieldIsUp: Bool { get }

    /// Raise the shield and open a pause session.
    ///
    /// Writes the App Group record *before* touching `ManagedSettings`, so a
    /// crash between the two leaves a record saying "a shield may be up" — the
    /// conservative direction, and the one every reconciliation path handles.
    func applyShield(plannedDuration: TimeInterval, now: Date) -> Result<SharedPauseRecord, ScreenTimeFailure>

    /// Take the shield down.
    ///
    /// Idempotent, non-throwing, and safe to call from any state including states
    /// that "know" the shield is already down. Deliberately returns nothing:
    /// there is no failure a caller could handle better than the next
    /// reconciliation already does.
    func clearShield(reason: ShieldReconciler.ClearReason)

    /// **The emergency path.** Clears everything, cancels everything, and always
    /// succeeds from the app's point of view.
    ///
    /// This is what "Restore Screen Access" calls. It must remain reachable from
    /// a caregiver surface that works when every other part of HopPotty is broken.
    func restoreScreenAccess()

    /// Cold-start and every-foreground reconciliation. Clears a shield that has
    /// outlived its session; leaves a live pause alone.
    @discardableResult
    func reconcile(now: Date) -> ShieldReconciler.Verdict

    // MARK: Extension boundary

    /// Push the pre-resolved shield appearance to the App Group so the
    /// configuration extension has no work to do.
    func publishShieldPresentation(_ presentation: ShieldPresentation)

    /// Collect and clear what the extensions reported since last time.
    func drainExtensionReports() -> [ExtensionReport]

    /// Everything the Potty Pause Lab needs to show, and nothing sensitive.
    func appGroupSnapshot(now: Date) -> AppGroupSnapshot
}

public extension ScreenTimeProviding {
    func reconcile() -> ShieldReconciler.Verdict { reconcile(now: Date()) }
    func appGroupSnapshot() -> AppGroupSnapshot { appGroupSnapshot(now: Date()) }
    func applyShield(plannedDuration: TimeInterval) -> Result<SharedPauseRecord, ScreenTimeFailure> {
        applyShield(plannedDuration: plannedDuration, now: Date())
    }
}

// MARK: - Selection summary

/// What HopPotty is allowed to know about a caregiver's selection: how many
/// things, of three kinds. Never which things.
///
/// This is the type the parent dashboard reads. `ScreenTimeConfiguration` in
/// `HopPottyCore` holds the same three counts for persistence; this one adds the
/// platform-limit checks, which belong here because the limits are a property of
/// ManagedSettings rather than of the domain.
public struct SelectionSummary: Equatable, Sendable {
    public let applicationCount: Int
    public let categoryCount: Int
    public let webDomainCount: Int

    public init(applicationCount: Int = 0, categoryCount: Int = 0, webDomainCount: Int = 0) {
        self.applicationCount = applicationCount
        self.categoryCount = categoryCount
        self.webDomainCount = webDomainCount
    }

    public static let empty = SelectionSummary()

    public var total: Int { applicationCount + categoryCount + webDomainCount }
    public var isEmpty: Bool { total == 0 }

    /// Apple caps each shield property at 50 tokens and documents no behaviour
    /// for exceeding it. HopPotty refuses an over-cap selection and says so,
    /// which is the only response that is correct whether the real behaviour is
    /// silent truncation, no shield at all, or a throw.
    ///
    /// UNVERIFIED — confirm on device: what actually happens at 51 tokens.
    public var exceedsShieldLimit: Bool {
        applicationCount > ScreenTimeIdentifiers.shieldTokenLimit
            || categoryCount > ScreenTimeIdentifiers.shieldTokenLimit
            || webDomainCount > ScreenTimeIdentifiers.shieldTokenLimit
    }

    /// Fold into the persisted domain record for one child.
    public func configuration(
        childID: UUID,
        authorizationStatus: ScreenTimeAuthorizationStatus,
        lastMonitoringRegistration: Date? = nil,
        lastRegistrationFailure: ScreenTimeFailure? = nil
    ) -> ScreenTimeConfiguration {
        ScreenTimeConfiguration(
            childID: childID,
            selectedApplicationCount: applicationCount,
            selectedCategoryCount: categoryCount,
            selectedWebDomainCount: webDomainCount,
            authorizationStatus: authorizationStatus,
            lastMonitoringRegistration: lastMonitoringRegistration,
            lastRegistrationFailure: lastRegistrationFailure
        )
    }
}
