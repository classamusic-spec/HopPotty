import Foundation
import Observation
import OSLog
import SwiftData

/// The composition root.
///
/// Everything the app needs is built here, once, at launch, and handed down. No
/// singletons, no service locator, no `shared` reachable from a view. A feature
/// that wants the reward repository is given the reward repository; it cannot
/// reach out and take the whole world.
///
/// ## What this file may contain
///
/// Wiring. Nothing else. There is no rule in here about pauses, stars, quiet
/// hours or copy — those live in `HopPottyCore` and are tested on Linux. If a
/// decision ever starts being made in this file, it is in the wrong place: the
/// composition root is the one file that cannot be unit-tested without standing
/// up the whole app.
///
/// ## Real services versus fakes
///
/// Chosen by **build configuration**, never by a runtime flag a user could flip.
/// The mechanism is `AppBuildConfiguration` (`Core/AppConfiguration.swift`) plus
/// the `#if HOPPOTTY_DEBUG_TOOLS` guard around `makeScreenTime`:
///
/// | Configuration | `HOPPOTTY_DEBUG_TOOLS` | `HOPPOTTY_MOCKS` | Result |
/// | --- | --- | --- | --- |
/// | Release | not defined | not defined | Live services. The fake is not compiled into the binary at all. |
/// | Debug | defined | not defined | Live services — except inside an Xcode preview or a test host, which `AppBuildConfiguration.resolved` detects. |
/// | DebugMock | defined | defined | Fakes everywhere. |
///
/// The important row is the first. In a shipping build the branch that returns a
/// fake Screen Time service does not exist, so no bug, no debug menu and no
/// forgotten launch argument can reach it.
@MainActor
@Observable
final class AppEnvironment {

    /// Which world this instance was built for. Read by the parent diagnostics
    /// screen so a tester can see, in the app, whether they are looking at real
    /// Screen Time behaviour.
    let configuration: AppBuildConfiguration

    /// The only legitimate source of "what time is it" in the app layer.
    let clock: any HopClock

    /// Owns the `ModelContainer` and the recovery ladder that keeps a failed
    /// store from becoming a failed launch.
    let persistence: PersistenceController

    /// The nine repositories, already bound to a store — SwiftData when one
    /// opened, in-memory when none did.
    let repositories: RepositorySet

    /// Authorization, selection, shield and reconciliation.
    let screenTime: any ScreenTimeProviding

    /// The launch and foreground hooks. Held here so the scene has exactly one
    /// thing to call.
    let launch: AppLaunchCoordinator

    private init(
        configuration: AppBuildConfiguration,
        clock: any HopClock,
        persistence: PersistenceController,
        repositories: RepositorySet,
        screenTime: any ScreenTimeProviding
    ) {
        self.configuration = configuration
        self.clock = clock
        self.persistence = persistence
        self.repositories = repositories
        self.screenTime = screenTime
        self.launch = AppLaunchCoordinator(screenTime: screenTime, clock: clock)
    }

    // MARK: - Construction

    /// Build the world for this process.
    ///
    /// Deliberately total: it cannot fail and it cannot throw. A caregiver
    /// opening this app is usually holding a child who has just announced an
    /// emergency, so every failure below degrades to something that still
    /// launches — an in-memory store, a Screen Time service that reports it
    /// cannot shield — rather than to a crash or a blocking error screen.
    static func bootstrap(configuration: AppBuildConfiguration = .resolved) -> AppEnvironment {
        let clock = SystemClock()
        let persistence = makePersistence(configuration)
        let repositories = makeRepositories(persistence)
        let screenTime = makeScreenTime(configuration)

        HopLog.persistence.info(
            "environment built configuration=\(configuration.rawValue, privacy: .public) store=\(String(describing: persistence.outcome), privacy: .public) persists=\(persistence.outcome.persistsWrites, privacy: .public)"
        )

        return AppEnvironment(
            configuration: configuration,
            clock: clock,
            persistence: persistence,
            repositories: repositories,
            screenTime: screenTime
        )
    }

    private static func makePersistence(_ configuration: AppBuildConfiguration) -> PersistenceController {
        switch configuration {
        case .live: .live()
        case .mock: .ephemeral()
        }
    }

    private static func makeRepositories(_ persistence: PersistenceController) -> RepositorySet {
        // No container means the store ladder bottomed out (Outcome.unavailable).
        // The in-memory set satisfies the same protocols, so every feature still
        // works for this session and the parent area explains why nothing saved.
        guard let container = persistence.container else { return .inMemory() }

        // `mainContext`, deliberately, and not `ModelContext(container)`. The
        // scene installs the same container with `.modelContainer(_:)`, which
        // binds any future `@Query` to `mainContext` too. Building a second
        // context here would give the app two sets of unsaved changes on the
        // same actor — the exact split `RepositorySet` exists to prevent, where
        // a deletion spanning seven tables is a deletion in one context and a
        // half-deleted child in the other.
        return .swiftData(context: container.mainContext)
    }

    /// The one place the app decides whether Screen Time is real.
    ///
    /// `PreviewScreenTimeService` is the in-memory conformance promised by
    /// `Docs/Entitlements.md` §4: it simulates authorization, selection, shield
    /// application and pause expiry so the Simulator, previews and UI tests never
    /// depend on Family Controls — which may not work in the Simulator at all
    /// (`Docs/ScreenTimeArchitecture.md` §12.7).
    ///
    /// INTEGRATION SEAM. This is the only reference to it in the app layer. It
    /// is owned by `HopPotty/Services/ScreenTime/`; if it has not landed yet, a
    /// Debug build will not compile until it does, and a Release build will,
    /// because this branch is not part of a Release build.
    private static func makeScreenTime(_ configuration: AppBuildConfiguration) -> any ScreenTimeProviding {
        #if HOPPOTTY_DEBUG_TOOLS
        if configuration == .mock {
            return PreviewScreenTimeService()
        }
        return ScreenTimeService()
        #else
        // Release: one branch, no condition, nothing to flip.
        return ScreenTimeService()
        #endif
    }
}
