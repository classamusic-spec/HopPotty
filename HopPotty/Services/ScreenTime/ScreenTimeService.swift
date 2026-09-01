import Foundation
import Combine
import HopPottyCore
import FamilyControls
import ManagedSettings

/// HopPotty's one adapter onto FamilyControls and ManagedSettings.
///
/// Everything Apple's Screen Time frameworks can do for the app target happens
/// here. Nothing else in the app imports `FamilyControls` or `ManagedSettings`
/// — not a view, not a view model, not the state machine — so the answer to "what
/// can shield a child's apps?" is one file long.
///
/// ## The four rules this class exists to keep
///
/// 1. **Tokens are never inspected, logged, or persisted anywhere but Apple's own
///    `Codable` route.** No hashing into an analytics key, no bundle identifiers,
///    no display names. `SelectionSummary` is the only thing that leaves.
/// 2. **The App Group record is written before the shield goes up and removed
///    after it comes down.** In both directions the ordering errs toward "a
///    process that runs later believes a shield may exist", which is the belief
///    that produces a clear.
/// 3. **Clearing never fails from the caller's perspective.** Errors are recorded
///    for the caregiver; they never turn into a code path that leaves a shield up.
/// 4. **Nothing here decides anything.** The pause state machine in
///    `HopPottyCore` decides; this class performs. That is what keeps the hard
///    logic testable on a machine with no Xcode.
@MainActor
@Observable
public final class ScreenTimeService: ScreenTimeProviding {

    // MARK: Stored state

    public private(set) var authorizationStatus: ScreenTimeAuthorizationStatus = .notDetermined

    /// The picker's binding target. Opaque; see `ScreenTimeProviding.selection`.
    public var selection: FamilyActivitySelection = FamilyActivitySelection()

    public private(set) var selectionSummary: SelectionSummary = .empty

    /// The last failure, kept so the parent dashboard can explain itself instead
    /// of silently doing nothing.
    public private(set) var lastFailure: ScreenTimeFailure?

    /// The last reconciliation verdict, for the Potty Pause Lab.
    public private(set) var lastReconciliation: ShieldReconciler.Verdict?

    private let appGroup: AppGroupStore
    private let center: AuthorizationCenter
    private let defaults: UserDefaults
    private var cancellables: Set<AnyCancellable> = []
    private var statusContinuations: [UUID: AsyncStream<ScreenTimeAuthorizationStatus>.Continuation] = [:]

    /// Remembers, in the app's *private* storage, that authorization was once
    /// granted.
    ///
    /// Needed because Apple's `authorizationStatus` "initial value is always
    /// `.notDetermined`" and is only populated after a successful
    /// `requestAuthorization(for:)`. Without this flag, HopPotty could not tell a
    /// returning authorized family from a brand-new one, and would either prompt
    /// everybody at launch or believe nobody is authorized. Private storage, not
    /// the App Group: no extension needs it.
    private static let hasEverBeenAuthorizedKey = "hoppotty.screentime.hasEverBeenAuthorized"

    public init(
        appGroup: AppGroupStore = .shared,
        center: AuthorizationCenter = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.appGroup = appGroup
        self.center = center
        self.defaults = defaults
        observeAuthorization()
        loadPersistedSelection()
    }

    deinit {
        for continuation in statusContinuations.values { continuation.finish() }
    }

    // MARK: - Authorization

