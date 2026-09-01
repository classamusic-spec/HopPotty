#if DEBUG
import Foundation
import HopPottyCore
import FamilyControls

/// A `ScreenTimeProviding` that touches nothing.
///
/// ## Why this exists
///
/// `ScreenTimeService` cannot run in a SwiftUI preview, and Apple documents
/// nothing about whether Family Controls authorization works in the simulator at
/// all (`Docs/ScreenTimeArchitecture.md` §12 item 7). Without a mock, every
/// screen that mentions a pause — onboarding, the parent dashboard, the error
/// states, the Potty Pause screen itself — would be undesignable and untestable,
/// and the states that matter most are the ones that are hardest to stage on real
/// hardware: authorization revoked mid-pause, a shield that will not clear,
/// another parental-controls app holding the authorization.
///
/// ## Why it cannot ship
///
/// Three independent barriers, of which the first two are structural rather than
/// procedural. A convention ("remember not to use the mock") is not a safety
/// mechanism in a component that controls whether a child's device works.
///
/// 1. **The whole file is inside `#if DEBUG`.** In a release build this type does
///    not exist. Any code that referenced it would fail to compile — not fail a
///    review, not fail a lint, fail the build.
/// 2. **`ScreenTimeEnvironment` has no release-build path that could produce
///    one.** Its release initialiser constructs `ScreenTimeService` and takes no
///    parameters. There is no flag, no argument, no environment variable, and no
///    launch option that selects a different implementation, because the type it
///    would select is not in the binary.
/// 3. **It is never a default.** Every consumer takes `any ScreenTimeProviding`
///    by injection. Nothing anywhere reaches for `MockScreenTimeService.shared`,
///    and there is no such property to reach for.
///
/// The failure this design refuses to allow is not "we shipped a mock and Potty
/// Pause silently did nothing". It is worse than that: a mock that reports
/// `believesShieldIsUp == false` after a real shield went up would make the app's
/// own fail-safe believe there is nothing to clear.
@MainActor
@Observable
public final class MockScreenTimeService: ScreenTimeProviding {

    // MARK: - Scripting

    /// What the mock should pretend the world is like.
    ///
    /// Every field maps to a real situation observed or documented on device, so
    /// a preview or UI test names the situation rather than a sequence of stubs.
    public struct Scenario: Equatable, Sendable {
        public var authorizationStatus: ScreenTimeAuthorizationStatus
        /// What `requestAuthorization()` resolves to. `nil` means "grant".
        public var authorizationRequestFailure: ScreenTimeFailure?
        /// Simulates a caregiver dismissing the system sheet: no change, no error.
        public var authorizationRequestCancelled: Bool
        public var applyShieldFailure: ScreenTimeFailure?
        /// The nastiest case in the product: the shield will not come down.
        public var clearShieldFails: Bool
        /// The App Group container is unreachable — a provisioning mistake.
        public var sharedContainerUnavailable: Bool
        public var applicationCount: Int
        public var categoryCount: Int
        public var webDomainCount: Int

        public init(
            authorizationStatus: ScreenTimeAuthorizationStatus = .approved,
            authorizationRequestFailure: ScreenTimeFailure? = nil,
            authorizationRequestCancelled: Bool = false,
            applyShieldFailure: ScreenTimeFailure? = nil,
            clearShieldFails: Bool = false,
            sharedContainerUnavailable: Bool = false,
            applicationCount: Int = 4,
            categoryCount: Int = 1,
            webDomainCount: Int = 0
        ) {
            self.authorizationStatus = authorizationStatus
            self.authorizationRequestFailure = authorizationRequestFailure
            self.authorizationRequestCancelled = authorizationRequestCancelled
            self.applyShieldFailure = applyShieldFailure
            self.clearShieldFails = clearShieldFails
            self.sharedContainerUnavailable = sharedContainerUnavailable
            self.applicationCount = applicationCount
            self.categoryCount = categoryCount
            self.webDomainCount = webDomainCount
        }

        /// A working device with a caregiver who has picked some apps.
        public static let authorized = Scenario()

        /// Before onboarding. Apple's status is `.notDetermined` at every launch
        /// until a request succeeds, so this is also what a *returning* authorized
        /// family looks like for the first moment of a launch.
        public static let notDetermined = Scenario(
            authorizationStatus: .notDetermined, applicationCount: 0, categoryCount: 0
        )

        /// A grown-up said no.
        public static let denied = Scenario(
            authorizationStatus: .denied, applicationCount: 0, categoryCount: 0
        )

        /// A managed device, or one already enrolled as a child device. Asking
        /// again cannot help, and the UI must not offer a retry that cannot work.
        public static let restricted = Scenario(
            authorizationStatus: .restricted, applicationCount: 0, categoryCount: 0
        )

