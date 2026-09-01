import SwiftData
import SwiftUI

/// The entry point.
///
/// Deliberately the shortest file in the app. Everything it does is one of three
/// things: build the world (`AppEnvironment`), hand it to the view tree, and run
/// the lifecycle hooks the Screen Time design depends on. There is no state
/// here, no business rule, and nothing a test would want to reach.
@main
struct HopPottyApp: App {

    /// Built once, at launch, and never replaced. `@State` rather than a stored
    /// property so SwiftUI owns its lifetime and the same instance survives
    /// every re-evaluation of `body`.
    @State private var environment = AppEnvironment.bootstrap()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            root
        }
    }

    @ViewBuilder
    private var root: some View {
        rootContent
            // The design system's single resolver of light / dark / increased
            // contrast / Reduce Motion. Installed once, here; nothing downstream
            // reads `colorScheme` itself.
            .hopThemedRoot()
            // Everything the feature layer needs, read with
            // `@Environment(AppEnvironment.self)`.
            .environment(environment)
            .task {
                // Cold start. This is the floor under every other way a Potty
                // Pause can end: it runs because the app ran, not because
                // something woke us. See AppLaunchCoordinator for why it always
                // clears rather than trying to be clever about what it finds.
                environment.launch.runColdStartReconciliation()
            }
            .onChange(of: scenePhase) { _, phase in
                // The caregiver could have revoked Screen Time in Settings, an
                // extension could have ended the pause, or the device could have
                // been asleep past the ceiling. Ask again rather than assume.
                guard phase == .active else { return }
                environment.launch.runForegroundReconciliation()
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        if let container = environment.persistence.container {
            // Installs the same container whose `mainContext` the repositories
            // hold, so a `@Query` and a repository read never disagree.
            rootView.modelContainer(container)
        } else {
            // The store ladder bottomed out. The app still launches on the
            // in-memory repository set; the parent area explains what is missing.
            // Installing no container is correct here — `.modelContainer(_:)`
            // has no failure mode that leaves the app usable.
            rootView
        }
    }

    /// INTEGRATION SEAM — the one symbol this file expects from the feature
    /// layer.
    ///
    /// `RootView` is owned by `HopPotty/Features/`. It decides between
    /// onboarding, the child surface and the parent area; that decision is
    /// product behaviour and does not belong in the entry point. If the feature
    /// layer names it something else, this is the single line to change, and the
    /// compiler will say so by name.
    private var rootView: some View {
        RootView()
    }
}
