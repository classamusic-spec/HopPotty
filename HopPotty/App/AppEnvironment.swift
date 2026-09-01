import Foundation
import Observation
import OSLog
import SwiftData

/// The composition root: the process-level world, built once, at launch.
///
/// ## What belongs here, and what does not
///
/// Wiring, and only wiring. There is no rule in this file about pauses, stars,
/// quiet hours or copy — those live in `HopPottyCore` and are tested on Linux.
/// If a decision ever starts being made here, it is in the wrong place: the
/// composition root is the one file that cannot be unit-tested without standing
/// up the whole app.
///
/// The split with `ParentEnvironment` is deliberate and worth stating, because
/// two objects called "environment" invite exactly the wrong guess:
///
/// | | `AppEnvironment` | `ParentEnvironment` |
/// | --- | --- | --- |
/// | Owns | the *process* — store, clock, launch hooks | the *feature graph* — the caregiver's services and shared UI state |
/// | Lives for | the lifetime of the app | the lifetime of the parent surface |
/// | Built by | `HopPottyApp`, before any view exists | the feature layer, from this object's `repositories`, `clock` and `configuration` |
///
/// The entry point does not assemble the feature graph. It cannot: the services
/// that graph needs are Screen Time, purchases, notifications, export and
/// deletion, and deciding how those fit together is product work that would then
/// be sitting in `@main`.
///
/// ## Real services versus fakes
///
/// Chosen by **build configuration**, never by a runtime flag a user could flip.
/// `AppBuildConfiguration` (`Core/AppConfiguration.swift`) reads the compile-time
/// `HOPPOTTY_MOCKS` flag; the `#if HOPPOTTY_DEBUG_TOOLS` guard around
/// `makeReconciler` decides whether a fake is even *present*:
///
/// | Configuration | `HOPPOTTY_DEBUG_TOOLS` | `HOPPOTTY_MOCKS` | Result |
/// | --- | --- | --- | --- |
/// | Release | not defined | not defined | Live services. The fake is not in the binary. |
/// | Debug | defined | not defined | Live services — except in an Xcode preview or a test host, which `AppBuildConfiguration.resolved` detects. |
/// | DebugMock | defined | defined | Fakes. |
///
/// The first row is the one that matters. In a shipping build the branch that
/// returns a fake does not exist, so no debug menu, no URL scheme and no bug can
/// reach it.
@MainActor
@Observable
final class AppEnvironment {

    /// Which world this instance was built for. Read by the feature layer so the
    /// parent graph is assembled from the same decision, and by the parent
    /// diagnostics screen so a tester can see, in the app, whether they are
    /// looking at real Screen Time behaviour.
    let configuration: AppBuildConfiguration

    /// The only legitimate source of "what time is it" in the app layer.
    let clock: any HopClock

    /// Owns the `ModelContainer` and the recovery ladder that keeps a failed
    /// store from becoming a failed launch.
    let persistence: PersistenceController

    /// The nine repositories, already bound to a store — SwiftData when one
    /// opened, in-memory when none did.
    let repositories: RepositorySet

    /// The launch and foreground hooks. The scene has exactly one thing to call.
    let launch: AppLaunchCoordinator

    /// Whether anything written this session will survive relaunch. The parent
    /// area explains it to the caregiver; nothing is ever said to the child.
    var isStoreAvailable: Bool { persistence.outcome.persistsWrites }

    private init(
        configuration: AppBuildConfiguration,
        clock: any HopClock,
        persistence: PersistenceController,
        repositories: RepositorySet,
        reconciler: any ScreenTimeReconciling
    ) {
        self.configuration = configuration
        self.clock = clock
        self.persistence = persistence
        self.repositories = repositories
        self.launch = AppLaunchCoordinator(reconciler: reconciler, clock: clock)
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
        let persistence = makePersistence(configuration)
        let repositories = makeRepositories(persistence)

        HopLog.persistence.info(
            "environment built configuration=\(configuration.rawValue, privacy: .public) store=\(String(describing: persistence.outcome), privacy: .public) persists=\(persistence.outcome.persistsWrites, privacy: .public)"
        )

        return AppEnvironment(
            configuration: configuration,
            clock: SystemClock(),
            persistence: persistence,
            repositories: repositories,
            reconciler: makeReconciler(configuration)
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
        // binds any future `@Query` to `mainContext` too. A second context here
        // would give the app two sets of unsaved changes on the same actor — the
        // exact split `RepositorySet` exists to prevent, where a deletion
        // spanning seven tables is one unit of work in one context and a
        // half-deleted child in the other.
        return .swiftData(context: container.mainContext)
    }

    /// The one place the app decides whether Screen Time is real.
    ///
    /// See `ScreenTimeReconciling` for why the port is one method wide.
    private static func makeReconciler(_ configuration: AppBuildConfiguration) -> any ScreenTimeReconciling {
        #if HOPPOTTY_DEBUG_TOOLS
        if configuration == .mock {
            // Previews, test hosts and the DebugMock scheme. Never a device
            // build that a family could be holding.
            return InMemoryScreenTimeReconciler()
        }
        return ScreenTimeService()
        #else
        // Release: one branch, no condition, nothing to flip.
        return ScreenTimeService()
        #endif
    }
}