        /// Another parental-controls app already holds authorization. The most
        /// likely real-world failure, and the one a caregiver can only fix
        /// outside HopPotty.
        public static let conflicted = Scenario(
            authorizationStatus: .notDetermined,
            authorizationRequestFailure: .authorizationConflict,
            applicationCount: 0,
            categoryCount: 0
        )

        /// Authorized, but the caregiver has not chosen anything to pause.
        public static let noSelection = Scenario(applicationCount: 0, categoryCount: 0, webDomainCount: 0)

        /// The shield went up and will not come down. Exists so the recovery
        /// screen and the "Restore Screen Access" path can be designed and tested
        /// against the situation they were written for.
        public static let shieldStuck = Scenario(clearShieldFails: true)

        /// The App Group entitlement is missing. Everything degrades toward
        /// clearing, and the Lab should say so loudly.
        public static let brokenAppGroup = Scenario(sharedContainerUnavailable: true)
    }

    public var scenario: Scenario {
        didSet {
            authorizationStatus = scenario.authorizationStatus
            selectionSummary = Self.summary(scenario)
            for continuation in continuations.values { continuation.yield(authorizationStatus) }
        }
    }

    // MARK: - Observable state

    public private(set) var authorizationStatus: ScreenTimeAuthorizationStatus
    public var selection = FamilyActivitySelection()
    public private(set) var selectionSummary: SelectionSummary
    public private(set) var believesShieldIsUp = false
    public private(set) var activeRecord: SharedPauseRecord?
    public private(set) var lastReconciliation: ShieldReconciler.Verdict?

    /// Everything the mock was asked to do, in order. UI tests assert on this;
    /// it is the only reason to prefer a mock over a stub here.
    public private(set) var journal: [Call] = []

    public enum Call: Equatable, Sendable {
        case requestAuthorization
        case revokeAuthorization
        case refreshStatus
        case commitSelection
        case clearSelection
        case applyShield(plannedDuration: TimeInterval)
        case clearShield(ShieldReconciler.ClearReason)
        case restoreScreenAccess
        case reconcile(ShieldReconciler.Verdict)
        case publishShieldPresentation
        case drainReports
    }

    private var continuations: [UUID: AsyncStream<ScreenTimeAuthorizationStatus>.Continuation] = [:]
    private var reports: [ExtensionReport] = []
    private var presentation: ShieldPresentation?

    public init(scenario: Scenario = .authorized) {
        self.scenario = scenario
        self.authorizationStatus = scenario.authorizationStatus
        self.selectionSummary = Self.summary(scenario)
    }

    private static func summary(_ scenario: Scenario) -> SelectionSummary {
        SelectionSummary(
            applicationCount: scenario.applicationCount,
            categoryCount: scenario.categoryCount,
            webDomainCount: scenario.webDomainCount
        )
    }

    // MARK: - ScreenTimeProviding

