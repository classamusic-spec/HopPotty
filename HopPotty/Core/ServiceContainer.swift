import Foundation
import HopPottyCore

/// The platform services, assembled once and injected as protocols.
///
/// ## Where this sits
///
/// `AppEnvironment` (`App/AppEnvironment.swift`) is the composition root: it
/// owns the process — the clock, the store, the launch hooks. This type owns the
/// *platform services* that sit on top of that store: notifications, audio,
/// haptics, purchases, and the three coordinators that join them to
/// `HopPottyCore`. Keeping them apart means the entry point does not have to
/// know how a reward is awarded, and the feature layer does not have to know how
/// a `ModelContainer` is opened.
///
/// A feature takes the one or two services it needs from here and holds those.
/// Nothing takes the container itself — a screen whose initialiser says
/// `ServiceContainer` has told you nothing about what it touches.
///
/// ## Protocol injection, compile-time selection
///
/// Every service is an existential (`any AudioProviding`), so a preview or a
/// test substitutes a fake without any feature knowing. **Which** set is built
/// is decided by `AppBuildConfiguration`, a compile-time value — see that type
/// for why a runtime switch able to select fakes is not something a shipping
/// binary should contain.
@MainActor
final class ServiceContainer {
    let configuration: AppBuildConfiguration
    let clock: any HopClock
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

    init(
        configuration: AppBuildConfiguration,
        clock: any HopClock,
        repositories: RepositorySet,
        notifications: any NotificationProviding,
        audio: any AudioProviding,
        haptics: any HapticProviding,
        purchases: any PurchaseProviding
    ) {
        self.configuration = configuration
        self.clock = clock
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

    /// The set this build should use, given a store that is already open.
    static func resolved(
        configuration: AppBuildConfiguration = .resolved,
        repositories: RepositorySet,
        clock: any HopClock = SystemClock()
    ) -> ServiceContainer {
        switch configuration {
        case .live: live(repositories: repositories, clock: clock)
        case .mock: mock(repositories: repositories, clock: clock)
        }
    }

    /// Real notifications, real audio session, real StoreKit.
    static func live(
        repositories: RepositorySet,
        clock: any HopClock = SystemClock()
    ) -> ServiceContainer {
        let settings = AppSettings()
        return ServiceContainer(
            configuration: .live,
            clock: clock,
            repositories: repositories,
            notifications: NotificationService(clock: clock),
            audio: AudioService(settings: settings),
            haptics: HapticService(settings: settings),
            purchases: PurchaseService(clock: clock)
        )
    }

    /// Fakes throughout.
    ///
    /// Previews, tests and the DebugMock scheme. Nothing here asks for
    /// notification permission, opens an audio session, or talks to StoreKit —
    /// a preview that did any of those would change the developer's own device
    /// state every time a canvas refreshed.
    static func mock(
        repositories: RepositorySet = .inMemory(),
        clock: any HopClock = SystemClock(),
        entitlement: HopEntitlement = .free,
        notificationPermission: NotificationPermission = .authorized
    ) -> ServiceContainer {
        ServiceContainer(
            configuration: .mock,
            clock: clock,
            repositories: repositories,
            notifications: MockNotificationService(permission: notificationPermission),
            audio: MockAudioService(),
            haptics: MockHapticService(),
            purchases: MockPurchaseService(entitlement: entitlement)
        )
    }

    // MARK: - Lifecycle

    /// Brings the services up: settings first, then the things that can take a
    /// round trip.
    ///
    /// Ordered so the child-facing path is ready first. Settings decide what the
    /// first screen looks like; the notification permission and the StoreKit
    /// round trip can finish while a child is already tapping.
    func start() async {
        await settingsStore.load()

        // The services were constructed with defaults; fan the loaded values out
        // once, before anything is played or scheduled.
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
    }

    /// Foreground. Permission and entitlement can both change while the app is
    /// away — Settings, a refund, a Family Sharing change — and a warning
    /// scheduled yesterday may now be in the past.
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

    /// Background. Audio stops; nothing else needs saying, because every write
    /// already happened at its own call site.
    func enterBackground() {
        audio.stopAll()
    }
}
