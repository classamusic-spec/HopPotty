import SwiftUI
import HopPottyCore

/// The one symbol `HopPottyApp` asks the feature layer for.
///
/// `AppEnvironment` deliberately stops at the process boundary — the store, the
/// clock, the launch hooks — and does not assemble the caregiver's service
/// graph. This view is where the two halves meet: it builds `ParentEnvironment`
/// from the process environment, loads the caregiver's settings and profiles
/// once, and hands the tree to `ParentAppRootView`, which chooses between
/// onboarding and the dashboard.
///
/// The graph is built here rather than in `HopPottyApp` for a practical reason:
/// it needs the main actor and it needs to `await` a first read from the store,
/// neither of which an `App`'s initialiser can do.
struct RootView: View {
    @Environment(AppEnvironment.self) private var app

    /// Nil until the first load finishes. The loading state is real, not a
    /// formality: on a cold launch this is a disk read, and a caregiver opening
    /// the app to a half-populated dashboard would read it as data loss.
    @State private var parent: ParentEnvironment?

    /// The Quick Reminder service, handed down through
    /// `EnvironmentValues.quickReminders`.
    ///
    /// Held apart from `ParentEnvironment` on purpose: a Quick Reminder touches
    /// no repository, no schedule and no child record, so the screens that
    /// never mention one should not gain a reference to it. See the environment
    /// key in `Features/QuickReminder/QuickReminderChip.swift`.
    @State private var quickReminders: (any QuickReminderProviding)?

    var body: some View {
        HopThemedRoot {
            if let parent {
                ParentAppRootView()
                    .environment(parent)
                    .environment(\.quickReminders, quickReminders)
            } else {
                HopLoadingState(message: nil)
            }
        }
        .task {
            guard parent == nil else { return }
            let services = Self.makeServices(app)
            let environment = Self.makeParentEnvironment(app, services: services)
            await environment.reload()
            await services.quickReminders.refresh()
            quickReminders = services.quickReminders
            parent = environment
        }
    }

    /// Assembles the caregiver's service graph.
    ///
    /// `isStoreAvailable` is threaded through rather than assumed: when the
    /// store failed to open, every screen still works and Settings says so.
    ///
    /// Screen Time comes from `ScreenTimeEnvironment.resolved`, which is the one
    /// place in the app that decides whether the Screen Time layer is real — the
    /// only other caller is `AppEnvironment.makeReconciler`, which needs just the
    /// one-method reconciliation port at launch. Both branch on the same
    /// compile-time configuration, so they cannot disagree at runtime, and in a
    /// Release build the branch that could answer "fake" does not exist: the
    /// mock is inside `#if DEBUG` and is not in the binary.
    @MainActor
    private static func makeParentEnvironment(
        _ app: AppEnvironment,
        services: ServiceContainer
    ) -> ParentEnvironment {
        let screenTime = ScreenTimeEnvironment.resolved(configuration: app.configuration)
        return ParentEnvironment(
            repositories: app.repositories,
            screenTime: ParentScreenTimeAdapter(
                service: screenTime.screenTime,
                monitoring: screenTime.monitoring,
                clock: app.clock
            ),
            purchases: services.purchases,
            notifications: services.notifications,
            deletion: services.deletion,
            export: services.export,
            liveActivities: services.liveActivities,
            clock: app.clock,
            settings: services.settingsStore.settings,
            isStoreAvailable: app.isStoreAvailable
        )
    }

    @MainActor
    private static func makeServices(_ app: AppEnvironment) -> ServiceContainer {
        #if HOPPOTTY_DEBUG_TOOLS
        if app.configuration == .mock {
            return .mock(repositories: app.repositories, clock: app.clock)
        }
        return .live(repositories: app.repositories, clock: app.clock)
        #else
        return .live(repositories: app.repositories, clock: app.clock)
        #endif
    }
}
