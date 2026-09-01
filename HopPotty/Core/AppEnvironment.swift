import Foundation
import HopPottyCore
import SwiftUI

/// Everything the app is built out of, assembled once.
///
/// ## Protocol injection, compile-time selection
///
/// Every service is held as an existential (`any AudioProviding`), so a preview
/// or a test can substitute a mock without any feature knowing. Which set gets
/// built is decided by `AppBuildConfiguration`, which is a **compile-time**
/// choice — see the note on that type for why a runtime switch that can select
/// mock services is not something a shipping build should contain.
///
/// ## What is not here
///
/// No feature state, no navigation, no view models. This is a bag of services
/// with a lifetime, not an application object. A feature takes the one or two
/// services it needs from it and holds those, so a screen's dependencies are
/// legible from its initialiser rather than from a global.
@MainActor
final class AppEnvironment {
    let configuration: AppBuildConfiguration
    let clock: any HopClock

    let persistence: PersistenceController
    let repositories: RepositorySet
    let settingsStore: AppSettingsStore

    let notifications: any NotificationProviding
    let audio: any AudioProviding
    let haptics: any HapticProviding
    let purchases: any PurchaseProviding

    let rewards: RewardCoordinator
    let scheduling: PauseSchedulingService
    let export: DataExportService
    let deletion: DataDeletionService

    /// How the store came up. Drives the one calm parent-facing notice when a
    /// launch had to recover — never shown to the child.
    var storeOutcome: PersistenceController.Outcome { persistence.outcome }

    init(
        configuration: AppBuildConfiguration,
        clock: any HopClock,
        persistence: PersistenceController,
        repositories: RepositorySet,
        notifications: any NotificationProviding,
        audio: any AudioProviding,
        haptics: any HapticProviding,
        purchases: any PurchaseProviding
    ) {
        self.configuration = configuration
        self.clock = clock
        self.persistence = persistence
        self.repositories = repositories
        self.notifications = notifications
        self.audio = audio
        self.haptics = haptics
        self.purchases = purchases

        self.settingsStore = AppSettingsStore(repository: repositories.settings)
        self.rewards = RewardCoordinator(
            rewards: repositories.rewards,
            pond: repositories.pond,
            clock: clock
        )
        self.scheduling = PauseSchedulingService(
            schedules: repositories.schedules,
            profiles: repositories.profiles,
            notifications: notifications,
            settings: repositories.settings,
            clock: clock
        )
        self.export = DataExportService(repositories: repositories, clock: clock)
        self.deletion = DataDeletionService(repositories: repositories, clock: clock)

        // One fan-out point for the settings that change how a service behaves.
        // Without it, every settings screen would have to remember to poke the
        // audio service, and one of them eventually would not.
        self.settingsStore.onChange = { [weak self] settings in
            self?.audio.apply(settings)
            self?.haptics.apply(settings)
        }
    }

    // MARK: - Construction

    /// The set this build should use. The one call `HopPottyApp` makes.
    static func resolved() -> AppEnvironment {
        switch AppBuildConfiguration.resolved {
        case .live: live()
        case .mock: mock()
        }
    }

    /// Real store, real notifications, real StoreKit.
    static func live() -> AppEnvironment {
        let clock = SystemClock()
        let persistence = PersistenceController.live()
        let repositories = Self.repositories(from: persistence)
        let settings = AppSettings()

        return AppEnvironment(
            configuration: .live,
            clock: clock,
            persistence: persistence,
            repositories: repositories,
            notifications: NotificationService(clock: clock),
            audio: AudioService(settings: settings),
            haptics: HapticService(settings: settings),
            purchases: PurchaseService(clock: clock)
        )
    }

    /// Everything in memory and nothing that touches a system service.
    ///
    /// Previews and tests. Nothing here asks for notification permission, opens
    /// a store file, or talks to StoreKit — a preview that did any of those
    /// would be a preview that changes the developer's device state.
    static func mock(
        repositories: RepositorySet? = nil,
        clock: any HopClock = SystemClock(),
        entitlement: HopEntitlement = .free
    ) -> AppEnvironment {
        AppEnvironment(
            configuration: .mock,
            clock: clock,
            persistence: PersistenceController.ephemeral(),
            repositories: repositories ?? .inMemory(),
            notifications: MockNotificationService(),
            audio: MockAudioService(),
            haptics: MockHapticService(),
            purchases: MockPurchaseService(entitlement: entitlement)
        )
    }

    /// SwiftData repositories when there is a container, in-memory ones when
    /// there is not.
    ///
    /// This is the line that makes a failed store survivable rather than fatal:
    /// the app is fully functional either way, and the only difference is
    /// whether this session is written down.
    private static func repositories(from persistence: PersistenceController) -> RepositorySet {
        guard let context = persistence.mainContext else {
            HopLog.persistence.fault("running on in-memory repositories; nothing will be saved")
            return .inMemory()
        }
        return .swiftData(context: context)
    }

    // MARK: - Launch

    /// Brings the app up: settings, permissions, entitlements, warnings.
    ///
    /// Ordered so the child-facing path is ready first. Settings decide what the
    /// first screen looks like; the notification permission and the store round
    /// trip can finish while a child is already tapping.
    func bootstrap() async {
        await settingsStore.load()

        // Fan the loaded values out once. The services were built with defaults.
        audio.apply(settingsStore.settings)
        haptics.apply(settingsStore.settings)

        await notifications.refreshPermission()
        await purchases.loadProducts()
        await purchases.refreshEntitlements()

        do {
            try await scheduling.applyNotificationSettings(settingsStore.settings)
        } catch {
            HopLog.scheduling.error(
                "warning refresh failed at launch error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }

        if storeOutcome.needsCaregiverNotice {
            HopLog.persistence.error(
                "launch outcome needs caregiver notice outcome=\(String(describing: self.storeOutcome), privacy: .public)"
            )
        }
    }

    /// Called when the app comes to the foreground.
    func refresh() async {
        await notifications.refreshPermission()
        await purchases.refreshEntitlements()
        do {
            try await scheduling.refreshAllWarnings()
        } catch {
            HopLog.scheduling.error(
                "warning refresh failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
    }

    /// Called when the app goes to the background. Audio stops; nothing else
    /// needs saying, because every write already happened at its call site.
    func enterBackground() {
        audio.stopAll()
    }
}

// MARK: - SwiftUI

private struct AppEnvironmentKey: EnvironmentKey {
    /// Optional with a `nil` default on purpose. A non-optional default would
    /// have to build a whole environment — opening a store — merely to satisfy
    /// SwiftUI's requirement for a default value, which would mean a preview
    /// that forgot to inject one silently wrote to the real store.
    static let defaultValue: AppEnvironment? = nil
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment? {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

extension View {
    func hopEnvironment(_ environment: AppEnvironment) -> some View {
        self.environment(\.appEnvironment, environment)
    }
}
