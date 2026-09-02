import Foundation
import SwiftUI
import HopPottyCore
import Observation

/// How the app gets hold of the Screen Time layer.
///
/// ## The structural rule
///
/// There is exactly one way to build the production environment and it takes no
/// arguments:
///
/// ```swift
/// let environment = ScreenTimeEnvironment.live()
/// ```
///
/// In a release build that is the only initialiser that exists. The one that
/// accepts arbitrary implementations is inside `#if DEBUG`, and the only type it
/// could usefully be handed — `MockScreenTimeService` — is also inside `#if
/// DEBUG`. So "could a mock reach production?" is not a question about review
/// discipline or a launch flag; it is a question about whether two `#if DEBUG`
/// blocks are in the binary, and they are not.
///
/// This matters more than the usual dependency-injection hygiene. A mock that
/// answers `believesShieldIsUp == false` while a real shield stands would make
/// HopPotty's own fail-safe believe there is nothing to clear — the mock would not
/// merely fail to shield, it would actively defeat the recovery path.
@MainActor
@Observable
public final class ScreenTimeEnvironment {

    public let screenTime: any ScreenTimeProviding
    public let monitoring: any ActivityMonitoringProviding
    public let appGroup: AppGroupStore

    /// The environment this build should use.
    ///
    /// Mirrors `ServiceContainer.resolved` so the two are wired the same way at
    /// the call site — but note the asymmetry, which is deliberate. The other
    /// mock services are ordinary types that a Release binary contains and simply
    /// never selects. `MockScreenTimeService` is not: it is inside `#if DEBUG`,
    /// so in Release **the `switch` below does not exist and there is nothing to
    /// select.** A fake haptics service is a cosmetic defect; a fake Screen Time
    /// service would report `believesShieldIsUp == false` while a real shield
    /// stands, which would make HopPotty's own fail-safe believe there is nothing
    /// to clear. That is worth a stronger guarantee than convention.
    ///
    /// The `configuration` parameter is accepted in both configurations so call
    /// sites are written once.
    // `internal`, not `public`. `AppBuildConfiguration` is internal, and a
    // public method cannot take an internal parameter type or use an internal
    // static property as a default argument -- the first compile of the app
    // target said so twice on these two lines. Demoting is the right direction
    // rather than promoting `AppBuildConfiguration`: this is an app target, not
    // a framework, so `public` buys nothing here, and the two peers this
    // deliberately mirrors -- `ServiceContainer.resolved` and
    // `LiveActivityController.resolved` -- are both internal already. This one
    // was the outlier.
    static func resolved(
        configuration: AppBuildConfiguration = .resolved
    ) -> ScreenTimeEnvironment {
        #if DEBUG
        switch configuration {
        case .live: return live()
        case .mock: return preview(.authorized)
        }
        #else
        return live()
        #endif
    }

    /// The one production path.
    public static func live() -> ScreenTimeEnvironment {
        let appGroup = AppGroupStore.shared
        return ScreenTimeEnvironment(
            screenTime: ScreenTimeService(appGroup: appGroup),
            monitoring: ActivityMonitoringService(appGroup: appGroup),
            appGroup: appGroup
        )
    }

    private init(
        screenTime: any ScreenTimeProviding,
        monitoring: any ActivityMonitoringProviding,
        appGroup: AppGroupStore
    ) {
        self.screenTime = screenTime
        self.monitoring = monitoring
        self.appGroup = appGroup
    }

    // MARK: - Launch

    /// Everything that must happen before the first frame.
    ///
    /// Ordered so the child's apps come back as early as possible: reconciliation
    /// first, before authorization, before the selection is read, before anything
    /// that could fail. A launch that crashes immediately after this line still
    /// leaves a stranded shield cleared.
    ///
    /// Call from `.task` on the root view, and again on every
    /// `scenePhase == .active`. Both, not one: a cold launch and a return from
    /// background are different events, and a shield can be stranded across
    /// either.
    public func reconcileOnLaunch(now: Date = Date()) -> ShieldReconciler.Verdict {
        let verdict = screenTime.reconcile(now: now)
        // An orphan can only exist if a previous build registered a name this one
        // does not know about, or a registration was interrupted. Cheap to check
        // and impossible to notice any other way.
        _ = monitoring.removeOrphanedMonitoring()
        return verdict
    }