    /// Bridge Apple's `@Published` status onto our stream.
    ///
    /// UNVERIFIED — confirm on device: that `AuthorizationCenter.shared` publishes
    /// a change when a caregiver revokes authorization in Settings while HopPotty
    /// is backgrounded, and that the change arrives on return to foreground. If it
    /// does not, `refreshAuthorizationStatus()` on foreground is the fallback and
    /// is already wired; the consequence of the publisher being silent is a stale
    /// badge in the parent UI, never a stranded shield.
    private func observeAuthorization() {
        center.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.setStatus(Self.map(status))
            }
            .store(in: &cancellables)
        authorizationStatus = Self.map(center.authorizationStatus)
    }

    private func setStatus(_ status: ScreenTimeAuthorizationStatus) {
        guard status != authorizationStatus else { return }
        authorizationStatus = status
        if status == .approved {
            defaults.set(true, forKey: Self.hasEverBeenAuthorizedKey)
        }
        for continuation in statusContinuations.values { continuation.yield(status) }

        // Authorization loss voids every token we hold and makes a live pause
        // unenforceable. Clearing here, at the point of observation, means the
        // caregiver does not have to open HopPotty for their child's apps to come
        // back — and means HopPotty never sits on a selection of dead tokens.
        if !status.canShield {
            ShieldReconciler.forceClear(reason: .authorizationLost, store: appGroup)
            clearSelection()
            lastFailure = .authorizationRevoked
        }
    }

    public var authorizationUpdates: AsyncStream<ScreenTimeAuthorizationStatus> {
        AsyncStream { continuation in
            let id = UUID()
            statusContinuations[id] = continuation
            continuation.yield(authorizationStatus)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.statusContinuations[id] = nil }
            }
        }
    }

    @discardableResult
    public func refreshAuthorizationStatus() -> ScreenTimeAuthorizationStatus {
        setStatus(Self.map(center.authorizationStatus))
        return authorizationStatus
    }

    /// Re-establish a previously granted authorization without prompting a
    /// first-time user.
    ///
    /// Apple's guidance is to "always request authorization when your app first
    /// launches", and notes that a previously authorized app gets no UI from the
    /// request. But a family that has *never* authorized would get a system
    /// prompt before HopPotty has explained what it is asking for or why, which
    /// is both bad manners and a bad conversion funnel for a parenting app. So
    /// the launch-time request is gated on having succeeded once before.
    public func restoreAuthorizationIfPreviouslyGranted() async {
        guard defaults.bool(forKey: Self.hasEverBeenAuthorizedKey) else {
            refreshAuthorizationStatus()
            return
        }
        _ = await requestAuthorization()
    }

    public func requestAuthorization() async -> Result<ScreenTimeAuthorizationStatus, ScreenTimeFailure> {
        do {
            // `.individual` because HopPotty runs on the *child's own device* and
            // is authorized there by a grown-up with the device's Screen Time
            // passcode. `.child` is for the parent-device flow across Family
            // Sharing, which HopPotty does not implement: a pause has to be
            // applied on the device the child is holding.
            try await center.requestAuthorization(for: .individual)
            let status = refreshAuthorizationStatus()
            lastFailure = status.canShield ? nil : .authorizationRevoked
            return .success(status)
        } catch {
            let failure = Self.map(error)
            // A caregiver cancelling the system sheet is not a failure. It is a
            // decision, and the UI returns to the explainer rather than showing
            // an error a parent did not cause.
            if Self.isCancellation(error) {
                refreshAuthorizationStatus()
                return .success(authorizationStatus)
            }
            if failure == .unknown, Self.isRestriction(error) {
                setStatus(.restricted)
                lastFailure = nil
                return .success(.restricted)
            }
            lastFailure = failure
            return .failure(failure)
        }
    }

    public func revokeAuthorization() async -> Result<Void, ScreenTimeFailure> {
        // Every shield comes down first, unconditionally. Revoking while a shield
        // stands would leave system state HopPotty is no longer permitted to
        // touch — the one genuinely unrecoverable configuration in this feature.
        ShieldReconciler.forceClear(reason: .parentRestoredAccess, store: appGroup)
        clearSelection()

        return await withCheckedContinuation { continuation in
            center.revokeAuthorization { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.defaults.set(false, forKey: Self.hasEverBeenAuthorizedKey)
                        self.setStatus(.notDetermined)
                        continuation.resume(returning: .success(()))
                    case .failure(let error):
                        let failure = Self.map(error)
                        self.lastFailure = failure
                        continuation.resume(returning: .failure(failure))
                    }
                }
            }
        }
    }

    // MARK: Status and error mapping

    /// Apple's `AuthorizationStatus` → HopPotty's.
    ///
    /// Note what is *not* here: `.restricted`. Apple's enum has no such case —
    /// `ScreenTimeConfiguration` documents ours as derived from
    /// `FamilyControlsError.restricted`, and `requestAuthorization()` above is
    /// the only place it is ever set.
    static func map(_ status: AuthorizationStatus) -> ScreenTimeAuthorizationStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .approved: .approved
        @unknown default:
            // iOS 26.4 added `.approvedWithDataAccess`, which HopPotty never
            // requests: it returns real bundle identifiers instead of tokens,
            // which is a privacy regression with no product gain
            // (`Docs/Entitlements.md`). Any future approved-ish case should behave
            // as approved; anything genuinely new and unknown must not be
            // treated as permission to shield.
            //
            // UNVERIFIED — confirm on device: that this compiles against the SDK
            // in use. If `AuthorizationStatus` is frozen, the `@unknown default`
            // becomes a warning and `.approvedWithDataAccess` needs an explicit
            // case mapping to `.approved`.
            .notDetermined
        }
    }

    /// `FamilyControlsError` → a caregiver-actionable failure.
    ///
    /// Each case has a different fix, which is why `ScreenTimeFailure` grew to
    /// match rather than collapsing them into `.unknown`. `.authorizationConflict`
    /// in particular — another parental-controls app already holds authorization
    /// on this device — is the most likely real-world failure and the one a
    /// generic error message would leave a caregiver completely stuck on.
    ///
    /// UNVERIFIED — confirm on device: the exact spelling of every case below.
    /// They are taken from Apple's documentation (`Docs/ScreenTimeArchitecture.md`
    /// §3) rather than from a compiled SDK. If one does not exist, delete the
    /// case; the `default` branch already maps it to `.unknown`, so a mistake here
    /// degrades to a vaguer message and never to a wrong behaviour.
    static func map(_ error: Error) -> ScreenTimeFailure {
        guard let familyError = error as? FamilyControlsError else { return .unknown }
        switch familyError {
        case .invalidAccountType: return .invalidAccountType
        case .authorizationConflict: return .authorizationConflict
        case .networkError: return .networkError
        case .authenticationMethodUnavailable: return .authenticationMethodUnavailable
        case .unavailable: return .extensionUnavailable
        case .restricted: return .unknown  // routed to `.restricted` status by `isRestriction`
        case .unauthorized: return .authorizationRevoked
        default: return .unknown
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        guard let familyError = error as? FamilyControlsError else { return false }
        if case .authorizationCanceled = familyError { return true }
        return false
    }

    private static func isRestriction(_ error: Error) -> Bool {
        guard let familyError = error as? FamilyControlsError else { return false }
        if case .restricted = familyError { return true }
        return false
    }

    // MARK: - Selection
    //
    // ## How the selection is persisted
    //
    // `FamilyActivitySelection` conforms to `Codable`, and `Token` conforms to
    // `Encodable`/`Decodable`. That is Apple's own persistence route and the only
    // supported one: there is no documented way to obtain a stable string for a
    // token, and any attempt to derive one would be an attempt to identify what a
    // family uses.
    //
    // The whole selection is encoded as a single blob rather than three loose
    // token sets, so `includeEntireCategory` round-trips with it.
    //
    // It is written to the App Group container because the monitor extension
    // needs it: when a usage threshold fires with HopPotty not running, the
    // extension is the process that must raise the shield, and it cannot run a
    // picker.
    //
    // Two lifetime facts govern everything else here. Apple: "If a user, parent,
    // or guardian revokes authorization of your app, any tokens that
    // `FamilyActivitySelection` provided while your app was authorized are
    // voided." And iOS 26.5 adds a token-expiry notification, so expiry exists as
    // a concept independently of revocation.
    //
    // UNVERIFIED — confirm on device: whether a persisted selection survives an
    // app update, a device restore from backup, and a reinstall. HopPotty assumes
    // it does not survive a reinstall and treats a decode failure as "no
    // selection", which routes the caregiver back to the picker rather than
    // silently shielding nothing.

    private func loadPersistedSelection() {
        guard let data = appGroup.loadSelectionData() else {
            selectionSummary = .empty
            return
        }
        guard let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            // Unreadable means gone. Removing it stops a dead blob being retried
            // on every launch, and the caregiver is routed back to the picker.
            appGroup.clearSelectionData()
            selectionSummary = .empty
            lastFailure = .noSelection
            return
        }
        selection = decoded
        selectionSummary = Self.summarize(decoded)
    }

    static func summarize(_ selection: FamilyActivitySelection) -> SelectionSummary {
        // Token sets rather than the richer `applications`/`categories` sets: a
        // token is what can actually be shielded, and counting anything else
        // would tell a caregiver we can pause more than we can.
        SelectionSummary(
            applicationCount: selection.applicationTokens.count,
            categoryCount: selection.categoryTokens.count,
            webDomainCount: selection.webDomainTokens.count
        )
    }

    @discardableResult
    public func commitSelection() -> Result<SelectionSummary, ScreenTimeFailure> {
        let summary = Self.summarize(selection)

        guard !summary.exceedsShieldLimit else {
            lastFailure = .scheduleInvalid
            return .failure(.scheduleInvalid)
        }

        guard let data = try? JSONEncoder().encode(selection) else {
            lastFailure = .unknown
            return .failure(.unknown)
        }
        guard appGroup.saveSelectionData(data) else {
            // The container is unreachable. Say so rather than letting the
            // caregiver believe a selection was saved that the monitor extension
            // will never see.
            lastFailure = .extensionUnavailable
            return .failure(.extensionUnavailable)
        }

        selectionSummary = summary
        lastFailure = summary.isEmpty ? .noSelection : nil
        return .success(summary)
    }

    public func clearSelection() {
        selection = FamilyActivitySelection()
        selectionSummary = .empty
        appGroup.clearSelectionData()
    }

    // MARK: - Shield

    /// Read back HopPotty's own store. See `ScreenTimeProviding.believesShieldIsUp`
    /// for why the name says "believes".
    ///
    /// UNVERIFIED — confirm on device: that reading a `ManagedSettingsStore`
    /// property returns what was last written to it, promptly, in the same
    /// process and across processes. Nothing safety-critical depends on the
    /// answer: the fail-safe keys off the App Group record, not this.
    public var believesShieldIsUp: Bool {
        let store = ManagedSettingsStore(named: .pottyPause)
        if let applications = store.shield.applications, !applications.isEmpty { return true }
        if let domains = store.shield.webDomains, !domains.isEmpty { return true }
        if store.shield.applicationCategories != nil { return true }
        if store.shield.webDomainCategories != nil { return true }
        return false
    }

    public func applyShield(
        plannedDuration: TimeInterval,
        now: Date = Date()
    ) -> Result<SharedPauseRecord, ScreenTimeFailure> {
        guard authorizationStatus.canShield else {
            lastFailure = .authorizationRevoked
            return .failure(.authorizationRevoked)
        }
        guard !selectionSummary.isEmpty else {
            lastFailure = .noSelection
            return .failure(.noSelection)
        }
        guard !selectionSummary.exceedsShieldLimit else {
            lastFailure = .scheduleInvalid
            return .failure(.scheduleInvalid)
        }

        // Record first, shield second. A crash between the two leaves a record
        // that says "a shield may be up", which every reconciliation path handles
        // by clearing. The reverse order would leave a shield no record claims.
        let record = SharedPauseRecord.starting(
            at: now,
            uptime: ProcessInfo.processInfo.systemUptime,
            plannedDuration: plannedDuration
        )
        guard appGroup.savePause(record) else {
            lastFailure = .extensionUnavailable
            return .failure(.extensionUnavailable)
        }

        let store = ManagedSettingsStore(named: .pottyPause)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens, except: Set())
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens, except: Set())

        // `nil`, never an empty set. Apple: "Changing the value of a setting to
        // `nil` deletes your app's configuration for that setting." An empty set
        // is a configuration that shields nothing, which is a different thing and
        // one whose behaviour Apple does not document.

        appGroup.advancePause(to: .shielded)
        appGroup.appendReport(
            ExtensionReport(source: .app, kind: .shieldApplied, at: now, sessionID: record.sessionID)
        )
        lastFailure = nil
        return .success(record)
    }

    public func clearShield(reason: ShieldReconciler.ClearReason) {
        appGroup.advancePause(to: .clearing)
        ShieldReconciler.forceClear(reason: reason, store: appGroup, source: .app)
        lastFailure = nil
    }

    /// **The emergency path.**
    ///
    /// Ordered so that the child's apps come back before anything else is
    /// attempted, and so that a failure in any later step cannot prevent the
    /// earlier ones. Nothing here can throw and nothing here returns a value to
    /// check: a caregiver pressing "Restore Screen Access" gets their child's
    /// apps back, and HopPotty's opinion about whether that went well is not part
    /// of the transaction.
    public func restoreScreenAccess() {
        // 1. The shield, first and unconditionally.
        ShieldReconciler.forceClear(reason: .parentRestoredAccess, store: appGroup, source: .app)
        // 2. Monitoring, so nothing re-raises it a moment later. Best-effort:
        //    a failure here cannot un-restore step 1.
        ActivityMonitoringService.cancelEverythingBestEffort()
        // 3. Local bookkeeping.
        lastReconciliation = .clearShield(.parentRestoredAccess)
        lastFailure = nil
    }

    @discardableResult
    public func reconcile(now: Date = Date()) -> ShieldReconciler.Verdict {
        let verdict = ShieldReconciler.reconcile(
            store: appGroup, source: .app, beating: .app, now: now
        )
        lastReconciliation = verdict
        if let reason = verdict.reason, reason.warrantsParentNotice {
            lastFailure = reason == .authorizationLost ? .authorizationRevoked : lastFailure
        }
        return verdict
    }

    // MARK: - Extension boundary

    public func publishShieldPresentation(_ presentation: ShieldPresentation) {
        appGroup.saveShieldPresentation(presentation)
    }

    public func drainExtensionReports() -> [ExtensionReport] {
        appGroup.drainReports()
    }

    public func appGroupSnapshot(now: Date = Date()) -> AppGroupSnapshot {
        appGroup.snapshot(now: now)
    }
}