    public var authorizationUpdates: AsyncStream<ScreenTimeAuthorizationStatus> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(authorizationStatus)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations[id] = nil }
            }
        }
    }

    @discardableResult
    public func refreshAuthorizationStatus() -> ScreenTimeAuthorizationStatus {
        journal.append(.refreshStatus)
        return authorizationStatus
    }

    public func requestAuthorization() async -> Result<ScreenTimeAuthorizationStatus, ScreenTimeFailure> {
        journal.append(.requestAuthorization)
        if scenario.authorizationRequestCancelled { return .success(authorizationStatus) }
        if let failure = scenario.authorizationRequestFailure { return .failure(failure) }
        authorizationStatus = .approved
        for continuation in continuations.values { continuation.yield(.approved) }
        return .success(.approved)
    }

    public func revokeAuthorization() async -> Result<Void, ScreenTimeFailure> {
        journal.append(.revokeAuthorization)
        // Mirrors the real service: revoking clears everything first, because a
        // shield left standing by an app that is no longer authorized is the one
        // genuinely unrecoverable configuration.
        believesShieldIsUp = false
        activeRecord = nil
        clearSelection()
        authorizationStatus = .notDetermined
        for continuation in continuations.values { continuation.yield(.notDetermined) }
        return .success(())
    }

    @discardableResult
    public func commitSelection() -> Result<SelectionSummary, ScreenTimeFailure> {
        journal.append(.commitSelection)
        guard !selectionSummary.exceedsShieldLimit else { return .failure(.scheduleInvalid) }
        return .success(selectionSummary)
    }

    public func clearSelection() {
        journal.append(.clearSelection)
        selection = FamilyActivitySelection()
        selectionSummary = .empty
    }

    public func applyShield(
        plannedDuration: TimeInterval,
        now: Date
    ) -> Result<SharedPauseRecord, ScreenTimeFailure> {
        journal.append(.applyShield(plannedDuration: plannedDuration))
        if let failure = scenario.applyShieldFailure { return .failure(failure) }
        guard authorizationStatus.canShield else { return .failure(.authorizationRevoked) }
        guard !selectionSummary.isEmpty else { return .failure(.noSelection) }

        let record = SharedPauseRecord.starting(
            at: now,
            uptime: ProcessInfo.processInfo.systemUptime,
            plannedDuration: plannedDuration
        )
        activeRecord = record
        believesShieldIsUp = true
        return .success(record)
    }

    public func clearShield(reason: ShieldReconciler.ClearReason) {
        journal.append(.clearShield(reason))
        guard !scenario.clearShieldFails else { return }
        believesShieldIsUp = false
        activeRecord = nil
    }

    public func restoreScreenAccess() {
        journal.append(.restoreScreenAccess)
        // The emergency path succeeds even in the `shieldStuck` scenario. That is
        // not the mock being generous: it is the mock matching the real service,
        // where `forceClear` issues the write unconditionally and reports nothing.
        // Whether the write *took* is discovered by the next read-back, which
        // `believesShieldIsUp` below still reflects.
        believesShieldIsUp = scenario.clearShieldFails
        activeRecord = nil
        lastReconciliation = .clearShield(.parentRestoredAccess)
    }

    @discardableResult
    public func reconcile(now: Date) -> ShieldReconciler.Verdict {
        let verdict: ShieldReconciler.Verdict
        if scenario.sharedContainerUnavailable {
            verdict = .clearShield(.sharedStateUnavailable)
        } else if let record = activeRecord {
            verdict = ShieldReconciler.decide(
                AppGroupSnapshot(
                    isSharedContainerAvailable: true,
                    containerPath: "/mock",
                    pause: record,
                    hasShieldPresentation: presentation != nil,
                    hasSelectionData: !selectionSummary.isEmpty,
                    heartbeats: [.app: now],
                    reportCount: reports.count,
                    observedAt: now,
                    observedUptime: ProcessInfo.processInfo.systemUptime
                )
            )
        } else {
            verdict = .clearShield(.noSession)
        }

        if verdict.clears, !scenario.clearShieldFails {
            believesShieldIsUp = false
            activeRecord = nil
        }
        lastReconciliation = verdict
        journal.append(.reconcile(verdict))
        return verdict
    }

    public func publishShieldPresentation(_ presentation: ShieldPresentation) {
        journal.append(.publishShieldPresentation)
        self.presentation = presentation
    }

    public func drainExtensionReports() -> [ExtensionReport] {
        journal.append(.drainReports)
        defer { reports = [] }
        return reports
    }

    public func appGroupSnapshot(now: Date) -> AppGroupSnapshot {
        AppGroupSnapshot(
            isSharedContainerAvailable: !scenario.sharedContainerUnavailable,
            containerPath: scenario.sharedContainerUnavailable ? nil : "/mock/HopPotty",
            pause: activeRecord,
            hasShieldPresentation: presentation != nil,
            hasSelectionData: !selectionSummary.isEmpty,
            heartbeats: [.app: now, .monitor: nil, .shieldConfiguration: nil, .shieldAction: nil],
            reportCount: reports.count,
            observedAt: now,
            observedUptime: ProcessInfo.processInfo.systemUptime
        )
    }

    // MARK: - Test affordances

    /// Simulate an extension filing a report — a pause that ended while the app
    /// was not running, which is the ordinary case for a usage-triggered pause.
    public func injectReport(_ report: ExtensionReport) {
        reports.append(report)
    }

    /// Simulate a caregiver revoking authorization in Settings mid-pause.
    public func simulateAuthorizationRevoked() {
        scenario.authorizationStatus = .denied
        believesShieldIsUp = false
        activeRecord = nil
    }

    /// Simulate the device clock jumping backwards under a live pause.
    public func simulateClockMovedBackwards(by interval: TimeInterval) {
        guard let record = activeRecord else { return }
        activeRecord = SharedPauseRecord(
            sessionID: record.sessionID,
            state: record.state,
            startedAt: record.startedAt.addingTimeInterval(interval),
            startedUptime: record.startedUptime,
            plannedEndAt: record.plannedEndAt.addingTimeInterval(interval),
            backstopEndAt: record.backstopEndAt.addingTimeInterval(interval)
        )
    }

    /// Simulate a reboot: uptime resets, so the recorded start uptime is now in
    /// the future relative to the device.
    public func simulateDeviceRestart() {
        guard let record = activeRecord else { return }
        activeRecord = SharedPauseRecord(
            sessionID: record.sessionID,
            state: record.state,
            startedAt: record.startedAt,
            startedUptime: ProcessInfo.processInfo.systemUptime + 10_000,
            plannedEndAt: record.plannedEndAt,
            backstopEndAt: record.backstopEndAt
        )
    }
}
#endif