    /// Publish the shield's appearance so the configuration extension has no work
    /// to do when the system next needs to draw it.
    ///
    /// Called on launch and whenever the copy or the palette could have changed —
    /// which is to say on every launch, because a language change or an OS
    /// appearance change arrives without notice.
    ///
    /// The strings come from `HopCopy` (Contract §5). Only their *resolution*
    /// happens here; the extension holds a compiled-in fallback for the case
    /// where this file is missing, and the fallback is not allowed to be the
    /// normal path.
    public func publishShieldAppearance() {
        screenTime.publishShieldPresentation(
            ShieldPresentation(
                title: HopCopy.shield.title.value,
                subtitle: HopCopy.shield.body.value,
                primaryButtonLabel: HopCopy.shield.primaryButton.value,
                secondaryButtonLabel: HopCopy.shield.secondaryButton.value,
                titleColor: .init(hex: 0x243047),
                subtitleColor: .init(hex: 0x243047),
                backgroundColor: .init(hex: 0xFFF9F2),
                primaryButtonColor: .init(hex: 0x63C88A),
                primaryButtonTextColor: .init(hex: 0x243047),
                backgroundBlurStyleRawValue: nil
            )
        )
    }

    // MARK: - DEBUG-only construction

    #if DEBUG
    /// Previews, UI tests, and the Potty Pause Lab.
    ///
    /// Not available in a release build, and neither is anything worth passing to
    /// it. See the type-level note.
    public static func preview(
        screenTime: any ScreenTimeProviding,
        monitoring: any ActivityMonitoringProviding = MockActivityMonitoringService(),
        appGroup: AppGroupStore = AppGroupStore(
            root: FileManager.default.temporaryDirectory
                .appendingPathComponent("HopPottyPreview", isDirectory: true)
        )
    ) -> ScreenTimeEnvironment {
        ScreenTimeEnvironment(screenTime: screenTime, monitoring: monitoring, appGroup: appGroup)
    }

    public static func preview(_ scenario: MockScreenTimeService.Scenario = .authorized) -> ScreenTimeEnvironment {
        preview(screenTime: MockScreenTimeService(scenario: scenario))
    }
    #endif
}

// MARK: - SwiftUI wiring

/// Deliberately optional, with a `nil` default.
///
/// A non-optional default would have to construct *something*, and the only two
/// candidates are a live service — which would silently start touching Screen
/// Time inside a SwiftUI preview — and a mock, which cannot exist in a release
/// build. `nil` forces the root view to inject one, so a screen that forgot to is
/// a screen that shows nothing rather than one that quietly does the wrong thing
/// to a child's device.
///
/// Written as an explicit `EnvironmentKey` rather than with SwiftUI's `@Entry`
/// macro, which arrived in the iOS 18 SDK. HopPotty targets iOS 17
/// (`Docs/ADR/0002-deployment-target.md`), and a macro that may or may not be
/// available is not worth six saved lines in the one file that decides whether
/// the Screen Time layer is reachable at all.
private struct ScreenTimeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ScreenTimeEnvironment? = nil
}

public extension EnvironmentValues {
    var screenTimeEnvironment: ScreenTimeEnvironment? {
        get { self[ScreenTimeEnvironmentKey.self] }
        set { self[ScreenTimeEnvironmentKey.self] = newValue }
    }
}

#if DEBUG
/// A monitoring service that registers nothing.
@MainActor
@Observable
public final class MockActivityMonitoringService: ActivityMonitoringProviding {
    public private(set) var monitoredActivityNames: [String] = []
    public private(set) var lastRegistration: Date?
    public private(set) var lastPlan: MonitoringPlan?
    public var lastFailure: ScreenTimeFailure?

    /// Set to make `register` fail, so the "we could not arm your schedule"
    /// screen can be designed against the state it exists for.
    public var registrationFailure: ScreenTimeFailure?

    public init() {}

    @discardableResult
    public func register(_ plan: MonitoringPlan) -> Result<MonitoringRegistration, ScreenTimeFailure> {
        if let registrationFailure {
            lastFailure = registrationFailure
            return .failure(registrationFailure)
        }
        lastPlan = plan
        lastRegistration = Date()
        monitoredActivityNames = Array(plan.activityNames).sorted()
        return .success(
            MonitoringRegistration(
                registeredAt: Date(),
                activityNames: monitoredActivityNames,
                stoppedNames: [],
                notes: plan.notes
            )
        )
    }

    @discardableResult
    public func registerBackstop(for record: SharedPauseRecord) -> Result<Void, ScreenTimeFailure> {
        monitoredActivityNames.append(ScreenTimeIdentifiers.backstopActivityName)
        return .success(())
    }

    public func cancelBackstop() {
        monitoredActivityNames.removeAll { $0 == ScreenTimeIdentifiers.backstopActivityName }
    }

    public func cancelAllMonitoring() {
        monitoredActivityNames = []
        lastPlan = nil
        lastRegistration = nil
    }

    @discardableResult
    public func removeOrphanedMonitoring() -> [String] { [] }
}
#endif
